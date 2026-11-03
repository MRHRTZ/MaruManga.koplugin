-- Runs one cancellable task through KOReader Trapper with a parent-side deadline.
local Runner={}
local unpack_values=unpack or table.unpack
local function pack(...) return {n=select("#",...),...} end
function Runner.new(ui,trapper)
    local self={}
    function self.run(task,timeout,callback)
        -- Trapper only needs a dismiss_callback holder; no modal widget is shown.
        local widget={}
        local finished=false
        local controller={}
        local reason="Cancelled"
        local function cancel()
            if not finished and widget.dismiss_callback then widget.dismiss_callback() end
        end
        function controller:cancel() cancel() end
        local function deadline() reason="Request timed out"; cancel() end
        ui:scheduleIn(timeout,deadline)
        local started,err=trapper:wrap(function()
            local values=pack(trapper:dismissableRunInSubprocess(task,widget))
            if finished then return end
            finished=true
            ui:unschedule(deadline)
            if not values[1] then callback(false,nil,nil,reason) else callback(unpack_values(values,1,values.n)) end
        end)
        if (not started or err==false) and not finished then
            finished=true; ui:unschedule(deadline); callback(false,nil,nil,err or "Unable to start subprocess")
        end
        return controller
    end
    return self
end
return Runner
