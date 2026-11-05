local WidgetContainer = require("ui/widget/container/widgetcontainer")
local UIManager = require("ui/uimanager")
local path = debug.getinfo(1, "S").source:sub(2):match("^(.*[/\\])") or "plugins/MaruManga.koplugin/"
-- Keep the standard square dialogs, except the custom home panel which sets
-- keep_radius and uses KOReader's rounded FrameContainer.
local function show(widget)
    if not widget.keep_radius then
        if widget.dialog_frame then widget.dialog_frame.radius=0 end
        if widget.movable and widget.movable[1] then widget.movable[1].radius=0 end
        if widget[1] and widget[1].radius then widget[1].radius=0 end
    end
    UIManager:show(widget)
end
local function clickable(items)
    local ImageWidget = require("ui/widget/imagewidget")
    local Screen = require("device").screen
    local icon_size = Screen:scaleBySize(30)
    local rules = {
        {"next page", "next-page"}, {"previous page", "back"},
        {"search", "search"}, {"filter", "filter"}, {"install", "add"}, {"add", "add"},
        {"delete", "delete"}, {"uninstall", "delete"}, {"remove", "delete"},
        {"download", "downloads"}, {"retry", "refresh"}, {"refresh", "refresh"},
        {"update", "refresh"}, {"enable", "toggle"}, {"disable", "toggle"},
        {"language", "language"}, {"source", "source"}, {"repository", "repositories"},
        {"setting", "settings"}, {"edit", "edit"}, {"save", "save"}, {"reset", "refresh"},
        {"chapter", "chapter"}, {"manga", "manga"}, {"cover", "manga"},
        {"read", "book"}, {"open", "book"}, {"view", "details"}, {"detail", "details"},
        {"verify", "verify"}, {"check", "refresh"}, {"popular", "discover"},
        {"latest", "discover"}, {"discover", "discover"}, {"cancel", "close"},
        {"back", "back"}, {"retry", "refresh"},
    }
    for _, item in ipairs(items) do
        if item.action and type(item.text) == "string" and item.text ~= "" then
            local icon = item.maru_icon
            if not icon then
                local label = item.text:lower()
                for _, rule in ipairs(rules) do
                    if label:find(rule[1], 1, true) then icon = rule[2]; break end
                end
            end
            icon = icon or "details"
            if not item.state and not item.maru_image then
                item.state = ImageWidget:new{file=item.icon or (path .. "images/menu/" .. icon .. ".svg"),width=icon_size,height=icon_size,alpha=true}
            end
        end
    end
    return items
