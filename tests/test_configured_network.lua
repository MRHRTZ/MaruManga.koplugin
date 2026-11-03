local Client=dofile("network/client.lua")
local requested
local client=Client.new({request=function(url,cb) requested=url; cb(200,"<html/>") end,schedule=function() end,
 decode=function(body) return body end, valid=function(body) return type(body)=="string" end,
 accept_url=function(url) return url:match("^https://example%.org/") end})
local result; client:get("https://example.org/page",function(body) result=body end)
assert(requested=="https://example.org/page" and result=="<html/>")
client:get("https://example.org.evil.invalid/page",function(body,err) assert(not body and err) end)
print("Configured-source network tests passed")
