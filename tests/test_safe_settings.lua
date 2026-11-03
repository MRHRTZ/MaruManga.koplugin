local Safe=dofile("storage/safe_settings.lua")
local files={}; local fail_write=false; local fail_rename=false
local io_api={open=function(path) local content=""; return {write=function(_,s) if fail_write then return nil end; content=content..s; return true end,close=function() files[path]=content; return true end} end}
local os_api={remove=function(p) files[p]=nil; return true end,rename=function(a,b) if fail_rename then return nil end; files[b]=files[a]; files[a]=nil; return true end}
local store={file="config.lua",data={value=1},backup=function() return false end}
Safe.wrap(store,function() return "{ value = 1 }" end,nil,io_api,os_api)
assert(store:flush() and files["config.lua"]:find("value = 1",1,true))
fail_write=true; assert(not store:flush() and not files["config.lua.new"]); fail_write=false
fail_rename=true; assert(not store:flush() and files["config.lua"] and not files["config.lua.new"])
print("Atomic settings tests passed")
