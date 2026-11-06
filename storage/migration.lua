-- Portable snapshot of all MaruManga settings and indexed manga archives.
-- The archive container and filesystem operations live in main.lua; this
-- module validates the untrusted manifest and remaps paths on import.
local M = {}
local FORMAT = "MaruManga Migration"
local VERSION = 1

local function safe_path(value)
    return type(value) == "string" and value:sub(1, 1) == "/"
        and not value:find("%.%.") and not value:find("[%c]")
end

function M.create(settings_data, archive_paths)
    if type(settings_data) ~= "table" then return nil, "Invalid MaruManga settings" end
    local archives, seen = {}, {}
    for _, item in ipairs(archive_paths or {}) do
        if type(item) == "table" and safe_path(item.path)
            and type(item.entry) == "string" and item.entry:match("^files/%d%d%d%d%d%d%.cbz$")
            and not seen[item.path] then
            archives[#archives + 1] = { path=item.path, entry=item.entry }
            seen[item.path] = true
        end
    end
    return { format=FORMAT, version=VERSION, settings=settings_data, archives=archives }
end

function M.validate(manifest)
    if type(manifest) ~= "table" or manifest.format ~= FORMAT or manifest.version ~= VERSION
        or type(manifest.settings) ~= "table" or type(manifest.archives) ~= "table" then
        return nil, "Unsupported or invalid MaruManga migration file"
    end
    if #manifest.archives > 10000 then return nil, "Migration contains too many manga files" end
    local entries, paths = {}, {}
    for _, item in ipairs(manifest.archives) do
        if type(item) ~= "table" or not safe_path(item.path)
            or type(item.entry) ~= "string" or not item.entry:match("^files/%d%d%d%d%d%d%.cbz$")
            or entries[item.entry] or paths[item.path] then
            return nil, "Migration archive index is invalid"
        end
        entries[item.entry], paths[item.path] = true, true
    end
    local library = manifest.settings.marumanga_library
    if library ~= nil and (type(library) ~= "table" or type(library.archives) ~= "table") then
        return nil, "Migration library metadata is invalid"
    end
    return true
end

function M.restore(manifest, imported_paths)
    local valid, err = M.validate(manifest)
    if not valid then return nil, err end
    if type(imported_paths) ~= "table" then return nil, "Imported file map is missing" end
    local settings = {}
    for key, value in pairs(manifest.settings) do settings[key] = value end
    local library = settings.marumanga_library
    if library then
        local archives = {}
        for old_path, record in pairs(library.archives) do
            local new_path = imported_paths[old_path]
            if new_path and type(record) == "table" then archives[new_path] = record end
        end
        library.archives = archives
    end
    return settings
end

M.FORMAT = FORMAT
M.VERSION = VERSION
M.safePath = safe_path
return M
