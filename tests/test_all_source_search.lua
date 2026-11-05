local Search=dofile("core/all_source_search.lua")
local queue,callbacks,progress={}, {}, {}
local first={searchManga=function(_,query,page,callback)
    assert(query=="sample" and page==2); callbacks[1]=callback
end}
local second={searchManga=function(_,query,page,callback)
    assert(query=="sample" and page==2); callbacks[2]=callback
end}
local profiles={{id="first"},{id="second"}}
local adapters={first=first,second=second}
Search.run(profiles,"sample",2,function(profile) return adapters[profile.id] end,
    function(task) queue[#queue+1]=task end,
    function(index,total) progress[#progress+1]={index,total} end,
    function(result,err) callbacks.done={result,err} end)
assert(progress[1][1]==1 and progress[1][2]==2 and callbacks[1] and not callbacks[2])
callbacks[1]({items={{id="a",source_id="first",title="First"}},has_next=true})
table.remove(queue,1)()
assert(progress[2][1]==2 and progress[2][2]==2 and callbacks[2])
callbacks[2]({items={{id="b",source_id="second",title="Second"}},has_next=false})
table.remove(queue,1)()
local result=assert(callbacks.done[1],callbacks.done[2])
assert(#result.items==2 and result.has_next and result.items[1].source_id=="first" and result.items[2].source_id=="second")

local failure
Search.run({{id="broken"}}, "sample", 1, function() error("offline") end,function(task) task() end,
    function() end,function(_,err) failure=err end)
assert(failure and failure:find("offline",1,true))
print("All source search tests passed")
