-- KOReader Turbo transport. Certificate verification is mandatory.
local M = {}
function M.new(ui, turbo, json, queue_class)
    assert(ui and turbo and json and queue_class)
    local pending = 0
    return queue_class.new({
        decode = json.decode,
        schedule = function(delay, callback) ui:scheduleIn(delay, callback) end,
        request = function(url, callback)
            ui:initLooper()
            if not ui.looper then return callback(nil, nil, "Asynchronous networking is unavailable") end
            ui.looper:add_callback(function()
                pending = pending + 1
                ui:setInputTimeout()
                local client = turbo.async.HTTPClient({verify_ca=true}, nil, 2097152)
                local response = coroutine.yield(client:fetch(url, {
                    method="GET", allow_redirects=false, connect_timeout=10, request_timeout=30,
                    user_agent="MaruMangaDownloader/0.1 (KOReader)",
                }))
                pending = pending - 1
                if pending == 0 then ui:resetInputTimeout() end
                if not response then return callback(nil, nil, "Empty network response") end
                if response.error and not response.code then return callback(nil, nil, "Connection or TLS verification failed") end
                callback(response.code, response.body, response.error and "Request failed" or nil)
            end)
        end,
    })
end
return M
