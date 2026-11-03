-- Builds a CBZ from validated local image files using KOReader's libarchive wrapper.
-- Paths supplied here must already be under the caller's private staging directory.
local Builder = {}
local extensions = {jpeg="jpg", jpg="jpg", png="png", gif="gif", webp="webp"}
function Builder.build(archiver, fs, target, pages)
    if type(target) ~= "string" or target == "" or type(pages) ~= "table" or #pages == 0 then return nil, "Empty chapter" end
    if fs.exists(target) then return nil, "Chapter already exists" end
    local tmp = target .. ".part"
    if fs.exists(tmp) then return nil, "Incomplete archive already exists" end
    local writer = archiver.Writer:new()
    if not writer:open(tmp, "zip") then return nil, "Unable to create archive" end
    local function fail(message)
        writer:close(); fs.remove(tmp); return nil, message
    end
    if not writer:setZipCompression("store") then return fail("Unable to configure archive") end
    local expected = {}
    for i, page in ipairs(pages) do
        local ext = extensions[page.extension or ""]
        if not ext or type(page.path) ~= "string" then return fail("Invalid image") end
        local name = string.format("%06d.%s", i, ext)
        expected[i] = name
        -- KOReader addPath may return false at end-of-archive even after writing.
        -- Verify the resulting entry below; a reported archive error is fatal.
        writer:addPath(name, page.path, false)
        if writer.err then return fail("Unable to add image") end
    end
    writer:close()
    local reader = archiver.Reader:new()
    if not reader:open(tmp) then fs.remove(tmp); return nil, "Unable to verify archive" end
    local count, valid = 0, true
    for entry in reader:iterate() do
        count = count + 1
        if entry.path ~= expected[count] or entry.mode ~= "file" or not entry.size or entry.size <= 0 or entry.size > 20971520 then
            valid = false
        elseif not fs.verifyEntry or not fs.verifyEntry(reader,entry) then
            valid = false
        end
    end
    if reader.err then valid = false end
    reader:close()
    if not valid or count ~= #expected then fs.remove(tmp); return nil, "Corrupted archive" end
    if fs.exists(target) then fs.remove(tmp); return nil, "Chapter already exists" end
    -- The filesystem adapter must guarantee an atomic no-overwrite publish.
    if type(fs.publishNoReplace) ~= "function" then fs.remove(tmp); return nil, "Safe archive publishing unavailable" end
    local ok = fs.publishNoReplace(tmp, target)
    if not ok then fs.remove(tmp); return nil, "Unable to save archive" end
    return true
end
return Builder
