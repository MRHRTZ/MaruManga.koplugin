-- Portable migration ZIP reader/writer. Only a JSON manifest and indexed CBZ
-- files are accepted; ZIP paths are never extracted directly to disk.
local M = {}

local function writeAll(file, data)
    return file:write(data) ~= nil
end

function M.export(archiver, output, manifest, manifest_file, archive_files, fs, verify_entry)
    local f, err = io.open(manifest_file, "wb")
    if not f then return nil, err or "Cannot create migration manifest" end
    local wrote = writeAll(f, manifest)
    local closed = f:close()
    if not wrote or not closed then os.remove(manifest_file); return nil, "Cannot write migration manifest" end
    local writer = archiver.Writer:new()
    if not writer:open(output, "zip") then os.remove(manifest_file); return nil, "Cannot create migration archive" end
    local function fail(message)
        pcall(writer.close, writer); os.remove(output); os.remove(manifest_file); return nil, message
    end
    if not writer:setZipCompression("store") then return fail("Cannot configure migration archive") end
    writer:addPath("manifest.json", manifest_file, false)
    if writer.err then return fail("Cannot add migration manifest") end
    for _, item in ipairs(archive_files) do
        writer:addPath(item.entry, item.path, false)
        if writer.err then return fail("Cannot add downloaded manga file") end
    end
    writer:close()
    os.remove(manifest_file)
    local reader = archiver.Reader:new()
    if not reader:open(output) then os.remove(output); return nil, "Cannot verify migration archive" end
    local count, valid = 0, true
    for entry in reader:iterate() do
        count = count + 1
        if entry.mode ~= "file" or not entry.size or entry.size <= 0
            or not verify_entry(reader, entry) then valid = false end
    end
    if reader.err then valid = false end
    reader:close()
    if not valid or count ~= #archive_files + 1 then os.remove(output); return nil, "Migration archive verification failed" end
    return true
end

local function streamEntry(reader, archive, entry, target, ffi)
    local temporary = target .. ".importing"
    local file = io.open(temporary, "wb")
    if not file then return nil, "Cannot create imported manga file" end
    reader.index = math.floor(reader.index) + 0.1
    local buffer = ffi.new("uint8_t[?]", 65536)
    local total = 0
    while true do
        local read = tonumber(archive.archive_read_data(reader.archive, buffer, 65536))
        if not read or read < 0 then file:close(); os.remove(temporary); return nil, "Cannot read migration archive entry" end
        if read == 0 then break end
        total = total + read
        if total > entry.size then file:close(); os.remove(temporary); return nil, "Migration archive entry exceeds its declared size" end
        if not file:write(ffi.string(buffer, read)) then file:close(); os.remove(temporary); return nil, "Cannot write imported manga file" end
    end
    local closed = file:close()
    if total ~= entry.size or not closed then os.remove(temporary); return nil, "Imported manga file is incomplete" end
    local ok, err = os.rename(temporary, target)
    if not ok then os.remove(temporary); return nil, err or "Cannot save imported manga file" end
    return true
end

function M.import(archiver, input, destination, migration, json, archive_check, verify_entry, fs)
    local reader = archiver.Reader:new()
    if not reader:open(input) then return nil, "Cannot open migration archive" end
    local manifest_json
    for entry in reader:iterate() do
        if entry.path == "manifest.json" then
            if entry.mode ~= "file" or not entry.size or entry.size < 2 or entry.size > 16777216 then
                reader:close(); return nil, "Migration manifest size is invalid"
            end
            manifest_json = reader:extractToMemory(entry.path)
            break
        end
    end
    local had_error = reader.err
    reader:close()
    if had_error or type(manifest_json) ~= "string" then return nil, "Migration manifest is missing or corrupted" end
    local decoded_ok, manifest = pcall(json.decode, manifest_json)
    if not decoded_ok then return nil, "Migration manifest is invalid JSON" end
    local valid, why = migration.validate(manifest)
    if not valid then return nil, why end

    local lfs = require("libs/libkoreader-lfs")
    local destination_mode=(lfs.symlinkattributes or lfs.attributes)(destination,"mode")
    if destination_mode and destination_mode~="directory" then return nil,"Selected storage path is not a directory" end
    if not destination_mode then
        local made,make_error=lfs.mkdir(destination)
        if not made then return nil,make_error or "Cannot create the selected storage folder" end
    end
    local ffi = require("ffi")
    require("ffi/libarchive_h")
    local archive = ffi.loadlib("archive", "13")
    local imported, imported_paths = {}, {}
    local record_by_entry = {}
    for old_path, record in pairs((manifest.settings.marumanga_library or {}).archives or {}) do
        for _, item in ipairs(manifest.archives) do
            if item.path == old_path then record_by_entry[item.entry] = record end
        end
    end
    local reader2 = archiver.Reader:new()
    if not reader2:open(input) then return nil, "Cannot reopen migration archive" end
    local expected = {}
    for _, item in ipairs(manifest.archives) do expected[item.entry] = true end
    local found = {}
    local function fail(message)
        reader2:close()
        for _, target in ipairs(imported) do os.remove(target) end
        return nil, message
    end
    for entry in reader2:iterate() do
        local record = record_by_entry[entry.path]
        if expected[entry.path] then
            if found[entry.path] or entry.mode ~= "file" or not entry.size or entry.size < 22
                or entry.size > 8589934592 then return fail("Migration archive has an invalid manga file") end
            found[entry.path] = true
            local manga = type(record) == "table" and record.manga
            if type(manga) ~= "table" or type(manga.source_id) ~= "string" or type(manga.id) ~= "string"
                or not manga.source_id:match("^[%w_-]+$") or not manga.id:match("^[%w_-]+$") then
                return fail("Migration manga metadata is invalid")
            end
            local title = type(manga.title) == "string" and manga.title or "Manga"
            local base = fs.mangaTargetFor(manga.source_id, manga.id, title)
            if not base then return fail("Cannot create a safe filename for imported manga") end
            local target, suffix = base, 1
            while lfs.symlinkattributes(target, "mode") do
                suffix = suffix + 1
                local stem = base:sub(1, -5)
                target = stem .. "-import-" .. suffix .. ".cbz"
                if suffix > 10000 then return fail("Too many filename conflicts during migration") end
            end
            local ok, err = streamEntry(reader2, archive, entry, target, ffi)
            if not ok then return fail(err) end
            local archive_ok, archive_err = archive_check.validate(target, archiver, verify_entry)
            if not archive_ok then os.remove(target); return fail(archive_err or "Imported manga archive is invalid") end
            imported[#imported + 1] = target
            for _, item in ipairs(manifest.archives) do
                if item.entry == entry.path then imported_paths[item.path] = target; break end
            end
        elseif entry.path ~= "manifest.json" then
            return fail("Migration archive contains an unexpected file")
        end
    end
    local archive_error = reader2.err
    reader2:close()
    if archive_error then for _, target in ipairs(imported) do os.remove(target) end; return nil, "Migration archive is corrupted" end
    for item in pairs(expected) do
        if not found[item] then for _, target in ipairs(imported) do os.remove(target) end; return nil, "Migration is missing a manga file" end
    end
    local restored, restore_error = migration.restore(manifest, imported_paths)
    if not restored then for _, target in ipairs(imported) do os.remove(target) end; return nil, restore_error end
    if type(restored.marumanga)=="table" then
        local default=destination=="/" and "/" or nil
        restored.marumanga.download_dir=default or destination
    end
    return restored, #imported, imported
end

return M
