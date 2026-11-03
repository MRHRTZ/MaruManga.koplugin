local Reader=dofile("reader/chapter_reader.lua")
local removed,opened,result
local deps={fs={prepare=function() return {target="t.cbz",staging="dir"} end,remove=function() end},
 removeDir=function(p) removed=p end, source={getPageList=function(_,_,cb) cb({{image_url="https://x"}}) end},
 stager={start=function(_,pages,target,cb) assert(#pages==1 and target=="t.cbz"); cb(true) end},
 library={linkArchive=function(_,path) assert(path=="t.cbz"); return true end},openDocument=function(p) opened=p end}
local manga={id="m",source_id="s"}; local chapter={id="c",manga_id="m"}
Reader.open(deps,manga,chapter,function(ok) result=ok end)
assert(result and removed=="dir" and opened=="t.cbz")
Reader.open(deps,manga,{id="c",manga_id="wrong"},function(ok,err) assert(not ok and err) end)
print("Chapter reader coordination tests passed")
