-- Coordinates a single chapter using injected source, storage and reader APIs.
local Reader = {}
local module_path=debug.getinfo(1,"S").source:sub(2):match("^(.*[/\\])") or "reader/"
local ArchiveCheck=dofile(module_path .. "archive_check.lua")
function Reader.open(deps, manga, chapter, callback)
    if not manga or not chapter or chapter.manga_id ~= manga.id then callback(nil,"Invalid chapter"); return end
    if deps.fs.targetFor then
        local existing = deps.library.archiveFor and deps.library:archiveFor(manga.source_id,manga.id,chapter.id)
        if not existing or not deps.fs.exists(existing) then existing = deps.fs.targetFor(manga.source_id,manga.id,chapter.id) end
        if existing and deps.fs.exists(existing .. ".incomplete") then callback(nil,"Incomplete archive; clear incomplete files before retrying"); return end
        local already_in_archive=deps.library.archiveHasChapter and deps.library:archiveHasChapter(existing,chapter.id)
        if already_in_archive==nil then already_in_archive=deps.fs.exists(existing) end
        if existing and deps.fs.exists(existing) and already_in_archive then
            local expected=deps.library.archiveDigest and deps.library:archiveDigest(existing)
            local function checked(valid,digest,why)
                if not valid then return callback(nil,why or "Downloaded archive is invalid") end
                if expected and digest~=expected then return callback(nil,"Downloaded file has changed; verify it before repair") end
                local saved,err=deps.library:linkArchive(existing,manga,chapter)
                if not saved then return callback(nil,err) end
                callback(true); deps.openDocument(existing)
            end
            if deps.verifyExisting then return deps.verifyExisting(existing,not not expected,checked) end
            local valid,why=ArchiveCheck.validate(existing,deps.archiver,deps.fs.verifyEntry)
            if expected then return callback(nil,"Archive hash verification unavailable") end
            checked(valid,nil,why); return
        end
    end
    local paths, err = deps.fs.prepare(manga.source_id,manga.id,chapter.id)
    if not paths then callback(nil,err); return end
    local finished=false
    local legacy_archives=deps.legacyArchives and deps.legacyArchives(manga,paths.target) or {}
    local controller={cancelled=false}
    function controller:cancel()
        self.cancelled=true
        if self.job then self.job:cancel() elseif self.source_job and self.source_job.cancel then self.source_job:cancel() end
    end
    local function finish(ok, failure)
        if finished then return end
        finished=true
        deps.removeDir(paths.staging)
        callback(ok,failure)
    end
    local source_completed=false
    local started,source_job=pcall(deps.source.getPageList,deps.source,chapter,function(pages, failure)
        source_completed=true
        if controller.cancelled then return finish(nil,"Cancelled") end
        if not pages then return finish(nil,failure or "Unable to load chapter") end
        local staged={
            pathFor=function(i) return paths.staging .. "/" .. string.format("%06d",i) .. ".image" end,
            download=deps.download, remove=deps.fs.remove, validate=deps.validate, progress=deps.progress,
            build=function(target,items) return deps.build(deps.archiver,deps.fs,target,items,chapter.name,legacy_archives) end,
            buildAsync=deps.buildAsync and function(target,items,callback) return deps.buildAsync(target,items,chapter,legacy_archives,callback) end or nil,
        }
        local staging_finished=false
        local staging_job=deps.stager.start(staged,pages,paths.target,function(ok,stage_err)
            staging_finished=true
            if not ok then return finish(nil,stage_err) end
            local function linked(digest,hash_error)
                if not digest and deps.hashArchive then return finish(nil,hash_error or "Unable to hash archive") end
                local saved,save_err=deps.library:linkArchive(paths.target,manga,chapter,#pages,digest)
                if not saved then return finish(nil,save_err or "Unable to save archive metadata") end
                if deps.library.mergeArchiveRecords then
                    local merged,old_paths=deps.library:mergeArchiveRecords(paths.target,manga,digest)
                    if not merged then return finish(nil,"Archive saved but legacy metadata could not be migrated: "..tostring(old_paths)) end
                    for _,old_path in ipairs(old_paths) do if old_path~=paths.target then deps.fs.remove(old_path) end end
                end
                finish(true)
                deps.openDocument(paths.target)
            end
            if deps.hashArchive then controller.job=deps.hashArchive(paths.target,linked) else linked(nil) end
        end)
        if not staging_finished then controller.job=staging_job end
    end)
    if not started then finish(nil,"Unable to load chapter")
    elseif not source_completed then controller.source_job=source_job end
    return controller
end
return Reader
