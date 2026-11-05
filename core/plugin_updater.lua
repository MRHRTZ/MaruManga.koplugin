-- Safe, self-contained updater for this plugin's own GitHub release archive.
local M = {}

function M.isNewer(current, latest)
    if type(current) ~= "string" or type(latest) ~= "string" then return false end
    local function parts(value)
        local result = {}
        for number in value:gmatch("(%d+)") do result[#result + 1] = tonumber(number) end
        return result
    end
    local a, b = parts(current), parts(latest)
    if #a == 0 or #b == 0 then return false end
    for i = 1, math.max(#a, #b) do
        local av, bv = a[i] or 0, b[i] or 0
        if bv > av then return true end
        if bv < av then return false end
    end
    return false
end

local release_hosts = {
    ["github.com"] = true,
    ["release-assets.githubusercontent.com"] = true,
    ["objects.githubusercontent.com"] = true,
    ["github-releases.githubusercontent.com"] = true,
}
M.release_hosts = release_hosts

function M.validateURL(url)
    if type(url) ~= "string" or #url > 4096 or url:find("[%c%s#]") then return nil, "Invalid update URL" end
    local host = url:match("^https://([%w%.%-]+)/")
    if not host or not release_hosts[host:lower()] then return nil, "Update URL host is not allowed" end
    if url:find("@", 9, true) then return nil, "Credentials are not allowed in update URLs" end
    return host:lower()
end

function M.resolveRedirect(current_url, location)
    if type(location) ~= "string" or location == "" or location:find("[%c%s#]") then return nil, "Invalid update redirect" end
    local next_url = location
    if location:sub(1, 2) == "//" then
        next_url = "https:" .. location
    elseif location:sub(1, 1) == "/" then
        local origin = current_url:match("^(https://[%w%.%-]+)")
        if not origin then return nil, "Invalid update redirect origin" end
        next_url = origin .. location
    elseif not location:match("^https://") then
        return nil, "Update redirects must use HTTPS"
    end
    local host, err = M.validateURL(next_url)
    if not host then return nil, err end
    return next_url, host
end

local function removeTree(lfs, root)
    local mode = (lfs.symlinkattributes or lfs.attributes)(root, "mode")
    if not mode then return true end
    if mode ~= "directory" then return nil, "Unsafe update cleanup path" end
    local ok, iter, state = pcall(lfs.dir, root)
    if not ok or not iter then return nil, "Could not inspect update staging directory" end
    for name in iter, state do
        if name ~= "." and name ~= ".." then
            if name:find("[/\\%z]") then return nil, "Unsafe update staging entry" end
            local item = root .. "/" .. name
            local item_mode = (lfs.symlinkattributes or lfs.attributes)(item, "mode")
            if item_mode == "directory" then
                local removed, err = removeTree(lfs, item)
                if not removed then return nil, err end
            elseif item_mode == "file" then
                if not os.remove(item) then return nil, "Could not remove update staging file" end
            else
                return nil, "Refusing to remove an unsafe update staging entry"
            end
        end
    end
    if not lfs.rmdir(root) then return nil, "Could not remove update staging directory" end
    return true
end

local function safeRelative(path)
    if type(path) ~= "string" or path == "" or path:find("[%z\\]") or path:sub(1, 1) == "/" then return false end
    for part in path:gmatch("[^/]+") do
        if part == "." or part == ".." or part:find(":", 1, true) or part:find("[%c]") then return false end
    end
    return true
end
M.safeRelative = safeRelative

local function ensureDirectory(lfs, util, dir)
    local mode = (lfs.symlinkattributes or lfs.attributes)(dir, "mode")
    if mode == "directory" then return true end
    if mode then return nil, "Unsafe update staging path" end
    local ok, err = pcall(util.makePath, dir)
    if not ok then return nil, "Could not create update staging directory: " .. tostring(err) end
    if (lfs.symlinkattributes or lfs.attributes)(dir, "mode") ~= "directory" then return nil, "Could not create update staging directory" end
    return true
end

local function readFile(path)
    local file = io.open(path, "rb")
    if not file then return nil end
    local data = file:read("*a")
    file:close()
    return data
end

local function extractArchive(archiver, lfs, util, zip_path, stage, version)
    local reader = archiver.Reader:new()
    if not reader:open(zip_path) then return nil, "Could not open the update archive" end
    local prefixes, entries, total = {}, {}, 0
    local function fail(message)
        reader:close()
        return nil, message
    end
    for entry in reader:iterate() do
        local archive_path = entry.path
        if type(archive_path) ~= "string" or archive_path:find("[%z\\]") or archive_path:sub(1, 1) == "/" then
            return fail("Update archive contains an unsafe path")
        end
        local meta_prefix = archive_path:match("^(.-)_meta%.lua$")
        if meta_prefix then
            local root = meta_prefix:match("^([^/]+/)$")
            if not root or not root:match("%.koplugin/$") then return fail("Update archive has an invalid plugin folder") end
            prefixes[root] = true
        end
        if entry.mode ~= "directory" then
            if entry.mode ~= "file" or not tonumber(entry.size) or entry.size < 0 or entry.size > 8 * 1024 * 1024 then
                return fail("Update archive contains an unsupported file")
            end
            total = total + entry.size
            if total > 40 * 1024 * 1024 then return fail("Update archive is too large") end
            entries[#entries + 1] = entry
        end
    end
    if reader.err then return fail("Could not read the update archive") end
    local prefix, prefix_count
    prefix_count = 0
    for candidate in pairs(prefixes) do prefix, prefix_count = candidate, prefix_count + 1 end
    if prefix_count ~= 1 then return fail("Could not identify one plugin folder in the update archive") end
    local has_main, has_meta = false, false
    for _, entry in ipairs(entries) do
        local archive_path = entry.path
        if archive_path:sub(1, #prefix) ~= prefix then return fail("Update archive contains files outside its plugin folder") end
        local relative = archive_path:sub(#prefix + 1)
        if relative == "main.lua" then has_main = true end
        if relative == "_meta.lua" then has_meta = true end
        if not safeRelative(relative) then return fail("Update archive contains an unsafe file path") end
        local destination = stage .. "/" .. relative
        local parent = destination:match("^(.*)/[^/]+$")
        if parent then
            local made, err = ensureDirectory(lfs, util, parent)
            if not made then return fail(err) end
        end
        local extracted, extract_err = pcall(reader.extractToPath, reader, archive_path, destination)
        if not extracted or reader.err then return fail("Could not extract an update file: " .. tostring(extract_err or reader.err)) end
    end
    reader:close()
    if not has_main or not has_meta then return nil, "Update archive is missing plugin metadata or main.lua" end
    local metadata = readFile(stage .. "/_meta.lua")
    if not metadata or not metadata:match('version%s*=%s*["\']' .. version:gsub("([%.%-])", "%%%1") .. '["\']') then
        return nil, "The downloaded plugin version does not match the update manifest"
    end
    return true
end

local function installArchive(opts, zip_path, stage, backup)
    local lfs, util = opts.lfs, opts.util
    local mode = (lfs.symlinkattributes or lfs.attributes)(opts.plugin_path, "mode")
    if mode ~= "directory" then return nil, "Installed plugin directory is missing or unsafe" end
    local extracted, err = extractArchive(opts.archiver, lfs, util, zip_path, stage, opts.version)
    if not extracted then removeTree(lfs, stage); return nil, err end
    local renamed, rename_err = os.rename(opts.plugin_path, backup)
    if not renamed then removeTree(lfs, stage); return nil, "Could not back up the installed plugin: " .. tostring(rename_err) end
    local installed, install_err = os.rename(stage, opts.plugin_path)
    if not installed then
        local restored, restore_err = os.rename(backup, opts.plugin_path)
        removeTree(lfs, stage)
        if not restored then return nil, "Update failed and the previous plugin could not be restored: " .. tostring(restore_err) end
        return nil, "Could not activate the update: " .. tostring(install_err)
    end
    -- The new directory is live; remove the backup tree if it is safe to do so.
    local backup_removed = removeTree(lfs, backup)
    return true, backup_removed and nil or "Update installed; a backup was retained"
end

function M.downloadAndInstall(opts)
    local first_host, url_error = M.validateURL(opts.url)
    if not first_host then return nil, url_error end
    local allowed = opts.allowed_hosts or release_hosts
    local suffix = tostring(opts.now or os.time()) .. "-" .. tostring(opts.salt or math.random(10000, 99999))
    local zip_path = opts.plugin_path .. ".update-" .. suffix .. ".zip"
    local stage = opts.plugin_path .. ".update-" .. suffix .. ".stage"
    local backup = opts.plugin_path .. ".update-" .. suffix .. ".backup"
    local made, make_err = ensureDirectory(opts.lfs, opts.util, stage)
    if not made then return nil, make_err end
    local current_url = opts.url
    local complete, response_meta, response_headers
    for attempt = 0, 4 do
        local host = M.validateURL(current_url)
        if not host or not allowed[host] then removeTree(opts.lfs, stage); return nil, "Update redirected to an untrusted host" end
        local file, err = io.open(zip_path, "wb")
        if not file then removeTree(opts.lfs, stage); return nil, "Could not create update package: " .. tostring(err) end
        local deps = opts.dependencies()
        deps.allowed_hosts = {[host] = true}
        deps.timeout = deps.timeout or 30
        deps.max_bytes = 16 * 1024 * 1024
        deps.headers = {Accept = "application/zip, application/octet-stream"}
        deps.write = function(chunk)
            local ok, why = file:write(chunk)
            if not ok then return nil, why or "Update download write failed" end
            return true
        end
        local ok, code, meta, err_text, headers = pcall(opts.secure_request.fetch, current_url, deps)
        file:close()
        if not ok then os.remove(zip_path); removeTree(opts.lfs, stage); return nil, "Update download failed" end
        if code == 200 then complete, response_meta, response_headers = true, meta, headers; break end
        os.remove(zip_path)
        if code and code >= 300 and code < 400 and headers and headers.location and attempt < 4 then
            local redirect, redirect_err = M.resolveRedirect(current_url, headers.location)
            if not redirect then removeTree(opts.lfs, stage); return nil, redirect_err end
            current_url = redirect
        else
            removeTree(opts.lfs, stage)
            return nil, err_text or (code and ("HTTP " .. tostring(code)) or "Could not download the update")
        end
    end
    if not complete then os.remove(zip_path); removeTree(opts.lfs, stage); return nil, "Too many update redirects" end
    if type(response_meta) ~= "table" or response_meta.size <= 0 or response_meta.size > 16 * 1024 * 1024 or type(response_meta.prefix) ~= "string" or response_meta.prefix:sub(1, 2) ~= "PK" then
        os.remove(zip_path); removeTree(opts.lfs, stage); return nil, "Downloaded update is not a valid ZIP file"
    end
    if opts.sha256 then
        if type(opts.sha256) ~= "string" or not opts.sha256:match("^[0-9a-fA-F]+$") or #opts.sha256 ~= 64 then
            os.remove(zip_path); removeTree(opts.lfs, stage); return nil, "Update manifest has an invalid checksum"
        end
        local digest, digest_err = opts.digest(zip_path)
        if not digest or digest:lower() ~= opts.sha256:lower() then
            os.remove(zip_path); removeTree(opts.lfs, stage); return nil, digest_err or "Update checksum did not match"
        end
    end
    local installed, install_err = installArchive(opts, zip_path, stage, backup)
    os.remove(zip_path)
    if not installed then return nil, install_err end
    return true, install_err
end

return M
