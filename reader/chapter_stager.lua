-- Sequential chapter staging. Dependencies provide bounded streaming downloads,
-- a private directory, and archive creation; no network or filesystem is global.
local Stager = {}
function Stager.start(deps, pages, target, callback)
    assert(deps and deps.download and deps.remove and deps.validate and deps.build)
    if type(pages) ~= "table" or #pages == 0 then callback(nil, "Empty chapter"); return end
    if #pages > (deps.max_pages or 500) then callback(nil, "Too many pages"); return end
    local job = {cancelled=false, finished=false, files={}}
    local index = 0
    local function finish(ok, err)
        if job.finished then return end
        job.finished = true
        for _, item in ipairs(job.files) do deps.remove(item.path) end
        callback(ok, err)
    end
    function job:cancel()
        if self.finished then return end
        self.cancelled = true
        if self.cancel_download then self.cancel_download() else finish(nil, "Cancelled") end
    end
    local function next_page()
        if job.finished then return end
        index = index + 1
        if index > #pages then
            local ok, result, err = pcall(deps.build, target, job.files)
            if not ok then return finish(nil, "Archive creation failed") end
            return finish(result, err)
        end
        local page = pages[index]
        if type(page) ~= "table" or type(page.image_url) ~= "string" or not page.image_url:match("^https://") then return finish(nil, "Invalid image URL") end
        local path = deps.pathFor(index)
        if type(path) ~= "string" then return finish(nil, "Invalid staging path") end
        -- Register before starting: interrupted and rejected downloads must be removed too.
        local item = {path=path}; job.files[#job.files+1] = item
        local completed = false
        local function on_download(meta, err)
            if completed then return end
            completed = true
            if job.finished then deps.remove(path); return end
            job.cancel_download = nil
            if job.cancelled then return finish(nil, "Cancelled") end
            if not meta then return finish(nil, err or "Download failed") end
            local extension, validation_error = deps.validate(meta.content_type, meta.size, meta.prefix, deps.max_image_bytes)
            if not extension then return finish(nil, validation_error) end
            item.extension = extension
            if deps.progress then deps.progress(index, #pages) end
            next_page()
        end
        local ok, cancel = pcall(deps.download, page, path, deps.max_image_bytes or 20971520, on_download)
        if not ok then return finish(nil, "Download failed") end
        if not completed and not job.finished and type(cancel) == "function" then job.cancel_download = cancel end
    end
    next_page()
    return job
end
return Stager
