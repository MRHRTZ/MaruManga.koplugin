-- Error handling: a device without a hostname verification method must fail closed.
local Request=dofile("network/secure_request.lua")
local sock={settimeout=function() return 1 end,connect=function() return 1 end,close=function() end}
local tls={settimeout=function() return 1 end,dohandshake=function() return 1 end,getpeercertificate=function() return {} end}
local deps={socket={tcp=function() return sock end},ssl={wrap=function() return tls end},http={request=function(req)
    local conn=req.create(); local ok,err=conn:connect("api.mangadex.org",443); return ok,err
end}}
local code,_,err=Request.fetch("https://api.mangadex.org/manga",deps)
assert(not code and err == "Hostname verification unavailable")
print("TLS fail-closed tests passed")
