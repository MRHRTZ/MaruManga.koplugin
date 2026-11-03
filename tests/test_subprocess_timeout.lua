local Runner=dofile("network/subprocess_runner.lua")
local scheduled,closed
local ui={show=function() end,close=function() closed=true end,scheduleIn=function(_,_,f) scheduled=f end,unschedule=function() end}
local trapper={wrap=function(_,fn) local co=coroutine.create(fn); return coroutine.resume(co) end,
    dismissableRunInSubprocess=function(_,_,widget)
        local co=coroutine.running(); widget.dismiss_callback=function() assert(coroutine.resume(co,false)) end
        return coroutine.yield()
    end}
local widget={new=function(_,v) return v end}; local outcome
local runner=Runner.new(ui,trapper,widget)
runner.run(function() end,10,function(ok,_,_,err) outcome={ok,err} end)
scheduled(); assert(outcome[1]==false and outcome[2]=="Request timed out")
closed=false; outcome=nil
local job=runner.run(function() end,10,function(ok,_,_,err) outcome={ok,err} end)
job:cancel(); assert(outcome[1]==false and outcome[2]=="Cancelled")
print("Subprocess timeout and cancellation tests passed")
