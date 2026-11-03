local Downloader=dofile("network/image_downloader.lua")
local p="test-image.tmp"
local trapper={wrap=function(_,f) f() end,dismissableRunInSubprocess=function(_,f) return true,f() end}
local request={fetch=function(url,deps) assert(deps.images and deps.max_bytes==100); assert(deps.write("data")); return 200,{size=4,prefix="data",content_type="image/jpeg"} end}
local result, written = nil, ""
local files={open=function() return {write=function(_,v) written=written..v; return true end,close=function() return true end} end,remove=function() end}
Downloader.new(trapper,request,function() return {} end,files)({image_url="https://test"},p,100,function(meta,err) result=meta or err end)
assert(result and result.size==4 and written=="data")
print("Image downloader tests passed")
