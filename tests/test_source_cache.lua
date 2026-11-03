local FS=dofile("reader/filesystem.lua"); local root="/root"; local source=root.."/manga/s"; local dir=source.."/m"; local cover=dir.."/cover.jpg"; local bad=dir.."/cover.png"
local modes={[root.."/manga"]="directory",[source]="directory",[dir]="directory",[cover]="file",[bad]="link"}; local removed={}
local lfs={attributes=function(p) return modes[p] end,symlinkattributes=function(p) return modes[p] end,dir=function() local i=0; local values={".","..","m"}; return function() i=i+1; return values[i] end end}
local fs=FS.new(lfs,function() end,root,function(p) removed[p]=true; return true end)
assert(fs.clearSourceCovers("s")==1 and removed[cover] and not removed[bad]); assert(not fs.clearSourceCovers("../bad"))
print("Source cache cleanup tests passed")
