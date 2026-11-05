local Downloader=dofile("network/image_downloader.lua")
local p="test-image.tmp"
local trapper={wrap=function(_,f) f() end,dismissableRunInSubprocess=function(_,f) return true,f() end}
local request={fetch=function(url,deps) assert(deps.images and deps.max_bytes==100); assert(deps.write("data")); return 200,{size=4,prefix="data",content_type="image/jpeg"} end}
local result, written = nil, ""
local files={open=function() return {write=function(_,v) written=written..v; return true end,close=function() return true end} end,remove=function() end}
Downloader.new(trapper,request,function() return {} end,files)({image_url="https://test"},p,100,function(meta,err) result=meta or err end)
assert(result and result.size==4 and written=="data")

-- Simulate a full filesystem at the streaming write boundary.  This stays
-- bounded and verifies the same failure path as ENOSPC without filling a device.
local no_space="No space left on device"
local Request=dofile("network/secure_request.lua")
local sock={settimeout=function() return true end,connect=function() return true end,close=function() end}
local tls={settimeout=function() return true end,sethost=function() return true end,dohandshake=function() return true end}
local full_request={fetch=Request.fetch}
local function full_dependencies()
    return {images=true,max_bytes=100,cafile="/ca",socket={tcp=function() return sock end},
        ssl={wrap=function() return tls end},http={request=function(req)
            local conn=req.create(); local ok,err=conn:connect("uploads.mangadex.org",443)
            if not ok then return nil,err end
            local written,write_error=req.sink("data")
            if not written then return nil,write_error end
            return 1,200,{["content-type"]="image/jpeg"}
        end}}
end
local full_files={open=function() return {write=function() return nil,no_space end,close=function() return true end} end,remove=function(path) assert(path==p) end}
local immediate_runner={run=function(task,_,callback)
    local code,meta,err=task(); callback(true,code,meta,err)
    return {cancel=function() end}
end}
result=nil
Downloader.new(trapper,full_request,full_dependencies,full_files,immediate_runner)({image_url="https://uploads.mangadex.org/test.jpg"},p,100,function(meta,err) result=meta or err end)
assert(result==no_space)

-- A slow/cancellable subprocess must remove its partial image and report cancel.
local delayed_done,removed
local delayed_runner={run=function(_,_,callback) delayed_done=callback; return {cancel=function() end} end}
local cancel_files={open=function() return {write=function(_,v) return true end,close=function() return true end} end,
    remove=function(path) removed=path end}
result=nil
local cancel=Downloader.new(trapper,request,function() return {} end,cancel_files,delayed_runner)({image_url="https://test"},p,100,function(meta,err) result=meta or err end)
cancel(); delayed_done(false,nil,nil,"Cancelled")
assert(result=="Cancelled" and removed==p)
print("Image downloader tests passed")
