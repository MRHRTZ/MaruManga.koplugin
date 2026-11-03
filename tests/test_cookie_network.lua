local Client=dofile("network/client.lua"); local Jar=dofile("network/cookie_manager.lua")
local pending={}; local calls=0
local c=Client.new({cookies=Jar.new(),request=function(url,cb,opts)
    calls=calls+1
    if calls==1 then assert(not opts.headers.Cookie); cb(200,"{}",nil,{["set-cookie"]="sid=secret; Path=/"})
    else assert(opts.headers.Cookie=="sid=secret"); cb(200,"{}") end
end,schedule=function(_,cb) pending[#pending+1]=cb end,decode=function() return {} end})
c:get("https://api.mangadex.org/one",function(v) assert(v) end)
c:get("https://api.mangadex.org/two",function(v) assert(v) end)
table.remove(pending,1)(); assert(calls==2)
print("Session cookie transport tests passed")
