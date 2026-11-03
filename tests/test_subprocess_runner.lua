local Runner=dofile("network/subprocess_runner.lua")
local scheduled,closed
local ui={show=function() end,close=function() closed=true end,scheduleIn=function(_,_,f) scheduled=f end,unschedule=function() end}
local trapper={wrap=function(_,fn) fn(); return true end,dismissableRunInSubprocess=function(_,task,widget) widget.dismiss_callback=function() end; return true,task() end}
local widget={new=function(_,v) return v end}; local got
Runner.new(ui,trapper,widget).run(function() return 200,"body" end,10,function(ok,code,body) got={ok,code,body} end)
assert(got[1] and got[2]==200 and got[3]=="body" and scheduled)
print("Subprocess deadline runner tests passed")
