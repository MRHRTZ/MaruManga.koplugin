-- Optional per-plugin DNS resolution over the selected UDP DNS server.
-- Auto leaves name resolution to the OS. This does not modify device DNS.
local M = {}
local cache = {}
local next_id = 17321

local function valid_host(host)
    return type(host)=="string" and #host<=253 and host:match("^[%w%.%-]+$") and not host:find("%.%.")
end
local function valid_ipv4(ip)
    if type(ip)~="string" then return false end
    local parts={}
    for part in ip:gmatch("[^%.]+") do
        local n=tonumber(part)
        if not n or n<0 or n>255 or tostring(n)~=part then return false end
        parts[#parts+1]=n
    end
    return #parts==4
end
local function u16(data,pos)
    local a,b=data:byte(pos,pos+1)
    if not b then return nil end
    return a*256+b
end
local function skip_name(data,pos)
    local guard=0
    while pos<=#data do
        guard=guard+1; if guard>128 then return nil end
        local n=data:byte(pos); if not n then return nil end
        if n==0 then return pos+1 end
        if n>=192 then return pos+2 end
        if n>63 then return nil end
        pos=pos+n+1
    end
end
local function query(host,server,socket_lib,now)
    local hit=cache[server.."|"..host]
    if hit and hit.until_time>now then return hit.ip end
    next_id=(next_id+1)%65536
    local id=next_id
    local qname={}
    for label in host:gmatch("[^%.]+") do
        if #label>63 then return nil,"Invalid DNS name" end
        qname[#qname+1]=string.char(#label)..label
    end
    local packet=string.char(math.floor(id/256),id%256,1,0,0,1,0,0,0,0,0,0)..table.concat(qname).."\0\0\1\0\1"
    local udp,err=socket_lib.udp(); if not udp then return nil,err or "DNS socket unavailable" end
    udp:settimeout(3)
    local ok; ok,err=udp:setpeername(server,53)
    if not ok then udp:close(); return nil,err or "DNS server unavailable" end
    ok,err=udp:send(packet)
    if not ok then udp:close(); return nil,err or "DNS query failed" end
    local response; response,err=udp:receive(); udp:close()
    if not response or #response<12 then return nil,err or "Invalid DNS response" end
    if u16(response,1)~=id then return nil,"Mismatched DNS response" end
    local flags=u16(response,3); if not flags or flags%16~=0 then return nil,"DNS lookup failed" end
    local questions,answers=u16(response,5),u16(response,7)
    if not questions or not answers or answers>128 then return nil,"Invalid DNS response" end
    local pos=13
    for _=1,questions do
        pos=skip_name(response,pos); if not pos or pos+3>#response then return nil,"Invalid DNS question" end
        pos=pos+4
    end
    for _=1,answers do
        pos=skip_name(response,pos); if not pos or pos+9>#response then return nil,"Invalid DNS answer" end
        local kind,class=u16(response,pos),u16(response,pos+2)
        local ttl=u16(response,pos+4)*65536+u16(response,pos+6)
        local length=u16(response,pos+8); local start=pos+10
        if not length or start+length-1>#response then return nil,"Invalid DNS answer length" end
        if kind==1 and class==1 and length==4 then
            local a,b,c,d=response:byte(start,start+3)
            local ip=string.format("%d.%d.%d.%d",a,b,c,d)
            cache[server.."|"..host]={ip=ip,until_time=now+math.max(30,math.min(ttl,3600))}
            return ip
        end
        pos=start+length
    end
    return nil,"DNS returned no IPv4 address"
end

function M.resolve(host,mode,manual_server,socket_lib,now)
    if mode==nil or mode=="auto" then return nil end
    if not valid_host(host) then return nil,"Invalid DNS hostname" end
    local server
    if mode=="google" then server="8.8.8.8"
    elseif mode=="cloudflare" then server="1.1.1.1"
    elseif mode=="other" and valid_ipv4(manual_server) then server=manual_server
    else return nil,"Invalid DNS configuration" end
    local ip,err=query(host,server,socket_lib or require("socket"),now or os.time())
    if not ip then return nil,err end
    return ip
end
function M.validIPv4(ip) return valid_ipv4(ip) end
return M
