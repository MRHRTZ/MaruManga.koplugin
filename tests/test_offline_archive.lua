local Reader=dofile("reader/chapter_reader.lua")
local entries={{path="000001.jpg",mode="file",size=20}}
local archive={open=function() return true end,iterate=function() local i=0; return function() i=i+1; return entries[i] end end,extractToMemory=function() return "data" end, close=function() end}
local opened, message
local deps={fs={verifyEntry=function() return true end,targetFor=function() return "existing.cbz" end,exists=function() return true end},archiver={Reader={new=function() return archive end}},library={linkArchive=function() return true end},openDocument=function(p) opened=p end}
local manga={id="m",source_id="s"}; local chapter={id="c",manga_id="m"}
Reader.open(deps,manga,chapter,function(ok,err) message=ok or err end); assert(message==true and opened=="existing.cbz")
opened=nil; entries[1].size=0
Reader.open(deps,manga,chapter,function(ok,err) message=ok or err end); assert(not opened and message=="Downloaded archive is invalid")
print("Offline archive checks passed")
