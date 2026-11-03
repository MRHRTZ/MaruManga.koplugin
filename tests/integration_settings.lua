-- Actual KOReader LuaSettings, serializer and LuaFileSystem on Linux.
local frontend=assert(os.getenv("KOREADER_FRONTEND")); package.path=frontend.."/?.lua;"..package.path
package.preload["libs/libkoreader-lfs"]=function() return require("lfs") end
package.preload.logger=function() return {warn=function() end} end
package.preload.util=function() return {} end
package.preload["ffi/util"]=function() return {orderedPairs=pairs} end
local LuaSettings=require("luasettings"); local Safe=dofile("storage/safe_settings.lua"); local Settings=dofile("storage/settings.lua"); local Library=dofile("storage/library.lua")
local path=os.tmpname(); os.remove(path)
local store=Safe.wrap(LuaSettings:open(path),require("dump")); local cfg=assert(Settings.open(store))
assert(cfg:setLanguage("ja")); assert(cfg:save()); local library=assert(Library.open(store)); assert(library:add({id="a",source_id="mangadex",title="Title"}))
local reopened=LuaSettings:open(path); assert(reopened:readSetting("marumanga").language=="ja" and reopened:readSetting("marumanga_library").manga["mangadex:a"].title=="Title")
local src=assert(io.open(path,"rb")); local content=src:read("*a"); src:close(); local backup=assert(io.open(path..".old","wb")); backup:write(content); backup:close()
local damaged=assert(io.open(path,"wb")); damaged:write("not valid lua !"); damaged:close()
local recovered=LuaSettings:open(path); assert(recovered:readSetting("marumanga").language=="ja")
os.remove(path); os.remove(path..".old"); os.remove(path..".new")
print("Real KOReader settings persistence and recovery passed")
