local FS=dofile("reader/filesystem.lua")
local dirs={}; local lfs={attributes=function(p) return dirs[p] end,mkdir=function(p) if dirs[p] then return nil,"exists" end; dirs[p]="directory"; return true end}
local fs=FS.new(lfs,function() return true end,"/data")
local result=assert(fs.prepare("mangadex","123","456")); assert(result.target=="/data/manga/mangadex/123/chapters/456.cbz")
assert(not fs.prepare("mangadex","../bad","456")); assert(not fs.prepare("mangadex","123","456"))
print("Download filesystem tests passed")

assert(fs.coverDir("mangadex","123")=="/data/manga/mangadex/123"); assert(not fs.coverDir("../bad","123"))
