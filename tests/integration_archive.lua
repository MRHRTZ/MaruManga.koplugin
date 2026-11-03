-- Integration test: real KOReader ffi/archiver and libarchive on Linux.
local base=assert(os.getenv("KOREADER_BASE")); local library=assert(os.getenv("LIBARCHIVE_PATH"))
package.path=base .. "/?.lua;" .. package.path
local ffi=require("ffi"); ffi.libc="GNU"; ffi.loadlib=function() return ffi.load(library) end
ffi.cdef[[int link(const char *, const char *);]]
local archiver=require("ffi/archiver")
local builder=dofile("reader/cbz_builder.lua")
local prefix=os.tmpname(); os.remove(prefix)
local input=prefix .. ".png"; local target=prefix .. ".cbz"
local f=assert(io.open(input,"wb")); f:write("\137PNG\r\n\26\nimage fixture"); f:close()
local integrity=dofile("reader/archive_integrity.lua")
local fs={verifyEntry=integrity.verifyEntry,exists=function(path) local h=io.open(path,"rb"); if h then h:close(); return true end; return false end,
 remove=os.remove,publishNoReplace=function(a,b) if ffi.C.link(a,b)~=0 then return false end; os.remove(a); return true end}
local ok,err=builder.build(archiver,fs,target,{{path=input,extension="png"}})
assert(ok,err)
local r=archiver.Reader:new(); assert(r:open(target)); local e=r:next(); assert(e.path=="000001.png" and e.size>0); r:close()
os.remove(input); os.remove(target)
print("Real KOReader archive integration passed")
