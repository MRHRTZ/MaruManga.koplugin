-- Versioned settings stored through KOReader LuaSettings.
local Settings = {}
Settings.__index = Settings
local current = 3
local DEFAULT_REPOSITORY_URL = "https://raw.githubusercontent.com/MRHRTZ/maru-manga-repository/refs/heads/master/metadata.json"
local function defaultKomiku()
    return {id="komiku",name="Komiku",kind="komiku",base_url="https://komiku.org",api_url="https://api.komiku.org",languages={"id"},image_hosts={"thumbnail.komiku.to","thumbnail.komiku.org","img.komiku.org","image.komiku.org","update.komiku.org","komikid.org"},enabled=true,repository_url=DEFAULT_REPOSITORY_URL,repository_version=3}
end
local function defaults() return {version=current, language="en", source="komiku", profiles={defaultKomiku()}, auto_installed_source_ids={}, download_concurrency=2, ignore_ssl_certificates=false,dns_mode="auto",mangadex_installed=false,mangadex_enabled=false} end
local function valid_language(s) return type(s) == "string" and #s >= 2 and #s <= 12 and s:match("^[a-z][a-z%-]*$") end
local function valid_dns_server(server)
    if type(server)~="string" then return false end
    local count=0
    for part in server:gmatch("[^%.]+") do local n=tonumber(part); if not n or n<0 or n>255 or tostring(n)~=part then return false end; count=count+1 end
    return count==4
