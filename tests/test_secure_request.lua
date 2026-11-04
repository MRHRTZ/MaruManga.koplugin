local Request = dofile("network/secure_request.lua")
local last_connected,last_sni
local function test(hostok, payload, ignore_ssl_certificates, resolved_ip)
    local sock={settimeout=function() return 1 end,connect=function(_,host) last_connected=host; return 1 end,close=function() end}
    local tls={settimeout=function() return 1 end,sni=function(_,host) last_sni=host end,dohandshake=function() return true end,
        getpeercertificate=function() return {checkhost=function() return hostok end} end}
    local expected_verify=ignore_ssl_certificates and "none" or "peer"
    local deps={socket={tcp=function() return sock end}, ssl={wrap=function(_,params) assert(params.verify == expected_verify and params.cafile=="/bundle"); return tls end}, capath="/ca",cafile="/bundle",ignore_ssl_certificates=ignore_ssl_certificates,
        http={request=function(req) assert(req.port == 443); local conn=req.create(); local ok, err=conn:connect("api.mangadex.org",443); if not ok then return nil,err end; local success, reason=req.sink(payload); if not success then return nil,reason end; return 1,200 end}}
    if resolved_ip then deps.resolve=function(host) assert(host=="api.mangadex.org"); return resolved_ip end end
    return Request.fetch("https://api.mangadex.org/manga",deps)
end
local code, body = test(true,"{}"); assert(code == 200 and body == "{}")
local code2, _, err = test(false,"{}"); assert(not code2 and err == "Certificate hostname mismatch")
local code3, body3 = test(true,"{}",true); assert(code3==200 and body3=="{}")
local code4, body4 = test(false,"{}",true); assert(code4==200 and body4=="{}")
assert(not Request.fetch("http://api.mangadex.org/manga",{}))
local resolved_code=test(true,"{}",false,"93.184.216.34")
assert(resolved_code==200 and last_connected=="93.184.216.34" and last_sni=="api.mangadex.org")
local invalid_dns,_,dns_error=test(true,"{}",false,"not-an-ip")
assert(not invalid_dns and dns_error=="DNS returned an invalid address")
print("Secure request tests passed")

assert(not Request.fetch("https://api.mangadex.org/a\r\nHost:evil",{}))
assert(not Request.fetch("https://api.mangadex.org/a#fragment",{}))
