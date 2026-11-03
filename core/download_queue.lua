-- Persisted sequential download queue. Running work is interrupted on restart.
local Queue={}; Queue.__index=Queue
function Queue.open(settings,start)
    local state=settings:readSetting("marumanga_queue") or {version=1,items={}}
    if type(state)~="table" or state.version~=1 or type(state.items)~="table" then return nil,"Invalid download queue" end
    for _,item in ipairs(state.items) do
        if type(item)~="table" or type(item.manga)~="table" or type(item.chapter)~="table" or type(item.status)~="string" then return nil,"Invalid download queue" end
        if item.status=="running" then item.status="failed"; item.error="Interrupted" end
    end
    return setmetatable({settings=settings,start=start,state=state},Queue)
end
function Queue:save()
    self.settings:saveSetting("marumanga_queue",self.state)
    local ok,result=pcall(self.settings.flush,self.settings)
    return ok and result~=false
end
function Queue:add(manga,chapter,open_after)
    if type(manga)~="table" or type(chapter)~="table" or type(manga.source_id)~="string" or type(manga.id)~="string" or type(chapter.id)~="string" or chapter.manga_id~=manga.id then return nil,"Invalid chapter" end
    for _,item in ipairs(self.state.items) do
        if item.manga.source_id==manga.source_id and item.chapter.id==chapter.id and (item.status=="queued" or item.status=="running") then return nil,"Chapter already queued" end
    end
    local item={manga=manga,chapter=chapter,status="queued",open_after=not not open_after}
    self.state.items[#self.state.items+1]=item
    if not self:save() then table.remove(self.state.items); return nil,"Could not save queue" end
    self:run(); return true
end
function Queue:run()
    if self.active then return end
    local item
    for _,v in ipairs(self.state.items) do if v.status=="queued" then item=v; break end end
    if not item then return end
    self.active=item; item.status="running"; item.error=nil; self:save()
    local done=false
    local function finish(ok,err)
        if done then return end
        done=true
        item.status=item.cancel_requested and "cancelled" or (ok and "completed" or "failed")
        item.error=not ok and err or nil
        self.active=nil; self.controller=nil; self:save()
        -- Opening a reader creates another plugin instance; do not start a
        -- second download concurrently with its persisted reading progress.
        if not (ok and item.open_after) then self:run() end
    end
    local ok,controller=pcall(self.start,item,finish)
    if not ok then finish(nil,"Download could not start") elseif not done then self.controller=controller end
end
function Queue:cancel(item)
    if item.status=="queued" then item.status="cancelled"; self:save(); return true end
    if item==self.active and item.status=="running" then
        item.cancel_requested=true; self:save()
        if self.controller and self.controller.cancel then self.controller:cancel() end
        return true
    end
    return nil,"Download is not active"
end
function Queue:remove(item)
    if item==self.active or item.status=="running" then return nil,"Download is active" end
    for i,v in ipairs(self.state.items) do
        if v==item then table.remove(self.state.items,i); if not self:save() then table.insert(self.state.items,i,item); return nil,"Could not save queue" end; return true end
    end
    return nil,"Download not found"
end
function Queue:retry(item)
    if item.status~="failed" and item.status~="cancelled" then return nil,"Download cannot be retried" end
    item.status="queued"; item.cancel_requested=nil; item.error=nil; self:save(); self:run(); return true
end
return Queue
