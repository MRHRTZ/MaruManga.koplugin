-- Runs in a subprocess: read bounded chunks and compare against recorded digests.
local Scan={}
function Scan.run(entries,digest,exists)
    local result,by_path={},{}
    for _,entry in ipairs(entries) do
        local status=by_path[entry.path]
        if not status then
            if exists(entry.path..".incomplete") then status="incomplete"
            elseif not exists(entry.path) then status="missing"
            elseif not entry.sha256 then status="unverified"
            else
                local hash=digest(entry.path)
                if not hash then status="error"
                elseif hash==entry.sha256 then status="valid" else status="modified" end
            end
            by_path[entry.path]=status
        end
        result[entry.source_id..":"..entry.chapter_id]=status
    end
    return result
end
return Scan
