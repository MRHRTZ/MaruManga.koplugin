-- Sequential refresh limits memory and leaves per-source rate limiting in place.
local Updates={}
function Updates.fetch(manga_list,source_for,callback,limit)
    if type(manga_list)~="table" then callback(nil,"Invalid library"); return end
    local index,results,errors=0,{},{}
    local cap=math.min(#manga_list,limit or 25)
    local cancelled=false
    local job={cancel=function() cancelled=true end}
    local function next_manga()
        if cancelled then return callback(nil,"Cancelled") end
        index=index+1
        if index>cap then
            table.sort(results,function(a,b)
                local at=type(a.chapter.upload_date)=="number" and a.chapter.upload_date or 0
                local bt=type(b.chapter.upload_date)=="number" and b.chapter.upload_date or 0
                if at~=bt then return at>bt end
                return (a.manga.title or "")<(b.manga.title or "")
            end)
            return callback({items=results,errors=errors,truncated=#manga_list>cap})
        end
        local manga=manga_list[index]
        local ok,source=pcall(source_for,manga.source_id)
        if not ok or not source then errors[#errors+1]=manga.title; return next_manga() end
        local completed=false
        local started,err=pcall(source.getChapterList,source,manga,1,function(list,failure)
            if completed then return end; completed=true
            if type(list)~="table" or type(list.items)~="table" then errors[#errors+1]=manga.title .. ": " .. tostring(failure or "invalid response")
            else
                for _,chapter in ipairs(list.items) do
                    if type(chapter)=="table" and type(chapter.name)=="string" then results[#results+1]={manga=manga,chapter=chapter} end
                end
            end
            next_manga()
        end,"desc")
        if not started and not completed then completed=true; errors[#errors+1]=manga.title .. ": unavailable"; next_manga() end
    end
    next_manga()
    return job
end
return Updates
