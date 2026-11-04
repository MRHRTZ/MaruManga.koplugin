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
local sample=assert(io.open(base .. "/spec/unit/data/sample.jpg","rb")); local image_data=sample:read("*a"); sample:close()
local digest=dofile("reader/file_digest.lua"); local sha=require("ffi/sha2")
local integrity=dofile("reader/archive_integrity.lua")
local fs={verifyEntry=integrity.verifyEntry,targetFor=function() return prefix .. ".cbz" end,exists=function(p) local f=io.open(p,"rb"); if f then f:close(); return true end; return false end,
 prepare=function() return {target=prefix .. ".cbz",staging=prefix} end, remove=os.remove,
 publishNoReplace=function(a,b) if ffi.C.link(a,b)~=0 then return false end; os.remove(a); return true end,publishReplace=os.rename}
local archived={}
local deps={fs=fs,archiver=archiver,stager=stager,build=builder.mergeAll,validate=validator.validate,
 removeDir=function() end, library={
    archiveFor=function(_,_,_,chapter_id) return archived[chapter_id] and prefix..".cbz" end,
    archiveHasChapter=function(_,_,chapter_id) return archived[chapter_id]~=nil end,
    linkArchive=function(_,_,manga,chapter,_,hash) archived[chapter.id]=chapter; files.hash=hash; return true end,
 },hashArchive=function(path,cb) cb(digest.hash(path,sha.sha256)) end,source={getPageList=function(_,_,cb) cb({{image_url="https://example.org/page"}}) end},
 download=function(_,p,_,cb) local f=assert(io.open(p,"wb")); f:write(image_data); f:close(); cb({content_type="image/jpeg",size=#image_data,prefix=image_data:sub(1,16)}) end,
 openDocument=function(p) files.opened=p end}
-- The path generator expects a staging directory.
assert(os.execute("mkdir " .. prefix)==0)
local manga={id="m",source_id="s"}; local chapter={id="c",manga_id="m",name="Chapter 1 - Fixture chapter"}
local result,err; reader.open(deps,manga,chapter,function(ok,e) result,err=ok,e end)
assert(result,err); assert(files.opened==prefix .. ".cbz"); assert(files.hash==digest.hash(files.opened,sha.sha256))
local r=archiver.Reader:new(); assert(r:open(files.opened)); local entry=r:next(); assert(entry and entry.path=="Chapter 1 - Fixture chapter/000001.jpg" and r:extractToMemory(entry.path)); r:close()
local checked,check_err; reader.open(deps,manga,chapter,function(ok,e) checked,check_err=ok,e end); assert(checked,check_err)
local chapter2={id="d",manga_id="m",name="Chapter 2 - Fixture chapter"}
local merged,merge_err; reader.open(deps,manga,chapter2,function(ok,e) merged,merge_err=ok,e end); assert(merged,merge_err)
local multi=archiver.Reader:new(); assert(multi:open(files.opened))
assert(multi:next().path=="Chapter 1 - Fixture chapter/000001.jpg")
assert(multi:next().path=="Chapter 2 - Fixture chapter/000001.jpg")
multi:close()
-- Corrupt an image byte while leaving the ZIP directory intact.
local archive_file=assert(io.open(files.opened,"rb")); local bytes=archive_file:read("*a"); archive_file:close()
local pos=assert(bytes:find(image_data:sub(32,40),1,true)); bytes=bytes:sub(1,pos-1) .. "X" .. bytes:sub(pos+1)
archive_file=assert(io.open(files.opened,"wb")); assert(archive_file:write(bytes)); archive_file:close()
local failed, failure
reader.open(deps,manga,chapter,function(ok,e) failed,failure=ok,e end)
assert(not failed and failure=="Downloaded archive is invalid")
os.remove(files.opened); os.execute("rmdir " .. prefix)
print("Chapter pipeline and corrupt archive detection passed")
