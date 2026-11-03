local Client=dofile("network/client.lua")
local options
local c=Client.new({request=function(url,cb,opts) options=opts; cb(200,"{}") end,schedule=function() end,decode=function() return {} end})
c:post("https://api.mangadex.org/test","a=b",{["X-Test"]="yes"},function(result) assert(result) end)
assert(options.method=="POST" and options.body=="a=b" and options.headers["X-Test"]=="yes")
assert(not c:post("https://api.mangadex.org/test",string.rep("x",65537),{},function() end))
print("HTTP POST tests passed")
