-- Refresh all bookmark chapter pages sequentially and report chapters missing locally.
local Updates={}
function Updates.fetch(manga_list,source_for,callback,options)
    if type(manga_list)~="table" then callback(nil,"Invalid library"); return end
    options=type(options)=="table" and options or {}
    local index,results,errors,counts=0,{},{},{}
    local cancelled,completed=false,false
    local job={}
    function job:cancel() cancelled=true; if self.current and self.current.cancel then self.current:cancel() end end
    local function finish(result,err)
        if completed then return end
        completed=true; callback(result,err)
    end
    local function next_manga()
        if cancelled then return finish(nil,"Cancelled") end
        index=index+1
        if index>#manga_list then
            table.sort(results,function(a,b)
                local at=type(a.chapter.upload_date)=="number" and a.chapter.upload_date or 0
                local bt=type(b.chapter.upload_date)=="number" and b.chapter.upload_date or 0
                if at~=bt then return at>bt end
                return (a.manga.title or "")<(b.manga.title or "")
            end)
            return finish({items=results,errors=errors,counts=counts})
        end
        local manga=manga_list[index]
        local ok,source=pcall(source_for,manga.source_id)
        if not ok or not source then errors[#errors+1]=(manga.title or manga.id)..": source unavailable"; return next_manga() end
        local seen={}; local pending={}; local page=0
        local function next_page()
            if cancelled then return finish(nil,"Cancelled") end
            page=page+1
            if page>1000 then errors[#errors+1]=(manga.title or manga.id)..": pagination limit reached"; return next_manga() end
            local replied=false
            local started,controller=pcall(source.getChapterList,source,manga,page,function(list,failure)
                if replied or completed then return end; replied=true
                if type(list)~="table" or type(list.items)~="table" then
                    errors[#errors+1]=(manga.title or manga.id)..": "..tostring(failure or "invalid response")
                    return next_manga()
                end
                for _,chapter in ipairs(list.items) do
                    if type(chapter)=="table" and type(chapter.id)=="string" and type(chapter.name)=="string" and chapter.manga_id==manga.id and not seen[chapter.id] then
                        seen[chapter.id]=true; pending[#pending+1]=chapter
                        local available=false
                        if options.is_downloaded then
                            local checked,value=pcall(options.is_downloaded,manga,chapter)
                            if not checked then errors[#errors+1]=(manga.title or manga.id)..": local check failed" else available=not not value end
                        end
                        if not available then results[#results+1]={manga=manga,chapter=chapter}; counts[manga.source_id..":"..manga.id]=(counts[manga.source_id..":"..manga.id] or 0)+1 end
                    end
                end
                if list.has_next then return next_page() end
                local sync_ok=true
                if options.save_chapters then
                    local saved,result,err=pcall(options.save_chapters,manga,pending)
                    if not saved or not result then sync_ok=false; errors[#errors+1]=(manga.title or manga.id)..": "..tostring(err or "metadata save failed") end
                end
                if sync_ok and options.mark_synced then
                    local manga_key=manga.source_id..":"..manga.id
                    local missing_count=counts[manga_key] or 0
                    local latest_number
                    for _,chapter in ipairs(pending) do
                        if type(chapter.chapter_number)=="number" and (latest_number==nil or chapter.chapter_number>latest_number) then latest_number=chapter.chapter_number end
                    end
                    local marked,result,err=pcall(options.mark_synced,manga,#pending,missing_count,latest_number)
                    if not marked or not result then errors[#errors+1]=(manga.title or manga.id)..": "..tostring(err or "sync state save failed") end
                end
                next_manga()
            end,"desc")
            if not started and not replied then replied=true; errors[#errors+1]=(manga.title or manga.id)..": unavailable"; next_manga()
            elseif not replied then job.current=controller end
        end
        next_page()
    end
    next_manga()
    return job
end
return Updates
