-- Preserve LuaSettings' format and recovery behavior while checking writes.
local M={}
-- Read each local settings file at most once; never replace an unreadable
-- primary when there is no usable backup.
function M.open(LuaSettings,path)
    local function read(file)
        local handle,_,code=io.open(file,"rb")
        if not handle then return nil,code~=2 end
        handle:close()
        local ok,value=pcall(dofile,file)
        if not ok or type(value)~="table" then return nil,true end
        return value,true
    end
    local data,primary_exists=read(path)
    local recovered=false
    if not data then
        local backup,backup_exists=read(path..".old")
        if backup then data=backup; recovered=true
        elseif primary_exists or backup_exists then return nil,"Settings are corrupted; original files were preserved" end
    end
    local store=LuaSettings:wrap(data or {})
    store.file=path; store.recovered_from_backup=recovered
    return store
end
function M.wrap(store,serialize,sync,io_api,os_api)
    io_api=io_api or io; os_api=os_api or os
    assert(store and store.file and type(serialize)=="function")
    function store:flush()
        local ok,body=pcall(serialize,self.data,nil,true)
        if not ok or type(body)~="string" then return false end
        local content="-- MaruManga settings\nreturn " .. body .. "\n"
        local temporary=self.file .. ".new"
        local f=io_api.open(temporary,"wb")
        if not f then return false end
        local wrote=f:write(content)
        if wrote and sync and sync.fsyncOpenedFile then pcall(sync.fsyncOpenedFile,f) end
        local closed=f:close()
        if not wrote or not closed then os_api.remove(temporary); return false end
        local backup_ok,moved=true,false
        if not self.recovered_from_backup then backup_ok,moved=pcall(self.backup,self) end
        if not backup_ok then os_api.remove(temporary); return false end
        local renamed=os_api.rename(temporary,self.file)
        if not renamed then
            if moved then os_api.rename(self.file .. ".old",self.file) end
            os_api.remove(temporary); return false
        end
        if sync and sync.fsyncDirectory then pcall(sync.fsyncDirectory,self.file) end
        self.recovered_from_backup=nil
        return self
    end
    return store
end
return M
