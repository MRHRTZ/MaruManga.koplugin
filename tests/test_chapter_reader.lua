local Reader=dofile("reader/chapter_reader.lua")
local removed,opened,result,recorded_digest
local deps={fs={prepare=function() return {target="t.cbz",staging="dir"} end,remove=function() end},
 removeDir=function(p) removed=p end, source={getPageList=function(_,_,cb) cb({{image_url="https://x"}}) end},
 stager={start=function(_,pages,target,cb) assert(#pages==1 and target=="t.cbz"); cb(true) end},
 library={linkArchive=function(_,path,_,_,_,digest) assert(path=="t.cbz"); recorded_digest=digest; return true end},hashArchive=function(_,cb) cb(string.rep("a",64)) end,openDocument=function(p) opened=p end}
local manga={id="m",source_id="s"}; local chapter={id="c",manga_id="m"}
Reader.open(deps,manga,chapter,function(ok) result=ok end)
assert(result and removed=="dir" and opened=="t.cbz" and recorded_digest==string.rep("a",64))
deps.hashArchive=function(_,cb) cb(nil,"hash failed") end; opened=nil
Reader.open(deps,manga,chapter,function(ok,err) assert(not ok and err=="hash failed") end); assert(not opened)
Reader.open(deps,manga,{id="c",manga_id="wrong"},function(ok,err) assert(not ok and err) end)
local hash_callback,hash_cancelled
 deps.hashArchive=function(_,cb) hash_callback=cb; return {cancel=function() hash_cancelled=true end} end
local running=Reader.open(deps,manga,chapter,function() end); running:cancel(); assert(hash_cancelled); hash_callback(nil,"Cancelled")
deps.source.getPageList=function() error("bad source") end; removed=nil
Reader.open(deps,manga,chapter,function(ok,err) assert(not ok and err=="Unable to load chapter") end); assert(removed=="dir")
print("Chapter reader coordination tests passed")
