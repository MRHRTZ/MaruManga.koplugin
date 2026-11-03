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
    if type(raw.archives) ~= "table" or type(raw.chapters) ~= "table" then return nil, "Invalid chapter metadata; original preserved" end
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
function Store:linkArchive(path, manga, chapter, page_count)
    if type(path) ~= "string" or path == "" or type(manga) ~= "table" or type(chapter) ~= "table" or not key(manga.source_id,manga.id) or not key(manga.source_id,chapter.id) then return nil, "Invalid archive metadata" end
    local old=self.data.archives[path]
    if not page_count and type(old)=="table" then page_count=old.page_count end
    self.data.archives[path] = {manga={id=manga.id,source_id=manga.source_id,title=manga.title},chapter={id=chapter.id,name=chapter.name},page_count=page_count}
    return self:save()
end
function Store:archiveFor(source,manga_id,chapter_id)
    if not key(source,manga_id) or not key(source,chapter_id) then return nil end
    local suffix="/manga/" .. source .. "/" .. manga_id .. "/chapters/" .. chapter_id .. ".cbz"
    for path,item in pairs(self.data.archives) do
        if type(path)=="string" and path:sub(1,1)=="/" and not path:find("%.%.") and path:sub(-#suffix)==suffix and type(item)=="table" and type(item.manga)=="table" and type(item.chapter)=="table" and item.manga.source_id==source and item.manga.id==manga_id and item.chapter.id==chapter_id then return path end
    end
end
function Store:unlinkArchive(path)
    if type(path)~="string" then return nil,"Invalid archive path" end
    self.data.archives[path]=nil
    return self:save()
end
function Store:recordArchivePage(path, page, defer)
    local item=self.data.archives[path]
    if type(item) ~= "table" then return false end
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
