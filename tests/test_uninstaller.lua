local Uninstaller = dofile("core/uninstaller.lua")

local function fixture(with_other_data)
    local modes = {}
    local function directory(path) modes[path] = "directory" end
    local function file(path) modes[path] = "file" end
    directory("/plugins")
    directory("/plugins/MaruManga.koplugin")
    file("/plugins/MaruManga.koplugin/main.lua")
    directory("/plugins/MaruManga.koplugin/core")
    file("/plugins/MaruManga.koplugin/core/uninstaller.lua")
    directory("/settings")
    file("/settings/marumanga.lua")
    file("/settings/marumanga.lua.old")
    file("/settings/marumanga.lua.new")
    directory("/data")
    directory("/data/manga")
    file("/data/manga/series.cbz")
    directory("/data/cache")
    file("/data/cache/icon.png")
    if with_other_data then file("/data/notes.txt") end
    local function children(path)
        local found = {}
        local prefix = path .. "/"
        for candidate in pairs(modes) do
            if candidate:sub(1, #prefix) == prefix then
                local tail = candidate:sub(#prefix + 1)
                local name = tail:match("^([^/]+)")
                if name then found[name] = true end
            end
        end
        local names = {".", ".."}
        for name in pairs(found) do names[#names + 1] = name end
        table.sort(names)
        local index = 0
        return function()
            index = index + 1
            return names[index]
        end
    end
    local lfs = {
        attributes=function(path) return modes[path] end,
        symlinkattributes=function(path) return modes[path] end,
        dir=function(path) return children(path) end,
        rmdir=function(path)
            for candidate in pairs(modes) do if candidate:sub(1, #path + 1) == path .. "/" then return nil end end
            modes[path] = nil
            return true
        end,
    }
    local function remove(path)
        if modes[path] ~= "file" then return nil end
        modes[path] = nil
        return true
    end
    return modes, lfs, remove
end

local modes, lfs, remove = fixture(true)
assert(Uninstaller.uninstall({lfs=lfs,remove_file=remove,plugin_path="/plugins/MaruManga.koplugin/",remove_data=false}))
assert(not modes["/plugins/MaruManga.koplugin"])
assert(modes["/settings/marumanga.lua"] and modes["/data/manga/series.cbz"])

modes, lfs, remove = fixture(true)
assert(Uninstaller.uninstall({lfs=lfs,remove_file=remove,plugin_path="/plugins/MaruManga.koplugin",remove_data=true,settings_path="/settings/marumanga.lua",download_root="/data"}))
assert(not modes["/plugins/MaruManga.koplugin"])
assert(not modes["/settings/marumanga.lua"] and not modes["/settings/marumanga.lua.old"] and not modes["/settings/marumanga.lua.new"])
assert(not modes["/data/manga"] and not modes["/data/cache"])
assert(modes["/data/notes.txt"] and modes["/data"] == "directory")

modes, lfs, remove = fixture(false)
modes["/plugins/MaruManga.koplugin/unsafe-link"] = "link"
local ok, err = Uninstaller.uninstall({lfs=lfs,remove_file=remove,plugin_path="/plugins/MaruManga.koplugin",remove_data=false})
assert(not ok and err:find("symlink",1,true))
assert(not Uninstaller.uninstall({lfs=lfs,remove_file=remove,plugin_path="/",remove_data=false}))

print("Plugin uninstaller safety checks passed")
