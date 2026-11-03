local Queue=dofile("core/download_queue.lua")
local store={readSetting=function(self) return self.value end,saveSetting=function(self,_,v) self.value=v end,flush=function() end}
local tasks={}; local q=assert(Queue.open(store,function(item,done) local t={item=item,done=done,cancel=function(self) self.cancelled=true end}; tasks[#tasks+1]=t; return t end))
local m={id="m",source_id="s"}; local c={id="c",manga_id="m"}; local d={id="d",manga_id="m"}
assert(q:add(m,c)); assert(q:add(m,d)); assert(#tasks==1 and not q:add(m,c)); tasks[1].done(true); assert(#tasks==2 and q.state.items[1].status=="completed")
assert(q:cancel(q.state.items[2])); assert(tasks[2].cancelled); tasks[2].done(nil,"Cancelled"); assert(q.state.items[2].status=="cancelled")
assert(q:retry(q.state.items[2]) and #tasks==3); tasks[3].done(nil,"offline"); assert(q.state.items[2].status=="failed")
q.state.items[2].status="running"; assert(Queue.open(store,function() end).state.items[2].error=="Interrupted")
print("Download queue tests passed")

assert(not Queue.open({readSetting=function() return {version=1,items={false}} end},function() end))
