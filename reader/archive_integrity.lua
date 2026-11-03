-- Stream each archive entry through libarchive so checksum errors are surfaced
-- without allocating an entire page image in Lua or native memory.
local ffi=require("ffi")
require("ffi/libarchive_h")
local archive=ffi.loadlib("archive","13")
local M={}
function M.verifyEntry(reader,entry)
    local size=tonumber(entry.size)
    if not reader.archive or not reader.index or not size or size<0 then return false end
    local buffer=ffi.new("uint8_t[?]",65536)
    local total=0
    reader.index=math.floor(reader.index)+0.1
    while true do
        local read=tonumber(archive.archive_read_data(reader.archive,buffer,65536))
        if not read or read<0 then return false end
        if read==0 then return total==size end
        total=total+read
        if total>size then return false end
    end
end
return M
