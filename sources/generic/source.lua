-- Generic configurable HTML source; profiles are data, never executable scripts.
local Source={}; Source.__index=Source
local function encode(s) return (tostring(s or ""):gsub("([^%w%-._~])",function(c) return string.format("%%%02X",string.byte(c)) end)) end
local function url_for(base,pattern,query,page)
    if type(pattern)~="string" or (not pattern:match("^/") and not pattern:match("^{page_path}/")) or pattern:match("^//") then return nil end
    local number=math.max(1,math.floor(tonumber(page) or 1))
    return base .. pattern:gsub("{query}",function() return encode(query) end):gsub("{page_path}",function() return number>1 and ("/page/" .. number) or "" end):gsub("{page}",function() return tostring(number) end)
end
function Source.new(profile,parser,transport)
    assert(type(profile)=="table" and type(profile.id)=="string" and profile.id:match("^[%w_-]+$") and type(profile.name)=="string")
    assert(type(profile.base_url)=="string" and profile.base_url:match("^https://[%w%.%-]+:?%d*$"))
    return setmetatable({profile=profile,parser=assert(parser),transport=assert(transport)},Source)
end
function Source:getName() return self.profile.name end
function Source:getId() return self.profile.id end
function Source:getBaseUrl() return self.profile.base_url end
function Source:getLanguages() return self.profile.languages or {} end
function Source:_get(url,callback)
    local base=self.profile.base_url
    if type(url)~="string" or (url~=base and url:sub(1,#base+1)~=base.."/") then return callback(nil,"URL outside configured source") end
    return self.transport:get(url,callback)
end
function Source:_list(pattern,query,page,callback)
    local url=url_for(self.profile.base_url,pattern,query,page)
    if not url then return callback(nil,"Unsupported source operation") end
    self:_get(url,function(body,err)
        if not body then return callback(nil,err) end
        local result,failure=self.parser:list(body,url)
        if not result then return callback(nil,failure) end
        result.page=page or 1; callback(result)
    end)
end
function Source:getPopularManga(page,cb) self:_list(self.profile.popular_path,"",page,cb) end
function Source:getLatestUpdates(page,cb) self:_list(self.profile.latest_path,"",page,cb) end
function Source:searchManga(query,page,cb) self:_list(self.profile.search_path,query,page,cb) end
function Source:getMangaDetails(manga,callback)
    self:_get(manga.url,function(body,err) if not body then return callback(nil,err) end; callback(self.parser:details(body,manga.url,manga)) end)
end
function Source:getChapterList(manga,page,callback,order)
    if page and page~=1 then return callback(nil,"Chapter pagination is not configured") end
    local function parsed(body,err)
        if not body then return callback(nil,err) end
        local items,failure=self.parser:chapters(body,manga.url,manga)
        if not items then return callback(nil,failure) end
        table.sort(items,function(a,b)
            if a.chapter_number and b.chapter_number and a.chapter_number~=b.chapter_number then
                if order=="asc" then return a.chapter_number<b.chapter_number end
                return a.chapter_number>b.chapter_number
            end
            if (a.chapter_number~=nil)~=(b.chapter_number~=nil) then return a.chapter_number~=nil end
            local an,bn=(a.name or ""):lower(),(b.name or ""):lower()
            if an==bn then return tostring(a.id)<tostring(b.id) end
            if order=="asc" then return an<bn end
            return an>bn
        end)
        callback({items=items,page=1,has_next=false})
    end
    if self.profile.chapter_mode=="ajax" then
        local suffix=self.profile.chapter_ajax_suffix or "/ajax/chapters/"
        if type(suffix)~="string" or not suffix:match("^/[%w/_%-]+/?$") then return callback(nil,"Invalid chapter endpoint") end
        local base=self.profile.base_url
        if type(manga.url)~="string" or manga.url:sub(1,#base+1)~=base.."/" then return callback(nil,"URL outside configured source") end
        local path=manga.url:match("^([^?#]+)")
        local endpoint=path:gsub("/$","") .. suffix
        return self.transport:post(endpoint,"",{["X-Requested-With"]="XMLHttpRequest",Referer=manga.url},parsed)
    end
    self:_get(manga.url,parsed)
end
function Source:getPageList(chapter,callback)
    return self:_get(chapter.url,function(body,err) if not body then return callback(nil,err) end; callback(self.parser:pages(body,chapter.url)) end)
end
return Source
