local FS=dofile("reader/filesystem.lua")
local root="/root"; local staging=root.."/manga/s/m/chapters/.c-1.staging"; local file=staging.."/000001.image"; local part=root.."/manga/s/m/chapters/c-1.cbz.part"
local modes={[staging]="directory",[file]="file",[part]="file"}; local names={".","..","000001.image"}; local removed={}
local lfs={attributes=function(p) return modes[p] end,symlinkattributes=function(p) return modes[p] end,
 dir=function() local i=0; return function() i=i+1; return names[i] end end,rmdir=function(p) modes[p]=nil; return true end}
local fs=FS.new(lfs,function() return false end,root,function(p) removed[p]=true; modes[p]=nil; return true end)
assert(fs.cleanupTemporary("s","m","c-1")); assert(removed[file] and removed[part] and not modes[staging])
modes[staging]="directory"; names={"unexpected.txt"}; assert(not fs.cleanupTemporary("s","m","c-1")); assert(modes[staging])
modes[staging]="link"; assert(not fs.cleanupTemporary("s","m","c-1"))
print("Temporary cleanup safety tests passed")
