-- Stream a MangaDex image into an owned staging path in a subprocess.
local Downloader = {}
function Downloader.new(trapper, request, dependencies, files, runner, deadline)
    files = files or {open=io.open, remove=os.remove}
    return function(page, path, limit, callback)
        local cancelled = false
        local handle
        local function task()
                local file, why = files.open(path, "wb")
                if not file then return nil, nil, why or "Cannot create staging file" end
                local deps = dependencies()
                deps.images = true; deps.max_bytes = limit; deps.referer = page.referer; deps.headers = page.headers
                deps.write = function(chunk) return file:write(chunk) end
                local clock=deps.socket and deps.socket.gettime or os.time
                local started=clock()
                local ok, status, result, failure = pcall(request.fetch, page.image_url, deps)
                local duration=math.max(0,math.floor((clock()-started)*1000))
                local closed = file:close()
                local host=page.image_url:match("^https://([%w%.%-]+)")
                if page.report_mangadex and host and (host=="mangadex.network" or host:match("%.mangadex%.network$")) then
                    -- Report network health without including source cookies or authorization.
                    local encoded_ok,encoded=pcall(require("json").encode,{
                        url=page.image_url,success=ok and status==200 and not not closed,
                        bytes=type(result)=="table" and result.size or 0,duration=duration,
                        cached=type(result)=="table" and result.cached or false,
                    })
                    if encoded_ok then
                        local report={socket=deps.socket,ssl=deps.ssl,http=deps.http,cafile=deps.cafile,capath=deps.capath,timeout=5,
                            method="POST",body=encoded,allowed_hosts={["api.mangadex.network"]=true},
                            headers={["Content-Type"]="application/json"},max_bytes=16384}
                        pcall(request.fetch,"https://api.mangadex.network/report",report)
                    end
                end
                if not ok then return nil, nil, "Image request failed" end
                if not closed then return nil, nil, "Could not finish image file" end
                return status, result, failure
        end
        local function done(complete,code,meta,err)
            if cancelled then files.remove(path); return callback(nil, "Cancelled") end
            if not complete then files.remove(path); return callback(nil, err or "Download cancelled") end
            if code ~= 200 then files.remove(path); return callback(nil, err or (code and ("HTTP " .. code) or "Download failed")) end
            callback(meta)
        end
        if runner then handle=runner.run(task,deadline or 35,done)
        else trapper:wrap(function() local complete,code,meta,err=trapper:dismissableRunInSubprocess(task,false); done(complete,code,meta,err) end) end
        return function() cancelled=true; if handle and handle.cancel then handle:cancel() end end
    end
end
return Downloader
