-- Serialized asynchronous requests, with bounded retries and an injectable clock.
local months={Jan=1,Feb=2,Mar=3,Apr=4,May=5,Jun=6,Jul=7,Aug=8,Sep=9,Oct=10,Nov=11,Dec=12}
local function retry_after(value, now)
    local seconds=tonumber(value)
    if seconds then return math.max(0,seconds) end
    if type(value)~="string" then return nil end
    local d,mon,y,h,mi,se=value:match("^%a%a%a,%s+(%d%d)%s+(%a%a%a)%s+(%d%d%d%d)%s+(%d%d):(%d%d):(%d%d)%s+GMT$")
    d,y,h,mi,se=tonumber(d),tonumber(y),tonumber(h),tonumber(mi),tonumber(se)
    local mo=months[mon]; if not y or not mo or d<1 or d>31 or h>23 or mi>59 or se>60 then return nil end
    if mo<=2 then y=y-1 end
    local era=math.floor(y/400); local yoe=y-era*400; local mp=mo+(mo>2 and -3 or 9)
    local day=era*146097+yoe*365+math.floor(yoe/4)-math.floor(yoe/100)+math.floor((153*mp+2)/5)+d-1-719468
    return math.max(0,day*86400+h*3600+mi*60+se-now)
end
local Client = {}
Client.__index = Client
function Client.new(options)
    assert(options and options.request and options.schedule and options.decode)
    return setmetatable({request=options.request, schedule=options.schedule, decode=options.decode,
        queue={}, active=false, max_attempts=options.max_attempts or 3,
        interval=options.interval or 1, max_bytes=options.max_bytes or 2097152,
        accept_url=options.accept_url or function(url) return url:match("^https://api%.mangadex%.org/") end,
        valid=options.valid or function(value) return type(value)=="table" end, cookies=options.cookies, on_result=options.on_result}, Client)
end
function Client:_submit(url, options, callback)
    if type(url) ~= "string" or not self.accept_url(url) then
        return callback(nil, "Unsupported API URL")
    end
    local task={url=url,options=options,callback=callback,attempts=0,owner=self}
    function task:cancel()
        if self.done then return end
        if self.finish then
            if self.cancelRequest then pcall(self.cancelRequest) end
            return self.finish(nil,"Cancelled")
        end
        for i,item in ipairs(self.owner.queue) do if item==self then table.remove(self.owner.queue,i); break end end
        self.done=true; self.callback(nil,"Cancelled")
    end
    self.queue[#self.queue+1] = task
    self:_next()
    return task
end
function Client:get(url,callback) return self:_submit(url,{},callback) end
function Client:post(url,body,headers,callback)
    if type(body)~="string" or #body>65536 or type(callback)~="function" then return nil,"Invalid POST request" end
    return self:_submit(url,{method="POST",body=body,headers=headers},callback)
end
function Client:_next()
    if self.active or #self.queue == 0 then return end
    self.active = true
    local task = table.remove(self.queue, 1)
    local function finish(data, err)
        if task.done then return end
        task.done=true
        self.schedule(self.interval, function()
            self.active = false
            self:_next()
        end)
        if self.on_result then pcall(self.on_result,err) end
        task.callback(data, err)
    end
    task.finish=finish
    local function attempt()
        if task.done then return end
        task.attempts = task.attempts + 1
        local completed = false
        local function response(code, body, err, headers)
            if completed or task.done then return end
            completed = true
            code = tonumber(code)
            if self.cookies and type(headers)=="table" then
                local values=headers["set-cookie"]
                if type(values)=="string" then self.cookies:store(task.url,values)
                elseif type(values)=="table" then for _,value in ipairs(values) do self.cookies:store(task.url,value) end end
            end
            if (not code or code == 429 or code >= 500) and task.attempts < self.max_attempts then
                -- Back off conservatively after rate limiting; never retry in a tight loop.
                local delay = code == 429 and 30 * task.attempts or math.max(self.interval, 2 ^ (task.attempts - 1))
                if code==429 and type(headers)=="table" then
                    local requested=retry_after(headers["retry-after"],os.time())
                    if requested and requested>delay then delay=requested end
                end
                return self.schedule(delay, attempt)
            end
            if not code then return finish(nil, err or "Network connection failed") end
            if code ~= 200 then return finish(nil, "HTTP " .. code) end
            if type(body) ~= "string" or #body > self.max_bytes then return finish(nil, "Invalid or oversized response") end
            local ok, data = pcall(self.decode, body)
            if not ok or not self.valid(data) then return finish(nil, "Invalid JSON response") end
            finish(data)
        end
        local options={method=task.options.method,body=task.options.body,headers={}}
        for name,value in pairs(task.options.headers or {}) do options.headers[name]=value end
        if self.cookies then
            local cookie=self.cookies:header(task.url)
            if cookie and not options.headers.Cookie and not options.headers.cookie then options.headers.Cookie=cookie end
        end
        local ok,handle = pcall(self.request, task.url, response, options)
        if not ok then response(nil, nil, "Network request failed")
        elseif type(handle)=="table" and type(handle.cancel)=="function" and not task.done then task.cancelRequest=function() handle:cancel() end end
    end
    attempt()
end
return Client
