-- Lightweight persistent library and history. Caller owns KOReader LuaSettings.
local Store = {}
Store.__index = Store
local function key(source, id)
    if type(source) ~= "string" or not source:match("^[%w_-]+$") or type(id) ~= "string" or not id:match("^[%w_-]+$") then return nil end
    return source .. ":" .. id
end
function Store.open(settings)
    local raw = settings:readSetting("marumanga_library")
    if raw == nil then raw = {version=1, manga={}, history={}} end
    if type(raw) ~= "table" or raw.version ~= 1 or type(raw.manga) ~= "table" or type(raw.history) ~= "table" then return nil, "Invalid library data; original preserved" end
    if raw.archives == nil then raw.archives = {} end
    if raw.chapters == nil then raw.chapters = {} end
    if raw.chapter_sync == nil then raw.chapter_sync = {} end
    if type(raw.archives) ~= "table" or type(raw.chapters) ~= "table" or type(raw.chapter_sync) ~= "table" then return nil, "Invalid chapter metadata; original preserved" end
    -- Preserve MangaMost library/history/download metadata after its former
    -- profile ID (`mangago`) was separated from the Mangago website source.
    local function old_mangamost(item)
        return type(item)=="table" and item.source_id=="mangago" and type(item.url)=="string" and item.url:match("^https://mangamost%.com/")~=nil
    end
    local old_mangamost_ids={}
    for old_key,item in pairs(raw.manga) do
        if old_mangamost(item) then
            old_mangamost_ids[item.id]=true
            local new_key="mangamost:"..item.id
            item.source_id="mangamost"
            if old_key~=new_key then raw.manga[old_key]=nil; if raw.manga[new_key]==nil then raw.manga[new_key]=item end end
        end
    end
    local function migrate_keys(map,belongs)
        local pending={}
        for old_key,value in pairs(map) do
            if type(old_key)=="string" and old_key:sub(1,8)=="mangago:" and belongs(old_key,value) then pending[#pending+1]={old_key=old_key,new_key="mangamost:"..old_key:sub(9),value=value} end
        end
        for _,entry in ipairs(pending) do map[entry.old_key]=nil; if map[entry.new_key]==nil then map[entry.new_key]=entry.value end end
    end
    migrate_keys(raw.chapters,function(_,value) return type(value)=="table" and type(value.metadata)=="table" and old_mangamost_ids[value.metadata.manga_id] end)
    migrate_keys(raw.chapter_sync,function(old_key) return old_mangamost_ids[old_key:sub(9)] end)
    for _,item in pairs(raw.archives) do
        if type(item)=="table" and type(item.manga)=="table" and item.manga.source_id=="mangago" and old_mangamost_ids[item.manga.id] then
            item.manga.source_id="mangamost"
            if type(item.chapters)=="table" then for _,chapter in ipairs(item.chapters) do if type(chapter)=="table" then chapter.source_id="mangamost" end end end
            if type(item.chapter)=="table" then item.chapter.source_id="mangamost" end
        end
    end
    for _,item in ipairs(raw.history) do if type(item)=="table" and item.source_id=="mangago" and old_mangamost_ids[item.manga_id] then item.source_id="mangamost"; item.key="mangamost:"..tostring(item.manga_id or "") end end
    return setmetatable({settings=settings, data=raw}, Store)
end
function Store:save()
    self.settings:saveSetting("marumanga_library", self.data)
    local ok, result = pcall(self.settings.flush, self.settings)
    if not ok or result == false then return nil, "Unable to save library" end
    return true
end
function Store:add(manga)
    if type(manga) ~= "table" then return nil, "Invalid manga" end
    local id=key(manga.source_id,manga.id)
    if not id or type(manga.title) ~= "string" or manga.title == "" then return nil, "Invalid manga" end
    local genres={}
    if type(manga.genres)=="table" then for _,genre in ipairs(manga.genres) do if type(genre)=="string" then genres[#genres+1]=genre end end end
    self.data.manga[id] = {id=manga.id,source_id=manga.source_id,title=manga.title,
        description=type(manga.description)=="string" and manga.description or nil,
        cover_url=type(manga.cover_url)=="string" and manga.cover_url or nil,
        url=type(manga.url)=="string" and manga.url or nil,
        author=type(manga.author)=="string" and manga.author or nil,
        artist=type(manga.artist)=="string" and manga.artist or nil,
        status=type(manga.status)=="string" and manga.status or nil,genres=genres}
    return self:save()
end
function Store:remove(source,id)
    local k=key(source,id); if not k then return nil, "Invalid manga" end
    self.data.manga[k]=nil
    return self:save()
end
function Store:list(query, sort, filter, selected_source)
    local list={}
    query=type(query)=="string" and query:lower() or ""
    for _, manga in pairs(self.data.manga) do
        if type(manga)=="table" and key(manga.source_id,manga.id) and type(manga.title)=="string" and (query=="" or manga.title:lower():find(query,1,true)) then
            local include=filter~="source" or manga.source_id==selected_source
            if filter=="unread" then
                include=false
                for chapter_key,status in pairs(self.data.chapters) do
                    if type(chapter_key)=="string" and chapter_key:sub(1,#manga.source_id+1)==manga.source_id..":" and type(status)=="table" and type(status.metadata)=="table" and status.metadata.manga_id==manga.id and not status.read then include=true; break end
                end
            end
            if include then list[#list+1]=manga end
        end
    end
    local latest={}
    if sort=="recent" then
        for _,entry in ipairs(self.data.history) do
            if type(entry)=="table" and type(entry.key)=="string" and type(entry.time)=="number" and not latest[entry.key] then latest[entry.key]=entry.time end
        end
    end
    table.sort(list,function(a,b)
        if sort=="recent" then
            local at=latest[key(a.source_id,a.id)] or 0; local bt=latest[key(b.source_id,b.id)] or 0
            if at~=bt then return at>bt end
        end
        local aa,bb=a.title:lower(),b.title:lower()
        if aa~=bb then return aa<bb end
        return tostring(a.id)<tostring(b.id)
    end)
    return list
end
function Store:contains(source,manga_id)
    local k=key(source,manga_id); return k~=nil and self.data.manga[k]~=nil
end
function Store:cacheChapters(manga,chapters)
    if type(manga)~="table" or not self:contains(manga.source_id,manga.id) or type(chapters)~="table" then return nil,"Invalid chapter list" end
    for _,chapter in ipairs(chapters) do
        local k=type(chapter)=="table" and key(manga.source_id,chapter.id)
        if k and chapter.manga_id==manga.id and type(chapter.name)=="string" then
            local status=self.data.chapters[k]; if type(status)~="table" then status={} end
            status.metadata={id=chapter.id,manga_id=manga.id,name=chapter.name,
                url=type(chapter.url)=="string" and chapter.url or nil,
                chapter_number=type(chapter.chapter_number)=="number" and chapter.chapter_number or nil,
                upload_date=type(chapter.upload_date)=="number" and chapter.upload_date or nil,
                scanlator=type(chapter.scanlator)=="string" and chapter.scanlator or nil}
            self.data.chapters[k]=status
        end
    end
    return self:save()
end
function Store:markChaptersSynced(manga,count,timestamp,missing_count,latest_number)
    local k=type(manga)=="table" and key(manga.source_id,manga.id)
    if not k or type(count)~="number" or count<0 or count%1~=0 then return nil,"Invalid chapter synchronization state" end
    if missing_count~=nil and (type(missing_count)~="number" or missing_count<0 or missing_count%1~=0 or missing_count>count) then return nil,"Invalid missing chapter count" end
    if latest_number~=nil and (type(latest_number)~="number" or latest_number~=latest_number or latest_number==math.huge or latest_number==-math.huge) then return nil,"Invalid latest chapter number" end
    local previous=self.data.chapter_sync[k]
    self.data.chapter_sync[k]={count=count,missing_count=missing_count,latest_number=latest_number,checked_at=type(timestamp)=="number" and timestamp or os.time()}
    local ok,err=self:save()
    if not ok then self.data.chapter_sync[k]=previous; return nil,err end
    return true
end
function Store:chapterStatus(source, chapter_id)
    local k=key(source,chapter_id)
    local item=k and self.data.chapters[k]
    return type(item)=="table" and item or nil
end
function Store:setChapterRead(source, chapter_id, is_read)
    local k=key(source,chapter_id); if not k or type(is_read)~="boolean" then return nil,"Invalid chapter status" end
    local item=self.data.chapters[k]
    if type(item)~="table" then item={} end
    item.read=is_read; self.data.chapters[k]=item
    return self:save()
end
function Store:linkArchive(path, manga, chapter, page_count, digest)
    if type(path) ~= "string" or path == "" or type(manga) ~= "table" or type(chapter) ~= "table" or not key(manga.source_id,manga.id) or not key(manga.source_id,chapter.id) then return nil, "Invalid archive metadata" end
    local old=self.data.archives[path]
    if not page_count and type(old)=="table" then page_count=old.page_count end
    if not digest and type(old)=="table" then digest=old.sha256 end
    if digest and (type(digest)~="string" or #digest~=64 or not digest:match("^[0-9a-f]+$")) then return nil,"Invalid archive digest" end
    local previous=type(old)=="table" and type(old.chapters)=="table" and type(old.chapters[chapter.id])=="table" and old.chapters[chapter.id]
        or type(old)=="table" and type(old.chapter)=="table" and old.chapter or {}
    local details={id=chapter.id,manga_id=manga.id,name=type(chapter.name)=="string" and chapter.name or previous.name,
        url=type(chapter.url)=="string" and chapter.url or previous.url,
        chapter_number=type(chapter.chapter_number)=="number" and chapter.chapter_number or previous.chapter_number,
        scanlator=type(chapter.scanlator)=="string" and chapter.scanlator or previous.scanlator,
        upload_date=type(chapter.upload_date)=="number" and chapter.upload_date or previous.upload_date,
        page_count=page_count or previous.page_count}
    local chapters={}
    if type(old)=="table" and type(old.chapters)=="table" then
        for id,meta in pairs(old.chapters) do if type(meta)=="table" then chapters[id]=meta end end
    elseif type(old)=="table" and type(old.chapter)=="table" and type(old.chapter.id)=="string" then
        chapters[old.chapter.id]={id=old.chapter.id,manga_id=old.chapter.manga_id,name=old.chapter.name,url=old.chapter.url,
            chapter_number=old.chapter.chapter_number,scanlator=old.chapter.scanlator,upload_date=old.chapter.upload_date,page_count=old.page_count}
    end
    chapters[chapter.id]=details
    local removed={}
    local merging_manga_archive=path:sub(-10)=="/manga.cbz"
    for other,item in pairs(self.data.archives) do
        if other~=path and type(item)=="table" and type(item.manga)=="table" and item.manga.source_id==manga.source_id and item.manga.id==manga.id then
            local other_chapters=type(item.chapters)=="table" and item.chapters or {}
            local legacy=type(item.chapter)=="table" and item.chapter or nil
            if not merging_manga_archive and (other_chapters[chapter.id] or legacy and legacy.id==chapter.id) then
                removed[other]=item
                if type(item.chapters)=="table" then
                    item.chapters[chapter.id]=nil
                    if next(item.chapters)==nil then self.data.archives[other]=nil end
                else self.data.archives[other]=nil end
            end
        end
    end
    self.data.archives[path] = {manga={id=manga.id,source_id=manga.source_id,title=manga.title},chapter=details,chapters=chapters,
        page_count=old and old.page_count or page_count,sha256=digest}
    local ok,err=self:save()
    if not ok then self.data.archives[path]=old; for other,item in pairs(removed) do self.data.archives[other]=item end; return nil,err end
    return true
end
function Store:archiveFor(source,manga_id,chapter_id)
    if not key(source,manga_id) or not key(source,chapter_id) then return nil end
    local manga_suffix="/manga/" .. source .. "/" .. manga_id .. "/manga.cbz"
    local suffix="/manga/" .. source .. "/" .. manga_id .. "/chapters/" .. chapter_id .. ".cbz"
    for path,item in pairs(self.data.archives) do
        if type(path)=="string" and path:sub(1,1)=="/" and not path:find("%.%.") and type(item)=="table" and type(item.manga)=="table" and item.manga.source_id==source and item.manga.id==manga_id then
            local chapters=type(item.chapters)=="table" and item.chapters or {}
            local legacy=type(item.chapter)=="table" and item.chapter
            if (path:sub(-#manga_suffix)==manga_suffix and chapters[chapter_id]) or (legacy and legacy.id==chapter_id and path:sub(-#suffix)==suffix) then return path end
        end
    end
end
function Store:archiveHasChapter(path,chapter_id)
    local item=self.data.archives[path]
    return type(item)=="table" and ((type(item.chapters)=="table" and item.chapters[chapter_id]~=nil)
        or (type(item.chapter)=="table" and item.chapter.id==chapter_id))
end
function Store:chaptersInArchive(path)
    local item=self.data.archives[path]
    if type(item)~="table" then return {} end
    local out={}
    if type(item.chapters)=="table" then
        for _,chapter in pairs(item.chapters) do if type(chapter)=="table" then out[#out+1]=chapter end end
    elseif type(item.chapter)=="table" then out[1]=item.chapter end
    table.sort(out,function(a,b)
        local an,bn=tonumber(a.chapter_number),tonumber(b.chapter_number)
        if an and bn and an~=bn then return an<bn end
        if an~=nil and bn==nil then return true end
        if bn~=nil and an==nil then return false end
        return tostring(a.name or a.id)<tostring(b.name or b.id)
    end)
    return out
end
function Store:archivePathsForManga(source,manga_id)
    local out={}
    for path,item in pairs(self.data.archives) do
        if type(item)=="table" and type(item.manga)=="table" and item.manga.source_id==source and item.manga.id==manga_id then out[#out+1]=path end
    end
    table.sort(out)
    return out
end
function Store:mergeArchiveRecords(path,manga,digest)
    local target=self.data.archives[path]
    if type(target)~="table" or type(target.manga)~="table" or target.manga.source_id~=manga.source_id or target.manga.id~=manga.id then return nil,"Missing manga archive record" end
    if type(digest)~="string" or #digest~=64 or not digest:match("^[0-9a-f]+$") then return nil,"Invalid archive digest" end
    local original={}
    for archive_path,item in pairs(self.data.archives) do original[archive_path]=item end
    local chapters={}
    for _,chapter in ipairs(self:chaptersInArchive(path)) do chapters[chapter.id]=chapter end
    local old_paths={}
    for other,item in pairs(self.data.archives) do
        if other~=path and type(item)=="table" and type(item.manga)=="table" and item.manga.source_id==manga.source_id and item.manga.id==manga.id then
            for _,chapter in ipairs(self:chaptersInArchive(other)) do
                if chapter.id and not chapters[chapter.id] then
                    chapters[chapter.id]=chapter
                end
            end
            self.data.archives[other]=nil
            old_paths[#old_paths+1]=other
        end
    end
    local ordered={}
    for _,chapter in pairs(chapters) do ordered[#ordered+1]=chapter end
    table.sort(ordered,function(a,b)
        local an,bn=tonumber(a.chapter_number),tonumber(b.chapter_number)
        if an and bn and an~=bn then return an<bn end
        if an~=nil and bn==nil then return true end
        if bn~=nil and an==nil then return false end
        return tostring(a.name or a.id)<tostring(b.name or b.id)
    end)
    local page_count=0
    for _,chapter in ipairs(ordered) do page_count=page_count+(tonumber(chapter.page_count) or 0) end
    local latest=ordered[#ordered]
    self.data.archives[path]={manga=target.manga,chapter=latest,chapters=chapters,page_count=page_count,sha256=digest}
    local ok,err=self:save()
    if not ok then self.data.archives=original; return nil,err end
    return true,old_paths
end
function Store:archiveDigest(path)
    local item=self.data.archives[path]
    return type(item)=="table" and item.sha256 or nil
end
function Store:unlinkArchive(path)
    if type(path)~="string" then return nil,"Invalid archive path" end
    self.data.archives[path]=nil
    return self:save()
end
function Store:recordArchivePage(path, page, defer)
    local item=self.data.archives[path]
    if type(item) ~= "table" or type(item.chapter)~="table" then return false end
    local k=key(item.manga.source_id,item.chapter.id)
    local status=self.data.chapters[k]
    if type(status)~="table" then status={} end
    status.page=page
    if type(item.page_count)=="number" and page>=item.page_count then status.read=true end
    self.data.chapters[k]=status
    return self:record(item.manga,item.chapter,page,nil,defer)
end
function Store:record(manga, chapter, page, timestamp, defer)
    local k=type(manga)=="table" and key(manga.source_id,manga.id)
    if not k or type(chapter)~="table" or not key(manga.source_id,chapter.id) or type(page)~="number" or page<1 or page%1~=0 then return nil, "Invalid reading position" end
    local h=self.data.history
    for i=#h,1,-1 do if type(h[i])=="table" and h[i].key==k then table.remove(h,i) end end
    table.insert(h,1,{key=k,manga_id=manga.id,source_id=manga.source_id,title=manga.title,chapter_id=chapter.id,chapter_name=chapter.name,page=page,time=timestamp or os.time()})
    while #h>200 do table.remove(h) end
    if defer then return true end
    return self:save()
end
return Store
