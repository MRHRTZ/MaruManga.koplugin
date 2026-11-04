local FS=dofile("reader/filesystem.lua")
local root="/root"; local staging=root.."/manga/s/m/.c-1.staging"; local file=staging.."/000001.image"; local part=root.."/manga/s/m/manga.cbz.part"
local modes={[staging]="directory",[file]="file",[part]="file"}; local names={".","..","000001.image"}; local removed={}
local lfs={attributes=function(p) return modes[p] end,symlinkattributes=function(p) return modes[p] end,
 dir=function() local i=0; return function() i=i+1; return names[i] end end,rmdir=function(p) modes[p]=nil; return true end}
local marker_content="owned\n"
local fs=FS.new(lfs,function() return false end,root,function(p) removed[p]=true; modes[p]=nil; return true end,nil,function() return marker_content end)
assert(fs.cleanupTemporary("s","m","c-1")); assert(removed[file] and removed[part] and not modes[staging])
modes[staging]="directory"; names={"unexpected.txt"}; assert(not fs.cleanupTemporary("s","m","c-1")); assert(modes[staging])
modes[staging]="link"; assert(not fs.cleanupTemporary("s","m","c-1"))
modes[staging]=nil; local target=root.."/manga/s/m/manga.cbz"; local marker=target..".incomplete"
modes[target]="file"; modes[marker]="file"; marker_content=""; assert(not fs.cleanupTemporary("s","m","c-1")); assert(modes[target])
marker_content="owned\n"; assert(fs.cleanupTemporary("s","m","c-1")); assert(removed[target] and removed[marker])
modes[target]="file"; modes[marker]=nil; removed[target]=nil; assert(fs.cleanupTemporary("s","m","c-1")); assert(not removed[target])
local backup=target..".broken"; local backup_marker=backup..".incomplete"
modes[target]="file"; modes[backup]="file"; modes[backup_marker]="file"; marker_content="owned\n"
assert(fs.cleanupTemporary("s","m","c-1")); assert(removed[backup] and removed[backup_marker] and modes[target])
modes[target]=nil; modes[backup]="file"; modes[backup_marker]="file"; assert(not fs.cleanupTemporary("s","m","c-1")); assert(modes[backup])
print("Temporary cleanup safety tests passed")
