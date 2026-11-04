local Downloader=dofile("network/image_downloader.lua")
local encoded
package.preload.json=function() return {encode=function(data) encoded=data; return "{}" end} end
local files={open=function() return {write=function() return true end,close=function() return true end} end,remove=function() end}
local trapper={wrap=function(_,f) f() end,dismissableRunInSubprocess=function(_,f) return true,f() end}
local calls=0
local request={fetch=function(url,deps)
    calls=calls+1
    if calls==1 then assert(deps.write("data")); return 200,{size=4,prefix="data",content_type="image/jpeg",cached=true} end
    assert(deps.cafile=="/bundle" and url=="https://api.mangadex.network/report" and deps.method=="POST" and deps.headers["Content-Type"]=="application/json")
    return 200,"ok"
end}
local result
Downloader.new(trapper,request,function() return {cafile="/bundle",socket={gettime=function() return 1 end}} end,files)({image_url="https://node.mangadex.network:1234/token/data/ab/1.jpg",report_mangadex=true},"tmp",100,function(meta) result=meta end)
assert(result and calls==2 and encoded.success and encoded.cached and encoded.bytes==4 and encoded.duration==0)
print("MangaDex network reporting tests passed")
