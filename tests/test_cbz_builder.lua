local Builder = dofile("reader/cbz_builder.lua")
local files, entries = {}, {}
local fs = {verifyEntry=function() return true end,exists=function(p) return files[p] end, remove=function(p) files[p]=nil end, publishNoReplace=function(a,b) if files[b] then return false end; files[b]=files[a]; files[a]=nil; return true end}
local writer = {open=function(_,p) files[p]=true; return true end, setZipCompression=function() return true end, addPath=function(_,name) entries[#entries+1]={path=name,mode="file",size=5}; return true end, extractToMemory=function() return "data" end, close=function() end}
local reader = {open=function() return true end, iterate=function() local i=0; return function() i=i+1; return entries[i] end end, extractToMemory=function() return "data" end, close=function() end}
local archiver={Writer={new=function() return writer end},Reader={new=function() return reader end}}
assert(Builder.build(archiver,fs,"chapter.cbz",{{path="a",extension="jpg"},{path="b",extension="png"}},"Chapter 1: The / Beginning"))
assert(entries[1].path == "Chapter 1 The Beginning/000001.jpg" and entries[2].path == "Chapter 1 The Beginning/000002.png")
assert(not Builder.build(archiver,fs,"chapter.cbz",{{path="a",extension="jpg"}}))
assert(not Builder.build(archiver,fs,"empty.cbz",{}))
entries={}; writer.addPath=function(_,name) entries[#entries+1]={path=name,mode="file",size=0}; return true end
assert(not Builder.build(archiver,fs,"bad.cbz",{{path="a",extension="jpg"}})); assert(not files["bad.cbz.part"])

-- Removing one chapter from a manga CBZ preserves and verifies the other
-- chapter entries before atomically replacing the archive.
local archive_files={["manga.cbz"]=true}
local archive_entries={["manga.cbz"]={
    {path="Chapter 1/000001.jpg",mode="file",size=5},
    {path="Chapter 1/000002.jpg",mode="file",size=6},
    {path="Chapter 2/000001.png",mode="file",size=7},
}}
local rebuilt_entries
local delete_fs={
    exists=function(p) return archive_files[p] end,
    remove=function(p) archive_files[p]=nil; archive_entries[p]=nil; return true end,
    verifyEntry=function() return true end,
    publishReplace=function(tmp,target)
        if not archive_files[tmp] then return false end
        archive_files[target]=true; archive_files[tmp]=nil
        archive_entries[target]=archive_entries[tmp]; archive_entries[tmp]=nil
        return true
    end,
}
local delete_writer={open=function(_,p) archive_files[p]=true; rebuilt_entries={}; archive_entries[p]=rebuilt_entries; return true end,
    setZipCompression=function() return true end,
    addFileFromMemory=function(_,name) rebuilt_entries[#rebuilt_entries+1]={path=name,mode="file",size=8}; return true end,
    close=function() end}
local delete_reader={open=function(self,p) self.entries=archive_entries[p]; return self.entries~=nil end,
    iterate=function(self) local index=0; return function() index=index+1; return self.entries[index] end end,
    extractToMemory=function() return "image" end,close=function() end}
local delete_archiver={Writer={new=function() return delete_writer end},Reader={new=function() return setmetatable({}, {__index=delete_reader}) end}}
local removed,remaining=Builder.removeChapter(delete_archiver,delete_fs,"manga.cbz","Chapter 1")
assert(removed and remaining==1)
assert(#archive_entries["manga.cbz"]==1 and archive_entries["manga.cbz"][1].path=="Chapter 2/000001.png")
assert(not archive_files["manga.cbz.part"])
print("CBZ builder contract tests passed")
