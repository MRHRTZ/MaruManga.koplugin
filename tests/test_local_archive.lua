local Local=dofile("core/local_archive.lua")
local manga={source_id="s",id="m"}; local chapter={id="c",manga_id="m"}
local library={data={archives={}},archiveFor=function() return "/old" end}
local fs={exists=function(p) return p=="/new" end,targetFor=function() return "/new" end}
local path,indexed=Local.resolve(library,fs,manga,chapter); assert(path=="/new" and not indexed)
library.data.archives["/new"]={}; path,indexed=Local.resolve(library,fs,manga,chapter); assert(path=="/new" and indexed)
fs.exists=function(p) return p=="/old" end; path,indexed=Local.resolve(library,fs,manga,chapter); assert(path=="/old" and indexed)
print("Local archive reconciliation tests passed")
