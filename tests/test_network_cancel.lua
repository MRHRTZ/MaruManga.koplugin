local Client=dofile("network/client.lua")
local scheduled,requestcb,callbacks={},nil,0
local client=Client.new({request=function(_,cb) requestcb=cb end,schedule=function(_,cb) scheduled[#scheduled+1]=cb end,decode=function() return {} end})
local job=client:get("https://api.mangadex.org/manga",function(_,err) callbacks=callbacks+1; assert(err=="Cancelled") end)
requestcb(429,""); assert(#scheduled==1); job:cancel(); assert(callbacks==1)
for _,f in ipairs(scheduled) do f() end
requestcb(200,"{}"); assert(callbacks==1)
print("Network cancellation tests passed")
