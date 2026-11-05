-- Removes only this plugin and its explicitly owned data paths.
local M = {}

local function normalizePath(path)
    if type(path) ~= "string" then return nil end
    path = path:gsub("[/\\]+$", "")
    if path == "" or path:find("[%z%c]") or not path:match("^/") then return nil end
    for part in path:gmatch("[^/]+") do
        if part == "." or part == ".." then return nil end
    end
    return path
end

local function modeOf(lfs, path)
    local attributes = lfs.symlinkattributes or lfs.attributes
    return attributes(path, "mode")
end

function M.removeTree(lfs, path, remove_file)
    remove_file = remove_file or os.remove
    path = normalizePath(path)
    if not path then return nil, "Refusing to remove an unsafe path" end
    local mode = modeOf(lfs, path)
    if not mode then return true end
    if mode ~= "directory" then return nil, "Refusing to remove a non-directory path" end
    local ok, iterator, state = pcall(lfs.dir, path)
    if not ok or not iterator then return nil, "Could not inspect directory for removal" end
    for name in iterator, state do
        if name ~= "." and name ~= ".." then
            if type(name) ~= "string" or name == "" or name:find("[/\\%z%c]") then
                return nil, "Directory contains an unsafe entry"
            end
            local child = path .. "/" .. name
            local child_mode = modeOf(lfs, child)
            if child_mode == "directory" then
                local removed, err = M.removeTree(lfs, child, remove_file)
                if not removed then return nil, err end
            elseif child_mode == "file" then
                if not remove_file(child) then return nil, "Could not remove plugin data file" end
            else
                return nil, "Refusing to remove a symlink or unsupported file"
            end
        end
    end
    if not lfs.rmdir(path) then return nil, "Could not remove plugin data directory" end
    return true
end

local function removeFile(lfs, path, remove_file)
    remove_file = remove_file or os.remove
    local mode = modeOf(lfs, path)
    if not mode then return true end
    if mode ~= "file" then return nil, "Refusing to remove a non-file setting" end
    if not remove_file(path) then return nil, "Could not remove plugin settings" end
    return true
end

local function removeIfEmpty(lfs, path)
    local mode = modeOf(lfs, path)
    if not mode then return true end
    if mode ~= "directory" then return nil, "Refusing to remove an unsafe data directory" end
    local ok, iterator, state = pcall(lfs.dir, path)
    if not ok or not iterator then return nil, "Could not inspect plugin data directory" end
    for name in iterator, state do
        if name ~= "." and name ~= ".." then return true end
    end
    if not lfs.rmdir(path) then return nil, "Could not remove empty plugin data directory" end
    return true
end

local function removeOwnedArchive(lfs, download_root, path, remove_file)
    local prefix=download_root.."/"
    if type(path)~="string" or path:sub(1,#prefix)~=prefix then return true end
    local name=path:sub(#prefix+1)
    if not name:match("^[%w_-]+%.cbz$") then return true end
    for _,suffix in ipairs({"", ".incomplete", ".part", ".broken", ".broken.incomplete"}) do
        local file=path..suffix
        local mode=modeOf(lfs,file)
        if mode then
            if mode~="file" then return nil,"Refusing to remove an unsafe manga archive" end
            if not remove_file(file) then return nil,"Could not remove a downloaded manga archive" end
        end
    end
    return true
end

function M.removeData(lfs, settings_path, download_root, remove_file, downloaded_archives)
    settings_path = normalizePath(settings_path)
    download_root = normalizePath(download_root)
    if not settings_path or not download_root then return nil, "Refusing to remove unsafe plugin data paths" end
    for _, child in ipairs({".marumanga", "manga", "cache"}) do
        local removed, err = M.removeTree(lfs, download_root .. "/" .. child, remove_file)
        if not removed then return nil, err end
    end
    for _,archive in ipairs(downloaded_archives or {}) do
        local removed,err=removeOwnedArchive(lfs,download_root,archive,remove_file)
        if not removed then return nil,err end
    end
    local removed, err = removeIfEmpty(lfs, download_root)
    if not removed then return nil, err end
    for _, suffix in ipairs({"", ".old", ".new"}) do
        removed, err = removeFile(lfs, settings_path .. suffix, remove_file)
        if not removed then return nil, err end
    end
    return true
end

function M.uninstall(opts)
    local plugin_path = normalizePath(opts.plugin_path)
    if not plugin_path or not plugin_path:match("%.koplugin$") then
        return nil, "Refusing to remove an invalid plugin directory"
    end
    if modeOf(opts.lfs, plugin_path) ~= "directory" then
        return nil, "Plugin directory is missing or unsafe"
    end
    if opts.remove_data then
        local removed, err = M.removeData(opts.lfs, opts.settings_path, opts.download_root, opts.remove_file, opts.downloaded_archives)
        if not removed then return nil, err end
    end
    return M.removeTree(opts.lfs, plugin_path, opts.remove_file)
end

return M
