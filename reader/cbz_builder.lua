-- Builds a CBZ from validated local image files using KOReader's libarchive wrapper.
-- Paths supplied here must already be under the caller's private staging directory.
local Builder = {}
local extensions = {jpeg="jpg", jpg="jpg", png="png", gif="gif", webp="webp"}
local function chapterFolder(title)
    if type(title)~="string" then title="Chapter" end
    title=title:gsub("[%z\1-\31\127/\\:*?\"<>|]", " "):gsub("%s+", " "):match("^%s*(.-)%s*$")
    if title=="" then title="Chapter" end
    -- Keep archive paths portable and avoid splitting UTF-8 sequences.
    local limit=180
    if #title>limit then
        local pieces,used={},0
        local index=1
        while index<=#title do
            local first=title:byte(index)
            local length=first<128 and 1 or first<224 and 2 or first<240 and 3 or 4
            if used+length>limit then break end
            pieces[#pieces+1]=title:sub(index,index+length-1)
            used=used+length; index=index+length
        end
        title=table.concat(pieces)
    end
    title=title:gsub("^[%. ]+", ""):gsub("[%. ]+$", "")
    if title=="" or title=="." or title==".." then return "Chapter" end
    return title
end
Builder.chapterFolder=chapterFolder
local function naturalLess(a,b)
    local ai,bi=1,1
    while ai<=#a and bi<=#b do
        local ac,bc=a:sub(ai,ai),b:sub(bi,bi)
        if ac:match("%d") and bc:match("%d") then
            local an=a:sub(ai):match("^(%d+)"); local bn=b:sub(bi):match("^(%d+)")
            local av,bv=tonumber(an),tonumber(bn)
            if av~=bv then return av<bv end
            if #an~=#bn then return #an<#bn end
            ai,bi=ai+#an,bi+#bn
        elseif ac~=bc then return ac:lower()<bc:lower()
        else ai,bi=ai+1,bi+1 end
    end
    return #a<#b
end
function Builder.build(archiver, fs, target, pages, chapter_title)
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
    local folder=chapterFolder(chapter_title)
    local expected = {}
    for i, page in ipairs(pages) do
        local ext = extensions[page.extension or ""]
        if not ext or type(page.path) ~= "string" then return fail("Invalid image") end
        local filename=string.format("%06d.%s",i,ext)
        local name=folder and (folder.."/"..filename) or filename
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
-- Rebuild one manga-level CBZ, merging the new chapter and naturally sorting
-- chapter folders so KOReader's native comic outline follows chapter order.
function Builder.merge(archiver,fs,target,pages,chapter_title)
    if type(target)~="string" or target=="" or type(pages)~="table" or #pages==0 then return nil,"Empty chapter" end
    local tmp=target..".part"
    if fs.exists(tmp) then return nil,"Incomplete archive already exists" end
    local folder=chapterFolder(chapter_title)
    local files={}
    local reader
    if fs.exists(target) then
        reader=archiver.Reader:new()
        if not reader:open(target) then return nil,"Existing manga archive is invalid" end
        local seen={}
        local ok,err=pcall(function()
            for entry in reader:iterate() do
                if entry.mode~="file" or type(entry.path)~="string" or entry.path:find("\\",1,true) or entry.path:sub(1,1)=="/" or entry.path:find("../",1,true) then error("Invalid existing archive entry") end
                local dir,filename=entry.path:match("^([^/]+)/([^/]+)$")
                local number,ext
                if filename then number,ext=filename:match("^(%d+)%.([%a]+)$") end
                local size=tonumber(entry.size)
                if not dir or dir=="." or dir==".." or not number or not extensions[ext:lower()] or tonumber(number)<1 or not size or size<=0 or size>20971520 then error("Invalid existing manga archive") end
                if dir~=folder then
                    if seen[entry.path] then error("Duplicate existing archive entry") end
                    seen[entry.path]=true
                    files[#files+1]={path=entry.path,reader=reader,source="archive"}
                end
            end
        end)
        if not ok or reader.err then reader:close(); return nil,(tostring(err):match("Invalid existing") and tostring(err)) or "Existing manga archive is corrupted" end
    end
    for i,page in ipairs(pages) do
        local ext=type(page)=="table" and extensions[page.extension or ""]
        if not ext or type(page.path)~="string" then if reader then reader:close() end; return nil,"Invalid image" end
        files[#files+1]={path=folder.."/"..string.format("%06d.%s",i,ext),source="new",disk_path=page.path}
    end
    table.sort(files,function(a,b) return naturalLess(a.path,b.path) end)
    local writer=archiver.Writer:new()
    if not writer:open(tmp,"zip") then if reader then reader:close() end; return nil,"Unable to create manga archive" end
    local function fail(message)
        writer:close(); if reader then reader:close() end; fs.remove(tmp); return nil,message
    end
    if not writer:setZipCompression("store") then return fail("Unable to configure archive") end
    local expected={}
    for i,item in ipairs(files) do
        expected[i]=item.path
        if item.source=="new" then
            writer:addPath(item.path,item.disk_path,false)
        else
            local data=item.reader:extractToMemory(item.path)
            if not data then return fail("Unable to read existing chapter image") end
            local added=writer:addFileFromMemory(item.path,data)
            data=nil
            if not added then return fail("Unable to merge existing chapter image") end
        end
        if writer.err then return fail("Unable to add manga image") end
    end
    writer:close(); if reader then reader:close() end
    local check=archiver.Reader:new()
    if not check:open(tmp) then fs.remove(tmp); return nil,"Unable to verify manga archive" end
    local count,valid=0,true
    for entry in check:iterate() do
        count=count+1
        if entry.path~=expected[count] or entry.mode~="file" or not entry.size or entry.size<=0 or entry.size>20971520 or not fs.verifyEntry or not fs.verifyEntry(check,entry) then valid=false end
    end
    if check.err then valid=false end
    check:close()
    if not valid or count~=#expected then fs.remove(tmp); return nil,"Merged manga archive is corrupted" end
    local published
    if fs.exists(target) and fs.publishReplace then published=fs.publishReplace(tmp,target)
    elseif fs.publishNoReplace then published=fs.publishNoReplace(tmp,target) end
    if not published then fs.remove(tmp); return nil,"Unable to publish manga archive" end
    return true,count
end
-- Merge a chapter with the current manga archive and optional per-chapter
-- legacy archives. Legacy root-level pages are placed under their chapter
-- title during the one-time migration.
function Builder.mergeAll(archiver,fs,target,pages,chapter_title,legacy_archives)
    if type(target)~="string" or target=="" or type(pages)~="table" or #pages==0 then return nil,"Empty chapter" end
    local tmp=target..".part"
    if fs.exists(tmp) then return nil,"Incomplete archive already exists" end
    local folder=chapterFolder(chapter_title)
    local sources={}
    if fs.exists(target) then sources[#sources+1]={path=target} end
    for _,source in ipairs(legacy_archives or {}) do
        if type(source)=="table" and type(source.path)=="string" and source.path~=target and type(source.folder)=="string" then
            sources[#sources+1]=source
        end
    end
    local readers,files,seen={},{},{}
    local function closeReaders() for _,r in ipairs(readers) do pcall(r.close,r) end end
    for _,source in ipairs(sources) do
        local reader=archiver.Reader:new()
        if not reader:open(source.path) then closeReaders(); return nil,"Existing chapter archive is invalid" end
        readers[#readers+1]=reader
        local ok,err=pcall(function()
            for entry in reader:iterate() do
                if entry.mode~="file" or type(entry.path)~="string" or entry.path:find("\\",1,true) or entry.path:sub(1,1)=="/" or entry.path:find("../",1,true) then error("unsafe entry") end
                local dir,filename=entry.path:match("^([^/]+)/([^/]+)$")
                if source.folder then
                    filename=filename or entry.path
                    dir=chapterFolder(source.folder)
                end
                local number,ext
                if filename then number,ext=filename:match("^(%d+)%.([%a]+)$") end
                local size=tonumber(entry.size)
                if not dir or dir=="." or dir==".." or not number or tonumber(number)<1 or not extensions[ext:lower()] or not size or size<=0 or size>20971520 then error("invalid image entry") end
                if not fs.verifyEntry or not fs.verifyEntry(reader,entry) then error("image checksum failed") end
                local output=dir.."/"..filename
                if dir~=folder and not seen[output] then
                    seen[output]=true
                    files[#files+1]={path=output,reader=reader,source="archive",entry_path=entry.path}
                end
            end
        end)
        if not ok or reader.err then closeReaders(); return nil,"Existing manga archive is corrupted" end
    end
    for i,page in ipairs(pages) do
        local ext=type(page)=="table" and extensions[page.extension or ""]
        if not ext or type(page.path)~="string" then closeReaders(); return nil,"Invalid image" end
        local output=folder.."/"..string.format("%06d.%s",i,ext)
        seen[output]=true
        files[#files+1]={path=output,source="new",disk_path=page.path}
    end
    table.sort(files,function(a,b) return naturalLess(a.path,b.path) end)
    local writer=archiver.Writer:new()
    if not writer:open(tmp,"zip") then closeReaders(); return nil,"Unable to create manga archive" end
    local function fail(message)
        writer:close(); closeReaders(); fs.remove(tmp); return nil,message
    end
    if not writer:setZipCompression("store") then return fail("Unable to configure archive") end
    local expected={}
    for i,item in ipairs(files) do
        expected[i]=item.path
        if item.source=="new" then writer:addPath(item.path,item.disk_path,false)
        else
            local data=item.reader:extractToMemory(item.entry_path)
            if not data then return fail("Unable to read existing chapter image") end
            local added=writer:addFileFromMemory(item.path,data)
            data=nil
            if not added then return fail("Unable to merge existing chapter image") end
        end
        if writer.err then return fail("Unable to add manga image") end
    end
    writer:close(); closeReaders()
    local check=archiver.Reader:new()
    if not check:open(tmp) then fs.remove(tmp); return nil,"Unable to verify manga archive" end
    local count,valid=0,true
    for entry in check:iterate() do
        count=count+1
        if entry.path~=expected[count] or entry.mode~="file" or not entry.size or entry.size<=0 or entry.size>20971520 or not fs.verifyEntry or not fs.verifyEntry(check,entry) then valid=false end
    end
    if check.err then valid=false end
    check:close()
    if not valid or count~=#expected then fs.remove(tmp); return nil,"Merged manga archive is corrupted" end
    local published
    if fs.exists(target) and fs.publishReplace then published=fs.publishReplace(tmp,target)
    elseif fs.publishNoReplace then published=fs.publishNoReplace(tmp,target) end
    if not published then fs.remove(tmp); return nil,"Unable to publish manga archive" end
    return true,count
end
return Builder
