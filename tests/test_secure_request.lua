local Request = dofile("network/secure_request.lua")
local function test(hostok, payload)
    local sock={settimeout=function() return 1 end,connect=function() return 1 end,close=function() end}
    local tls={settimeout=function() return 1 end,sni=function() end,dohandshake=function() return true end,
        getpeercertificate=function() return {checkhost=function() return hostok end} end}
    local deps={socket={tcp=function() return sock end}, ssl={wrap=function(_,params) assert(params.verify == "peer"); return tls end}, capath="/ca",
        http={request=function(req) assert(req.port == 443); local conn=req.create(); local ok, err=conn:connect("api.mangadex.org",443); if not ok then return nil,err end; local success, reason=req.sink(payload); if not success then return nil,reason end; return 1,200 end}}
    return Request.fetch("https://api.mangadex.org/manga",deps)
end
local code, body = test(true,"{}"); assert(code == 200 and body == "{}")
local code2, _, err = test(false,"{}"); assert(not code2 and err == "Certificate hostname mismatch")
assert(not Request.fetch("http://api.mangadex.org/manga",{}))
print("Secure request tests passed")

assert(not Request.fetch("https://api.mangadex.org/a\r\nHost:evil",{}))
assert(not Request.fetch("https://api.mangadex.org/a#fragment",{}))
