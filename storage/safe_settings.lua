-- Preserve LuaSettings' format and recovery behavior while checking writes.
local M={}
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
        local backup_ok,moved=pcall(self.backup,self)
        if not backup_ok then os_api.remove(temporary); return false end
        local renamed=os_api.rename(temporary,self.file)
        if not renamed then
            if moved then os_api.rename(self.file .. ".old",self.file) end
            os_api.remove(temporary); return false
        end
        if sync and sync.fsyncDirectory then pcall(sync.fsyncDirectory,self.file) end
        return self
    end
    return store
end
return M
