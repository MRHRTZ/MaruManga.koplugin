-- Validate ordered CBZ entries and their CRCs with bounded streaming reads.
local Check={}
local extensions={jpg=true,jpeg=true,png=true,gif=true,webp=true}
function Check.validate(path,archiver,verify)
    if type(path)~="string" or not archiver or type(verify)~="function" then return nil,"Invalid archive check" end
    local archive=archiver.Reader:new()
    if not archive:open(path) then return nil,"Downloaded archive is invalid" end
    local ok,valid,count=pcall(function()
        local total,good=0,true
        local next_page={}
        local folders={}
        for entry in archive:iterate() do
            total=total+1
            if total>100000 then return false,total end
            local number,ext,filename
            if type(entry.path)=="string" then
                filename=entry.path
                if filename:find("/",1,true) then
                    local folder,base=filename:match("^([^/]+)/([^/]+)$")
                    if not folder or folder=="." or folder==".." or folder:find("\\",1,true) then return false,total end
                    filename=base
                    folders[folder]=true
                else
                    folders[""]=true
                end
                number,ext=filename:match("^(%d+)%.([%a]+)$")
            end
            local size=tonumber(entry.size)
            local folder=entry.path:match("^([^/]+)/") or ""
            local expected=(next_page[folder] or 0)+1
            if not number or tonumber(number)~=expected or not extensions[ext:lower()] or entry.mode~="file" or not size or size<=0 or size>20971520 or not verify(archive,entry) then good=false
            else next_page[folder]=expected end
        end
        if archive.err then good=false end
        return good,total
    end)
    archive:close()
    if not ok or not valid or count==0 then return nil,"Downloaded archive is invalid" end
    return true,count
end
return Check
