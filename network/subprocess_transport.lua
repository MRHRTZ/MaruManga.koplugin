-- KOReader's Trapper runs LuaSocket in a child process and yields to the UI.
local M = {}
function M.new(ui, trapper, json, queue_class, secure_request, deps, options)
    options = options or {}
    return queue_class.new({decode=options.decode or json.decode, accept_url=options.accept_url, valid=options.valid, max_attempts=options.max_attempts, cookies=options.cookies, on_result=options.on_result, schedule=function(delay, cb) ui:scheduleIn(delay, cb) end,
        request=function(url, callback, request_options)
            local function task()
                local config=deps()
                if request_options then config.method=request_options.method; config.body=request_options.body; config.headers=request_options.headers end
                local ok, a, b, c, d = pcall(secure_request.fetch, url, config)
                if not ok then return nil, nil, "Secure request failed" end
                return a, b, c, d
            end
            local function done(completed,code,body,err,headers)
                if not completed then return callback(nil,nil,err or "Request cancelled") end
                callback(code,body,err,headers)
            end
            if options.runner then return options.runner.run(task,options.deadline or 35,done) end
            trapper:wrap(function()
                local completed,code,body,err,headers=trapper:dismissableRunInSubprocess(task,false)
                done(completed,code,body,err,headers)
            end)
        end})
end
return M
