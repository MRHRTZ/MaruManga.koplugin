-- Integration test: real KOReader ffi/archiver and libarchive on Linux.
local base=assert(os.getenv("KOREADER_BASE")); local library=assert(os.getenv("LIBARCHIVE_PATH"))
package.path=base .. "/?.lua;" .. package.path
local ffi=require("ffi"); ffi.libc="GNU"; ffi.loadlib=function() return ffi.load(library) end
ffi.cdef[[int link(const char *, const char *);]]
local archiver=require("ffi/archiver")
local builder=dofile("reader/cbz_builder.lua")
local prefix=os.tmpname(); os.remove(prefix)
local input=prefix .. ".jpg"; local target=prefix .. ".cbz"
local source=assert(io.open(base .. "/spec/unit/data/sample.jpg","rb")); local data=source:read("*a"); source:close()
local f=assert(io.open(input,"wb")); f:write(data); f:close()
local integrity=dofile("reader/archive_integrity.lua")
local fs={verifyEntry=integrity.verifyEntry,exists=function(path) local h=io.open(path,"rb"); if h then h:close(); return true end; return false end,
 remove=os.remove,publishNoReplace=function(a,b) if ffi.C.link(a,b)~=0 then return false end; os.remove(a); return true end,
 publishReplace=function(a,b) return os.rename(a,b) end}
local chapter_title="Chapter 1: The / Reunion"
local ok,err=builder.build(archiver,fs,target,{{path=input,extension="jpg"}},chapter_title)
assert(ok,err)
local r=archiver.Reader:new(); assert(r:open(target)); local e=r:next(); assert(e.path=="Chapter 1 The Reunion/000001.jpg" and e.size>0); r:close()
local check=dofile("reader/archive_check.lua")
local valid,count=check.validate(target,archiver,integrity.verifyEntry)
assert(valid and count==1,"Generated titled chapter archive failed integrity validation")
local merged=prefix..".manga.cbz"
assert(builder.mergeAll(archiver,fs,merged,{{path=input,extension="jpg"}},"Chapter 10",{}))
assert(builder.mergeAll(archiver,fs,merged,{{path=input,extension="jpg"}},"Chapter 2",{}))
local r2=archiver.Reader:new(); assert(r2:open(merged))
local one,two=r2:next(),r2:next()
assert(one.path=="Chapter 2/000001.jpg" and two.path=="Chapter 10/000001.jpg","Manga CBZ chapter order is not numeric")
r2:close()
local valid_multi,count_multi=check.validate(merged,archiver,integrity.verifyEntry)
assert(valid_multi and count_multi==2,"Merged manga CBZ failed integrity validation")
local legacy=prefix..".legacy.cbz"
assert(builder.build(archiver,fs,legacy,{{path=input,extension="jpg"}},"Chapter 1"))
local migrated=prefix..".migrated.cbz"
assert(builder.mergeAll(archiver,fs,migrated,{{path=input,extension="jpg"}},"Chapter 2",{{path=legacy,folder="Chapter 1"}}))
local r3=archiver.Reader:new(); assert(r3:open(migrated))
assert(r3:next().path=="Chapter 1/000001.jpg" and r3:next().path=="Chapter 2/000001.jpg","Legacy chapter archive was not merged")
r3:close()
os.remove(input); os.remove(target); os.remove(merged); os.remove(legacy); os.remove(migrated)
print("Real KOReader archive integration passed")
