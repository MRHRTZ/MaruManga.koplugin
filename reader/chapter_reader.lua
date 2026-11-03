-- Coordinates a single chapter using injected source, storage and reader APIs.
local Reader = {}
function Reader.open(deps, manga, chapter, callback)
    if not manga or not chapter or chapter.manga_id ~= manga.id then callback(nil,"Invalid chapter"); return end
    if deps.fs.targetFor then
        local existing = deps.library.archiveFor and deps.library:archiveFor(manga.source_id,manga.id,chapter.id)
        if not existing or not deps.fs.exists(existing) then existing = deps.fs.targetFor(manga.source_id,manga.id,chapter.id) end
        if existing and deps.fs.exists(existing) then
            local archive=deps.archiver.Reader:new()
            if not archive:open(existing) then callback(nil,"Downloaded archive is invalid"); return end
            local count, valid=0,true
            for entry in archive:iterate() do
                count=count+1
                if entry.mode ~= "file" or not entry.size or entry.size <= 0 or entry.size > 20971520 or not entry.path:match("^%d+%.[%a]+$") then
                    valid=false
                elseif not deps.fs.verifyEntry or not deps.fs.verifyEntry(archive,entry) then
                    valid=false
                end
            end
            if archive.err then valid=false end
            archive:close()
            if not valid or count==0 then callback(nil,"Downloaded archive is invalid"); return end
            local saved,err=deps.library:linkArchive(existing,manga,chapter)
            if not saved then callback(nil,err); return end
            callback(true); deps.openDocument(existing); return
        end
    end
    local paths, err = deps.fs.prepare(manga.source_id,manga.id,chapter.id)
    if not paths then callback(nil,err); return end
    local finished=false
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
    controller.source_job=deps.source:getPageList(chapter,function(pages, failure)
        if controller.cancelled then return finish(nil,"Cancelled") end
        if not pages then return finish(nil,failure or "Unable to load chapter") end
        local staged={
            pathFor=function(i) return paths.staging .. "/" .. string.format("%06d",i) .. ".image" end,
            download=deps.download, remove=deps.fs.remove, validate=deps.validate, progress=deps.progress,
            build=function(target,items) return deps.build(deps.archiver,deps.fs,target,items) end,
        }
        controller.job=deps.stager.start(staged,pages,paths.target,function(ok,stage_err)
            if not ok then return finish(nil,stage_err) end
            local saved, save_err=deps.library:linkArchive(paths.target,manga,chapter,#pages)
            if not saved then return finish(nil,save_err or "Unable to save reading history") end
            finish(true)
            deps.openDocument(paths.target)
        end)
    end)
    return controller
end
return Reader
