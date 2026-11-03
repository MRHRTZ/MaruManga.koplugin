local Adapter=dofile("network/subprocess_transport.lua")
local events={}; local ui={scheduleIn=function(_,delay,cb) events[#events+1]=cb end}
local trapper={wrap=function(_,fn) fn() end,dismissableRunInSubprocess=function(_,fn) return true,fn() end}
local opts; local queue={new=function(config) opts=config; return config end}
local request={fetch=function(url,deps) assert(url=="https://api.mangadex.org/manga" and deps.marker and deps.method=="POST" and deps.body=="a=b"); return 200,"{}" end}
Adapter.new(ui,trapper,{decode=function() end},queue,request,function() return {marker=true} end)
local status,body; opts.request("https://api.mangadex.org/manga",function(a,b) status,body=a,b end,{method="POST",body="a=b"})
assert(status==200 and body=="{}")
trapper.dismissableRunInSubprocess=function() return false end
local error_message; opts.request("https://api.mangadex.org/manga",function(_,_,err) error_message=err end)
assert(error_message == "Request cancelled")
print("Subprocess transport tests passed")
