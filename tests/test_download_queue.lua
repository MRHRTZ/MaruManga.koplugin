local Queue=dofile("core/download_queue.lua")
local store={readSetting=function(self) return self.value end,saveSetting=function(self,_,v) self.value=v end,flush=function() end}
local tasks={}; local q=assert(Queue.open(store,function(item,done) local t={item=item,done=done,cancel=function(self) self.cancelled=true end}; tasks[#tasks+1]=t; return t end,function() return 1 end))
local m={id="m",source_id="s"}; local c={id="c",manga_id="m"}; local d={id="d",manga_id="m"}
assert(q:add(m,c)); assert(q:add(m,d)); assert(#tasks==1 and not q:add(m,c)); tasks[1].done(true); assert(#tasks==2 and q.state.items[1].status=="completed")
assert(q:cancel(q.state.items[2])); assert(tasks[2].cancelled); tasks[2].done(nil,"Cancelled"); assert(q.state.items[2].status=="cancelled")
assert(q:retry(q.state.items[2]) and #tasks==3); tasks[3].done(nil,"offline"); assert(q.state.items[2].status=="failed")
q.state.items[2].status="running"; assert(Queue.open(store,function() end).state.items[2].error=="Interrupted")
local writes=0; local store2={readSetting=function() end,saveSetting=function() end,flush=function() writes=writes+1 end}
local batch=assert(Queue.open(store2,function() return {} end,function() return 1 end))
local added,skipped=batch:addMany({{manga=m,chapter=c},{manga=m,chapter=c},{manga=m,chapter=d}})
assert(added==2 and skipped==1 and writes==2 and #batch.state.items==2) -- one batch write plus the running-state write
local count=#batch.state.items; assert(not batch:addMany({{manga=m,chapter={id="bad",manga_id="other"}}})); assert(#batch.state.items==count)
local failed_store={readSetting=function() end,saveSetting=function() end,flush=function() return false end}
local never_started=false; local failed_queue=assert(Queue.open(failed_store,function() never_started=true end))
assert(not failed_queue:addMany({{manga=m,chapter=c}})); assert(#failed_queue.state.items==0 and not never_started)
print("Download queue tests passed")

local concurrent_tasks={}
local concurrent=assert(Queue.open({readSetting=function() end,saveSetting=function() end,flush=function() end},
    function(item,done) concurrent_tasks[#concurrent_tasks+1]={item=item,done=done}; return {} end,function() return 2 end))
local e={id="e",manga_id="other"}
local other_manga={id="other",source_id="s"}
assert(concurrent:addMany({{manga=m,chapter=c},{manga=m,chapter=d},{manga=other_manga,chapter=e}})==3)
assert(#concurrent_tasks==2 and concurrent_tasks[1].item.manga.id=="m" and concurrent_tasks[2].item.manga.id=="other")
concurrent_tasks[1].done(true)
assert(#concurrent_tasks==3 and concurrent_tasks[3].item.chapter.id=="d")
concurrent_tasks[2].done(nil,"offline"); concurrent_tasks[3].done(true)
assert(concurrent.state.items[1].status=="completed" and concurrent.state.items[2].status=="completed" and concurrent.state.items[3].status=="failed")

local old={readSetting=function() return {version=1,items={{manga=m,chapter=c,status="queued",open_after=true}}} end}
assert(Queue.open(old,function() end).state.items[1].open_after==nil)
local old_most={readSetting=function() return {version=1,items={{manga={id="8",source_id="mangago",url="https://mangamost.com/comics/8"},chapter={id="96",manga_id="8",source_id="mangago"},status="queued"}}} end}
local migrated_most=assert(Queue.open(old_most,function() end)).state.items[1]
assert(migrated_most.manga.source_id=="mangamost" and migrated_most.chapter.source_id=="mangamost")
assert(not Queue.open({readSetting=function() return {version=1,items={false}} end},function() end))

local pause_tasks={}
local pause_queue=assert(Queue.open({readSetting=function() end,saveSetting=function() end,flush=function() end},
    function(item,done) local task={item=item,done=done,cancel=function(self) self.cancelled=true end}; pause_tasks[#pause_tasks+1]=task; return task end,function() return 1 end))
local p1={id="p1",manga_id="m"}; local p2={id="p2",manga_id="m"}
assert(pause_queue:addMany({{manga=m,chapter=p1},{manga=m,chapter=p2}})==2)
assert(pause_queue:pauseManga("s","m")==2)
assert(pause_queue.state.items[1].status=="running" and pause_queue.state.items[1].pause_requested and pause_queue.state.items[2].status=="paused")
assert(pause_tasks[1].cancelled)
assert(pause_queue:resumeManga("s","m")==2 and #pause_tasks==1)
pause_tasks[1].done(nil,"Cancelled")
assert(pause_queue.state.items[1].status=="running" and #pause_tasks==2)
pause_tasks[2].done(true)
assert(pause_queue.state.items[1].status=="completed" and pause_queue.state.items[2].status=="running" and #pause_tasks==3)
assert(pause_queue:cancel(pause_queue.state.items[2]))
pause_tasks[3].done(nil,"Cancelled")
assert(pause_queue.state.items[2].status=="cancelled")
assert(pause_queue:pauseManga("s","m")==0)

local single_tasks={}
local single=assert(Queue.open({readSetting=function() end,saveSetting=function() end,flush=function() end},
    function(item,done) local task={item=item,done=done,cancel=function(self) self.cancelled=true end}; single_tasks[#single_tasks+1]=task; return task end,function() return 1 end))
local one={id="one",manga_id="m"}; local two={id="two",manga_id="m"}
assert(single:addMany({{manga=m,chapter=one},{manga=m,chapter=two}})==2)
assert(single:pauseManga("s","m")==2)
assert(single:resume(single.state.items[2]) and single.state.items[2].status=="queued" and single.state.items[1].pause_requested)
single_tasks[1].done(nil,"Cancelled")
assert(single.state.items[1].status=="paused" and single.state.items[2].status=="running")
single_tasks[2].done(true)
assert(single:resume(single.state.items[1]) and single.state.items[1].status=="running")
single_tasks[3].done(true)
assert(single.state.items[1].status=="completed" and single.state.items[2].status=="completed")