end
function Settings.open(store)
    assert(type(store) == "table")
    local raw = store:readSetting("marumanga")
    if raw == nil then raw = defaults() end
    if type(raw) ~= "table" then return nil, "Invalid settings data; original data was preserved" end
    local version = raw.version or 0
    if type(version) ~= "number" or version < 0 or version % 1 ~= 0 then return nil, "Invalid settings version; original data was preserved" end
    if version > current then return nil, "Settings are from a newer version; original data was preserved" end
    if raw.profiles ~= nil and type(raw.profiles) ~= "table" then return nil, "Invalid source profiles; original data was preserved" end
    -- The APK-backed adapter is MangaMost; release builds before 1.19 called
    -- it MangaGo. Migrate that exact saved profile in place so installed users
    -- keep its enabled state and repository provenance while MangaGo gets its
    -- separate website identity.
    if raw.profiles then
        for _,profile in ipairs(raw.profiles) do
            -- Earlier builds tagged the built-in Komiku profile with the
            -- sentinel "builtin", while repository management identifies
            -- the built-in catalog by its raw GitHub URL. Reconcile it so the
            -- installed source is represented under its repository.
            if type(profile)=="table" and profile.id=="komiku" and profile.repository_url=="builtin" then
                profile.repository_url=DEFAULT_REPOSITORY_URL
            end
            if type(profile)=="table" and profile.id=="mangago" and profile.base_url=="https://www.mangago.me" then
                profile.base_url="https://www.mangago.zone"
                profile.image_hosts={"www.mangago.zone","i1.mangapicgallery.com","i2.mangapicgallery.com","i4.mangapicgallery.com","i6.mangapicgallery.com","i8.mangapicgallery.com","i9.mangapicgallery.com","iweb12.mangapicgallery.com","pic1.mangapicgallery.com"}
            end
            if type(profile)=="table" and profile.id=="mangago" and profile.base_url=="https://mangamost.com" and profile.api_url=="https://mangamost.com/api/v1" then
                profile.id="mangamost"; profile.kind="mangamost"; profile.name="MangaMost"
                if raw.source=="mangago" then raw.source="mangamost" end
            end
        end
    end
    local seen={}
    for _, profile in ipairs(raw.profiles or {}) do
        if type(profile)~="table" or type(profile.id)~="string" or not profile.id:match("^[%w_-]+$") or profile.id=="mangadex" or seen[profile.id] or type(profile.name)~="string" or type(profile.base_url)~="string" or not profile.base_url:match("^https://[%w%.%-]+$") or (profile.image_hosts~=nil and type(profile.image_hosts)~="table") then return nil,"Invalid source profile; original data was preserved" end
        if profile.id=="komiku" and (profile.kind~="komiku" or profile.base_url~="https://komiku.org" or profile.api_url~="https://api.komiku.org") then return nil,"Invalid Komiku source profile; original data was preserved" end
        if profile.id=="mangamost" and (profile.kind~="mangamost" or profile.base_url~="https://mangamost.com" or profile.api_url~="https://mangamost.com/api/v1") then return nil,"Invalid MangaMost source profile; original data was preserved" end
        if profile.id=="mangago" and (profile.kind~="mangago" or profile.base_url~="https://www.mangago.zone") then return nil,"Invalid Mangago source profile; original data was preserved" end
        if (profile.id=="webtoon" or profile.id=="webtoon_id") and (profile.kind~="webtoon" or profile.base_url~="https://www.webtoons.com" or profile.locale~=(profile.id=="webtoon_id" and "id" or "en")) then return nil,"Invalid WEBTOON source profile; original data was preserved" end
        if profile.id=="westmanga" and (profile.kind~="westmanga" or profile.base_url~="https://www.westmanga.shop" or profile.api_url~="https://www.westmanga.shop/api/manga") then return nil,"Invalid WestManga source profile; original data was preserved" end
        seen[profile.id]=true
        for _,host in ipairs(profile.image_hosts or {}) do
            if type(host)~="string" or not host:match("^[%w%.%-]+$") then return nil,"Invalid image host; original data was preserved" end
            if profile.id=="komiku" and not ({["thumbnail.komiku.to"]=true,["thumbnail.komiku.org"]=true,["img.komiku.org"]=true,["image.komiku.org"]=true,["update.komiku.org"]=true,["komikid.org"]=true})[host] then return nil,"Unsupported Komiku image host; original data was preserved" end
            if profile.id=="mangamost" and host~="mangamost.com" then return nil,"Unsupported MangaMost image host; original data was preserved" end
            if profile.id=="mangago" and host~="www.mangago.zone" and not host:match("^i[124689]%.mangapicgallery%.com$") and host~="iweb12.mangapicgallery.com" and host~="pic1.mangapicgallery.com" then return nil,"Unsupported Mangago image host; original data was preserved" end
            if (profile.id=="webtoon" or profile.id=="webtoon_id") and host~="webtoon-phinf.pstatic.net" then return nil,"Unsupported WEBTOON image host; original data was preserved" end
            if profile.id=="westmanga" and host~="www.westmanga.shop" and host~="cdn.westmanga.shop" and host~="proxy.westmanga.shop" then return nil,"Unsupported WestManga image host; original data was preserved" end
        end
    end
    local dns_mode=({auto=true,google=true,cloudflare=true,other=true})[raw.dns_mode] and raw.dns_mode or "auto"
    local dns_server=valid_dns_server(raw.dns_server) and raw.dns_server or nil
    if dns_mode=="other" and not dns_server then dns_mode="auto" end
    local profiles=raw.profiles
    if profiles==nil then profiles={defaultKomiku()} end
    local selected_source=type(raw.source)=="string" and raw.source or "komiku"
    if selected_source=="mangadex" or selected_source=="" then selected_source="komiku" end
    local auto_installed_source_ids={}
    for _,id in ipairs(type(raw.auto_installed_source_ids)=="table" and raw.auto_installed_source_ids or {}) do
        if type(id)=="string" and id:match("^[%w_-]+$") and id~="mangadex" then auto_installed_source_ids[#auto_installed_source_ids+1]=id end
    end
    local result = {version=current, language=valid_language(raw.language) and raw.language or "en", source=selected_source, profiles=profiles, auto_installed_source_ids=auto_installed_source_ids, mangadex_installed=false, mangadex_enabled=false, timeout=type(raw.timeout)=="number" and raw.timeout>=5 and raw.timeout<=120 and raw.timeout or 15,
        retries=type(raw.retries)=="number" and raw.retries>=1 and raw.retries<=5 and raw.retries or 3,
        user_agent=type(raw.user_agent)=="string" and #raw.user_agent<=200 and not raw.user_agent:find("[%c]") and raw.user_agent or "MaruMangaDownloader/0.1 (KOReader)",
        download_dir=type(raw.download_dir)=="string" and raw.download_dir:match("^/") and not raw.download_dir:find("%.%.") and not raw.download_dir:find("[%c]") and raw.download_dir or nil,
        download_concurrency=type(raw.download_concurrency)=="number" and raw.download_concurrency>=1 and raw.download_concurrency<=5 and raw.download_concurrency%1==0 and raw.download_concurrency or 2,
        ignore_ssl_certificates=raw.ignore_ssl_certificates==true,
        dns_mode=dns_mode,dns_server=dns_server}
    return setmetatable({store=store, data=result}, Settings)
end
function Settings:setLanguage(language)
    if not valid_language(language) then return nil, "Invalid language" end
    self.data.language = language
    return true
end
function Settings:setNetwork(timeout,retries,user_agent,download_dir,download_concurrency,ignore_ssl_certificates)
    timeout,retries=tonumber(timeout),tonumber(retries)
    if not timeout or timeout<5 or timeout>120 or timeout%1~=0 then return nil,"Timeout must be 5–120 seconds" end
    if not retries or retries<1 or retries>5 or retries%1~=0 then return nil,"Attempts must be 1–5" end
    if type(user_agent)~="string" or user_agent=="" or #user_agent>200 or user_agent:find("[%c]") then return nil,"Invalid user agent" end
    if download_dir~="" and (type(download_dir)~="string" or not download_dir:match("^/") or download_dir:find("%.%.") or download_dir:find("[%c]")) then return nil,"Download folder must be an absolute path without .." end
    download_concurrency=tonumber(download_concurrency or self.data.download_concurrency or 2)
    if not download_concurrency or download_concurrency<1 or download_concurrency>5 or download_concurrency%1~=0 then return nil,"Concurrent downloads must be 1–5" end
    if ignore_ssl_certificates~=nil and type(ignore_ssl_certificates)~="boolean" then return nil,"Invalid SSL certificate setting" end
    self.data.timeout=timeout; self.data.retries=retries; self.data.user_agent=user_agent; self.data.download_dir=download_dir~="" and download_dir or nil
    self.data.download_concurrency=download_concurrency
    if ignore_ssl_certificates~=nil then self.data.ignore_ssl_certificates=ignore_ssl_certificates end
    return true
end
function Settings:setDns(mode,server)
    if mode~="auto" and mode~="google" and mode~="cloudflare" and mode~="other" then return nil,"Invalid DNS mode" end
    if mode=="other" then
        if not valid_dns_server(server) then return nil,"Enter a valid IPv4 DNS server" end
        self.data.dns_server=server
    else self.data.dns_server=nil end
    self.data.dns_mode=mode
    return true
end
function Settings:addProfile(profile)
    if type(profile)~="table" or type(profile.id)~="string" or not profile.id:match("^[%w_-]+$") or profile.id=="mangadex" or type(profile.name)~="string" or profile.name=="" or type(profile.base_url)~="string" or not profile.base_url:match("^https://[%w%.%-]+$") then return nil,"Invalid source profile" end
    for _,existing in ipairs(self.data.profiles) do if existing.id==profile.id then return nil,"Source ID already exists" end end
    self.data.profiles[#self.data.profiles+1]=profile
    return true
end
function Settings:save()
    self.store:saveSetting("marumanga", self.data)
    local ok, err = pcall(self.store.flush, self.store)
    if not ok or err == false then return nil, "Unable to save settings" end
    return true
end
return Settings
