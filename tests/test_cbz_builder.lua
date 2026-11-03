local Builder = dofile("reader/cbz_builder.lua")
local files, entries = {}, {}
local fs = {verifyEntry=function() return true end,exists=function(p) return files[p] end, remove=function(p) files[p]=nil end, publishNoReplace=function(a,b) if files[b] then return false end; files[b]=files[a]; files[a]=nil; return true end}
local writer = {open=function(_,p) files[p]=true; return true end, setZipCompression=function() return true end, addPath=function(_,name) entries[#entries+1]={path=name,mode="file",size=5}; return true end, extractToMemory=function() return "data" end, close=function() end}
local reader = {open=function() return true end, iterate=function() local i=0; return function() i=i+1; return entries[i] end end, extractToMemory=function() return "data" end, close=function() end}
local archiver={Writer={new=function() return writer end},Reader={new=function() return reader end}}
assert(Builder.build(archiver,fs,"chapter.cbz",{{path="a",extension="jpg"},{path="b",extension="png"}}))
assert(entries[1].path == "000001.jpg" and entries[2].path == "000002.png")
assert(not Builder.build(archiver,fs,"chapter.cbz",{{path="a",extension="jpg"}}))
assert(not Builder.build(archiver,fs,"empty.cbz",{}))
entries={}; writer.addPath=function(_,name) entries[#entries+1]={path=name,mode="file",size=0}; return true end
assert(not Builder.build(archiver,fs,"bad.cbz",{{path="a",extension="jpg"}})); assert(not files["bad.cbz.part"])
print("CBZ builder contract tests passed")
