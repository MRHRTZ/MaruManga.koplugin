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
assert(cfg.data.download_concurrency==2 and cfg:setNetwork(15,3,"MaruMangaDownloader test","",4) and cfg:save())
local reopened=LuaSettings:open(path); assert(reopened:readSetting("marumanga").language=="ja" and reopened:readSetting("marumanga").download_concurrency==4 and reopened:readSetting("marumanga_library").manga["mangadex:a"].title=="Title")
local src=assert(io.open(path,"rb")); local content=src:read("*a"); src:close(); local backup=assert(io.open(path..".old","wb")); backup:write(content); backup:close()
local damaged=assert(io.open(path,"wb")); damaged:write("not valid lua !"); damaged:close()
local recovered=assert(Safe.open(LuaSettings,path)); assert(recovered:readSetting("marumanga").language=="ja" and recovered.recovered_from_backup)
Safe.wrap(recovered,require("dump")); assert(recovered:flush())
local backup_check=assert(io.open(path..".old","rb")); local preserved=backup_check:read("*a"); backup_check:close(); assert(preserved==content)
local bad=assert(io.open(path,"wb")); bad:write("not valid lua !"); bad:close()
bad=assert(io.open(path..".old","wb")); bad:write("also invalid !"); bad:close()
local missing,why=Safe.open(LuaSettings,path); assert(not missing and why:find("preserved",1,true))
os.remove(path); os.remove(path..".old"); os.remove(path..".new")
print("Real KOReader settings persistence and recovery passed")
