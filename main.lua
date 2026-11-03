local WidgetContainer = require("ui/widget/container/widgetcontainer")
local UIManager = require("ui/uimanager")
local InfoMessage = require("ui/widget/infomessage")
local Menu = require("ui/widget/menu")
local ConfirmBox = require("ui/widget/confirmbox")
local InputDialog = require("ui/widget/inputdialog")
local MultiInputDialog = require("ui/widget/multiinputdialog")
local _ = require("gettext")
local path = debug.getinfo(1, "S").source:sub(2):match("^(.*[/\\])") or "plugins/MaruManga.koplugin/"
local parser = dofile(path .. "sources/mangadex/parser.lua")
local Source = dofile(path .. "sources/mangadex/source.lua")
local GenericParser = dofile(path .. "sources/generic/parser.lua")
local GenericSource = dofile(path .. "sources/generic/source.lua")
local Madara = dofile(path .. "sources/madara/source.lua")
local Client = dofile(path .. "network/client.lua")
local Transport = dofile(path .. "network/subprocess_transport.lua")
local SubprocessRunner = dofile(path .. "network/subprocess_runner.lua")
local SecureRequest = dofile(path .. "network/secure_request.lua")
local Settings = dofile(path .. "storage/settings.lua")
local SafeSettings = dofile(path .. "storage/safe_settings.lua")
local Library = dofile(path .. "storage/library.lua")
local ChapterReader = dofile(path .. "reader/chapter_reader.lua")
local Stager = dofile(path .. "reader/chapter_stager.lua")
local Builder = dofile(path .. "reader/cbz_builder.lua")
local ImageValidation = dofile(path .. "reader/image_validation.lua")
local FileSystem = dofile(path .. "reader/filesystem.lua")
local Downloader = dofile(path .. "network/image_downloader.lua")
local DownloadQueue = dofile(path .. "core/download_queue.lua")
local Updates = dofile(path .. "core/updates.lua")
local CookieJar = dofile(path .. "network/cookie_manager.lua")
local LuaSettings = require("luasettings")
local DataStorage = require("datastorage")
local MaruManga = WidgetContainer:extend{ name="marumanga", is_doc_only=false }

function MaruManga:init()
    self.ui.menu:registerToMainMenu(self)
    self.source_errors={}
    local store = LuaSettings:open(DataStorage:getSettingsDir() .. "/marumanga.lua")
    SafeSettings.wrap(store,require("dump"),require("ffi/util"))
    self.config, self.config_error = Settings.open(store)
    self.library, self.library_error = Library.open(store)
    self.downloads, self.download_error = DownloadQueue.open(store,function(item,done)
        return self:startChapter(item.manga,item.chapter,done,item.open_after,item)
    end)
end
function MaruManga:notice(message)
    UIManager:show(InfoMessage:new{text=tostring(message)})
end
local function networkDependencies()
    local lfs = require("libs/libkoreader-lfs")
    local paths = {"/system/etc/security/cacerts", "/etc/ssl/certs"}
    local capath
    for _, candidate in ipairs(paths) do if lfs.attributes(candidate, "mode") == "directory" then capath = candidate; break end end
    return {socket=require("socket"), ssl=require("ssl"), http=require("socket.http"), capath=capath}
end
function MaruManga:runner()
    return SubprocessRunner.new(UIManager,require("ui/trapper"))
end
function MaruManga:profile(id)
    if not self.config then return nil end
    for _, profile in ipairs(self.config.data.profiles) do if profile.id==id then return profile end end
end
function MaruManga:dependenciesFor(id)
    local deps=networkDependencies()
    deps.timeout=self.config.data.timeout; deps.user_agent=self.config.data.user_agent
    if id and id~="mangadex" then
        local profile=self:profile(id)
        if not profile then return nil end
        local host=profile.base_url:match("^https://([%w%.%-]+)$")
        if not host then return nil end
        deps.allowed_hosts={[host]=true}; deps.accept="text/html"
        for _,image_host in ipairs(profile.image_hosts or {}) do
            if type(image_host)=="string" and image_host:match("^[%w%.%-]+$") then deps.allowed_hosts[image_host]=true end
        end
    end
    return deps
