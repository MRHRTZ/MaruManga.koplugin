-- Session-only, exact-host cookies. Never persisted or logged.
local Jar={}; Jar.__index=Jar
function Jar.new() return setmetatable({hosts={}},Jar) end
local function parse_url(url)
    local host,path=url:match("^https://([%w%.%-]+):?%d*(/[^?#]*)")
    return host and host:lower(),path
end
function Jar:store(url,header)
    local host,request_path=parse_url(url)
    if not host or type(header)~="string" or #header>4096 or header:find("[\r\n]") then return end
    local first=header:match("^%s*([^;]+)")
    if not first then return end
    local name,value=first:match("^%s*([!#$%%&'*+.%^_`|~%w-]+)=([^;]*)$")
    if not name or not value or value:find("[%c,%s]") then return end
    local path=request_path:match("^(.*)/") or ""
    if path=="" then path="/" end
    local max_age,expires_present
    for part in header:gmatch(";([^;]+)") do
        local k,v=part:match("^%s*([^=%s]+)%s*=%s*(.-)%s*$")
        if k then
            k=k:lower()
            if k=="domain" and v:gsub("^%.",""):lower()~=host then return end
            if k=="path" and v:match("^/") then path=v end
            if k=="max-age" then max_age=tonumber(v) end
            if k=="expires" then expires_present=true end
        end
    end
    -- Expiry dates are not interpreted; omit such cookies unless Max-Age is present.
    if expires_present and not max_age then return end
    local jar=self.hosts[host] or {}; self.hosts[host]=jar
    local id=name .. "\0" .. path
    if max_age and max_age<=0 then jar[id]=nil; return end
    jar[id]={name=name,value=value,path=path,expires=max_age and (os.time()+max_age) or nil}
end
function Jar:header(url)
    local host,path=parse_url(url); local jar=host and self.hosts[host]
    if not jar then return nil end
    local values={}
    for id,cookie in pairs(jar) do
        if cookie.expires and cookie.expires<=os.time() then jar[id]=nil
        elseif path:sub(1,#cookie.path)==cookie.path and (cookie.path:sub(-1)=="/" or #path==#cookie.path or path:sub(#cookie.path+1,#cookie.path+1)=="/") then values[#values+1]=cookie.name .. "=" .. cookie.value end
    end
    table.sort(values)
    if #values>0 then return table.concat(values,"; ") end
end
return Jar