end
local InfoMessage = require("ui/widget/infomessage")
local Menu = require("ui/widget/menu")
local ConfirmBox = require("ui/widget/confirmbox")
local ButtonDialog = require("ui/widget/buttondialog")
local InputDialog = require("ui/widget/inputdialog")
local MultiInputDialog = require("ui/widget/multiinputdialog")
local _ = require("gettext")
local MainMenu = dofile(path .. "ui/main_menu.lua")
local GenericParser = dofile(path .. "sources/generic/parser.lua")
local GenericSource = dofile(path .. "sources/generic/source.lua")
local Komiku = dofile(path .. "sources/komiku/source.lua")
local MangaMost = dofile(path .. "sources/mangamost/source.lua")
local Mangago = dofile(path .. "sources/mangago/source.lua")
local MangaRock = dofile(path .. "sources/mangarock/source.lua")
local MangaRockParser = dofile(path .. "sources/mangarock/parser.lua")
local Webtoon = dofile(path .. "sources/webtoon/source.lua")
local WestManga = dofile(path .. "sources/westmanga/source.lua")
local KomikuParser = dofile(path .. "sources/komiku/parser.lua")
local Client = dofile(path .. "network/client.lua")
local Transport = dofile(path .. "network/subprocess_transport.lua")
local SubprocessRunner = dofile(path .. "network/subprocess_runner.lua")
local SecureRequest = dofile(path .. "network/secure_request.lua")
local DNSResolver = dofile(path .. "network/dns_resolver.lua")
local Settings = dofile(path .. "storage/settings.lua")
local SafeSettings = dofile(path .. "storage/safe_settings.lua")
local Library = dofile(path .. "storage/library.lua")
local ChapterReader = dofile(path .. "reader/chapter_reader.lua")
local Stager = dofile(path .. "reader/chapter_stager.lua")
local Builder = dofile(path .. "reader/cbz_builder.lua")
local ImageValidation = dofile(path .. "reader/image_validation.lua")
local FileDigest = dofile(path .. "reader/file_digest.lua")
local ArchiveScan = dofile(path .. "core/archive_scan.lua")
local AllSourceSearch = dofile(path .. "core/all_source_search.lua")
local PluginUpdater = dofile(path .. "core/plugin_updater.lua")
local Uninstaller = dofile(path .. "core/uninstaller.lua")
local LocalArchive = dofile(path .. "core/local_archive.lua")
local ArchiveCheck = dofile(path .. "reader/archive_check.lua")
local FileSystem = dofile(path .. "reader/filesystem.lua")
local Downloader = dofile(path .. "network/image_downloader.lua")
local DownloadQueue = dofile(path .. "core/download_queue.lua")
local Updates = dofile(path .. "core/updates.lua")
local Repositories = dofile(path .. "core/repositories.lua")
local CookieJar = dofile(path .. "network/cookie_manager.lua")
local LuaSettings = require("luasettings")
local DataStorage = require("datastorage")
local function repositorySources(repo)
    local available={}
    for _,entry in ipairs(repo and repo.catalog and repo.catalog.sources or {}) do
        if entry.id~="mangadex" and entry.adapter~="mangadex" then available[#available+1]=entry end
    end
    return available
end
local function languageLabel(languages)
    if type(languages)~="table" or #languages==0 then return "" end
    local codes={}
    for _,language in ipairs(languages) do
        if type(language)=="string" and language:match("^[a-z][a-z%-]*$") then codes[#codes+1]=language:upper() end
    end
    return table.concat(codes,"-")
end
local function sourceIconUrl(entry)
    if type(entry)~="table" then return nil end
    if type(entry.icon_url)=="string" then return entry.icon_url end
    local domain=type(entry.base_url)=="string" and entry.base_url:match("^https://([%w%.%-]+)$")
    if domain then return "https://www.google.com/s2/favicons?domain="..domain.."&sz=64" end
end
local function bundledSourceIcon(entry)
    if type(entry)~="table" or type(entry.id)~="string" or not entry.id:match("^[%w_-]+$") then return nil end
    for _,extension in ipairs({"png","jpg","webp"}) do
        local file=path.."images/sources/"..entry.id.."."..extension
        local handle=io.open(file,"rb")
        if handle then handle:close(); return file end
    end
end
local function sourceCompatibilityIssue(entry)
    if type(entry)~="table" then return _("Invalid source catalog entry") end
    if entry.adapter=="planned" then return _("This source is planned but has no adapter") end
    if entry.adapter=="generic" or entry.adapter=="madara" then
        local profile=entry.profile or {}
        local missing={}
        local function has_path(key,query)
            local value=profile[key]
            if type(value)~="string" then return false end
            local local_path=(value:sub(1,1)=="/" and value:sub(1,2)~="//") or value:sub(1,12)=="{page_path}/"
            return local_path and (not query or value:find("{query}",1,true)~=nil)
        end
        if not has_path("search_path",true) then missing[#missing+1]=_("search path with {query}") end
        if not has_path("popular_path") then missing[#missing+1]=_("popular path") end
        if not has_path("latest_path") then missing[#missing+1]=_("latest path") end
        if not (type(profile.list_selector)=="string" and profile.list_selector~="" or type(profile.list_selectors)=="table" and #profile.list_selectors>0) then missing[#missing+1]=_("manga list selector") end
        if type(profile.chapter_selector)~="string" or profile.chapter_selector=="" then missing[#missing+1]=_("chapter selector") end
        if type(profile.page_selector)~="string" or profile.page_selector=="" then missing[#missing+1]=_("page image selector") end
        if #missing>0 then return _("Missing profile fields: ")..table.concat(missing,", ") end
    elseif entry.adapter~="komiku" and entry.adapter~="mangamost" and entry.adapter~="mangago" and entry.adapter~="mangarock" and entry.adapter~="webtoon" and entry.adapter~="westmanga" then
        return _("This plugin version does not support the source adapter")
    end
end
local MaruManga = WidgetContainer:extend{ name="marumanga", is_doc_only=false }
local function loadingMessage(text)
    -- A zero timeout is scheduled immediately by KOReader. Keep this modal
    -- text dialog open until its caller explicitly closes it on completion.
    local message=InfoMessage:new{text=text,timeout=nil,dismissable=false,show_icon=false,flush_events_on_show=true}
    message.keep_radius=true
    if message.movable and message.movable[1] then message.movable[1].radius=require("device").screen:scaleBySize(12) end
    function message:updateText(updated_text)
        self.text=updated_text
        -- InfoMessage builds HorizontalGroup(image, span, TextBoxWidget).
        -- Reuse its TextBoxWidget so sequential source progress updates do
        -- not close and remount the modal on every response.
        local text_widget=self.movable and self.movable[1] and self.movable[1][1] and self.movable[1][1][3]
        if not text_widget or type(text_widget.setText)~="function" then return false end
        text_widget:setText(updated_text)
        UIManager:setDirty(self,function() return "ui",self.movable.dimen end)
        return true
    end
    return message
end
local PLUGIN_VERSION="0.2.6"
local PLUGIN_LAST_UPDATE="2026-11-05"
function MaruManga:init()
    self.ui.menu:registerToMainMenu(self)
    self.source_errors={}
    local store,store_error=SafeSettings.open(LuaSettings,DataStorage:getSettingsDir() .. "/marumanga.lua")
    if not store then
        self.config_error=store_error; self.library_error=store_error; self.download_error=store_error; self.repository_error=store_error
        return
    end
    SafeSettings.wrap(store,require("dump"),require("ffi/util"))
    self.config, self.config_error = Settings.open(store)
    self.library, self.library_error = Library.open(store)
    self.repositories, self.repository_error = Repositories.open(store)
    if self.config and self.repositories then
        local ok,err=pcall(self.installDefaultCatalogSources,self)
        if not ok then self.default_source_install_error=tostring(err) end
    end
    self.downloads, self.download_error = DownloadQueue.open(store,function(item,done)
        return self:startChapter(item.manga,item.chapter,done,item)
    end,function() return self.config and self.config.data.download_concurrency or 2 end)
end
function MaruManga:notice(message)
    show(InfoMessage:new{text=tostring(message)})
end
local function networkDependencies()
    local lfs = require("libs/libkoreader-lfs")
    local paths = {"/system/etc/security/cacerts", "/etc/ssl/certs"}
    local capath
    for ignored_index, candidate in ipairs(paths) do if lfs.attributes(candidate, "mode") == "directory" then capath = candidate; break end end
    -- KOReader bundles a CA file in its private application directory. Android's
    -- system CA directory uses a different hash convention than OpenSSL.
    local cafile=lfs.attributes("data/ca-bundle.crt","mode")=="file" and "data/ca-bundle.crt" or nil
    return {socket=require("socket"), ssl=require("ssl"), http=require("socket.http"), cafile=cafile, capath=capath}
end
local function applyDNS(deps,settings)
    local mode=settings and settings.dns_mode or "auto"
    if mode~="auto" then
        local server=settings.dns_server
        deps.resolve=function(host) return DNSResolver.resolve(host,mode,server,deps.socket) end
    end
    return deps
end
function MaruManga:runner()
    return SubprocessRunner.new(UIManager,require("ui/trapper"))
end
function MaruManga:profile(id)
    if not self.config then return nil end
    for ignored_index, profile in ipairs(self.config.data.profiles) do if profile.id==id then return profile end end
end
function MaruManga:dependenciesFor(id)
    local deps=applyDNS(networkDependencies(),self.config.data)
    deps.timeout=self.config.data.timeout; deps.user_agent=self.config.data.user_agent
    deps.ignore_ssl_certificates=self.config.data.ignore_ssl_certificates==true
    if id then
        local profile=self:profile(id)
        if not profile then return nil end
        local host=profile.base_url:match("^https://([%w%.%-]+)$")
        if not host then return nil end
        deps.allowed_hosts={[host]=true}; deps.accept=(profile.kind=="mangamost" or profile.kind=="westmanga") and "application/json, text/html;q=0.9, */*;q=0.8" or "text/html"
        if profile.kind=="mangago" then
            if profile.id~="mangago" or profile.base_url~="https://www.mangago.zone" then return nil end
            -- Mangago's current edge certificate chain fails validation in
            -- this runtime. Keep HTTPS and its exact host allowlist, but scope
            -- the certificate bypass to Mangago instead of changing other sources.
            deps.ignore_ssl_certificates=true
        end
        if profile.kind=="mangamost" then
            if profile.base_url~="https://mangamost.com" or profile.api_url~="https://mangamost.com/api/v1" then return nil end
            deps.allowed_hosts["mangamost.com"]=true
            deps.headers={Accept="application/json"}
        elseif profile.kind=="komiku" then
            if profile.base_url~="https://komiku.org" or profile.api_url~="https://api.komiku.org" then return nil end
            deps.allowed_hosts["api.komiku.org"]=true
            deps.headers={ ["Accept-Language"]="id-ID,id;q=0.9,en-US;q=0.8,en;q=0.7" }
        end
        for ignored_index,image_host in ipairs(profile.image_hosts or {}) do
            if type(image_host)=="string" and image_host:match("^[%w%.%-]+$") then deps.allowed_hosts[image_host]=true end
        end
    end
    return deps
end
function MaruManga:source(id)
    if not self.config then self:notice(self.config_error); return end
    id=id or self.config.data.source
    if id=="mangadex" then self:notice(_("MangaDex is no longer available; use Komiku")); return nil end
    self.manga_sources=self.manga_sources or {}
    if self.manga_sources[id] then return self.manga_sources[id] end
    local json=require("json")
    local source
    do
        local config=self:profile(id)
        if not config or config.enabled==false then self:notice(_("Source is unavailable or disabled")); return end
        local profile=config
        local base=profile.base_url
        local transport=Transport.new(UIManager,require("ui/trapper"),json,Client,SecureRequest,function() return self:dependenciesFor(id) end,{
            decode=function(body) return body end, valid=function(body) return type(body)=="string" end, max_attempts=self.config.data.retries, interval=config.kind=="komiku" and 0.5 or nil, runner=self:runner(), deadline=self.config.data.timeout*2+10, cookies=CookieJar.new(), on_result=function(err) self.source_errors[id]=err end,
            accept_url=function(url) return url==base or url:sub(1,#base+1)==base.."/" or (config.kind=="komiku" or config.kind=="mangamost") and (url==config.api_url or url:sub(1,#config.api_url+1)==config.api_url.."/") end,
        })
        local html=require("htmlparser")
        local url=require("socket.url")
        local util=require("util")
        local digest=require("ffi/sha2").md5
        local parsed=GenericParser.new(html,url.absolute,util.htmlToPlainText,profile,digest)
        local source_class=GenericSource
        if config.kind=="komiku" then
            profile.api_url=config.api_url
            parsed=KomikuParser.new(html,url.absolute,util.htmlToPlainText,profile,digest)
            source_class=Komiku
        elseif config.kind=="mangamost" then
            parsed=nil
            source_class=MangaMost
        elseif config.kind=="mangago" then
            source_class=Mangago
        elseif config.kind=="webtoon" then
            source_class=Webtoon
        elseif config.kind=="westmanga" then
            source_class=WestManga
        elseif config.kind=="mangarock" then
            parsed=MangaRockParser.new(html,url.absolute,util.htmlToPlainText,profile,digest)
            source_class=MangaRock
        end
        local ok,result
        if config.kind=="webtoon" then ok,result=pcall(source_class.new,profile,parsed,transport,html)
        else ok,result=pcall(source_class.new,profile,parsed,transport) end
        if not ok then self:notice(_("Invalid source configuration")..": "..tostring(result)); return end
        source=result
    end
    self.manga_sources[id]=source
    return source
end
function MaruManga:menu(title, items, selected, grouped, replace_page, page_options)
    items=clickable(items)
    if self.main_menu and self.panel_enabled then
        self.panel_enabled=true
        page_options=page_options or {}
        page_options.push=not replace_page
        local panel=self.main_menu:setPage(title,items,page_options)
        if not self.main_menu.visible then show(self.main_menu); self.main_menu.visible=true end
        return panel
    end
    local Screen=require("device").screen
    local state_width=Screen:scaleBySize(42)
    for _,item in ipairs(items) do
        if type(item.maru_state_width)=="number" then state_width=math.max(state_width,item.maru_state_width) end
    end
    local menu
    local TitleBar=require("ui/widget/titlebar")
    local titlebar=TitleBar:new{
        title=title,width=Screen:getWidth(),fullscreen="true",align="center",
        with_bottom_line=true,left_icon="chevron.left",
        left_icon_tap_callback=function()
            if page_options and page_options.on_back then pcall(page_options.on_back) end
            if menu then UIManager:close(menu) end
        end,
    }
    menu = Menu:new{
        title=title,custom_title_bar=titlebar,item_table=items,covers_fullscreen=true,
        state_w=state_width,
        onMenuSelect=function(_, item) if item.action then item.action() end end,
    }
    menu.page_limit=page_options and page_options.page_limit
    if grouped then
        local function apply_group_lines(widget)
            if not widget.item_group then return end
            for ignored_index,item in ipairs(widget.item_group) do
                if item.entry and not item.entry.group_end and item._underline_container then item._underline_container.linesize=0 end
            end
        end
        if type(Menu.updateItems)=="function" then
            menu.updateItems=function(widget,...) Menu.updateItems(widget,...); apply_group_lines(widget) end
        end
        apply_group_lines(menu)
    end
    show(menu)
    return menu
end
function MaruManga:findCachedCover(manga)
    if type(manga)~="table" or type(manga.source_id)~="string" or type(manga.id)~="string" then return nil end
    local ok,fs=pcall(self.filesystem,self)
    if not ok or type(fs.coverDir)~="function" or type(fs.exists)~="function" then return nil end
    local dir_ok,dir=pcall(fs.coverDir,manga.source_id,manga.id)
    if not dir_ok then return nil end
    if not dir then return nil end
    for _,extension in ipairs({"jpg","png","gif","webp"}) do
        local file=dir.."/cover."..extension
        local exists_ok,exists=pcall(fs.exists,file)
        if exists_ok and exists then return file end
    end
end
function MaruManga:findCachedSourceIcon(entry)
    if type(entry)~="table" or type(entry.id)~="string" or not entry.id:match("^[%w_-]+$") then return nil end
    local ok,lfs=pcall(require,"libs/libkoreader-lfs")
    if not ok then return nil end
    local dir=self:downloadRoot().."/cache/source-icons"
    for _,extension in ipairs({"png","jpg","webp","gif"}) do
        local file=dir.."/"..entry.id.."."..extension
        local mode=lfs.symlinkattributes and lfs.symlinkattributes(file,"mode") or lfs.attributes(file,"mode")
        if mode=="file" then return file end
    end
end
function MaruManga:cacheSourceIcon(entry,callback)
    callback=callback or function() end
    local cached=self:findCachedSourceIcon(entry)
    if cached then return callback(cached) end
    if type(entry)~="table" then return callback(nil) end
    local icon_url=sourceIconUrl(entry)
    if type(icon_url)~="string" then return callback(nil) end
    local id=entry.id
    if type(id)~="string" or not id:match("^[%w_-]+$") then return callback(nil) end
    self.source_icon_attempts=self.source_icon_attempts or {}
    self.source_icon_waiters=self.source_icon_waiters or {}
    if self.source_icon_waiters[id] then self.source_icon_waiters[id][#self.source_icon_waiters[id]+1]=callback; return end
    if self.source_icon_attempts[id] then return callback(nil) end
    local host=icon_url:match("^https://([%w%.%-]+)/")
    if not host or #icon_url>2048 or icon_url:find("[%c%s#]") then return callback(nil) end
    self.source_icon_attempts[id]=true
    self.source_icon_waiters[id]={callback}
    local function finish(file)
        local waiters=self.source_icon_waiters[id] or {}
        self.source_icon_waiters[id]=nil
        for _,done in ipairs(waiters) do pcall(done,file) end
    end
    local ok,lfs=pcall(require,"libs/libkoreader-lfs")
    if not ok then finish(nil); return end
    local root=self:downloadRoot()
    local directory=""
    for part in root:gmatch("[^/]+") do
        directory=directory.."/"..part
        local mode=lfs.symlinkattributes and lfs.symlinkattributes(directory,"mode") or lfs.attributes(directory,"mode")
        if mode and mode~="directory" then finish(nil); return end
        if not mode and not lfs.mkdir(directory) then finish(nil); return end
    end
    for _,suffix in ipairs({"/cache","/cache/source-icons"}) do
        directory=directory..suffix
        local mode=lfs.symlinkattributes and lfs.symlinkattributes(directory,"mode") or lfs.attributes(directory,"mode")
        if mode and mode~="directory" then finish(nil); return end
        if not mode and not lfs.mkdir(directory) then finish(nil); return end
    end
    local temp=directory.."/"..id..".download"
    os.remove(temp)
    local made,downloader=pcall(Downloader.new,require("ui/trapper"),SecureRequest,function()
        local deps=applyDNS(networkDependencies(),self.config.data)
        deps.timeout=self.config.data.timeout; deps.user_agent=self.config.data.user_agent
        deps.ignore_ssl_certificates=self.config.data.ignore_ssl_certificates==true
        deps.allowed_hosts={[host]=true}; deps.images=true
        deps.headers={Accept="image/png, image/jpeg, image/webp, image/gif"}
        return deps
    end,nil,self:runner(),self.config.data.timeout*2+15)
    if not made or type(downloader)~="function" then os.remove(temp); finish(nil); return end
    local fs_ok,fs=pcall(self.filesystem,self)
    if not fs_ok then os.remove(temp); finish(nil); return end
    local started=pcall(downloader,{image_url=icon_url,referer=entry.base_url,headers={Accept="image/png, image/jpeg, image/webp, image/gif"}},temp,65536,function(meta)
        if not meta then os.remove(temp); return finish(nil) end
        local extension=ImageValidation.validate(meta.content_type,meta.size,meta.prefix,65536)
        if not extension then os.remove(temp); return finish(nil) end
        local target=directory.."/"..id.."."..extension
        local published=fs.publishNoReplace(temp,target)
        if published or fs.exists(target) then return finish(target) end
        os.remove(temp); finish(nil)
    end)
    if not started then os.remove(temp); finish(nil) end
end
function MaruManga:cacheCover(manga,callback)
    callback=callback or function() end
    local existing=self:findCachedCover(manga)
    if existing then return callback(existing) end
    if type(manga)~="table" or type(manga.cover_url)~="string" or not manga.cover_url:match("^https://") then return callback(nil) end
    local key=manga.source_id..":"..manga.id
    self.cover_waiters=self.cover_waiters or {}
    if self.cover_waiters[key] then self.cover_waiters[key][#self.cover_waiters[key]+1]=callback; return end
    self.cover_waiters[key]={callback}
    local function finish(file)
        local waiters=self.cover_waiters[key] or {}
        self.cover_waiters[key]=nil
        for _,done in ipairs(waiters) do pcall(done,file) end
    end
    local ok,fs=pcall(self.filesystem,self)
    if not ok then finish(nil); return end
    local dir,err=fs.coverDir(manga.source_id,manga.id)
    if not dir then finish(nil); return end
    local temp=dir.."/.cover.download"
    if fs.exists(temp) then fs.remove(temp) end
    local made,downloader=pcall(Downloader.new,require("ui/trapper"),SecureRequest,function() return self:dependenciesFor(manga.source_id) end,nil,self:runner(),self.config.data.timeout*2+15)
    if not made or type(downloader)~="function" then fs.remove(temp); finish(nil); return end
    local started=pcall(downloader,{image_url=manga.cover_url,referer=manga.url,headers={}},temp,5242880,function(meta)
        if not meta then fs.remove(temp); finish(nil); return end
        local extension=ImageValidation.validate(meta.content_type,meta.size,meta.prefix,5242880)
        if not extension then fs.remove(temp); finish(nil); return end
        local target=dir.."/cover."..extension
        if not fs.publishNoReplace(temp,target) then
            fs.remove(temp)
            finish(fs.exists(target) and target or nil)
            return
        end
        finish(target)
    end)
    if not started then fs.remove(temp); finish(nil) end
end
function MaruManga:prefetchVisibleCovers(items,first,last,page)
    if type(items)~="table" then return end
    local index=first
    local function renderCover(item,file,page_manga)
        item.maru_cover_pending=nil
        if file then item.maru_image=file else item.maru_cover_failed=true end
        if file and self.main_menu and self.main_menu.visible and self.main_menu.current_page==page_manga then
            self.main_menu:renderCurrentPage()
        end
    end
    local function next_cover()
        while index<=last do
            local item=items[index]
            index=index+1
            local manga=item and item.maru_manga
            if manga and not item.maru_image and not item.maru_cover_failed and not item.maru_cover_pending then
                item.maru_cover_pending=true
                local function finish(file) renderCover(item,file,page); next_cover() end
                self:cacheCover(manga,function(file)
                    if file then return finish(file) end
                    -- Some source list rows contain a stale or low-resolution
                    -- cover URL while the detail page exposes the current cover.
                    -- Retry only visible cards and only once, keeping requests serial.
                    if item.maru_cover_detail_attempted then return finish(nil) end
                    item.maru_cover_detail_attempted=true
                    local ok,source=pcall(self.source,self,manga.source_id)
                    if not ok or not source or type(source.getMangaDetails)~="function" then return finish(nil) end
                    local original=manga.cover_url
                    local replied=false
                    local started=pcall(source.getMangaDetails,source,manga,function(detail)
                        if replied then return end; replied=true
                        local detail_url=type(detail)=="table" and detail.cover_url
                        if type(detail_url)~="string" or not detail_url:match("^https://") or detail_url==original then return finish(nil) end
                        manga.cover_url=detail_url
                        self:cacheCover(manga,finish)
                    end)
                    if not started and not replied then replied=true; finish(nil) end
                end)
                return
            end
        end
    end
    next_cover()
end
function MaruManga:loadList(title, fetch, convert, page, options)
    page = page or 1
    options=options or {}
    local loading = not options.no_loading and loadingMessage(_("Loading…")) or nil
    if loading then show(loading) end
    local loading_open=loading~=nil
    local function closeLoading()
        if loading_open then loading_open=false; UIManager:close(loading) end
    end
    UIManager:nextTick(function()
        local ok, err = pcall(fetch, page, function(result, failure)
            closeLoading()
            if not result then return self:notice(failure or _("Could not load results.")) end
            local items = {}
            for ignored_index, model in ipairs(result.items) do
                local item = model
                local source=self:source(item.source_id)
                local languages=source and source:getLanguages() or {}
                local latest=item.latest_chapter or item.latestChapter or item.chapter or ""
                if type(latest)=="table" then latest=latest.name or latest.title or latest.chapter_number or "" end
                if latest~="" and not tostring(latest):lower():find("chapter",1,true) and not tostring(latest):lower():match("^ch[%s%.]?") then latest="Chapter "..tostring(latest) end
                items[#items+1] = {text=convert(item),maru_title=item.title or convert(item),maru_meta=(source and source:getName() or item.source_id)..(#languages>0 and (" · "..languageLabel(languages)) or ""),maru_progress=latest~="" and tostring(latest) or "",maru_manga=item,maru_image=self:findCachedCover(item),action=function() self:showManga(item) end}
            end
            local has_results=#items>0
            if not has_results then items[#items+1]={text=_("No matching titles"),maru_no_icon=true} end
            local external_next=options.external_next or {text=_("Load more results"),action=function() self:loadList(title,fetch,convert,page+1,options) end}
            -- Keep search result pages to two card rows on small e-ink screens.
            -- This avoids handing an oversized results page to KOReader's
            -- ButtonDialog layout immediately after the loading dialog closes.
            self:menu(title, items,nil,false,nil,{grid=has_results,page_limit=4,page_title=has_results and title or nil,external_next=has_results and result.has_next and external_next or nil,on_page=function(first,last)
                self:prefetchVisibleCovers(items,first,last,self.main_menu and self.main_menu.current_page)
            end})
        end)
        if not ok then closeLoading(); self:notice(err) end
    end)
end
function MaruManga:searchAllManga(query,page)
    page=math.max(1,math.floor(tonumber(page) or 1))
    local enabled={}
    for _,profile in ipairs(self.config.data.profiles or {}) do
        if profile.enabled~=false then enabled[#enabled+1]=profile end
    end
    if #enabled==0 then return self:notice(_("No enabled sources are installed. Use Manage Sources to enable one.")) end
    local loading
    local function closeLoading()
        if loading then UIManager:close(loading); loading=nil end
    end
    local function finish(result,failure)
        closeLoading()
        if not result then return self:notice(failure or first_error or _("Could not search enabled sources.")) end
        self:loadList(_("Search"),function(_,callback) callback(result) end,function(manga) return manga.title end,page,{
            no_loading=true,
            external_next={text=_("Load more results"),action=function() self:searchAllManga(query,page+1) end},
        })
    end
    local ok,err=pcall(AllSourceSearch.run,enabled,query,page,function(profile) return self:source(profile.id) end,
        function(task) UIManager:nextTick(task) end,
        function(index,total)
            local message=_("Searching manga...").." ("..index.."/"..total..")"
            if loading then
                loading:updateText(message)
            else
                loading=loadingMessage(message)
                show(loading)
            end
        end,finish)
    if not ok then
        closeLoading()
        self:notice(err or _("Could not search enabled sources."))
    end
end
function MaruManga:showManga(manga)
    local source = self:source(manga.source_id); if not source then return end
    local loading=loadingMessage(_("Loading manga details…")); show(loading)
    local loading_open=true
    source:getMangaDetails(manga, function(detail, err)
        if loading_open then loading_open=false; UIManager:close(loading) end
        if not detail then return self:notice(err or _("Could not load manga.")) end
        detail.cover_url=detail.cover_url or manga.cover_url
        local function present(value)
            if type(value)~="string" or value:gsub("%s+","")=="" then return _("Unknown") end
            return value
        end
        local source=self:source(detail.source_id)
        local genres=type(detail.genres)=="table" and table.concat(detail.genres,", ") or ""
        local in_library=self.library and self.library:contains(detail.source_id,detail.id)
        local items={
            {maru_key=_("Author"),maru_value=present(detail.author)},
            {maru_key=_("Artist"),maru_value=present(detail.artist)},
            {maru_key=_("Status"),maru_value=present(detail.status)},
            {maru_key=_("Genres"),maru_value=present(genres)},
            {maru_key=_("Source"),maru_value=source and source:getName() or detail.source_id,group_end=true},
            {text=_("Download All Chapters"),icon=path.."images/menu/download-all.svg",action=function() self:downloadAllChapters(detail) end},
            {text=_("Chapters"),icon=path.."images/menu/downloads.svg",action=function() self:chapters(detail,1) end},
        }
        if in_library then
            items[#items+1]={text=_("Remove from library"),icon=path.."images/menu/library.svg",action=function()
                if not self.library then return self:notice(self.library_error) end
                local ok,failure=self.library:remove(detail.source_id,detail.id)
                if ok then self:showManga(detail) else self:notice(failure) end
            end}
        else
            items[#items+1]={text=_("Add to library"),icon=path.."images/menu/library.svg",action=function()
                if not self.library then return self:notice(self.library_error) end
                local ok, failure = self.library:add(detail)
                if ok then self:showManga(detail) else self:notice(failure) end
            end}
        end
        local function showDetails(cover)
            local description=present(detail.description)
            self:menu(detail.title,items,nil,false,nil,{
                hero=cover,
                hero_icon=not cover,
                page_limit=#items,
                description=description==_("Unknown") and _("No description") or description,
            })
        end
        self:cacheCover(detail,showDetails)
    end)
end
function MaruManga:showCover(manga)
    if type(manga.cover_url)~="string" then return self:notice(_("Cover is unavailable")) end
    local ok,fs=pcall(self.filesystem,self)
    if not ok then return self:notice(_("Storage is unavailable")) end
    local dir,err=fs.coverDir(manga.source_id,manga.id); if not dir then return self:notice(err) end
    local viewer=require("ui/widget/imageviewer")
    local function open(file) show(viewer:new{file=file,title=manga.title,fullscreen=true}) end
    for ignored_index,extension in ipairs({"jpg","png","gif","webp"}) do
        local file=dir .. "/cover." .. extension
        if fs.exists(file) then return open(file) end
    end
    local temp=dir .. "/.cover.download"
    if fs.exists(temp) then return self:notice(_("An incomplete cover download exists")) end
    local loading=loadingMessage(_("Loading cover…")); show(loading)
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
        for ignored_index, chapter in ipairs(result.items) do
            local c = chapter
            local downloaded=false
            if self.library then
                local file=self.library:archiveFor(manga.source_id,manga.id,c.id)
                downloaded=file~=nil and self.library:archiveHasChapter(file,c.id) and self:filesystem().exists(file)
            end
            local date=type(c.upload_date)=="number" and (" · " .. os.date("%Y-%m-%d",c.upload_date)) or ""
            items[#items+1] = {text=c.name .. (status and status.read and " · ✓" or "") .. (downloaded and " · ↓" or "") .. date .. (c.scanlator and (" · " .. c.scanlator) or ""), action=function()
                self:menu(c.name, {
                    {text=_("Download"),action=function() self:queueChapter(manga,c) end},
                })
            end}
        end
        if #items == 1 then items[2]={text=_("No chapters in the selected language")} end
        if result.has_next then items[#items+1]={text=_("Next page"),icon=path.."images/menu/next-page.svg", action=function() self:chapters(manga, page+1, order) end} end
        self:menu(manga.title .. " · " .. page, items,nil,false,nil,{
            page_limit=8,
            page_title=manga.title,
            header_action={icon=path.."images/menu/download-all.svg",callback=function() self:downloadAllChapters(manga) end},
        })
    end,order)
end
function MaruManga:downloadAllChapters(manga)
    if not self.downloads then return self:notice(self.download_error) end
    local source=self:source(manga.source_id); if not source then return end
    local job={cancelled=false,request=nil}
    local function cancel()
        if job.cancelled then return end
        job.cancelled=true
        local request=job.request
        if request and request.cancel then pcall(request.cancel,request) end
    end
    local loading_view
    local loading_items={
        {text=_("Loading chapter list…"),maru_icon="refresh"},
        {text=_("Cancel"),icon=path.."images/menu/close.svg",action=function()
            cancel()
            if self.main_menu and self.main_menu.visible then self.main_menu:goBack() end
            if loading_view and loading_view~=self.main_menu then UIManager:close(loading_view) end
            self:notice(_("Download cancelled"))
        end},
    }
    loading_view=self:menu(_("Preparing download"),loading_items,nil,false,nil,{on_back=cancel,on_close=cancel})
    local loading_page=self.main_menu and self.main_menu.current_page
    local chapters,seen={},{}
    local page=1
    local function finish(err)
        if job.cancelled then return end
        if self.main_menu and loading_page and self.main_menu.current_page==loading_page then
            self.main_menu:goBack()
        elseif loading_view and loading_view~=self.main_menu then
            UIManager:close(loading_view)
        end
        if err then return self:notice(err) end
        table.sort(chapters,function(a,b)
            local an,bn=tonumber(a.chapter_number),tonumber(b.chapter_number)
            if an and bn and an~=bn then return an<bn end
            if an~=nil and bn==nil then return true end
            if bn~=nil and an==nil then return false end
            local ad,bd=tonumber(a.upload_date) or 0,tonumber(b.upload_date) or 0
            if ad~=bd then return ad<bd end
            return tostring(a.id)<tostring(b.id)
        end)
        if self.library and self.library:contains(manga.source_id,manga.id) then
            local ok,save_error=self.library:cacheChapters(manga,chapters)
            if not ok then return self:notice(save_error) end
        end
        local fs=self:filesystem()
        local pending,skipped={},0
        for _,chapter in ipairs(chapters) do
            local file,downloaded=LocalArchive.resolve(self.library or {archiveFor=function() end},fs,manga,chapter)
            if downloaded and file and fs.exists(file) then skipped=skipped+1
            else pending[#pending+1]={manga=manga,chapter=chapter} end
        end
        local added,duplicates=self.downloads:addMany(pending)
        if not added then return self:notice(duplicates) end
        self:notice(_("Queued: ")..added.." · ".._("Already downloaded or queued: ")..(skipped+duplicates))
    end
    local function fetch()
        if job.cancelled then return end
        if page>100 then return finish(_("Source chapter pagination limit exceeded")) end
        local current=page
        job.request=source:getChapterList(manga,current,function(result,err)
            if job.cancelled then return end
            if not result then return finish(err or _("Could not load chapter list")) end
            for _,chapter in ipairs(result.items or {}) do
                if type(chapter)=="table" and chapter.manga_id==manga.id and type(chapter.id)=="string" and not seen[chapter.id] then
                    seen[chapter.id]=true; chapters[#chapters+1]=chapter
                end
            end
            if result.has_next then page=current+1; fetch() else finish() end
        end,"asc")
    end
    fetch()
end
function MaruManga:downloadRoot()
    return self.config and self.config.data.download_dir or (DataStorage:getFullDataDir() .. "/marumanga")
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
    end,self:downloadRoot(),nil,dofile(path .. "reader/exclusive_copy.lua").move)
end
function MaruManga:startChapter(manga,chapter,done,item)
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
    local deps={source=source,fs=fs,library=self.library,archiver=require("ffi/archiver"),stager=Stager,build=Builder.mergeAll,
        legacyArchives=function(current_manga,target)
            local out={}
            for _,archive_path in ipairs(self.library:archivePathsForManga(current_manga.source_id,current_manga.id)) do
                if archive_path~=target then
                    for _,archived in ipairs(self.library:chaptersInArchive(archive_path)) do
                        local legacy=fs.legacyTargetFor(current_manga.source_id,current_manga.id,archived.id)
                        if legacy==archive_path and fs.exists(legacy) then out[#out+1]={path=legacy,folder=archived.name or archived.id} end
                    end
                end
            end
            return out
        end,
        validate=ImageValidation.validate,download=function(page,file,limit,callback)
            local copy={}; for k,v in pairs(page) do copy[k]=v end
            copy.headers={}; for k,v in pairs(page.headers or {}) do copy.headers[k]=v end
            local jar=source.resolved and source.resolved.transport and source.resolved.transport.cookies
            local cookie=jar and jar:header(page.image_url); if cookie then copy.headers.Cookie=cookie end
            return downloader(copy,file,limit,callback)
        end,
        verifyExisting=function(file,needs_hash,callback) return self:checkArchive(file,needs_hash,callback) end,
        buildAsync=function(target,items,chapter_info,legacy_archives,callback)
            return self:runner().run(function() return Builder.mergeAll(require("ffi/archiver"),fs,target,items,chapter_info.name,legacy_archives) end,600,function(ok,result,why,runner_error)
                if not ok then return callback(nil,runner_error or "Archive creation interrupted") end
                callback(result,why)
            end)
        end,
        hashArchive=function(file,callback)
            return self:runner().run(function() return FileDigest.hash(file,require("ffi/sha2").sha256) end,300,function(ok,digest,why,runner_error)
                if not ok then return callback(nil,runner_error or "Hashing interrupted") end
                callback(digest,why)
            end)
        end,
        progress=function(current,total)
            if item then
                item.current=current; item.total=total
                local widgets=self.download_widgets and self.download_widgets[item]
                local bar=widgets and widgets.bar
                local label=widgets and widgets.label
                if bar and total and total>0 then
                    local percentage=math.max(0,math.min(current/total,1))
                    local step=math.floor(percentage*20)
                    if step~=widgets.progress_step then
                        widgets.progress_step=step
                        bar:setPercentage(percentage)
                        if label then label:setText(_("Running") .. " " .. tostring(math.floor(percentage*100)) .. "%") end
                        local menu=self.download_menu
                        if menu and UIManager.isShown and UIManager:isShown(menu) then UIManager:setDirty(menu,"ui") end
                    end
                end
            end
        end,
        removeDir=function(dir) lfs.rmdir(dir) end,
        openDocument=function() end}
    return ChapterReader.open(deps,manga,chapter,function(ok,err)
        local widgets=item and self.download_widgets and self.download_widgets[item]
        if widgets and widgets.label then
            local state=ok and _("Complete") or (err=="Cancelled" and _("Cancelled") or _("Failed"))
            widgets.label:setText(state)
            local menu=self.download_menu
            if menu and UIManager.isShown and UIManager:isShown(menu) then UIManager:setDirty(menu,"ui") end
        end
        done(ok,err)
    end)
end
function MaruManga:checkArchive(file,needs_hash,callback)
    return self:runner().run(function()
        local valid,why=ArchiveCheck.validate(file,require("ffi/archiver"),dofile(path .. "reader/archive_integrity.lua").verifyEntry)
        if not valid then return nil,nil,why end
        if needs_hash then local digest,err=FileDigest.hash(file,require("ffi/sha2").sha256); if not digest then return nil,nil,err end; return true,digest end
        return true
    end,600,function(ok,valid,digest,why)
        if not ok then return callback(nil,nil,why or "Archive check interrupted") end
        callback(valid,digest,why)
    end)
end
function MaruManga:openDownloaded(manga,chapter)
    if not self.library then return self:notice(self.library_error) end
    local file=self.library:archiveFor(manga.source_id,manga.id,chapter.id)
    local fs=self:filesystem()
    if not file or not fs.exists(file) then return self:notice(_("Downloaded file is missing")) end
    if fs.exists(file..".incomplete") then return self:notice(_("Downloaded file is incomplete")) end
    local expected=self.library:archiveDigest(file)
    local loading=loadingMessage(_("Checking download...")); show(loading)
    self:checkArchive(file,not not expected,function(valid,digest,why)
        UIManager:close(loading)
        if not valid then return self:notice(why or _("Downloaded archive is invalid")) end
        if expected and expected~=digest then return self:verifyDownload(manga,chapter) end
        if self.panel_enabled and self.main_menu then self.panel_enabled=false; self.main_menu.visible=false; UIManager:close(self.main_menu) end
        require("apps/reader/readerui"):showReader(file)
    end)
end
function MaruManga:openMangaArchive(manga)
    if not self.library then return self:notice(self.library_error) end
    for _,item in ipairs(self.downloads and self.downloads.state.items or {}) do
        if item.manga.source_id==manga.source_id and item.manga.id==manga.id
            and (item.status=="running" or self.downloads:isActive(item)) then
            return show(ConfirmBox:new{text=_("A chapter for this manga is still downloading. Wait for the download to finish before opening the manga CBZ."),ok_text=_("OK")})
        end
    end
    local file
    for _,candidate in ipairs(self.library:archivePathsForManga(manga.source_id,manga.id)) do
        if candidate:sub(-#"/manga.cbz")=="/manga.cbz" then file=candidate; break end
    end
    if not file then return self:notice(_("No downloaded manga CBZ is available yet")) end
    local fs=self:filesystem()
    if not fs.exists(file) then return self:notice(_("Downloaded manga CBZ is missing")) end
    if fs.exists(file..".incomplete") then
        return show(ConfirmBox:new{text=_("The manga CBZ is still being written or was interrupted. Refresh Downloads after the queue stops, then try again."),ok_text=_("OK")})
    end
    local expected=self.library:archiveDigest(file)
    local loading=loadingMessage(_("Checking manga archive...")); show(loading)
    self:checkArchive(file,not not expected,function(valid,digest,why)
        UIManager:close(loading)
        if not valid then return self:notice(why or _("Downloaded manga CBZ is invalid")) end
        if expected and expected~=digest then return self:notice(_("Manga CBZ integrity check failed. Use Verify downloaded file on a chapter to repair it.")) end
        if self.panel_enabled and self.main_menu then self.panel_enabled=false; self.main_menu.visible=false; UIManager:close(self.main_menu) end
        require("apps/reader/readerui"):showReader(file)
    end)
end
function MaruManga:queueChapter(manga,chapter)
    if not self.downloads then return self:notice(self.download_error) end
    local file=self.library and self.library:archiveFor(manga.source_id,manga.id,chapter.id)
    if file and self.library:archiveHasChapter(file,chapter.id) and self:filesystem().exists(file) then return self:notice(_("This chapter is already in the manga CBZ")) end
    local ok,err=self.downloads:add(manga,chapter,false)
    self:notice(ok and _("Chapter queued for download") or err)
end
function MaruManga:search(source_id)
    local dialog
    dialog = InputDialog:new{title=_("Search manga"), input="", buttons={{{text=_("Cancel"), callback=function() UIManager:close(dialog) end}, {text=_("Search"), is_enter_default=true, callback=function()
        local query = dialog:getInputText()
        if query == "" then return end
        UIManager:close(dialog)
        if not source_id then return self:searchAllManga(query,1) end
        local source = self:source(source_id); if source then self:loadList(_("Search"), function(page, cb) source:searchManga(query,page,cb) end, function(m) return m.title end) end
    end}}}}
    show(dialog); dialog:onShowKeyboard()
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
    show(dialog); dialog:onShowKeyboard()
end
function MaruManga:editProfile(profile)
    local fields={"base_url","search_path","popular_path","latest_path","list_selector","list_link_selector","list_title_selector","next_selector","title_selector","description_selector","author_selector","artist_selector","status_selector","genre_selector","cover_selector","cover_attribute","chapter_selector","chapter_link_selector","chapter_attribute","chapter_mode","chapter_ajax_suffix","latest_selector","latest_label","page_selector","page_attribute","image_hosts"}
    local defaults=profile.kind=="madara" and Madara.profile(profile) or profile
    local items={}
    for ignored_index,name in ipairs(fields) do
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
            show(dialog); dialog:onShowKeyboard()
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
    show(dialog); dialog:onShowKeyboard()
end
function MaruManga:refreshRepository(repo,options)
    options=options or {}
    local host=repo.url:match("^https://([%w%.%-]+)/")
    if not host then if options.callback then options.callback(nil,"Invalid repository URL") end; if not options.silent then self:notice(_("Invalid repository URL")) end; return end
    local transport=Transport.new(UIManager,require("ui/trapper"),require("json"),Client,SecureRequest,function()
        local deps=applyDNS(networkDependencies(),self.config.data); deps.timeout=self.config.data.timeout; deps.user_agent=self.config.data.user_agent; deps.ignore_ssl_certificates=self.config.data.ignore_ssl_certificates==true; deps.allowed_hosts={[host]=true}; return deps
    end,{accept_url=function(url) return url==repo.url end,max_attempts=self.config.data.retries,runner=self:runner(),deadline=self.config.data.timeout*2+10})
    local loading
    if not options.silent then loading=loadingMessage(_("Refreshing repository...")); show(loading) end
    transport:get(repo.url,function(catalog,err)
        if loading then UIManager:close(loading) end
        local ok,why
        if not catalog then repo.unreachable=true; why=err or _("Repository not reachable"); repo.last_error=why
        else
            local previous,previous_error=repo.unreachable,repo.last_error; repo.unreachable=nil; repo.last_error=nil
            ok,why=self.repositories:update(repo,catalog)
            if not ok then repo.unreachable=previous; repo.last_error=previous_error or why end
            if ok and repo.builtin then
                local install_ok,install_error=self:installDefaultCatalogSources()
                if install_ok==nil then ok=false; why=install_error end
            end
        end
        if options.callback then pcall(options.callback,ok,why) end
        if not options.silent then self:notice(ok and _("Repository refreshed") or why) end
    end)
end
function MaruManga:showRepositories(page)
    if not self.repositories then return self:notice(self.repository_error) end
    page=math.max(1,tonumber(page) or 1)
    local items={{text=_("Add Repositories"),action=function()
        local dialog
        dialog=InputDialog:new{title=_("HTTPS catalog URL"),input="https://",buttons={{{text=_("Cancel"),callback=function() UIManager:close(dialog) end},{text=_("Add"),callback=function()
            local repo,err=self.repositories:add(dialog:getInputText())
            if not repo then return self:notice(err) end
            UIManager:close(dialog); self:refreshRepository(repo,{callback=function(ok)
                if ok and not repo.title and repo.catalog then repo.title=repo.catalog.name; self.repositories:save() end
                self:showRepositories()
            end})
        end}}}}
        show(dialog); dialog:onShowKeyboard()
    end}}
    items[#items+1]={text=_("Refresh Repositories"),group_end=true,action=function()
        local repos=self.repositories:list(); local index=1
        local function nextRepo()
            local repo=repos[index]; index=index+1
            if not repo then return self:showRepositories() end
            self:refreshRepository(repo,{silent=true,callback=function(ok)
                if ok and not repo.builtin and not repo.title and repo.catalog then repo.title=repo.catalog.name; self.repositories:save() end
                nextRepo()
            end})
        end
        nextRepo()
    end}
    local all_repos=self.repositories:list()
    local function installedCount(repo)
        local count=0; local origin=repo.url or "builtin"
        for _,entry in ipairs(repositorySources(repo)) do
            for _,profile in ipairs(self.config.data.profiles or {}) do if profile.id==entry.id and profile.repository_url==origin then count=count+1; break end end
        end
        return count
    end
    local page_size=12
    local first=(page-1)*page_size+1; local last=math.min(#all_repos,page*page_size)
    for ignored_index,repository in ipairs(all_repos) do
        local repo=repository
        if ignored_index>=first and ignored_index<=last then
            local source_total=repo.catalog and #repo.catalog.sources or 0
            local title=repo.title or (repo.catalog and repo.catalog.name) or repo.url or _("Bundled")
            items[#items+1]={text=title.."  ("..installedCount(repo).."/"..source_total.." ".._("Sources Installed")..")",action=function() self:showRepository(repo) end}
        end
    end
    if page>1 then items[#items+1]={text=_("Previous page"),action=function() self:showRepositories(page-1) end} end
    if last<#all_repos then items[#items+1]={text=_("Next page"),action=function() self:showRepositories(page+1) end} end
    self:menu(_("Repositories").." ("..#all_repos..")",clickable(items),nil,true)
end
function MaruManga:searchRepositorySources(repo,query)
    local dialog
    dialog=InputDialog:new{title=_("Search Sources"),input=query or "",buttons={{{text=_("Cancel"),callback=function() UIManager:close(dialog) end},{text=_("Search"),callback=function()
        local value=dialog:getInputText(); UIManager:close(dialog); self:showRepositorySources(repo,value)
    end}}}}
    show(dialog); dialog:onShowKeyboard()
end
function MaruManga:showRepository(repo)
    local catalog=repo.catalog
    local title=repo.title or (catalog and catalog.name) or repo.url
    local author=catalog and catalog.author
    if not author or author=="" or author=="Unknown" then author=repo.url and repo.url:match("raw%.githubusercontent%.com/([^/]+)/") or "Unknown" end
    local version=catalog and tostring(catalog.version) or "Unknown"
    local raw_status=catalog and catalog.status or "Unknown"
    local normalized=type(raw_status)=="string" and raw_status:lower() or "unknown"
    local status=repo.last_error and "Error" or ((normalized=="ok" and "OK") or (normalized=="maintenance" and "Maintenance") or (normalized=="error" and "Error") or "Unknown")
    local sources=repositorySources(repo)
    local installed_count=0
    for _,entry in ipairs(sources) do
        local installed=entry.id=="mangadex" and self.config.data.mangadex_installed or self:profile(entry.id)
        if installed and (entry.id=="mangadex" or installed.repository_url==(repo.url or "builtin")) then installed_count=installed_count+1 end
    end
    local items={
        {maru_key=_("Title"),maru_value=title},
        {maru_key=_("Author"),maru_value=author},
        {maru_key=_("Version"),maru_value=version},
        {maru_key=_("Status"),maru_value=status..(status=="Error" and (" · ".._("Details")) or ""),action=status=="Error" and function() self:notice(repo.last_error or (catalog and catalog.status_message) or _("Repository owner reported an error")) end or nil},
        {maru_key=_("Repo URL"),maru_value=repo.url,group_end=true},
        {text=_("Edit title and URL"),icon=path.."images/menu/settings.svg",action=function() self:editRepository(repo) end},
        {text=_("Reset title from verified metadata"),icon=path.."images/menu/refresh.svg",action=function()
            self:refreshRepository(repo,{callback=function(ok)
                if ok then repo.title=nil; self.repositories:save(); self:showRepository(repo) end
            end})
        end},
        {text=_("Refresh Repository"),icon=path.."images/menu/refresh.svg",action=function() self:refreshRepository(repo,{callback=function(ok) if ok then self:showRepository(repo) end end}) end},
        {text=_("Sources: ")..#sources.."  ·  "..installed_count.."/"..#sources.." ".._("Installed"),icon=path.."images/menu/source.svg",group_end=true,action=function() self:showRepositorySources(repo) end},
    }
    items[#items+1]={text=_("Delete Repository"),icon=path.."images/menu/close.svg",action=function()
        show(ConfirmBox:new{text=_("Delete this repository? Installed sources and downloads remain."),ok_text=_("Delete"),ok_callback=function()
            local ok,err=self.repositories:remove(repo); self:notice(ok and _("Repository deleted") or err); self:showRepositories()
        end})
    end}
    self:menu(title,clickable(items),nil,true,nil,{page_limit=#items})
end
function MaruManga:showRepositorySources(repo,source_query,page,replace_page)
    local catalog=repo.catalog
    local title=repo.title or (catalog and catalog.name) or repo.url
    local sources=repositorySources(repo)
    page=math.max(1,tonumber(page) or 1)
    local needle=type(source_query)=="string" and source_query:lower() or ""
    local filtered={}
    for _,entry in ipairs(sources) do
        if needle=="" or entry.name:lower():find(needle,1,true) or entry.id:lower():find(needle,1,true) then filtered[#filtered+1]=entry end
    end
    local items={{text=_("Search Sources")..(needle~="" and ("  ·  ".._("Matches: ")..#filtered) or ""),icon=path.."images/menu/search.svg",action=function() self:searchRepositorySources(repo,source_query) end}}
    if needle~="" then items[#items+1]={text=_("Clear source search"),icon=path.."images/menu/close.svg",action=function() self:showRepositorySources(repo) end} end
    items[#items+1]={text=_("Mass Install"),icon=path.."images/menu/downloads.svg",action=function() self:massSourceAction(repo,true) end}
    items[#items+1]={text=_("Mass Uninstall"),icon=path.."images/menu/library.svg",group_end=true,action=function() self:massSourceAction(repo,false) end}
    local page_size=12
    local first=(page-1)*page_size+1
    local last=math.min(#filtered,page*page_size)
    for index=first,last do
        local entry=filtered[index]
        local profile=entry.id=="mangadex" and self.config.data.mangadex_installed or self:profile(entry.id)
        local disabled=entry.id=="mangadex" and profile and not self.config.data.mangadex_enabled or type(profile)=="table" and profile.enabled==false
        local outdated=type(profile)=="table" and Repositories.versionLess(profile.repository_version or 0,entry.version)
        local compatibility=sourceCompatibilityIssue(entry)
        local state=compatibility and _("Unsupported") or disabled and _("Disabled") or outdated and _("Update available") or profile and _("Installed") or _("Available")
        local tags=""
        if entry.nsfw then tags=tags.." [NSFW]" end
        if entry.languages and #entry.languages>0 then tags=tags.." "..languageLabel(entry.languages) end
        local installed=profile~=nil
        local row={text=entry.name..tags.."  ·  "..state,icon=path.."images/menu/"..(installed and "check-on" or "check-off")..".svg",action=function() self:catalogSourceDialog(repo,entry) end}
        items[#items+1]=row
    end
    if #sources==0 then items[#items+1]={text=_("No sources in this repository")} elseif #filtered==0 then items[#items+1]={text=_("No matching sources")} end
    if page>1 then items[#items+1]={text=_("Previous page"),icon=path.."images/menu/back.svg",action=function() self:showRepositorySources(repo,source_query,page-1) end} end
    if last<#filtered then items[#items+1]={text=_("Next page"),icon=path.."images/menu/next.svg",action=function() self:showRepositorySources(repo,source_query,page+1) end} end
    local page_title=title.." · Sources · Page "..page
    self:menu(page_title,clickable(items),nil,true,replace_page)
end
function MaruManga:editRepository(repo)
    local catalog=repo.catalog
    local dialog
    dialog=MultiInputDialog:new{title=_("Edit Repository"),fields={
        {text=repo.title or (catalog and catalog.name) or "",hint=_("Title")},
        {text=repo.url or "",hint=_("Repo URL (HTTPS)")},
    },buttons={{{text=_("Cancel"),callback=function() UIManager:close(dialog) end},{text=_("Reset"),callback=function()
        local url=dialog:getFields()[2]
        if url~=repo.url then
            local old=repo.url; local ok,err=self.repositories:edit(repo,repo.title or (catalog and catalog.name) or "Repository",url)
            if not ok then return self:notice(err) end
            self:refreshRepository(repo,{callback=function(success)
                if success then repo.title=nil; self.repositories:save(); UIManager:close(dialog); self:showRepository(repo) else self:notice(_("Could not verify repository URL")) end
            end})
        else self:refreshRepository(repo,{callback=function(success) if success then repo.title=nil; self.repositories:save(); UIManager:close(dialog); self:showRepository(repo) end end}) end
    end},{text=_("Save"),callback=function()
        local fields=dialog:getFields(); local new_title,new_url=fields[1],fields[2]
        if new_title==(repo.title or (catalog and catalog.name) or "") and new_url==repo.url then return self:notice(_("No changes to save")) end
        local ok,err=self.repositories:edit(repo,new_title,new_url); if not ok then return self:notice(err) end
        UIManager:close(dialog); self:refreshRepository(repo,{callback=function(success) if success then self:showRepository(repo) end end})
    end}}}}
    show(dialog)
end
function MaruManga:catalogSourceDialog(repo,entry)
    if entry.id=="mangadex" or entry.adapter=="mangadex" then return self:notice(_("MangaDex is no longer available")) end
    local installed=entry.id=="mangadex" and self.config.data.mangadex_installed or self:profile(entry.id)
    local conflict=type(installed)=="table" and installed.repository_url~=(repo.url or "builtin")
    local compatibility=sourceCompatibilityIssue(entry)
    local items={{text=_("Version: ")..tostring(entry.version)},{text=_("Languages: ")..languageLabel(entry.languages)}}
    if entry.nsfw then items[#items+1]={text=_("Content: NSFW")} end
    if compatibility then items[#items+1]={text=_("Unsupported: ")..compatibility}
    elseif conflict then items[#items+1]={text=_("Source ID belongs to another repository")}
    elseif not installed then items[#items+1]={text=_("Install"),action=function() if self:installCatalogSource(repo,entry) then self:showRepositorySources(repo) end end}
    else
        if type(installed)=="table" and Repositories.versionLess(installed.repository_version or 0,entry.version) then
            items[#items+1]={text=_("Update"),action=function() if self:installCatalogSource(repo,entry) then self:showRepositorySources(repo) end end}
        end
        items[#items+1]={text=(type(installed)=="table" and installed.enabled==false or entry.id=="mangadex" and not self.config.data.mangadex_enabled) and _("Enable") or _("Disable"),action=function()
            if entry.id=="mangadex" then self.config.data.mangadex_enabled=not self.config.data.mangadex_enabled
            else installed.enabled=not (installed.enabled~=false) end
            local ok,err=self.config:save(); if not ok then return self:notice(err) end
            self.manga_sources=nil; self:showRepositorySources(repo)
        end}
        items[#items+1]={text=_("Uninstall"),action=function() show(ConfirmBox:new{text=_("Uninstall this source? Library and downloads remain."),ok_text=_("Uninstall"),ok_callback=function()
            if entry.id=="mangadex" then self.config.data.mangadex_installed=false
            else for i,profile in ipairs(self.config.data.profiles) do if profile==installed then table.remove(self.config.data.profiles,i); break end end end
            local ok,err=self.config:save(); if not ok then return self:notice(err) end
            self.manga_sources=nil; self:showRepositorySources(repo)
        end}) end}
    end
    self:menu(entry.name,clickable(items))
end
function MaruManga:massSourceAction(repo,install)
    local entries={}; for _,entry in ipairs(repositorySources(repo)) do
        local active=self:profile(entry.id)
        if not sourceCompatibilityIssue(entry) and (install or active) then entries[#entries+1]=entry end
    end
    local selected={}; for _,entry in ipairs(entries) do selected[entry.id]=install end
    local function render()
        local items={}
        for _,entry in ipairs(entries) do local item=entry; items[#items+1]={text=item.name,icon=path.."images/menu/"..(selected[item.id] and "check-on" or "check-off")..".svg",action=function() selected[item.id]=not selected[item.id]; render() end} end
    items[#items+1]={text=install and _("Install selected") or _("Uninstall selected"),action=function()
            if not install then return show(ConfirmBox:new{text=_("Uninstall selected sources? Library and downloads remain."),ok_text=_("Uninstall"),ok_callback=function() self:applyMassSources(repo,entries,selected,false); self:showRepositorySources(repo) end}) end
            self:applyMassSources(repo,entries,selected,true); self:showRepositorySources(repo)
        end}
        self:menu(install and _("Mass Install") or _("Mass Uninstall"),clickable(items))
    end
    render()
end
function MaruManga:applyMassSources(repo,entries,selected,install)
    local changed=0
    for _,entry in ipairs(entries) do if selected[entry.id] then
        if install then if self:installCatalogSource(repo,entry) then changed=changed+1 end
        elseif entry.id=="mangadex" and self.config.data.mangadex_installed then self.config.data.mangadex_installed=false; changed=changed+1
        else for i,profile in ipairs(self.config.data.profiles) do if profile.id==entry.id and profile.repository_url==(repo.url or "builtin") then table.remove(self.config.data.profiles,i); changed=changed+1; break end end end
    end end
    self.config:save(); self.manga_sources=nil; self:notice((install and _("Installed: ") or _("Uninstalled: "))..changed)
end
function MaruManga:installCatalogSource(repo,entry)
    if entry.id=="mangadex" or entry.adapter=="mangadex" then return self:notice(_("MangaDex is no longer available")) end
    local compatibility=sourceCompatibilityIssue(entry)
    if compatibility then self:notice(_("Cannot install this source: ")..compatibility); return false end
    local existing=self:profile(entry.id)
    local origin=repo.url or "builtin"
    if existing and existing.repository_url~=origin then return self:notice(_("A source with this ID is already installed")) end
    local profile={id=entry.id,name=entry.name,base_url=entry.base_url,icon_url=entry.icon_url,kind=entry.adapter,languages=entry.languages,nsfw=entry.nsfw==true,enabled=not existing or existing.enabled~=false,repository_url=origin,repository_version=entry.version}
    for k,v in pairs(entry.profile or {}) do profile[k]=v end
    if existing then
        local index; for i,value in ipairs(self.config.data.profiles) do if value==existing then index=i; break end end
        self.config.data.profiles[index]=profile
        local ok,err=self.config:save(); if not ok then self.config.data.profiles[index]=existing; return self:notice(err) end
    else
        local ok,err=self.config:addProfile(profile); if not ok then return self:notice(err) end
        ok,err=self.config:save(); if not ok then table.remove(self.config.data.profiles); return self:notice(err) end
    end
    self.manga_sources=nil; return true
end
function MaruManga:installDefaultCatalogSources()
    if not self.config or not self.repositories then return false end
    local default_repo
    for _,repo in ipairs(self.repositories:list()) do if repo.builtin then default_repo=repo; break end end
    if not default_repo or type(default_repo.catalog)~="table" then return false end
    local installed_before={}
    for _,id in ipairs(self.config.data.auto_installed_source_ids or {}) do installed_before[id]=true end
    local changed=false
    for _,entry in ipairs(repositorySources(default_repo)) do
        if not installed_before[entry.id] then
            local profile=self:profile(entry.id)
            if profile or not sourceCompatibilityIssue(entry) then
                if not profile then
                    local ok=self:installCatalogSource(default_repo,entry)
                    if not ok then return false end
                    profile=self:profile(entry.id)
                    if profile and entry.nsfw then profile.enabled=false end
                end
                self.config.data.auto_installed_source_ids[#self.config.data.auto_installed_source_ids+1]=entry.id
                installed_before[entry.id]=true
                changed=true
            end
        end
    end
    if changed then
        table.sort(self.config.data.auto_installed_source_ids)
        local ok,err=self.config:save()
        if not ok then return nil,err end
    end
    return true
end
function MaruManga:sourceCatalogs()
    local catalogs=self.repositories:list(); local represented={}; local installed_by_id={}
    for ignored_index,profile in ipairs(self.config.data.profiles) do installed_by_id[profile.id]=profile end
    for ignored_index,repo in ipairs(catalogs) do
        local origin=repo.url or "builtin"
    for ignored_source,entry in ipairs(repositorySources(repo)) do
            local installed=installed_by_id[entry.id]
            if installed and installed.repository_url==origin then represented[entry.id]=true end
        end
    end
    local local_entries={}
    for ignored_index,profile in ipairs(self.config.data.profiles) do
        if not represented[profile.id] then local_entries[#local_entries+1]={id=profile.id,name=profile.name,adapter=profile.kind or "generic",version=profile.repository_version or 1,base_url=profile.base_url} end
    end
    if #local_entries>0 then catalogs[#catalogs+1]={local_profiles=true,catalog={name=_("Local sources"),sources=local_entries}} end
    return catalogs
end
function MaruManga:sourceManager(query,filter)
    if not self.repositories or not self.config then return self:notice(self.repository_error or self.config_error) end
    local manager_menu
    local items={{text=_("Search sources"),action=function()
        local dialog
        dialog=InputDialog:new{title=_("Search sources"),input=query or "",buttons={{{text=_("Cancel"),callback=function() UIManager:close(dialog) end},{text=_("Search"),callback=function() local q=dialog:getInputText(); UIManager:close(dialog); if manager_menu and not self.panel_enabled then UIManager:close(manager_menu) end; self:sourceManager(q,filter) end}}}}
        show(dialog); dialog:onShowKeyboard()
    end},{text=_("Filter by repository"),action=function()
        local filter_menu
        local function choose(origin)
            if filter_menu and not self.panel_enabled then UIManager:close(filter_menu) end
            if manager_menu and not self.panel_enabled then UIManager:close(manager_menu) end
            self:sourceManager(query,origin)
        end
        local choices={{text=_("All repositories"),action=function() choose(nil) end}}
        for ignored_index,repository in ipairs(self:sourceCatalogs()) do local repo=repository; local origin=repo.local_profiles and "local" or repo.url or "builtin"; choices[#choices+1]={text=repo.catalog and repo.catalog.name or repo.url,action=function() choose(origin) end} end
        filter_menu=self:menu(_("Filter by repository"),choices)
    end},{text=_("Manage Repositories"),group_end=true,action=function() self:showRepositories() end}}
    query=(query or ""):lower()
    local installed_by_id={}; for ignored_index,profile in ipairs(self.config.data.profiles) do installed_by_id[profile.id]=profile end
    for ignored_index,repository in ipairs(self:sourceCatalogs()) do
        local repo=repository; local origin=repo.local_profiles and "local" or repo.url or "builtin"
        if not filter or filter==origin then
            if repo.unreachable or repo.last_error then items[#items+1]={text=(repo.catalog and repo.catalog.name or repo.url) .. " · " .. (repo.unreachable and _("Not reachable") or _("Repository error")),action=function() self:notice(repo.last_error or _("Repository not reachable")) end} end
            for ignored_index,source in ipairs(repo.catalog and repo.catalog.sources or {}) do
                local entry=source; local installed=entry.id=="mangadex" and self.config.data.mangadex_installed or installed_by_id[entry.id]
                local conflict=type(installed)=="table" and not repo.local_profiles and installed.repository_url~=origin
                local status=conflict and _("ID conflict") or installed and _("Installed") or _("Available")
                if entry.id=="mangadex" and installed and not self.config.data.mangadex_enabled then status=_("Disabled") end
                if type(installed)=="table" and installed.enabled==false then status=_("Disabled") end
                if entry.id=="mangadex" and entry.version>1 then status=_("Plugin update required") end
                if repo.unreachable then status=_("Not reachable") end
                if conflict then status=_("ID conflict") end
                if not repo.unreachable and type(installed)=="table" and installed.repository_url==origin and Repositories.versionLess(installed.repository_version or 0,entry.version) then status=_("Update available") end
                if entry.name:lower():find(query,1,true) then items[#items+1]={text=entry.name .. " · " .. status,action=function()
                    local choices={}; local detail_menu
                    local function refreshed(message)
                        if detail_menu and not self.panel_enabled then UIManager:close(detail_menu) end
                        if manager_menu and not self.panel_enabled then UIManager:close(manager_menu) end
                        self:sourceManager(query,filter)
                        self:notice(message)
                    end
                    if conflict then return self:notice(_("Another source already uses this ID")) end
                    if not installed or (type(installed)=="table" and installed.repository_url==origin and Repositories.versionLess(installed.repository_version or 0,entry.version)) then
                        choices[#choices+1]={text=installed and _("Update") or _("Install"),action=function() if self:installCatalogSource(repo,entry) then refreshed(_("Source installed")) end end}
                    end
                    if entry.id=="mangadex" and installed then
                        choices[#choices+1]={text=self.config.data.mangadex_enabled and _("Disable") or _("Enable"),action=function()
                            local old=self.config.data.mangadex_enabled; self.config.data.mangadex_enabled=not old
                            local ok,err=self.config:save(); if not ok then self.config.data.mangadex_enabled=old; return self:notice(err) end
                            self.manga_sources=nil; refreshed(_("Source updated"))
                        end}
                        choices[#choices+1]={text=_("Uninstall"),action=function()
                            show(ConfirmBox:new{text=_("Uninstall MangaDex? Library and downloads remain."),ok_text=_("Uninstall"),ok_callback=function()
                                local old=self.config.data.mangadex_installed; self.config.data.mangadex_installed=false
                                local ok,err=self.config:save(); if not ok then self.config.data.mangadex_installed=old; return self:notice(err) end
                                self.manga_sources=nil; refreshed(_("Source uninstalled"))
                            end})
                        end}
                    end
                    if type(installed)=="table" then
                        choices[#choices+1]={text=installed.enabled==false and _("Enable") or _("Disable"),action=function()
                            local old,selected=installed.enabled,self.config.data.source; installed.enabled=installed.enabled==false
                            if not installed.enabled and selected==installed.id then self.config.data.source="komiku" end
                            local ok,err=self.config:save(); if not ok then installed.enabled=old; self.config.data.source=selected; return self:notice(err) end
                            self.manga_sources=nil; refreshed(_("Source updated"))
                        end}
                        choices[#choices+1]={text=_("Uninstall"),action=function()
                            show(ConfirmBox:new{text=_("Uninstall this source? Library and downloads remain."),ok_text=_("Uninstall"),ok_callback=function()
                                local profiles=self.config.data.profiles; local index
                                for i,v in ipairs(profiles) do if v==installed then index=i; break end end
                                if not index then return self:notice(_("Source is unavailable")) end
                                table.remove(profiles,index); local old=self.config.data.source
                                if old==installed.id then self.config.data.source="komiku" end
                                local ok,err=self.config:save(); if not ok then table.insert(profiles,index,installed); self.config.data.source=old; return self:notice(err) end
                                self.manga_sources=nil; refreshed(_("Source uninstalled"))
                            end})
                        end}
                    end
                    if #choices==0 then choices[1]={text=_("Bundled source")} end
                    detail_menu=self:menu(entry.name,choices)
                end} end
            end
        end
    end
    if #items==3 then items[#items+1]={text=_("No matching sources")} end
    manager_menu=self:menu(_("Source Manager"),items,nil,true)
    if not self.default_refresh_started then
        self.default_refresh_started=true
        local default=self.repositories.data.default_repository
        UIManager:nextTick(function()
            self:refreshRepository(default,{silent=true,callback=function()
                if UIManager:isWidgetShown(manager_menu) and UIManager:getTopmostVisibleWidget()==manager_menu then
                    if not self.panel_enabled then UIManager:close(manager_menu) end
                    self:sourceManager(query,filter)
                end
            end})
        end)
    end
end
function MaruManga:sourceMenu()
    self:showRepositories()
end
function MaruManga:showSources()
    if not self.config then return self:notice(self.config_error) end
    local choices={}
    for ignored_index, profile in ipairs(self.config.data.profiles) do
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
                    if not entry.enabled and selected==entry.id then self.config.data.source="komiku" end
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
        show(ConfirmBox:new{text=_("Remove cached covers for the selected source?"),ok_text=_("Clear"),ok_callback=function()
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
    local items={}
    local downloaded={}
    local latest_downloaded={}
    for archive_path,archive in pairs(self.library.data.archives or {}) do
        if type(archive)=="table" and type(archive.manga)=="table" then
            local source_id,manga_id=archive.manga.source_id,archive.manga.id
            local key=type(source_id)=="string" and type(manga_id)=="string" and source_id..":"..manga_id or nil
            if key then
                for _,chapter in ipairs(self.library:chaptersInArchive(archive_path)) do
                    downloaded[key]=(downloaded[key] or 0)+1
                    local number=chapter.chapter_number
                    if type(number)=="number" and (latest_downloaded[key]==nil or number>latest_downloaded[key]) then latest_downloaded[key]=number end
                end
            end
        end
    end
    for ignored_index, manga in ipairs(self.library:list(query,"title","all",self.config and self.config.data.source)) do
        local entry=manga
        local key=entry.source_id..":"..entry.id
        local downloaded_count=downloaded[key] or 0
        local sync=self.library.data.chapter_sync and self.library.data.chapter_sync[key]
        local latest_count=type(sync)=="table" and type(sync.count)=="number" and sync.count or nil
        local missing_count=type(sync)=="table" and latest_count~=nil and type(sync.missing_count)=="number" and sync.missing_count or nil
        local source_latest=type(sync)=="table" and type(sync.latest_number)=="number" and sync.latest_number or nil
        local genre_names={}
        if type(entry.genres)=="table" then
            for _,genre in ipairs(entry.genres) do if type(genre)=="string" and genre~="" then genre_names[#genre_names+1]=genre end end
        end
        local genres=table.concat(genre_names," · ")
        local state
        if missing_count==nil then state=_("Check Updates")
        elseif source_latest~=nil and latest_downloaded[key]~=nil then state=latest_downloaded[key]<source_latest and _("Update Available") or _("Latest")
        else state=missing_count>0 and _("Update Available") or _("Latest") end
        local known_downloaded=missing_count~=nil and math.max(0,latest_count-missing_count) or downloaded_count
        local chapter_count
        if source_latest~=nil and latest_downloaded[key]~=nil then chapter_count=tostring(latest_downloaded[key]).."/"..tostring(source_latest)
        elseif latest_count==nil then chapter_count=tostring(downloaded_count).."/?"
        else chapter_count=tostring(known_downloaded).."/"..tostring(latest_count) end
        local state_icon=missing_count==nil and "badge-check" or state==_("Update Available") and "badge-update" or "badge-latest"
        local meta=(entry.status or _("Unknown"))..(genres~="" and (" · "..genres) or "")
        local progress=_("Chapter ")..chapter_count.." · "..state
        items[#items+1]={text=entry.title,maru_icon="manga",maru_badge=state_icon,maru_title=entry.title,maru_meta=meta,maru_progress=progress,maru_manga=entry,maru_image=self:findCachedCover(entry),action=function()
            self:menu(entry.title, {
                {text=_("Saved details"),action=function()
                    self:notice(entry.title .. "\n\n" .. (entry.description or _("No description")) .. "\n\n" .. _("Author: ") .. (entry.author or _("Unknown")) .. "\n" .. _("Status: ") .. (entry.status or _("Unknown")))
                end},
                {text=_("Read Manga"),icon=path.."images/menu/book.svg",action=function() self:openMangaArchive(entry) end},
                {text=_("Offline chapters"), action=function() self:offlineChapters(entry) end},
                {text=_("Live Detail"), action=function() self:showManga(entry) end},
                {text=_("Remove from library"), action=function()
                    local ok,err=self.library:remove(entry.source_id,entry.id)
                    self:notice(ok and _("Removed from library") or err)
                end},
            })
        end}
    end
    if #items == 0 then items[1]={text=_("No matching titles"),maru_no_icon=true} end
    self:menu(_("Library"),clickable(items),nil,false,nil,{grid=not items[1].maru_no_icon,page_limit=4,page_title=not items[1].maru_no_icon and _("Library") or nil,on_page=function(first,last)
        self:prefetchVisibleCovers(items,first,last,self.main_menu and self.main_menu.current_page)
    end})
end
function MaruManga:openLibrary()
    self:menu(_("Library"),clickable({
        {text=_("Browse library"),icon=path.."images/menu/library.svg",action=function() self:showLibrary() end},
        {text=_("Search library"),action=function()
            local dialog
            dialog=InputDialog:new{title=_("Search library"),input="",buttons={{{text=_("Cancel"),callback=function() UIManager:close(dialog) end},{text=_("Search"),callback=function()
                local text=dialog:getInputText(); UIManager:close(dialog); self:showLibrary(text)
            end}}}}
            show(dialog); dialog:onShowKeyboard()
        end},
        {text=_("Check Updates"),group_end=true,action=function() self:showUpdates() end},
    }))
end
function MaruManga:offlineChapters(manga)
    local items={}
    for archive_path,item in pairs(self.library.data.archives) do
        if type(item)=="table" and type(item.manga)=="table" and item.manga.id==manga.id and item.manga.source_id==manga.source_id then
            for _,archived in ipairs(self.library:chaptersInArchive(archive_path)) do
                local cached=self.library:chapterStatus(manga.source_id,archived.id)
                local metadata=cached and cached.metadata or archived
                local c={id=archived.id,name=archived.name,manga_id=manga.id,url=metadata.url,chapter_number=metadata.chapter_number,scanlator=metadata.scanlator,upload_date=metadata.upload_date}
                items[#items+1]={text=c.name or c.id,action=function()
                    self:menu(c.name or c.id,{
                        {text=_("Open downloaded file"),action=function() self:openDownloaded(manga,c) end},
                        {text=_("Verify downloaded file"),action=function() self:verifyDownload(manga,c) end},
                    })
                end}
            end
        end
    end
    table.sort(items,function(a,b) return a.text<b.text end)
    if #items==0 then items[1]={text=_("No offline chapters")} end
    self:menu(_("Offline chapters"),items)
end
function MaruManga:setArchiveBaseline(file,manga,chapter)
    return show(ConfirmBox:new{text=_("This older download has no original hash. Verify its archive and record its current contents as a new baseline? This cannot prove the original contents."),ok_text=_("Set baseline"),ok_callback=function()
            local loading=loadingMessage(_("Checking archive...")); show(loading)
            self:runner().run(function()
                local valid,err=ArchiveCheck.validate(file,require("ffi/archiver"),dofile(path .. "reader/archive_integrity.lua").verifyEntry)
                if not valid then return nil,err end
                return FileDigest.hash(file,require("ffi/sha2").sha256)
            end,600,function(ok,digest,why,runner_error)
                UIManager:close(loading)
                if not ok or not digest then return self:notice(runner_error or why or _("Could not verify archive")) end
                local saved,err=self.library:linkArchive(file,manga,chapter,nil,digest)
                self:notice(saved and _("Current contents recorded as baseline") or err)
            end)
        end})
end
function MaruManga:verifyDownload(manga,chapter)
    local file=self.library and self.library:archiveFor(manga.source_id,manga.id,chapter.id)
    local metadata=file and self.library.data.archives[file]
    local fs=self:filesystem()
    if not file or not fs.exists(file) then return self:notice(_("Downloaded file is missing")) end
    if fs.exists(file..".incomplete") then return self:notice(_("Downloaded file is incomplete")) end
    if not metadata.sha256 then return self:setArchiveBaseline(file,manga,chapter) end
    local loading=loadingMessage(_("Verifying download…")); show(loading)
    self:runner().run(function() return FileDigest.hash(file,require("ffi/sha2").sha256) end,300,function(ok,digest,why,runner_error)
        UIManager:close(loading)
        if not ok or not digest then return self:notice(runner_error or why or _("Could not verify download")) end
        if digest==metadata.sha256 then return self:notice(_("Download matches its recorded SHA-256 hash")) end
        show(ConfirmBox:new{text=_("The downloaded file has changed. Save the damaged file as a backup and download this chapter again?"),ok_text=_("Redownload"),ok_callback=function()
            local active=false
            for item in pairs(self.downloads and self.downloads.active_items or {}) do if item.manga.source_id==manga.source_id and item.chapter.id==chapter.id then active=true; break end end
            if active then return self:notice(_("This chapter is in use")) end
            local fs=self:filesystem(); local backup=file..".broken"
            if fs.exists(backup..".incomplete") then
                return show(ConfirmBox:new{text=_("An incomplete repair backup exists. Remove the incomplete backup and retry?"),ok_text=_("Remove"),ok_callback=function()
                    local cleaned,why=fs.cleanupTemporary(manga.source_id,manga.id,chapter.id)
                    self:notice(cleaned and _("Incomplete backup removed; retry repair") or why)
                end})
            end
            if fs.exists(backup) then return self:notice(_("A damaged-file backup already exists")) end
            local moved,err=fs.publishNoReplace(file,backup)
            if not moved then return self:notice(err or _("Could not preserve damaged file")) end
            local queued,queue_err=self.downloads:add(manga,chapter,false)
            if not queued then
                local restored=fs.publishNoReplace(backup,file)
                return self:notice((queue_err or _("Could not queue repair")) .. (restored and "" or " · " .. _("Backup retained")))
            end
            self:notice(_("Repair queued; damaged file retained as backup"))
        end})
    end)
end
function MaruManga:showDownloads(page)
    if not self.downloads then return self:notice(self.download_error) end
    local groups,by_key={},{}
    for _,item in ipairs(self.downloads.state.items) do
        local key=item.manga.source_id..":"..item.manga.id
        local group=by_key[key]
        if not group then
            group={manga=item.manga,source_id=item.manga.source_id,manga_id=item.manga.id,running=0,queued=0,paused=0,completed=0,failed=0,cancelled=0}
            by_key[key]=group; groups[#groups+1]=group
        end
        group[item.status]=(group[item.status] or 0)+1
    end
    local page_size=6
    local total=#groups
    local page_count=math.max(1,math.ceil(total/page_size))
    page=math.max(1,math.min(math.floor(tonumber(page) or 1),page_count))
    local items={}
    local first=(page-1)*page_size+1
    local last=math.min(total,first+page_size-1)
    for index=first,last do
        local group=groups[index]
        local summary={}
        for ignored_index,status in ipairs({"running","queued","paused","completed","failed","cancelled"}) do
            if group[status]>0 then summary[#summary+1]=_(status:gsub("^%l",string.upper)).." "..group[status] end
        end
        local current=group
        items[#items+1]={
            text=current.manga.title or current.manga_id,
            icon=path.."images/menu/downloads.svg",
            maru_title=current.manga.title or current.manga_id,
            maru_meta=table.concat(summary," · "),
            action=function() self:showMangaDownloads(current.source_id,current.manga_id,1) end,
            hold_callback=function() self:showMangaDownloadActions(current,page) end,
        }
    end
    if total==0 then items[1]={text=_("No downloads")} end
    if page>1 then items[#items+1]={text=_("Previous page"),icon=path.."images/menu/back.svg",action=function() self:showDownloads(page-1) end} end
    if page<page_count then items[#items+1]={text=_("Next page"),icon=path.."images/menu/next-page.svg",action=function() self:showDownloads(page+1) end} end
    self.download_menu=self:menu(_("Downloads").." · ".._("Page ")..page.." / "..page_count,items,nil,false,true,{
        header_action={icon=path.."images/menu/refresh.svg",callback=function() self:showDownloads(page) end},
    })
end
function MaruManga:showMangaDownloadActions(group,page)
    local has_pending=group.running+group.queued+group.paused>0
    local items={}
    if group.running+group.queued>0 then
        items[#items+1]={text=_("Pause All"),icon=path.."images/menu/pause.svg",action=function()
            local count=self.downloads:pauseManga(group.source_id,group.manga_id)
            self:notice(_("Paused chapters: ")..count)
            self:showMangaDownloads(group.source_id,group.manga_id,1,true)
        end}
    end
    if group.paused>0 then
        items[#items+1]={text=_("Continue All"),icon=path.."images/menu/next-page.svg",action=function()
            local count=self.downloads:resumeManga(group.source_id,group.manga_id)
            self:notice(_("Continued chapters: ")..count)
            self:showMangaDownloads(group.source_id,group.manga_id,1,true)
        end}
    end
    if has_pending then
        items[#items+1]={text=_("Cancel All"),icon=path.."images/menu/close.svg",action=function()
            show(ConfirmBox:new{text=_("Cancel all pending chapter downloads for this manga? Completed chapters and the manga CBZ will be kept."),ok_text=_("Cancel All"),ok_callback=function()
                local count=self.downloads:cancelManga(group.source_id,group.manga_id)
                self:notice(_("Cancelled chapters: ")..count)
                self:showMangaDownloads(group.source_id,group.manga_id,1,true)
            end})
        end}
    end
    if #items==0 then items[1]={text=_("No pending downloads")} end
    self:menu(group.manga.title or group.manga_id,items)
end
function MaruManga:showMangaDownloads(source_id,manga_id,page,replace_page)
    if not self.downloads then return self:notice(self.download_error) end
    local entries,manga={},nil
    for _,item in ipairs(self.downloads.state.items) do
        if item.manga.source_id==source_id and item.manga.id==manga_id then
            manga=manga or item.manga
            entries[#entries+1]=item
        end
    end
    if not manga then return self:showDownloads() end
    local page_size=8
    local total=#entries
    local page_count=math.max(1,math.ceil(total/page_size))
    page=math.max(1,math.min(math.floor(tonumber(page) or 1),page_count))
    local items={}
    local Device=require("device")
    local Screen=Device.screen
    local ProgressWidget=require("ui/widget/progresswidget")
    local VerticalGroup=require("ui/widget/verticalgroup")
    local TextWidget=require("ui/widget/textwidget")
    local Font=require("ui/font")
    local CenterContainer=require("ui/widget/container/centercontainer")
    local Geom=require("ui/geometry")
    local first=(page-1)*page_size+1
    local last=math.min(total,first+page_size-1)
    for index=first,last do
        local current=entries[index]
        local row={text=current.chapter.name or current.chapter.id,icon=path.."images/menu/chapter.svg",action=function()
            local choices={}
            if current.status=="failed" or current.status=="cancelled" then
                choices[#choices+1]={text=_("Retry"),icon=path.."images/menu/refresh.svg",action=function() local ok,err=self.downloads:retry(current); self:notice(ok and _("Queued") or err); self:showMangaDownloads(source_id,manga_id,page,true) end}
                choices[#choices+1]={text=_("Clear incomplete files"),icon=path.."images/menu/delete.svg",action=function()
                    show(ConfirmBox:new{text=_("Remove incomplete files for this chapter?"),ok_text=_("Remove"),ok_callback=function()
                        local active=self.downloads.active
                        if active and active.manga.source_id==source_id and active.manga.id==manga_id and active.chapter.id==current.chapter.id then return self:notice(_("This chapter is in use")) end
                        local fs=self:filesystem(); local ok,err=fs.cleanupTemporary(source_id,manga_id,current.chapter.id)
                        self:notice(ok and _("Incomplete files removed") or err)
                    end})
                end}
            elseif current.status=="paused" or (current.status=="running" and current.pause_requested) then
                choices[#choices+1]={text=_("Continue"),icon=path.."images/menu/next-page.svg",action=function()
                    local ok,err=self.downloads:resume(current)
                    self:notice(ok and _("Download resumed") or err)
                    self:showMangaDownloads(source_id,manga_id,page,true)
                end}
                choices[#choices+1]={text=_("Cancel"),icon=path.."images/menu/close.svg",action=function() local ok,err=self.downloads:cancel(current); self:notice(ok and _("Cancellation requested") or err); self:showMangaDownloads(source_id,manga_id,page,true) end}
            elseif current.status=="queued" or current.status=="running" then
                choices[#choices+1]={text=_("Cancel"),icon=path.."images/menu/close.svg",action=function() local ok,err=self.downloads:cancel(current); self:notice(ok and _("Cancellation requested") or err); self:showMangaDownloads(source_id,manga_id,page,true) end}
            elseif current.status=="completed" then
                choices[#choices+1]={text=_("Open downloaded file"),icon=path.."images/menu/book.svg",action=function() self:openDownloaded(current.manga,current.chapter) end}
                choices[#choices+1]={text=_("Verify downloaded file"),icon=path.."images/menu/verify.svg",action=function() self:verifyDownload(current.manga,current.chapter) end}
                choices[#choices+1]={text=_("Delete manga CBZ (all chapters)"),icon=path.."images/menu/delete.svg",action=function()
                    show(ConfirmBox:new{text=_("Delete the manga's combined CBZ and all chapters inside it?"),ok_text=_("Delete"),ok_callback=function()
                        local active=self.downloads.active
                        if active and active.manga.source_id==source_id and active.manga.id==manga_id then return self:notice(_("This manga archive is in use")) end
                        local fs=self:filesystem(); local target=self.library:archiveFor(source_id,manga_id,current.chapter.id); local err
                        if not target then target,err=fs.targetFor(source_id,manga_id,current.chapter.id) end
                        if not target then return self:notice(err) end
                        local removed,why=os.remove(target); if not removed then return self:notice(why or _("Could not delete manga CBZ")) end
                        local ok,save_error=self.library:unlinkArchive(target); if not ok then return self:notice(save_error) end
                        for i=#self.downloads.state.items,1,-1 do local queued=self.downloads.state.items[i]; if queued.status=="completed" and queued.manga.source_id==source_id and queued.manga.id==manga_id then self.downloads:remove(queued) end end
                        self:notice(_("Manga CBZ deleted")); self:showDownloads()
                    end})
                end}
            end
            if current.status~="running" and current.status~="queued" then
                choices[#choices+1]={text=_("Remove from list"),icon=path.."images/menu/delete.svg",action=function() local ok,err=self.downloads:remove(current); self:notice(ok and _("Removed") or err); self:showMangaDownloads(source_id,manga_id,page,true) end}
            end
            if current.error then choices[#choices+1]={text=current.error} end
            if #choices>0 then self:menu(current.chapter.name or current.chapter.id,choices) end
        end}
        if current.status=="queued" or current.status=="running" or current.status=="paused" then
            local width=Screen:scaleBySize(86)
            local pages=tonumber(current.total) or 0
            local fraction=pages>0 and math.max(0,math.min((current.current or 0)/pages,1)) or 0
            local progress_bar=ProgressWidget:new{width=width,height=Screen:scaleBySize(12),percentage=fraction,radius=Screen:scaleBySize(3)}
            local percent=current.status=="paused" and _("Paused") or pages>0 and (_("Running").." "..math.floor(fraction*100).."%") or current.status=="queued" and _("Queued") or _("Preparing")
            local progress_label=TextWidget:new{text=percent,face=Font:getFace("infont",16)}
            self.download_widgets=self.download_widgets or setmetatable({}, {__mode="k"})
            self.download_widgets[current]={bar=progress_bar,label=progress_label,progress_step=math.floor(fraction*20)}
            row.state=CenterContainer:new{dimen=Geom:new{w=Screen:scaleBySize(98),h=Screen:scaleBySize(42)},VerticalGroup:new{align="center",progress_bar,progress_label}}
            row.maru_state_width=Screen:scaleBySize(102)
        end
        items[#items+1]=row
    end
    if total==0 then items[1]={text=_("No queued chapters")} end
    if page>1 then items[#items+1]={text=_("Previous page"),icon=path.."images/menu/back.svg",action=function() self:showMangaDownloads(source_id,manga_id,page-1,true) end} end
    if page<page_count then items[#items+1]={text=_("Next page"),icon=path.."images/menu/next-page.svg",action=function() self:showMangaDownloads(source_id,manga_id,page+1,true) end} end
    self:menu((manga.title or manga_id).." · ".._("Page ")..page.." / "..page_count,items,nil,false,replace_page==true,{
        header_action={icon=path.."images/menu/refresh.svg",callback=function() self:showMangaDownloads(source_id,manga_id,page,true) end},
    })
end
function MaruManga:showUpdates()
    if not self.library then return self:notice(self.library_error) end
    local list=self.library:list()
    if #list==0 then return self:notice(_("Library is empty")) end
    local loading=loadingMessage(_("Checking library manga…"))
    show(loading)
    UIManager:nextTick(function()
        local fs=self:filesystem()
        local by_manga={}; for ignored_index,manga in ipairs(list) do by_manga[manga.source_id..":"..manga.id]=manga end
        local scans={}; local incomplete_entries={}; local unindexed_entries={}
        for archive_path,metadata in pairs(self.library.data.archives) do
            local manga=type(metadata)=="table" and metadata.manga
            if type(manga)=="table" and by_manga[tostring(manga.source_id)..":"..tostring(manga.id)] then
                local archived=self.library:chaptersInArchive(archive_path)
                for _,chapter in ipairs(archived) do
                    if self.library:archiveFor(manga.source_id,manga.id,chapter.id)==archive_path then
                        local cached=self.library:chapterStatus(manga.source_id,chapter.id)
                        local details=cached and cached.metadata or chapter
                        scans[#scans+1]={path=archive_path,sha256=metadata.sha256,source_id=manga.source_id,chapter_id=chapter.id,manga=by_manga[manga.source_id..":"..manga.id],chapter={id=chapter.id,manga_id=manga.id,name=chapter.name,url=details.url,chapter_number=details.chapter_number,scanlator=details.scanlator,upload_date=details.upload_date}}
                    end
                end
            end
        end
        self:runner().run(function()
            local lfs=require("libs/libkoreader-lfs")
            return ArchiveScan.run(scans,function(file) return FileDigest.hash(file,require("ffi/sha2").sha256) end,function(file) return lfs.attributes(file,"mode")=="file" end)
        end,3600,function(scan_ok,integrity,ignored_scan_error,scan_error)
        if not scan_ok or type(integrity)~="table" then UIManager:close(loading); return self:notice(scan_error or _("Could not verify local downloads")) end
        for ignored_index,entry in ipairs(scans) do
            if integrity[entry.source_id..":"..entry.chapter_id]=="incomplete" then incomplete_entries[entry.source_id..":"..entry.chapter_id]=entry end
        end
        Updates.fetch(list,function(id)
            if id~="mangadex" then local profile=self:profile(id); if not profile or profile.enabled==false then return nil end end
            return self:source(id)
        end,function(result,err)
            UIManager:close(loading)
            if not result then return self:notice(err) end
            local items={{text=_("Not downloaded: ") .. #result.items}}
            local damaged,unverified,unreadable={},0,0
            for ignored_index,entry in ipairs(scans) do
                local state=integrity[entry.source_id..":"..entry.chapter_id]
                if state=="modified" then damaged[#damaged+1]=entry
                elseif state=="unverified" then unverified=unverified+1
                elseif state=="error" then unreadable=unreadable+1 end
            end
            if #damaged>0 then items[#items+1]={text=_("Changed downloads: ") .. #damaged,action=function()
                local choices={}
                for ignored_index,entry in ipairs(damaged) do local item=entry; choices[#choices+1]={text=item.manga.title .. " / " .. (item.chapter.name or item.chapter.id),action=function() self:verifyDownload(item.manga,item.chapter) end} end
                self:menu(_("Changed downloads"),choices)
            end} end
            if unverified>0 then items[#items+1]={text=_("Older downloads without a hash: ") .. unverified,action=function()
                local choices={}
                for ignored_index,entry in ipairs(scans) do
                    local item=entry
                    if integrity[item.source_id..":"..item.chapter_id]=="unverified" then choices[#choices+1]={text=item.manga.title .. " / " .. (item.chapter.name or item.chapter.id),action=function() self:verifyDownload(item.manga,item.chapter) end} end
                end
                self:menu(_("Unverified downloads"),choices)
            end} end
            local unindexed={}; for ignored_key,entry in pairs(unindexed_entries) do unindexed[#unindexed+1]=entry end
            if #unindexed>0 then items[#items+1]={text=_("Unindexed downloads: ") .. #unindexed,action=function()
                local choices={}
                for ignored_index,entry in ipairs(unindexed) do local item=entry; choices[#choices+1]={text=item.manga.title .. " / " .. item.chapter.name,action=function() self:setArchiveBaseline(item.path,item.manga,item.chapter) end} end
                self:menu(_("Unindexed downloads"),choices)
            end} end
            if unreadable>0 then items[#items+1]={text=_("Downloads that could not be checked: ") .. unreadable} end
            local incomplete={}; for ignored_key,entry in pairs(incomplete_entries) do incomplete[#incomplete+1]=entry end
            if #incomplete>0 then items[#items+1]={text=_("Incomplete downloads: ") .. #incomplete,action=function()
                local choices={}
                for ignored_index,entry in ipairs(incomplete) do
                    local item=entry
                    choices[#choices+1]={text=item.manga.title .. " / " .. (item.chapter.name or item.chapter.id),action=function()
                        show(ConfirmBox:new{text=_("Remove incomplete files for this chapter?"),ok_text=_("Remove"),ok_callback=function()
                            local active=false
                            for queued in pairs(self.downloads and self.downloads.active_items or {}) do if queued.manga.source_id==item.manga.source_id and queued.chapter.id==item.chapter.id then active=true; break end end
                            if active then return self:notice(_("This chapter is in use")) end
                            local ok,why=fs.cleanupTemporary(item.manga.source_id,item.manga.id,item.chapter.id)
                            self:notice(ok and _("Incomplete files removed") or why)
                        end})
                    end}
                end
                self:menu(_("Incomplete downloads"),choices)
            end} end
            if #result.errors>0 then items[#items+1]={text=_("Titles with errors: ") .. #result.errors,action=function() self:notice(table.concat(result.errors,"\n")) end} end
            if #result.items>0 then
                items[#items+1]={text=_("Download all missing chapters"),action=function()
                    if not self.downloads then return self:notice(self.download_error) end
                    local pending,skipped={},0
                    for ignored_index,entry in ipairs(result.items) do
                        local existing,downloaded=LocalArchive.resolve(self.library,fs,entry.manga,entry.chapter)
                        if downloaded and existing and fs.exists(existing) then skipped=skipped+1 else pending[#pending+1]=entry end
                    end
                    local added,duplicates=self.downloads:addMany(pending)
                    if not added then return self:notice(duplicates) end
                    self:notice(_("Queued: ") .. added .. " / " .. _("Skipped: ") .. (skipped+duplicates))
                end}
            end
            for ignored_index,manga in ipairs(list) do
                local title=manga
                local count=result.counts[title.source_id..":"..title.id] or 0
                if count>0 then
                    items[#items+1]={text=title.title .. " · " .. count,action=function()
                        local chapters={}
                        for ignored_index,entry in ipairs(result.items) do
                            local item=entry
                            if item.manga.id==title.id and item.manga.source_id==title.source_id then
                                chapters[#chapters+1]={text=item.chapter.name,action=function() self:queueChapter(item.manga,item.chapter) end}
                            end
                        end
                        self:menu(title.title,chapters)
                    end}
                end
            end
            self:menu(_("Library updates"),items)
        end,{
            is_downloaded=function(manga,chapter)
                local file,indexed=LocalArchive.resolve(self.library,fs,manga,chapter)
                if file and fs.exists(file..".incomplete") then
                    incomplete_entries[manga.source_id..":"..chapter.id]={manga=manga,chapter=chapter}
                    return false
                end
                if file and not indexed and fs.exists(file) and not (self.library.data.archives and self.library.data.archives[file]) then
                    unindexed_entries[manga.source_id..":"..chapter.id]={path=file,manga=manga,chapter=chapter}
                end
                if not file or not fs.exists(file) then return false end
                return indexed or not (self.library.data.archives and self.library.data.archives[file])
            end,
            save_chapters=function(manga,chapters) return self.library:cacheChapters(manga,chapters) end,
            mark_synced=function(manga,count,missing_count,latest_number) return self.library:markChaptersSynced(manga,count,nil,missing_count,latest_number) end,
        })
        end)
    end)
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
    show(dialog); dialog:onShowKeyboard()
end
local function saveNetworkConfig(plugin,values)
    local config=plugin.config.data
    local old={config.timeout,config.retries,config.user_agent,config.download_dir,config.download_concurrency,config.ignore_ssl_certificates}
    local download_dir=config.download_dir or ""
    local ignore_ssl=config.ignore_ssl_certificates==true
    if values.download_dir~=nil then download_dir=values.download_dir end
    if values.ignore_ssl_certificates~=nil then ignore_ssl=values.ignore_ssl_certificates end
    local ok,err=plugin.config:setNetwork(
        values.timeout or config.timeout,values.retries or config.retries,values.user_agent or config.user_agent,
        download_dir,
        values.download_concurrency or config.download_concurrency or 2,
        ignore_ssl
    )
    if not ok then return nil,err end
    ok,err=plugin.config:save()
    if not ok then
        config.timeout,config.retries,config.user_agent,config.download_dir,config.download_concurrency,config.ignore_ssl_certificates=unpack(old)
        return nil,err
    end
    plugin.manga_sources=nil
    return true
end
function MaruManga:networkValuesSettings()
    if not self.config then return self:notice(self.config_error) end
    local config=self.config.data
    local dialog
    local ignore_ssl_checkbox
    dialog=MultiInputDialog:new{title=_("Network"),fields={
        {text=tostring(config.timeout),hint=_("Timeout in seconds")},
        {text=tostring(config.retries),hint=_("Maximum attempts")},
        {text=config.user_agent,hint=_("User agent")},
    },buttons={{{text=_("Cancel"),callback=function() UIManager:close(dialog) end},{text=_("Save"),callback=function()
        local fields=dialog:getFields()
        local ok,err=saveNetworkConfig(self,{timeout=fields[1],retries=fields[2],user_agent=fields[3],ignore_ssl_certificates=ignore_ssl_checkbox.checked})
        if not ok then return self:notice(err) end
        UIManager:close(dialog); self:notice(_("Network settings saved"))
    end}}}}
    local CheckButton=require("ui/widget/checkbutton")
    ignore_ssl_checkbox=CheckButton:new{
        text=_("Ignore SSL certificate validation (less secure)"),
        checked=config.ignore_ssl_certificates==true,parent=dialog,
        hold_callback=function() self:notice(_("This skips certificate authority and hostname checks. Requests still require HTTPS and an allowed source host. Use only on a trusted network.")) end,
    }
    dialog:addWidget(ignore_ssl_checkbox)
    show(dialog); dialog:onShowKeyboard()
end
function MaruManga:networkSettings(replace_page)
    if not self.config then return self:notice(self.config_error) end
    local mode=self.config.data.dns_mode or "auto"
    local labels={auto=_("Auto"),google=_("Google"),cloudflare=_("Cloudflare"),other=_("Other")}
    self:menu(_("Network"),{
        {text=_("Connection settings"),action=function() self:networkValuesSettings() end},
        {text=_("DNS resolver: ")..(labels[mode] or labels.auto),maru_icon="source",action=function() self:dnsSettings() end},
    },nil,nil,replace_page)
end
function MaruManga:downloadSettings(replace_page)
    if not self.config then return self:notice(self.config_error) end
    self:menu(_("Download"),{
        {text=_("Concurrent downloads: ")..tostring(self.config.data.download_concurrency or 2),action=function()
            local dialog
            dialog=InputDialog:new{title=_("Concurrent downloads (1–5)"),input=tostring(self.config.data.download_concurrency or 2),buttons={{{text=_("Cancel"),callback=function() UIManager:close(dialog) end},{text=_("Save"),callback=function()
                local ok,err=saveNetworkConfig(self,{download_concurrency=dialog:getInputText()})
                if not ok then return self:notice(err) end
                UIManager:close(dialog); self:menu(_("Download"),{{text=_("Concurrent downloads: ")..tostring(self.config.data.download_concurrency),action=function() self:downloadSettings(true) end}},nil,nil,true)
            end}}}}
            show(dialog); dialog:onShowKeyboard()
        end},
    },nil,nil,replace_page)
end
function MaruManga:storageSettings(replace_page)
    if not self.config then return self:notice(self.config_error) end
    local default_path=DataStorage:getFullDataDir().."/marumanga"
    local current_path=self:downloadRoot()
    local items={
        {maru_key=_("Folder"),maru_value=current_path},
        {text=_("Choose folder"),maru_icon="folder",action=function() self:chooseDownloadFolder() end},
    }
    if self.config.data.download_dir then
        items[#items+1]={text=_("Restore default folder"),action=function()
            local ok,err=saveNetworkConfig(self,{download_dir=""})
            if not ok then return self:notice(err) end
            self:storageSettings(true)
        end}
    end
    self:menu(_("Storage"),items,nil,nil,replace_page)
end
function MaruManga:chooseDownloadFolder()
    if not self.config then return self:notice(self.config_error) end
    local lfs=require("libs/libkoreader-lfs")
    local selected=self:downloadRoot()
    local start=selected
    while start and start~="/" and lfs.attributes(start,"mode")~="directory" do
        start=start:match("^(.*)/[^/]+$")
    end
    if not start or lfs.attributes(start,"mode")~="directory" then start="/" end
    local chooser=require("ui/widget/pathchooser"):new{
        path=start,select_directory=true,select_file=false,show_files=false,
        title=_("Choose download folder"),
        onConfirm=function(folder)
            local ok,err=saveNetworkConfig(self,{download_dir=folder})
            if not ok then return self:notice(err) end
            self:storageSettings(true)
        end,
    }
    show(chooser)
end
function MaruManga:dnsSettings()
    if not self.config then return self:notice(self.config_error) end
    local modes={
        {id="auto",label=_("Auto (device DNS)")},
        {id="google",label=_("Google DNS (8.8.8.8)")},
        {id="cloudflare",label=_("Cloudflare DNS (1.1.1.1)")},
        {id="other",label=_("Other DNS server…")},
    }
    local items={}
    for _,entry in ipairs(modes) do
        local selected=entry
        local icons={auto="toggle",google="source",cloudflare="filter",other="edit"}
        items[#items+1]={text=selected.label..(self.config.data.dns_mode==selected.id and "  ✓" or ""),maru_icon=icons[selected.id],action=function()
            local function save(server)
                local old_mode,old_server=self.config.data.dns_mode,self.config.data.dns_server
                local ok,err=self.config:setDns(selected.id,server)
                if not ok then return self:notice(err) end
                ok,err=self.config:save()
                if not ok then self.config.data.dns_mode,self.config.data.dns_server=old_mode,old_server; return self:notice(err) end
                if self.panel_enabled and self.main_menu then self.main_menu:goBack(); self:networkSettings(true) else self:notice(_("DNS setting saved")) end
            end
            if selected.id=="other" then
                local dialog
                dialog=InputDialog:new{title=_("Manual DNS IPv4 address"),input=self.config.data.dns_server or "",buttons={{{text=_("Cancel"),callback=function() UIManager:close(dialog) end},{text=_("Save"),callback=function()
                    local server=dialog:getInputText()
                    local old_mode,old_server=self.config.data.dns_mode,self.config.data.dns_server
                    local ok,err=self.config:setDns("other",server)
                    if not ok then return self:notice(err) end
                    ok,err=self.config:save()
                    if not ok then self.config.data.dns_mode,self.config.data.dns_server=old_mode,old_server; return self:notice(err) end
                    UIManager:close(dialog); self:networkSettings(true)
                end}}}}
                show(dialog); dialog:onShowKeyboard()
            else save() end
        end}
    end
    self:menu(_("DNS resolver"),items)
end
function MaruManga:openSettings()
    self:menu(_("Settings"),{
        {text=_("Chapter language"),action=function() self:settings() end},
        {text=_("Network"),group_end=true,action=function() self:networkSettings() end},
        {text=_("Download"),action=function() self:downloadSettings() end},
        {text=_("Storage"),maru_icon="folder",group_end=true,action=function() self:storageSettings() end},
        {text=_("Uninstall"),action=function() self:confirmUninstall() end},
    })
end
function MaruManga:confirmUninstall()
    if self.downloads then
        for _,item in ipairs(self.downloads.state and self.downloads.state.items or {}) do
            if item.status=="running" then
                return self:notice(_("Wait for active downloads to finish before uninstalling."))
            end
        end
    end
    show(ConfirmBox:new{
        text=_("Uninstall MaruManga Downloader from KOReader? You can choose whether to keep its library and downloaded files in the next step."),
        ok_text=_("Uninstall"),cancel_text=_("Cancel"),
        ok_callback=function() self:chooseUninstallData() end,
    })
end
function MaruManga:chooseUninstallData()
    local TextBoxWidget=require("ui/widget/textboxwidget")
    local Screen=require("device").screen
    local dialog
    dialog=ButtonDialog:new{
        title=_("Uninstall MaruManga Downloader"),
        _added_widgets={TextBoxWidget:new{
            text=_("Keep data preserves the library, settings, cache, and downloaded manga. Uninstall removes MaruManga's settings and its manga and cache folders."),
            width=math.floor(Screen:getWidth()*0.76),padding=0,
        }},
        dismissable=false,
        buttons={
            {{text=_("Cancel"),callback=function() UIManager:close(dialog) end}},
            {{text=_("Keep data"),callback=function() UIManager:close(dialog); self:runUninstall(false) end}},
            {{text=_("Uninstall"),callback=function() UIManager:close(dialog); self:runUninstall(true) end}},
        },
    }
    show(dialog)
end
function MaruManga:runUninstall(remove_data)
    local loading=loadingMessage(remove_data and _("Removing MaruManga and its data…") or _("Removing MaruManga…"))
    show(loading)
    local loading_open=true
    local function finish(ok,result,why,runner_error)
        if loading_open then loading_open=false; UIManager:close(loading) end
        if not ok then return self:notice(result or why or runner_error or _("Could not uninstall MaruManga Downloader")) end
        self:notice(remove_data and _("MaruManga and its data were removed. Restart KOReader to finish uninstalling.") or _("MaruManga was removed. Its data was kept. Restart KOReader to finish uninstalling."))
        UIManager:askForRestart()
    end
    local plugin_dir=path:gsub("[/\\]+$","")
    local settings_path=DataStorage:getSettingsDir().."/marumanga.lua"
    local download_root=self:downloadRoot()
    local started,err=pcall(function()
        self:runner().run(function()
            return Uninstaller.uninstall({
                lfs=require("libs/libkoreader-lfs"),plugin_path=plugin_dir,
                remove_data=remove_data,settings_path=settings_path,download_root=download_root,
            })
        end,600,finish)
    end)
    if not started then finish(false,nil,nil,tostring(err)) end
end
function MaruManga:about()
    self:menu(_("About"),{
        {text=_("Version: ")..PLUGIN_VERSION,icon=path .. "images/menu/details.svg"},
        {text=_("Author: MRHRTZ"),icon=path .. "images/menu/source.svg"},
        {text=_("Last Update: ")..PLUGIN_LAST_UPDATE.." "..os.date("%H:%M"),icon=path .. "images/menu/clock.svg",group_end=true},
        {text=_("Check for updates"),icon=path .. "images/menu/refresh.svg",action=function() self:checkPluginUpdates() end},
    })
end
function MaruManga:checkPluginUpdates()
    local url="https://raw.githubusercontent.com/MRHRTZ/MaruManga.koplugin/main/release.json"
    local loading=loadingMessage(_("Checking for plugin updates…")); show(loading)
    local transport=Transport.new(UIManager,require("ui/trapper"),require("json"),Client,SecureRequest,function()
        local deps=applyDNS(networkDependencies(),self.config and self.config.data)
        deps.timeout=self.config and self.config.data.timeout or 20
        deps.user_agent="MaruMangaDownloader/"..PLUGIN_VERSION.." (KOReader)"
        deps.ignore_ssl_certificates=self.config and self.config.data.ignore_ssl_certificates==true
        deps.allowed_hosts={["raw.githubusercontent.com"]=true}
        deps.headers={Accept="application/json"}
        return deps
    end,{accept_url=function(candidate) return candidate==url end,max_attempts=1,runner=self:runner(),deadline=(self.config and self.config.data.timeout or 20)+10})
    transport:get(url,function(release,err)
        UIManager:close(loading)
        if not release then
            if err=="HTTP 404" then return self:notice(_("Could not find release.json on the update server.")) end
            return self:notice(_("Could not check for plugin updates: ")..tostring(err or _("network error")))
        end
        local latest=type(release.version)=="string" and release.version:gsub("^[vV]","")
        if not latest or latest=="" then return self:notice(_("The latest release has no version tag.")) end
        if PluginUpdater.isNewer(PLUGIN_VERSION,latest) then
            local download=type(release.download_url)=="string" and release.download_url or nil
            local host=download and PluginUpdater.validateURL(download)
            if not host then return self:notice(_("A newer version was found, but its download URL is invalid.")) end
            show(ConfirmBox:new{
                text=_("Version ")..latest.._(" is available. Installed version: ")..PLUGIN_VERSION..".\n\n".._("Download and install the update now?"),
                ok_text=_("Update now"),cancel_text=_("Cancel"),
                ok_callback=function() self:installPluginUpdate(download,latest,release.sha256) end,
            })
        else
            self:notice(_("MaruManga Downloader is up to date.").." ("..PLUGIN_VERSION..")")
        end
    end)
end
function MaruManga:installPluginUpdate(download_url,version,sha256)
    local loading=loadingMessage(_("Downloading and installing update…")); show(loading)
    local loading_open=true
    local function finish(ok,result,runner_error)
        if loading_open then loading_open=false; UIManager:close(loading) end
        if not ok then return self:notice(result or runner_error or _("Could not install the update")) end
        self:notice(_("Update installed: ")..version..". ".._("Restart KOReader to finish updating."))
        UIManager:askForRestart()
    end
    local plugin_dir=path:gsub("[/\\]+$","")
    local runner=self:runner()
    local started,err=pcall(function()
        runner.run(function()
            local config=self.config and self.config.data or {}
            return PluginUpdater.downloadAndInstall({
                url=download_url,version=version,sha256=sha256,plugin_path=plugin_dir,
                secure_request=SecureRequest,archiver=require("ffi/archiver"),
                lfs=require("libs/libkoreader-lfs"),util=require("util"),
                dependencies=function()
                    local deps=applyDNS(networkDependencies(),config)
                    deps.timeout=config.timeout or 25
                    deps.user_agent="MaruMangaDownloader/"..PLUGIN_VERSION.." (KOReader update)"
                    deps.ignore_ssl_certificates=config.ignore_ssl_certificates==true
                    return deps
                end,
                digest=function(file) return FileDigest.hash(file,require("ffi/sha2").sha256) end,
            })
        end,240,finish)
    end)
    if not started then finish(false,tostring(err)) end
end
function MaruManga:manageDiscoverSources()
    if not self.config then return self:notice(self.config_error) end
    local installed=self.config.data.profiles or {}
    if #installed==0 then return self:notice(_("No installed sources")) end
    local drafts={}
    for _,profile in ipairs(installed) do drafts[profile.id]=profile.enabled~=false end
    local page_size=10
    local page_count=math.max(1,math.ceil(#installed/page_size))
    local function finish(save)
        if save then
        local previous={}
        local enabled_count=0
        for _,profile in ipairs(installed) do
            previous[profile]=profile.enabled
            profile.enabled=drafts[profile.id]==true
            if profile.enabled then enabled_count=enabled_count+1 end
        end
        local old_source=self.config.data.source
        if old_source then
            local current=self:profile(old_source)
            if current and current.enabled==false then
                self.config.data.source=nil
                for _,profile in ipairs(installed) do if profile.enabled then self.config.data.source=profile.id; break end end
            end
        end
        local ok,err=self.config:save()
        if not ok then
            for profile,enabled in pairs(previous) do profile.enabled=enabled end
            self.config.data.source=old_source
            return self:notice(err or _("Could not save source settings"))
        end
        self.manga_sources=nil
        self:notice(enabled_count==0 and _("No sources are enabled") or _("Source settings saved"))
    end
        if self.panel_enabled and self.main_menu then self.main_menu:goBack() else self:openDiscover() end
    end
    local function render(page,replace_page)
        page=math.max(1,math.min(page_count,tonumber(page) or 1))
        local items={}
        local first=(page-1)*page_size+1
        local last=math.min(#installed,page*page_size)
        for index=first,last do
            local profile=installed[index]
            items[#items+1]={text=(profile.name or profile.id).."  ("..profile.id..")",icon=path.."images/menu/"..(drafts[profile.id] and "check-on" or "check-off")..".svg",action=function()
                drafts[profile.id]=not drafts[profile.id]
                render(page,true)
            end}
        end
        if page>1 then items[#items+1]={text=_("Previous page"),icon=path.."images/menu/back.svg",action=function() render(page-1,true) end} end
        if page<page_count then items[#items+1]={text=_("Next page"),icon=path.."images/menu/next.svg",action=function() render(page+1,true) end} end
        items[#items+1]={text=_("Save"),icon=path.."images/menu/save.svg",group_end=true,action=function() finish(true) end}
        items[#items+1]={text=_("Cancel"),icon=path.."images/menu/close.svg",action=function() finish(false) end}
        self:menu(_("Manage Sources · Page ")..page.." / "..page_count,items,nil,false,replace_page,{page_limit=page_size+4})
    end
    render(1,false)
end
function MaruManga:withDiscoverSource(label,callback,all_callback,replace_page)
    local sources={}
    for _,profile in ipairs(self.config.data.profiles or {}) do
        if profile.enabled~=false then sources[#sources+1]=profile end
    end
    if #sources==0 then return self:notice(_("No enabled sources are installed. Use Manage Sources to enable one.")) end
    local choices,icons_to_load={},{}
    if all_callback then choices[#choices+1]={text=_("All Manga"),action=all_callback} end
    if #sources==1 and not all_callback then return callback(sources[1].id) end
    for _,entry in ipairs(sources) do
        local source=entry
        local label=source.name or source.id
        if type(source.languages)=="table" and #source.languages>0 then label=label.." "..languageLabel(source.languages) end
        local nsfw=source.nsfw==true
        if not nsfw and self.repositories then
            for _,repo in ipairs(self.repositories:list()) do
                for _,catalog_entry in ipairs(repositorySources(repo)) do
                    if catalog_entry.id==source.id then nsfw=catalog_entry.nsfw==true; break end
                end
                if nsfw then break end
            end
        end
        if nsfw then label=label.." [NSFW]" end
        local row={text=label,action=function() callback(source.id) end}
        local icon_file=bundledSourceIcon(source) or self:findCachedSourceIcon(source)
        if icon_file then
            local Screen=require("device").screen
            local ImageWidget=require("ui/widget/imagewidget")
            local ok,widget=pcall(ImageWidget.new,ImageWidget,{file=icon_file,width=Screen:scaleBySize(34),height=Screen:scaleBySize(34),alpha=true,scale_factor=0})
            if ok then row.state=widget end
        elseif sourceIconUrl(source) then
            icons_to_load[#icons_to_load+1]=source
        end
        choices[#choices+1]=row
    end
    local title=label.." · ".._("Sources")
    local menu=self:menu(title,choices,nil,false,replace_page)
    if #icons_to_load>0 then
        local remaining,loaded=#icons_to_load,false
        local function on_icon(file)
            if file then loaded=true end
            remaining=remaining-1
            if remaining~=0 or not loaded then return end
            UIManager:nextTick(function()
                if self.panel_enabled and self.main_menu and self.main_menu.current_page and self.main_menu.current_page.title==title then
                    self:withDiscoverSource(label,callback,all_callback,true)
                elseif UIManager.isWidgetShown and UIManager:isWidgetShown(menu) then
                    UIManager:close(menu)
                    self:withDiscoverSource(label,callback,all_callback)
                end
            end)
        end
        for _,entry in ipairs(icons_to_load) do self:cacheSourceIcon(entry,on_icon) end
    end
end
function MaruManga:openDiscover(source_id)
    local function choose(label,callback,all_callback)
        if source_id then return callback(source_id) end
        return self:withDiscoverSource(label,callback,all_callback)
    end
    self:menu(_("Discover"),{
        {text=_("Search"),action=function() choose(_("Search"),function(id) self:search(id) end,function() self:search(nil) end) end},
        {text=_("Popular"),action=function() choose(_("Popular"),function(id) local source=self:source(id); if source then self:loadList(_("Popular"),function(p,cb) source:getPopularManga(p,cb) end,function(m) return m.title end) end end) end},
        {text=_("Latest updates"),action=function() choose(_("Latest updates"),function(id) local source=self:source(id); if source then self:loadList(_("Latest updates"),function(p,cb) source:getLatestUpdates(p,cb) end,function(m) return m.title end) end end) end},
        {text=_("Manage Sources"),maru_icon="source",group_end=true,action=function() self:manageDiscoverSources() end},
    })
end
function MaruManga:open()
    if self.downloads then self.downloads:run() end
    local function icon(name) return path .. "images/menu/" .. name .. ".svg" end
    local items={
        {text=_("Discover"),icon=icon("discover"),action=function() self:openDiscover() end},
        {text=_("Library"),icon=icon("library"),group_end=true,action=function() self:openLibrary() end},
        {text=_("Repositories"),icon=icon("repositories"),group_end=true,action=function() self:showRepositories() end},
        {text=_("Downloads"),icon=icon("downloads"),action=function() self:showDownloads() end},
        {text=_("Settings"),icon=icon("settings"),action=function() self:openSettings() end},
        {text=_("About"),icon=icon("details"),action=function() self:about() end},
    }
    self.panel_enabled=true
    if self.main_menu then
        self.main_menu:setPage(_("MaruManga Downloader"),items,{root=true,mascot=path.."images/maru-manga-reader.png",show=false})
        if not self.main_menu.visible then show(self.main_menu); self.main_menu.visible=true end
    else
        self.main_menu=MainMenu.new{
            title=_("MaruManga Downloader"),items=items,mascot=path.."images/maru-manga-reader.png",
            icon_dir=path .. "images/menu/",on_close=function() self.panel_enabled=false; if self.main_menu then self.main_menu.visible=false end end,
        }
        show(self.main_menu)
        self.main_menu.visible=true
    end
end
local function placeAtTopOfToolsOrder(item_id)
    local order_paths={"ui/elements/reader_menu_order","ui/elements/filemanager_menu_order"}
    local function contains(entries,wanted)
        if type(entries)~="table" then return false end
        for _,value in pairs(entries) do
            if value==wanted or type(value)=="table" and contains(value,wanted) then return true end
        end
        return false
    end
    for _,module_name in ipairs(order_paths) do
        local ok,order=pcall(require,module_name)
        if ok and type(order)=="table" and type(order.tools)=="table" and not contains(order.tools,item_id) then
            table.insert(order.tools,1,item_id)
        end
    end
end
function MaruManga:addToMainMenu(items)
    placeAtTopOfToolsOrder("marumanga")
    items.marumanga={text=_("MaruManga Downloader"), icon=path.."images/maru-manga-reader.png", sorting_hint="tools", callback=function() self:open() end}
end
return MaruManga
