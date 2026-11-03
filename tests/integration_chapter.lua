-- Real libarchive with mocked source and image transfer; no live sites required.
local base=assert(os.getenv("KOREADER_BASE")); package.path=base .. "/?.lua;" .. package.path
local ffi=require("ffi"); ffi.libc="GNU"; ffi.loadlib=function() return ffi.load(assert(os.getenv("LIBARCHIVE_PATH"))) end
ffi.cdef[[int link(const char *,const char *);]]
local archiver=require("ffi/archiver")
local stager=dofile("reader/chapter_stager.lua")
local builder=dofile("reader/cbz_builder.lua")
local validator=dofile("reader/image_validation.lua")
local reader=dofile("reader/chapter_reader.lua")
local prefix=os.tmpname(); os.remove(prefix)
local files={}
local integrity=dofile("reader/archive_integrity.lua")
local fs={verifyEntry=integrity.verifyEntry,targetFor=function() return prefix .. ".cbz" end,exists=function(p) local f=io.open(p,"rb"); if f then f:close(); return true end; return false end,
 prepare=function() return {target=prefix .. ".cbz",staging=prefix} end, remove=os.remove,
 publishNoReplace=function(a,b) if ffi.C.link(a,b)~=0 then return false end; os.remove(a); return true end}
local deps={fs=fs,archiver=archiver,stager=stager,build=builder.build,validate=validator.validate,
 removeDir=function() end, library={linkArchive=function() return true end},source={getPageList=function(_,_,cb) cb({{image_url="https://example.org/page"}}) end},
 download=function(_,p,_,cb) local f=assert(io.open(p,"wb")); local image="\255\216\255fixture"; f:write(image); f:close(); cb({content_type="image/jpeg",size=#image,prefix=image}) end,
 openDocument=function(p) files.opened=p end}
-- The path generator expects a staging directory.
assert(os.execute("mkdir " .. prefix)==0)
local result,err; reader.open(deps,{id="m",source_id="s"},{id="c",manga_id="m"},function(ok,e) result,err=ok,e end)
assert(result,err); assert(files.opened==prefix .. ".cbz")
local r=archiver.Reader:new(); assert(r:open(files.opened)); local entry=r:next(); assert(entry and entry.path=="000001.jpg" and r:extractToMemory(entry.path)); r:close()
-- Corrupt an image byte while leaving the ZIP directory intact.
local archive_file=assert(io.open(files.opened,"rb")); local bytes=archive_file:read("*a"); archive_file:close()
local pos=assert(bytes:find("fixture",1,true)); bytes=bytes:sub(1,pos-1) .. "X" .. bytes:sub(pos+1)
archive_file=assert(io.open(files.opened,"wb")); assert(archive_file:write(bytes)); archive_file:close()
local failed, failure
reader.open(deps,{id="m",source_id="s"},{id="c",manga_id="m"},function(ok,e) failed,failure=ok,e end)
assert(not failed and failure=="Downloaded archive is invalid")
os.remove(files.opened); os.execute("rmdir " .. prefix)
print("Chapter pipeline and corrupt archive detection passed")
