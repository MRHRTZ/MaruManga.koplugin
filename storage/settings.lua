-- Versioned settings stored through KOReader LuaSettings.
local Settings = {}
Settings.__index = Settings
local current = 1
local function defaults() return {version=current, language="en", source="mangadex"} end
local function valid_language(s) return type(s) == "string" and #s >= 2 and #s <= 12 and s:match("^[a-z][a-z%-]*$") end
function Settings.open(store)
    assert(type(store) == "table")
    local raw = store:readSetting("marumanga")
    if raw == nil then raw = defaults() end
    if type(raw) ~= "table" then return nil, "Invalid settings data; original data was preserved" end
    local version = raw.version or 0
    if type(version) ~= "number" or version < 0 or version % 1 ~= 0 then return nil, "Invalid settings version; original data was preserved" end
    if version > current then return nil, "Settings are from a newer version; original data was preserved" end
    if raw.profiles ~= nil and type(raw.profiles) ~= "table" then return nil, "Invalid source profiles; original data was preserved" end
    local seen={}
    for _, profile in ipairs(raw.profiles or {}) do
        if type(profile)~="table" or type(profile.id)~="string" or not profile.id:match("^[%w_-]+$") or profile.id=="mangadex" or seen[profile.id] or type(profile.name)~="string" or type(profile.base_url)~="string" or not profile.base_url:match("^https://[%w%.%-]+$") or (profile.image_hosts~=nil and type(profile.image_hosts)~="table") then return nil,"Invalid source profile; original data was preserved" end
        seen[profile.id]=true
        for _,host in ipairs(profile.image_hosts or {}) do if type(host)~="string" or not host:match("^[%w%.%-]+$") then return nil,"Invalid image host; original data was preserved" end end
    end
    local result = {version=current, language=valid_language(raw.language) and raw.language or "en", source=type(raw.source)=="string" and raw.source or "mangadex", profiles=raw.profiles or {}, timeout=type(raw.timeout)=="number" and raw.timeout>=5 and raw.timeout<=120 and raw.timeout or 15,
        retries=type(raw.retries)=="number" and raw.retries>=1 and raw.retries<=5 and raw.retries or 3,
        user_agent=type(raw.user_agent)=="string" and #raw.user_agent<=200 and not raw.user_agent:find("[%c]") and raw.user_agent or "MaruManga/0.1 (KOReader)",
        download_dir=type(raw.download_dir)=="string" and raw.download_dir:match("^/") and not raw.download_dir:find("%.%.") and not raw.download_dir:find("[%c]") and raw.download_dir or nil}
    return setmetatable({store=store, data=result}, Settings)
end
function Settings:setLanguage(language)
    if not valid_language(language) then return nil, "Invalid language" end
    self.data.language = language
    return true
end
function Settings:setNetwork(timeout,retries,user_agent,download_dir)
    timeout,retries=tonumber(timeout),tonumber(retries)
    if not timeout or timeout<5 or timeout>120 or timeout%1~=0 then return nil,"Timeout must be 5–120 seconds" end
    if not retries or retries<1 or retries>5 or retries%1~=0 then return nil,"Attempts must be 1–5" end
    if type(user_agent)~="string" or user_agent=="" or #user_agent>200 or user_agent:find("[%c]") then return nil,"Invalid user agent" end
    if download_dir~="" and (type(download_dir)~="string" or not download_dir:match("^/") or download_dir:find("%.%.") or download_dir:find("[%c]")) then return nil,"Download folder must be an absolute path without .." end
    self.data.timeout=timeout; self.data.retries=retries; self.data.user_agent=user_agent; self.data.download_dir=download_dir~="" and download_dir or nil
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
