-- Persisted sequential download queue. Running work is interrupted on restart.
local Queue={}; Queue.__index=Queue
function Queue.open(settings,start,max_concurrent)
    local state=settings:readSetting("marumanga_queue") or {version=1,items={}}
    if type(state)~="table" or state.version~=1 or type(state.items)~="table" then return nil,"Invalid download queue" end
    for _,item in ipairs(state.items) do
        if type(item)~="table" or type(item.manga)~="table" or type(item.chapter)~="table" or type(item.status)~="string" or type(item.manga.source_id)~="string" or type(item.manga.id)~="string" or type(item.chapter.id)~="string" or item.chapter.manga_id~=item.manga.id then return nil,"Invalid download queue" end
        if item.status~="queued" and item.status~="running" and item.status~="paused" and item.status~="completed" and item.status~="failed" and item.status~="cancelled" then return nil,"Invalid download queue" end
    end
    for _,item in ipairs(state.items) do
        if item.status=="running" then
            item.status=item.pause_requested and "paused" or "failed"
            item.error=item.status=="failed" and "Interrupted" or nil
        end
        item.pause_requested=nil; item.resume_after_pause=nil; item.cancel_requested=nil
        -- Old versions queued online-reader actions; downloads no longer open automatically.
        item.open_after=nil
    end
    return setmetatable({settings=settings,start=start,state=state,max_concurrent=max_concurrent or function() return 2 end,active_items={},controllers={},pumping=false},Queue)
end
function Queue:save()
    self.settings:saveSetting("marumanga_queue",self.state)
    local ok,result=pcall(self.settings.flush,self.settings)
    return ok and result~=false
