-- Fallback for shared filesystems without hard links or renameat2.
-- Exclusive destination creation never replaces a file. An unfinished marker
-- lets cleanup identify a partial destination after interruption.
local ffi=require("ffi")
pcall(ffi.cdef,[[int open(const char *pathname, int flags, ...); long write(int fd, const void *buf, unsigned long count); int close(int fd); int fsync(int fd);]])
local M={}
local function create(path)
    return ffi.C.open(path,1+64+128,ffi.new("int",384))
end
function M.move(source,target)
    local marker=target..".incomplete"
    local marker_fd=create(marker)
    if marker_fd<0 then return nil,"Incomplete publication already exists or cannot be created" end
    local input,err=io.open(source,"rb")
    if not input then ffi.C.close(marker_fd); os.remove(marker); return nil,err or "Cannot open source" end
    local fd=create(target)
    if fd<0 then input:close(); ffi.C.close(marker_fd); os.remove(marker); return nil,"Destination already exists or cannot be created" end
    -- Only an owned marker permits automatic removal of the destination. If a
    -- crash occurs before this marker is durable, cleanup must preserve it.
    local marked=ffi.C.write(marker_fd,"owned\n",6)==6 and ffi.C.fsync(marker_fd)==0
    local marker_closed=ffi.C.close(marker_fd)==0
    if not marked or not marker_closed then
        input:close(); ffi.C.close(fd); os.remove(target); os.remove(marker)
        return nil,"Cannot record incomplete publication"
    end
    local ok,why=pcall(function()
        while true do
            local chunk,read_err=input:read(65536)
            if not chunk then if read_err then error(read_err) end; break end
            local offset=1
            while offset<=#chunk do
                local written=tonumber(ffi.C.write(fd,chunk:sub(offset),#chunk-offset+1))
                if not written or written<=0 then error("write failed") end
                offset=offset+written
            end
        end
        if ffi.C.fsync(fd)~=0 then error("sync failed") end
    end)
    input:close(); local closed=ffi.C.close(fd)==0
    if not ok or not closed then os.remove(target); os.remove(marker); return nil,"Cannot copy chapter safely" end
    if not os.remove(marker) then return nil,"Cannot finish publication; incomplete marker retained" end
    if not os.remove(source) then return nil,"Chapter copied but staging file could not be removed" end
    return true
end
return M
