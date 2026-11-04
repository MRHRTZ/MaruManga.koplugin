-- Incremental SHA-256, using KOReader's bundled implementation.
local M={}
function M.hash(path,sha256)
    if type(path)~="string" or type(sha256)~="function" then return nil,"Invalid hash request" end
    local file,err=io.open(path,"rb"); if not file then return nil,err or "Cannot open file" end
    local ok,result=pcall(function()
        local feed=sha256()
        while true do
            local part,why=file:read(65536)
            if not part then if why then error(why) end; break end
            feed(part)
        end
        return feed()
    end)
    file:close()
    if not ok then return nil,"Cannot hash file" end
    if type(result)~="string" or #result~=64 or not result:match("^[0-9a-f]+$") then return nil,"Invalid digest" end
    return result
end
return M