end
function Queue:add(manga,chapter)
    if type(manga)~="table" or type(chapter)~="table" or type(manga.source_id)~="string" or type(manga.id)~="string" or type(chapter.id)~="string" or chapter.manga_id~=manga.id then return nil,"Invalid chapter" end
    for _,item in ipairs(self.state.items) do
        if item.manga.source_id==manga.source_id and item.chapter.id==chapter.id and (item.status=="queued" or item.status=="running" or item.status=="paused") then return nil,"Chapter already queued" end
    end
    local item={manga=manga,chapter=chapter,status="queued"}
    self.state.items[#self.state.items+1]=item
    if not self:save() then table.remove(self.state.items); return nil,"Could not save queue" end
    self:run(); return true
end
-- Save a batch once before starting it, rather than flushing once per chapter.
function Queue:addMany(entries)
    if type(entries)~="table" then return nil,"Invalid chapter batch" end
    local seen={}
    for _,item in ipairs(self.state.items) do
        if item.status=="queued" or item.status=="running" or item.status=="paused" then seen[item.manga.source_id..":"..item.chapter.id]=true end
    end
    local original=#self.state.items; local skipped=0
    for _,entry in ipairs(entries) do
        local manga=type(entry)=="table" and entry.manga
        local chapter=type(entry)=="table" and entry.chapter
        if type(manga)~="table" or type(chapter)~="table" or type(manga.source_id)~="string" or type(manga.id)~="string" or type(chapter.id)~="string" or chapter.manga_id~=manga.id then
            while #self.state.items>original do table.remove(self.state.items) end
            return nil,"Invalid chapter"
        end
        local key=manga.source_id..":"..chapter.id
        if seen[key] then skipped=skipped+1
        else seen[key]=true; self.state.items[#self.state.items+1]={manga=manga,chapter=chapter,status="queued"} end
    end
    local added=#self.state.items-original
    if added>0 and not self:save() then
        while #self.state.items>original do table.remove(self.state.items) end
        return nil,"Could not save queue"
    end
    self:run(); return added,skipped
end
function Queue:run()
    if self.pumping then self.run_again=true; return end
    self.pumping=true
    repeat
        self.run_again=false
        local ok_limit,limit=pcall(self.max_concurrent)
        limit=ok_limit and tonumber(limit) or 2
        if not limit or limit<1 then limit=1 end
        if limit>5 then limit=5 end
        limit=math.floor(limit)
        local active_count=0; self.active=nil; local locked_manga={}
        for item in pairs(self.active_items) do
            active_count=active_count+1; self.active=self.active or item
            locked_manga[item.manga.source_id..":"..item.manga.id]=true
        end
        while active_count<limit do
            local item
            for _,candidate in ipairs(self.state.items) do
                local key=candidate.manga.source_id..":"..candidate.manga.id
                if candidate.status=="queued" and not self.active_items[candidate] and not locked_manga[key] then item=candidate; break end
            end
            if not item then break end
            locked_manga[item.manga.source_id..":"..item.manga.id]=true
            self.active_items[item]=true; self.active=self.active or item; item.status="running"; item.error=nil; active_count=active_count+1; self:save()
            local done=false
            local function finish(ok,err)
                if done then return end
                done=true
                if item.cancel_requested then item.status="cancelled"
                elseif item.resume_after_pause then item.status="queued"
                elseif item.pause_requested then item.status="paused"
                else item.status=ok and "completed" or "failed" end
                item.error=item.status=="failed" and (err or "Download failed") or nil
                item.cancel_requested=nil; item.pause_requested=nil; item.resume_after_pause=nil
                self.active_items[item]=nil; self.controllers[item]=nil; self.active=nil
                for active in pairs(self.active_items) do self.active=self.active or active end
                self:save(); self:run()
            end
            local ok,controller=pcall(self.start,item,finish)
            if not ok then finish(nil,"Download could not start") elseif not done and controller then self.controllers[item]=controller end
        end
    until not self.run_again
    self.pumping=false
end
function Queue:cancel(item)
    if item.status=="queued" then item.status="cancelled"; self:save(); return true end
    if item.status=="paused" then item.status="cancelled"; item.pause_requested=nil; item.resume_after_pause=nil; self:save(); return true end
    if self.active_items[item] and item.status=="running" then
        item.cancel_requested=true; self:save()
        local controller=self.controllers[item]
        if controller and controller.cancel then controller:cancel() end
        return true
    end
    return nil,"Download is not active"
end
function Queue:pauseManga(source_id,manga_id)
    local count,controllers=0,{}
    for _,item in ipairs(self.state.items) do
        if item.manga.source_id==source_id and item.manga.id==manga_id then
            if item.status=="queued" then item.status="paused"; count=count+1
            elseif item.status=="running" and not item.pause_requested then
                item.pause_requested=true; count=count+1
                local controller=self.controllers[item]
                if controller and controller.cancel then controllers[#controllers+1]=controller end
            end
        end
    end
    if count>0 then self:save() end
    for _,controller in ipairs(controllers) do pcall(controller.cancel,controller) end
    return count
end
function Queue:resumeManga(source_id,manga_id)
    local count=0
    for _,item in ipairs(self.state.items) do
        if item.manga.source_id==source_id and item.manga.id==manga_id then
            if item.status=="paused" then
                item.status="queued"; item.pause_requested=nil; item.resume_after_pause=nil; item.error=nil; count=count+1
            elseif item.status=="running" and item.pause_requested then
                item.resume_after_pause=true; count=count+1
            end
        end
    end
    if count>0 then self:save(); self:run() end
    return count
end
function Queue:cancelManga(source_id,manga_id)
    local count,controllers=0,{}
    for _,item in ipairs(self.state.items) do
        if item.manga.source_id==source_id and item.manga.id==manga_id then
            if item.status=="queued" or item.status=="paused" then
                item.status="cancelled"; item.error=nil; item.pause_requested=nil; item.resume_after_pause=nil; count=count+1
            elseif item.status=="running" and not item.cancel_requested then
                item.cancel_requested=true; item.pause_requested=nil; item.resume_after_pause=nil; count=count+1
                local controller=self.controllers[item]
                if controller and controller.cancel then controllers[#controllers+1]=controller end
            end
        end
    end
    if count>0 then self:save() end
    for _,controller in ipairs(controllers) do pcall(controller.cancel,controller) end
    return count
end
function Queue:isActive(item)
    return self.active_items[item]==true
end
function Queue:remove(item)
    if self.active_items[item] or item.status=="running" then return nil,"Download is active" end
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
