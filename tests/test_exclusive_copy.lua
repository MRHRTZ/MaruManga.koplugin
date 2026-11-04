local copy=dofile("reader/exclusive_copy.lua")
local base=os.tmpname(); os.remove(base)
local function put(p,v) local f=assert(io.open(p,"wb")); assert(f:write(v)); f:close() end
local function read(p) local f=io.open(p,"rb"); if not f then return nil end; local s=f:read("*a"); f:close(); return s end
put(base..".source",string.rep("data",30000))
assert(copy.move(base..".source",base..".dest")); assert(read(base..".dest")==string.rep("data",30000)); assert(not read(base..".source") and not read(base..".dest.incomplete"))
put(base..".source","new"); assert(not copy.move(base..".source",base..".dest")); assert(read(base..".dest")==string.rep("data",30000) and read(base..".source")=="new")
put(base..".another.incomplete","unfinished"); assert(not copy.move(base..".source",base..".another")); assert(read(base..".another.incomplete")=="unfinished")
os.remove(base..".source"); os.remove(base..".dest"); os.remove(base..".another.incomplete")
print("Exclusive-copy publication tests passed")