end
function MaruManga:source(id)
    if not self.config then self:notice(self.config_error); return end
    id=id or self.config.data.source
    self.manga_sources=self.manga_sources or {}
    if self.manga_sources[id] then return self.manga_sources[id] end
    local json=require("json")
    local source
    if id=="mangadex" then
        local transport=Transport.new(UIManager,require("ui/trapper"),json,Client,SecureRequest,function() return self:dependenciesFor("mangadex") end,{max_attempts=self.config.data.retries,runner=self:runner(),deadline=self.config.data.timeout*2+10,on_result=function(err) self.source_errors[id]=err end})
        source=Source.new(transport,parser,self.config.data.language)
    else
        local config=self:profile(id)
        if not config or config.enabled==false then self:notice(_("Source is unavailable or disabled")); return end
        local profile=config.kind=="madara" and Madara.profile(config) or config
        local base=profile.base_url
        local transport=Transport.new(UIManager,require("ui/trapper"),json,Client,SecureRequest,function() return self:dependenciesFor(id) end,{
            decode=function(body) return body end, valid=function(body) return type(body)=="string" end, max_attempts=self.config.data.retries, runner=self:runner(), deadline=self.config.data.timeout*2+10, cookies=CookieJar.new(), on_result=function(err) self.source_errors[id]=err end,
            accept_url=function(url) return url==base or url:sub(1,#base+1)==base.."/" end,
        })
        local html=require("htmlparser")
        local url=require("socket.url")
        local util=require("util")
        local digest=require("ffi/sha2").md5
        local parsed=GenericParser.new(html,url.absolute,util.htmlToPlainText,profile,digest)
        local ok,result=pcall(GenericSource.new,profile,parsed,transport)
        if not ok then self:notice(_("Invalid source configuration")); return end
        source=result
    end
    self.manga_sources[id]=source
    return source
end
function MaruManga:menu(title, items, selected)
    local menu
    menu = Menu:new{
        title=title, item_table=items, covers_fullscreen=true,
        onMenuSelect=function(_, item) if item.action then item.action() end end,
    }
    UIManager:show(menu)
    return menu
end
function MaruManga:loadList(title, fetch, convert, page)
    page = page or 1
    local loading = InfoMessage:new{text=_("Loading…"), timeout=0}
    UIManager:show(loading)
    UIManager:nextTick(function()
        local ok, err = pcall(fetch, page, function(result, failure)
            UIManager:close(loading)
            if not result then return self:notice(failure or _("Could not load results.")) end
            local items = {}
            for _, model in ipairs(result.items) do
                local item = model
                items[#items+1] = {text=convert(item), action=function() self:showManga(item) end}
            end
            if #items == 0 then items[#items+1]={text=_("No results")} end
            if result.has_next then items[#items+1]={text=_("Next page"), action=function() self:loadList(title, fetch, convert, page+1) end} end
            self:menu(title .. " · " .. page, items)
        end)
        if not ok then UIManager:close(loading); self:notice(err) end
    end)
end
function MaruManga:showManga(manga)
    local source = self:source(manga.source_id); if not source then return end
    source:getMangaDetails(manga, function(detail, err)
        if not detail then return self:notice(err or _("Could not load manga.")) end
        local description = detail.title .. "\n\n" .. (detail.description ~= "" and detail.description or _("No description"))
        self:menu(detail.title, {
            {text=_("Details"), action=function()
                local source=self:source(detail.source_id)
                local genres=type(detail.genres)=="table" and table.concat(detail.genres,", ") or ""
                self:notice(description .. "\n\n" .. _("Author: ") .. (detail.author or _("Unknown")) .. "\n" .. _("Artist: ") .. (detail.artist or _("Unknown")) .. "\n" .. _("Status: ") .. (detail.status or _("Unknown")) .. "\n" .. _("Genres: ") .. genres .. "\n" .. _("Source: ") .. (source and source:getName() or detail.source_id))
            end},
            {text=_("View cover"), action=function() self:showCover(detail) end},
            {text=_("Chapters"), action=function() self:chapters(detail, 1) end},
            {text=_("Add to library"), action=function()
                if not self.library then return self:notice(self.library_error) end
                local ok, failure = self.library:add(detail)
                self:notice(ok and _("Added to library") or failure)
            end},
            {text=_("Remove from library"), action=function()
                if not self.library then return self:notice(self.library_error) end
                local ok, failure = self.library:remove(detail.source_id, detail.id)
                self:notice(ok and _("Removed from library") or failure)
            end},
        })
    end)
end
function MaruManga:showCover(manga)
    if type(manga.cover_url)~="string" then return self:notice(_("Cover is unavailable")) end
    local ok,fs=pcall(self.filesystem,self)
    if not ok then return self:notice(_("Storage is unavailable")) end
    local dir,err=fs.coverDir(manga.source_id,manga.id); if not dir then return self:notice(err) end
    local viewer=require("ui/widget/imageviewer")
    local function open(file) UIManager:show(viewer:new{file=file,title=manga.title,fullscreen=true}) end
    for _,extension in ipairs({"jpg","png","gif","webp"}) do
        local file=dir .. "/cover." .. extension
        if fs.exists(file) then return open(file) end
    end
    local temp=dir .. "/.cover.download"
    if fs.exists(temp) then return self:notice(_("An incomplete cover download exists")) end
    local loading=InfoMessage:new{text=_("Loading cover…"),timeout=0}; UIManager:show(loading)
    local download=Downloader.new(require("ui/trapper"),SecureRequest,function() return self:dependenciesFor(manga.source_id) end,nil,self:runner(),self.config.data.timeout*2+15)
    download({image_url=manga.cover_url,referer=manga.url,headers={}},temp,5242880,function(meta,failure)
        UIManager:close(loading)
        if not meta then fs.remove(temp); return self:notice(failure or _("Could not load cover")) end
        local extension,validation=ImageValidation.validate(meta.content_type,meta.size,meta.prefix,5242880)
        if not extension then fs.remove(temp); return self:notice(validation) end
        local target=dir .. "/cover." .. extension
        if not fs.publishNoReplace(temp,target) then fs.remove(temp); return self:notice(_("Could not save cover")) end
        open(target)
    end)
end
function MaruManga:chapters(manga, page, order)
    order=order or "desc"
    local source = self:source(manga.source_id); if not source then return end
    source:getChapterList(manga, page, function(result, err)
        if not result then return self:notice(err or _("Could not load chapters.")) end
        if self.library and self.library:contains(manga.source_id,manga.id) then
            local saved,save_error=self.library:cacheChapters(manga,result.items)
            if not saved then self:notice(save_error) end
        end
        local items = {{text=order=="desc" and _("Sort: descending") or _("Sort: ascending"),action=function() self:chapters(manga,1,order=="desc" and "asc" or "desc") end}}
        for _, chapter in ipairs(result.items) do
            local c = chapter
            local status=self.library and self.library:chapterStatus(manga.source_id,c.id)
            local downloaded=false
            if self.library then for _,entry in pairs(self.library.data.archives) do
                if type(entry)=="table" and type(entry.manga)=="table" and type(entry.chapter)=="table" and entry.manga.source_id==manga.source_id and entry.chapter.id==c.id then downloaded=true; break end
            end end
            local date=type(c.upload_date)=="number" and (" · " .. os.date("%Y-%m-%d",c.upload_date)) or ""
            items[#items+1] = {text=c.name .. (status and status.read and " · ✓" or "") .. (downloaded and " · ↓" or "") .. date .. (c.scanlator and (" · " .. c.scanlator) or ""), action=function()
                self:menu(c.name, {
                    {text=_("Read"),action=function() self:readChapter(manga,c) end},
                    {text=_("Download"),action=function() self:queueChapter(manga,c) end},
                    {text=status and status.read and _("Mark unread") or _("Mark read"),action=function()
                        if not self.library then return self:notice(self.library_error) end
                        local ok,err=self.library:setChapterRead(manga.source_id,c.id,not (status and status.read))
                        self:notice(ok and _("Chapter status updated") or err)
                    end},
                })
            end}
        end
        if #items == 1 then items[2]={text=_("No chapters in the selected language")} end
        if result.has_next then items[#items+1]={text=_("Next page"), action=function() self:chapters(manga, page+1, order) end} end
        self:menu(manga.title .. " · " .. page .. (result.total and (" / " .. result.total) or ""), items)
    end,order)
end
function MaruManga:downloadRoot()
    return self.config and self.config.data.download_dir or (DataStorage:getFullDataDir() .. "/MaruManga")
end
function MaruManga:filesystem()
    local ffi=require("ffi")
    pcall(ffi.cdef, "int link(const char *oldpath, const char *newpath); int renameat2(int olddirfd, const char *oldpath, int newdirfd, const char *newpath, unsigned int flags);")
    local lfs=require("libs/libkoreader-lfs")
    return FileSystem.new(lfs,function(a,b)
        -- RENAME_NOREPLACE avoids overwriting a completed chapter; not all
        -- devices expose it, in which case an atomic hard link is attempted.
        local available, renamed=pcall(function() return ffi.C.renameat2(-100,a,-100,b,1)==0 end)
        if available and renamed then return true end
        local linked, result=pcall(function() return ffi.C.link(a,b)==0 end)
        return linked and result
    end,self:downloadRoot())
end
function MaruManga:startChapter(manga,chapter,done,open_after,item)
    local source
    source={getPageList=function(_,chapter,callback)
        local active=self:source(manga.source_id)
        if not active then return callback(nil,"Source unavailable") end
        source.resolved=active
        return active:getPageList(chapter,callback)
    end}
    if not self.library then done(nil,self.library_error); return end
    local lfs=require("libs/libkoreader-lfs")
    local fs=self:filesystem()
    fs.verifyEntry=dofile(path .. "reader/archive_integrity.lua").verifyEntry
    local downloader=Downloader.new(require("ui/trapper"),SecureRequest,function() return self:dependenciesFor(manga.source_id) end,nil,self:runner(),self.config.data.timeout*2+15)
    local deps={source=source,fs=fs,library=self.library,archiver=require("ffi/archiver"),stager=Stager,build=Builder.build,
        validate=ImageValidation.validate,download=function(page,file,limit,callback)
            local copy={}; for k,v in pairs(page) do copy[k]=v end
            copy.headers={}; for k,v in pairs(page.headers or {}) do copy.headers[k]=v end
            local jar=source.resolved and source.resolved.transport and source.resolved.transport.cookies
            local cookie=jar and jar:header(page.image_url); if cookie then copy.headers.Cookie=cookie end
            return downloader(copy,file,limit,callback)
        end,
        progress=function(current,total) if item then item.current=current; item.total=total end end,
        removeDir=function(dir) lfs.rmdir(dir) end,
        openDocument=function(file) if open_after then require("apps/reader/readerui"):showReader(file) end end}
    return ChapterReader.open(deps,manga,chapter,done)
end
function MaruManga:readChapter(manga,chapter)
    if not self.downloads then return self:notice(self.download_error) end
    local ok,err=self.downloads:add(manga,chapter,true)
    self:notice(ok and _("Chapter queued") or err)
end
function MaruManga:queueChapter(manga,chapter)
    if not self.downloads then return self:notice(self.download_error) end
    local ok,err=self.downloads:add(manga,chapter,false)
    self:notice(ok and _("Chapter queued for download") or err)
end
function MaruManga:search()
    local dialog
    dialog = InputDialog:new{title=_("Search manga"), input="", buttons={{{text=_("Cancel"), callback=function() UIManager:close(dialog) end}, {text=_("Search"), is_enter_default=true, callback=function()
        local query = dialog:getInputText()
        if query == "" then return end
        UIManager:close(dialog)
        local source = self:source(); if source then self:loadList(_("Search"), function(page, cb) source:searchManga(query,page,cb) end, function(m) return m.title end) end
    end}}}}
    UIManager:show(dialog); dialog:onShowKeyboard()
end
function MaruManga:addHtmlSource(kind)
    if not self.config then return self:notice(self.config_error) end
    local dialog
    dialog=MultiInputDialog:new{
        title=kind=="madara" and _("Add Madara source") or _("Add HTML source"),
        fields={{text="",hint=_("Source name")},{text="",hint=_("Source ID (letters and numbers)")},{text="",hint=_("HTTPS base URL")}},
        buttons={{{text=_("Cancel"),callback=function() UIManager:close(dialog) end},{text=_("Save"),callback=function()
            local fields=dialog:getFields()
            local profile={name=fields[1],id=fields[2],base_url=fields[3],kind=kind,languages={self.config.data.language},enabled=true}
            local ok,err=self.config:addProfile(profile)
            if not ok then return self:notice(err) end
            local previous=self.config.data.source
            self.config.data.source=profile.id
            ok,err=self.config:save()
            if not ok then table.remove(self.config.data.profiles); self.config.data.source=previous; return self:notice(err) end
            self.manga_sources=nil; UIManager:close(dialog); self:notice(_("Source added"))
        end}}}
    }
    UIManager:show(dialog); dialog:onShowKeyboard()
end
function MaruManga:editProfile(profile)
    local fields={"base_url","search_path","popular_path","latest_path","list_selector","list_link_selector","list_title_selector","next_selector","title_selector","description_selector","author_selector","artist_selector","status_selector","genre_selector","cover_selector","cover_attribute","chapter_selector","chapter_link_selector","chapter_attribute","chapter_mode","chapter_ajax_suffix","page_selector","page_attribute","image_hosts"}
    local defaults=profile.kind=="madara" and Madara.profile(profile) or profile
    local items={}
    for _,name in ipairs(fields) do
        local field=name
        items[#items+1]={text=field,action=function()
            local old=profile[field]
            local value=old or defaults[field] or ""
            if type(value)=="table" then value=table.concat(value,",") end
            local dialog
            dialog=InputDialog:new{title=field,input=value,buttons={{{text=_("Cancel"),callback=function() UIManager:close(dialog) end},{text=_("Save"),callback=function()
                local input=dialog:getInputText()
                if field=="image_hosts" then
                    local hosts={}; for host in input:gmatch("[^,%s]+") do
                        if not host:match("^[%w%.%-]+$") then return self:notice(_("Invalid image host")) end
                        hosts[#hosts+1]=host
                    end
                    profile[field]=hosts
                elseif field=="base_url" then
                    if not input:match("^https://[%w%.%-]+$") then return self:notice(_("Invalid HTTPS base URL")) end
                    profile[field]=input
                else profile[field]=input~="" and input or nil end
                local ok,err=self.config:save(); if not ok then profile[field]=old; return self:notice(err) end
                self.manga_sources=nil; UIManager:close(dialog)
            end}}}}
            UIManager:show(dialog); dialog:onShowKeyboard()
        end}
    end
    self:menu(_("Source configuration"),items)
end
function MaruManga:editSourceLanguage(profile)
    local dialog
    dialog=InputDialog:new{title=_("Source language code"),input=(profile.languages and profile.languages[1]) or "en",buttons={{{text=_("Cancel"),callback=function() UIManager:close(dialog) end},{text=_("Save"),callback=function()
        local value=dialog:getInputText()
        if #value<2 or #value>12 or not value:match("^[a-z][a-z%-]*$") then return self:notice(_("Invalid language code")) end
        local previous=profile.languages; profile.languages={value}
        local ok,err=self.config:save(); if not ok then profile.languages=previous; return self:notice(err) end
        self.manga_sources=nil; UIManager:close(dialog)
    end}}}}
    UIManager:show(dialog); dialog:onShowKeyboard()
end
function MaruManga:showSources()
    if not self.config then return self:notice(self.config_error) end
    local choices={{text="MangaDex" .. (self.config.data.source=="mangadex" and " ✓" or ""),action=function()
        local previous=self.config.data.source; self.config.data.source="mangadex"
        local ok,err=self.config:save(); if not ok then self.config.data.source=previous; return self:notice(err) end
        self:notice(_("Source selected"))
    end}}
    for _, profile in ipairs(self.config.data.profiles) do
        local entry=profile
        choices[#choices+1]={text=(entry.name or entry.id) .. (entry.enabled==false and " · disabled" or "") .. (self.config.data.source==entry.id and " ✓" or ""),action=function()
            self:menu(entry.name or entry.id, {
                {text=_("Select"),action=function()
                    if entry.enabled==false then return self:notice(_("Enable this source first")) end
                    local previous=self.config.data.source; self.config.data.source=entry.id
                    local ok,err=self.config:save(); if not ok then self.config.data.source=previous; return self:notice(err) end
                    self:notice(_("Source selected"))
                end},
                {text=entry.enabled==false and _("Enable") or _("Disable"),action=function()
                    local previous,selected=entry.enabled,self.config.data.source
                    entry.enabled=entry.enabled==false
                    if not entry.enabled and selected==entry.id then self.config.data.source="mangadex" end
                    local ok,err=self.config:save(); if not ok then entry.enabled=previous; self.config.data.source=selected; return self:notice(err) end
                    self.manga_sources=nil; self:notice(_("Source updated"))
                end},
                {text=_("Source language"),action=function() self:editSourceLanguage(entry) end},
                {text=_("Configure selectors and URLs"),action=function() self:editProfile(entry) end},
            })
        end}
    end
    choices[#choices+1]={text=_("Add Madara source"),action=function() self:addHtmlSource("madara") end}
    choices[#choices+1]={text=_("Add generic HTML source"),action=function() self:addHtmlSource("generic") end}
    choices[#choices+1]={text=_("View selected source error"),action=function()
        self:notice(self.source_errors[self.config.data.source] or _("No source error recorded"))
    end}
    choices[#choices+1]={text=_("Refresh selected source"),action=function()
        local source=self:source(); if not source then return end
        source:getPopularManga(1,function(result,err)
            self:notice(result and _("Source refreshed") or (err or _("Source refresh failed")))
        end)
    end}
    choices[#choices+1]={text=_("Clear selected source cover cache"),action=function()
        local selected=self.config.data.source
        UIManager:show(ConfirmBox:new{text=_("Remove cached covers for the selected source?"),ok_text=_("Clear"),ok_callback=function()
            local fs=self:filesystem(); local trapper=require("ui/trapper")
            trapper:wrap(function()
                local complete,count,err=trapper:dismissableRunInSubprocess(function() return fs.clearSourceCovers(selected) end,false)
                if not complete then return self:notice(_("Cache cleanup cancelled")) end
                if count==nil then return self:notice(err) end
                self:notice(_("Cached covers removed: ") .. tostring(count))
            end)
        end})
    end}
    self:menu(_("Sources"),choices)
end
function MaruManga:showLibrary(query,sort,filter)
    if not self.library then return self:notice(self.library_error) end
    local items={{text=_("Search library"),action=function()
        local dialog
        dialog=InputDialog:new{title=_("Search library"),input=query or "",buttons={{{text=_("Cancel"),callback=function() UIManager:close(dialog) end},{text=_("Search"),callback=function()
            local text=dialog:getInputText(); UIManager:close(dialog); self:showLibrary(text,sort,filter)
        end}}}}
        UIManager:show(dialog); dialog:onShowKeyboard()
    end}}
    items[#items+1]={text=sort=="recent" and _("Sort: last read") or _("Sort: title"),action=function() self:showLibrary(query,sort=="recent" and "title" or "recent",filter) end}
    local labels={all=_("Filter: all"),unread=_("Filter: unread"),source=_("Filter: selected source")}
    local current=filter or "all"
    items[#items+1]={text=labels[current] or labels.all,action=function()
        self:showLibrary(query,sort,current=="all" and "unread" or current=="unread" and "source" or "all")
    end}
    for _, manga in ipairs(self.library:list(query,sort,current,self.config and self.config.data.source)) do
        local entry=manga
        local progress=""
        for _,record in ipairs(self.library.data.history) do
            if type(record)=="table" and record.source_id==entry.source_id and record.manga_id==entry.id then progress=" · " .. (record.chapter_name or "") .. " · " .. _("Page ") .. tostring(record.page or 1); break end
        end
        items[#items+1]={text=entry.title .. progress, action=function()
            self:menu(entry.title, {
                {text=_("Saved details"),action=function()
                    self:notice(entry.title .. "\n\n" .. (entry.description or _("No description")) .. "\n\n" .. _("Author: ") .. (entry.author or _("Unknown")) .. "\n" .. _("Status: ") .. (entry.status or _("Unknown")))
                end},
                {text=_("Offline chapters"), action=function() self:offlineChapters(entry) end},
                {text=_("Refresh details and chapters"), action=function() self:showManga(entry) end},
                {text=_("Remove from library"), action=function()
                    local ok,err=self.library:remove(entry.source_id,entry.id)
                    self:notice(ok and _("Removed from library") or err)
                end},
            })
        end}
    end
    if #items == 3 then items[4]={text=_("No matching titles")} end
    self:menu(_("Library"),items)
end
function MaruManga:offlineChapters(manga)
    local items={}
    for _, item in pairs(self.library.data.archives) do
        if type(item)=="table" and type(item.manga)=="table" and type(item.chapter)=="table" and item.manga.id==manga.id and item.manga.source_id==manga.source_id then
            local c={id=item.chapter.id,name=item.chapter.name,manga_id=manga.id}
            items[#items+1]={text=c.name or c.id,action=function() self:readChapter(manga,c) end}
        end
    end
    table.sort(items,function(a,b) return a.text<b.text end)
    if #items==0 then items[1]={text=_("No offline chapters")} end
    self:menu(_("Offline chapters"),items)
end
function MaruManga:showDownloads()
    if not self.downloads then return self:notice(self.download_error) end
    local items={}
    for _, item in ipairs(self.downloads.state.items) do
        local current=item
        items[#items+1]={text=(current.chapter.name or current.chapter.id) .. " · " .. current.status .. (current.total and (" · " .. tostring(current.current or 0) .. "/" .. tostring(current.total)) or ""), action=function()
            local choices={}
            if current.status=="failed" or current.status=="cancelled" then
                choices[#choices+1]={text=_("Retry"),action=function() local ok,err=self.downloads:retry(current); self:notice(ok and _("Queued") or err) end}
                choices[#choices+1]={text=_("Clear incomplete files"),action=function()
                    UIManager:show(ConfirmBox:new{text=_("Remove incomplete files for this chapter?"),ok_text=_("Remove"),ok_callback=function()
                        local active=self.downloads.active
                        if active and active.manga.source_id==current.manga.source_id and active.chapter.id==current.chapter.id then return self:notice(_("This chapter is in use")) end
                        local fs=self:filesystem()
                        local ok,err=fs.cleanupTemporary(current.manga.source_id,current.manga.id,current.chapter.id)
                        self:notice(ok and _("Incomplete files removed") or err)
                    end})
                end}
            elseif current.status=="queued" or current.status=="running" then
                choices[#choices+1]={text=_("Cancel"),action=function() local ok,err=self.downloads:cancel(current); self:notice(ok and _("Cancellation requested") or err) end}
            elseif current.status=="completed" then
                choices[#choices+1]={text=_("Read"),action=function() self:readChapter(current.manga,current.chapter) end}
                choices[#choices+1]={text=_("Delete downloaded chapter"),action=function()
                    UIManager:show(ConfirmBox:new{text=_("Delete this downloaded chapter?"),ok_text=_("Delete"),ok_callback=function()
                        local active=self.downloads.active
                        if active and active.manga.source_id==current.manga.source_id and active.chapter.id==current.chapter.id then return self:notice(_("This chapter is in use")) end
                        local fs=self:filesystem()
                        local target=self.library:archiveFor(current.manga.source_id,current.manga.id,current.chapter.id)
                        local err
                        if not target then target,err=fs.targetFor(current.manga.source_id,current.manga.id,current.chapter.id) end
                        if not target then return self:notice(err) end
                        local removed,why=os.remove(target)
                        if not removed then return self:notice(why or _("Could not delete chapter")) end
                        local ok,save_error=self.library:unlinkArchive(target)
                        if not ok then return self:notice(save_error) end
                        self.downloads:remove(current); self:notice(_("Downloaded chapter deleted"))
                    end})
                end}
            end
            if current.status~="running" and current.status~="queued" then
                choices[#choices+1]={text=_("Remove from list"),action=function()
                    local ok,err=self.downloads:remove(current); self:notice(ok and _("Removed") or err)
                end}
            end
            if current.error then choices[#choices+1]={text=current.error} end
            if #choices>0 then self:menu(_("Download"),choices) end
        end}
    end
    if #items==0 then items[1]={text=_("No downloads")} end
    self:menu(_("Downloads"),items)
end
function MaruManga:showUpdates()
    if not self.library then return self:notice(self.library_error) end
    local list=self.library:list()
    if #list==0 then return self:notice(_("Library is empty")) end
    local loading=InfoMessage:new{text=_("Checking library updates…"),timeout=0}
    UIManager:show(loading)
    UIManager:nextTick(function()
        Updates.fetch(list,function(id)
            if id~="mangadex" then local profile=self:profile(id); if not profile or profile.enabled==false then return nil end end
            return self:source(id)
        end,function(result,err)
            UIManager:close(loading)
            if not result then return self:notice(err) end
            local items={}
            if result.truncated then items[#items+1]={text=_("Only the first 25 library titles were checked")} end
            if #result.errors>0 then items[#items+1]={text=_("Sources with errors: ") .. #result.errors,action=function() self:notice(table.concat(result.errors,"\n")) end} end
            for _,entry in ipairs(result.items) do
                local item=entry
                items[#items+1]={text=item.manga.title .. " · " .. item.chapter.name,action=function()
                    self:menu(item.chapter.name,{
                        {text=_("Read"),action=function() self:readChapter(item.manga,item.chapter) end},
                        {text=_("Download"),action=function() self:queueChapter(item.manga,item.chapter) end},
                    })
                end}
            end
            if #items==0 then items[1]={text=_("No chapters found")} end
            self:menu(_("Library updates"),items)
        end)
    end)
end
function MaruManga:continueReading()
    if not self.library then return self:notice(self.library_error) end
    local record=self.library.data.history[1]
    if type(record)~="table" then return self:notice(_("No reading history")) end
    self:readChapter({id=record.manga_id,source_id=record.source_id,title=record.title},
        {id=record.chapter_id,manga_id=record.manga_id,name=record.chapter_name})
end
function MaruManga:showHistory()
    if not self.library then return self:notice(self.library_error) end
    local items={}
    for _, entry in ipairs(self.library.data.history) do
        if type(entry) == "table" and type(entry.title) == "string" then
            local record=entry
            items[#items+1]={text=record.title .. " · " .. (record.chapter_name or "") .. " · " .. _("Page ") .. tostring(record.page or 1), action=function()
                self:readChapter({id=record.manga_id, source_id=record.source_id, title=record.title},
                    {id=record.chapter_id,manga_id=record.manga_id,name=record.chapter_name})
            end}
        end
    end
    if #items == 0 then items[1]={text=_("No reading history")} end
    self:menu(_("History"),items)
end
function MaruManga:settings()
    if not self.config then return self:notice(self.config_error) end
    local dialog
    dialog = InputDialog:new{title=_("Chapter language code"), input=self.config.data.language, buttons={{{text=_("Cancel"), callback=function() UIManager:close(dialog) end}, {text=_("Save"), callback=function()
        local previous = self.config.data.language
        local ok, err = self.config:setLanguage(dialog:getInputText())
        if not ok then return self:notice(err) end
        ok, err = self.config:save()
        if not ok then self.config.data.language = previous; return self:notice(err) end
        self.manga_sources = nil
        UIManager:close(dialog)
    end}}}}
    UIManager:show(dialog); dialog:onShowKeyboard()
end
function MaruManga:networkSettings()
    if not self.config then return self:notice(self.config_error) end
    local config=self.config.data
    local dialog
    dialog=MultiInputDialog:new{title=_("Network and storage"),fields={
        {text=tostring(config.timeout),hint=_("Timeout in seconds")},
        {text=tostring(config.retries),hint=_("Maximum attempts")},
        {text=config.user_agent,hint=_("User agent")},
        {text=config.download_dir or "",hint=_("Download folder (blank for default)")},
    },buttons={{{text=_("Cancel"),callback=function() UIManager:close(dialog) end},{text=_("Save"),callback=function()
        local fields=dialog:getFields(); local old={config.timeout,config.retries,config.user_agent,config.download_dir}
        local ok,err=self.config:setNetwork(fields[1],fields[2],fields[3],fields[4])
        if not ok then return self:notice(err) end
        ok,err=self.config:save()
        if not ok then config.timeout,config.retries,config.user_agent,config.download_dir=old[1],old[2],old[3],old[4]; return self:notice(err) end
        self.manga_sources=nil; UIManager:close(dialog); self:notice(_("Settings saved"))
    end}}}}
    UIManager:show(dialog); dialog:onShowKeyboard()
end
function MaruManga:openSettings()
    self:menu(_("Settings"),{
        {text=_("Chapter language"),action=function() self:settings() end},
        {text=_("Network and storage"),action=function() self:networkSettings() end},
    })
end
function MaruManga:open()
    if self.downloads then self.downloads:run() end
    self:menu(_("MaruManga"), {
        {text=_("Continue reading"), action=function() self:continueReading() end},
        {text=_("Sources"), action=function() self:showSources() end},
        {text=_("Search"), action=function() self:search() end},
        {text=_("Popular"), action=function() local source = self:source(); if not source then return end; self:loadList(_("Popular"), function(p, cb) source:getPopularManga(p, cb) end, function(m) return m.title end) end},
        {text=_("Latest updates"), action=function() local source = self:source(); if not source then return end; self:loadList(_("Latest updates"), function(p, cb) source:getLatestUpdates(p, cb) end, function(m) return m.title end) end},
        {text=_("Library"), action=function() self:showLibrary() end},
        {text=_("Updates"), action=function() self:showUpdates() end},
        {text=_("History"), action=function() self:showHistory() end},
        {text=_("Downloads"), action=function() self:showDownloads() end},
        {text=_("Settings"), action=function() self:openSettings() end},
    })
end
function MaruManga:onPageUpdate(page)
    if self.library and self.ui and self.ui.document and self.ui.document.file then
        local file=self.ui.document.file
        if self.library.data.archives[file] then
            self.library:recordArchivePage(file, page, true)
            if self.progress_flush then UIManager:unschedule(self.progress_flush) end
            self.progress_flush = function() self.library:save(); self.progress_flush=nil end
            UIManager:scheduleIn(10, self.progress_flush)
        end
    end
end
function MaruManga:onCloseDocument()
    if self.progress_flush then UIManager:unschedule(self.progress_flush); self.progress_flush=nil; self.library:save() end
end
function MaruManga:addToMainMenu(items)
    items.marumanga={text=_("MaruManga"), sorting_hint="more_tools", callback=function() self:open() end}
end
return MaruManga
