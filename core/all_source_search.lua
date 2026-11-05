-- Search enabled source adapters one at a time and collect their first page.
-- The source list is supplied by the caller so this module has no UI/config
-- dependencies and can be tested with mocked adapters.
local Search={}

function Search.run(sources,query,page,get_source,schedule,on_progress,callback)
    if type(sources)~="table" or #sources==0 then return callback(nil,"No enabled sources") end
    local result={items={},has_next=false}
    local successful=0
    local first_error
    local function next_source(index)
        if index>#sources then
            if successful==0 and first_error then return callback(nil,first_error) end
            return callback(result)
        end
        on_progress(index,#sources)
        local entry=sources[index]
        local ok,source=pcall(get_source,entry)
        if not ok or not source or type(source.searchManga)~="function" then
            first_error=first_error or (not ok and tostring(source) or "Source is unavailable")
            return schedule(function() next_source(index+1) end)
        end
        local replied=false
        local started,err=pcall(source.searchManga,source,query,page,function(response,failure)
            if replied then return end
            replied=true
            if type(response)=="table" and type(response.items)=="table" then
                successful=successful+1
                result.has_next=result.has_next or response.has_next==true
                for _,manga in ipairs(response.items) do
                    if type(manga)=="table" then result.items[#result.items+1]=manga end
                end
            else
                first_error=first_error or failure or "Could not search source"
            end
            schedule(function() next_source(index+1) end)
        end)
        if not started and not replied then
            replied=true
            first_error=first_error or tostring(err or "Could not search source")
            schedule(function() next_source(index+1) end)
        end
    end
    next_source(1)
end

return Search
