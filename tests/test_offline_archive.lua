local Reader=dofile("reader/chapter_reader.lua")
local entries={{path="000001.jpg",mode="file",size=20}}
local archive={open=function() return true end,iterate=function() local i=0; return function() i=i+1; return entries[i] end end,extractToMemory=function() return "data" end, close=function() end}
local opened, message
local deps={fs={verifyEntry=function() return true end,targetFor=function() return "existing.cbz" end,exists=function(path) return not path:match("%.incomplete$") end},archiver={Reader={new=function() return archive end}},library={linkArchive=function() return true end},openDocument=function(p) opened=p end}
local manga={id="m",source_id="s"}; local chapter={id="c",manga_id="m"}
Reader.open(deps,manga,chapter,function(ok,err) message=ok or err end); assert(message==true and opened=="existing.cbz")
entries[1].path="Chapter 1 - Reunion/000001.jpg"
Reader.open(deps,manga,chapter,function(ok,err) message=ok or err end); assert(message==true,"titled CBZ chapter should remain readable")
entries[1].path="000001.jpg"
opened=nil; entries[1].size=0
Reader.open(deps,manga,chapter,function(ok,err) message=ok or err end); assert(not opened and message=="Downloaded archive is invalid")
entries[1].size=20; entries[1].path=nil
Reader.open(deps,manga,chapter,function(ok,err) message=ok or err end); assert(message=="Downloaded archive is invalid")
entries[1].path="000002.jpg"
Reader.open(deps,manga,chapter,function(ok,err) message=ok or err end); assert(message=="Downloaded archive is invalid")
entries[1].path="../000001.jpg"
Reader.open(deps,manga,chapter,function(ok,err) message=ok or err end); assert(message=="Downloaded archive is invalid")
entries[1].path="000001.jpg"; deps.library.archiveDigest=function() return "expected" end
deps.verifyExisting=function(_,_,cb) cb(true,"different") end
Reader.open(deps,manga,chapter,function(ok,err) message=ok or err end); assert(message:find("changed",1,true))
deps.verifyExisting=function(_,_,cb) cb(true,"expected") end
Reader.open(deps,manga,chapter,function(ok,err) message=ok or err end); assert(message==true)
print("Offline archive checks passed")
