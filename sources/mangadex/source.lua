local Source = {}
Source.__index = Source
local base = "https://api.mangadex.org"
local function encode(s)
    return (tostring(s):gsub("([^%w%-._~])", function(c) return string.format("%%%02X", string.byte(c)) end))
end
local function valid(id)
    return type(id) == "string" and id:match("^%x%x%x%x%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%-%x%x%x%x%x%x%x%x%x%x%x%x$")
end
function Source.new(transport, parser, language)
    return setmetatable({transport=assert(transport), parser=assert(parser), language=language or "en"}, Source)
end
function Source:getName() return "MangaDex" end
function Source:getId() return "mangadex" end
function Source:getBaseUrl() return base end
function Source:getLanguages() return {self.language} end
function Source:_list(path, query, page, limit, convert, callback)
    page = math.max(1, math.floor(tonumber(page) or 1))
    local url = base .. path .. "?limit=" .. limit .. "&offset=" .. ((page-1)*limit) .. query
    self.transport:get(url, function(data, err)
        if not data then return callback(nil, err) end
        if type(data.data) ~= "table" then return callback(nil, "Invalid list response") end
        local items = {}
        for _, entry in ipairs(data.data) do
            local ok,item = pcall(convert,entry)
            if not ok then return callback(nil,"Invalid source response") end
            if item then items[#items+1] = item end
        end
        local offset,total=tonumber(data.offset),tonumber(data.total)
        if not offset or not total or offset<0 or total<0 or offset%1~=0 or total%1~=0 then return callback(nil,"Invalid list pagination") end
        callback({items=items, page=page, total=total, has_next=(offset + #data.data < total)})
    end)
end
local includes = "&includes%5B%5D=cover_art&includes%5B%5D=author&includes%5B%5D=artist"
function Source:_manga(query, page, callback)
    self:_list("/manga", includes .. query, page, 20, self.parser.manga, callback)
end
function Source:getPopularManga(page, callback) self:_manga("&order%5BfollowedCount%5D=desc", page, callback) end
function Source:getLatestUpdates(page, callback) self:_manga("&order%5BlatestUploadedChapter%5D=desc", page, callback) end
function Source:searchManga(query, page, callback) self:_manga("&title=" .. encode(query or ""), page, callback) end
function Source:getMangaDetails(manga, callback)
    if not manga or not valid(manga.id) then return callback(nil, "Invalid manga ID") end
    self.transport:get(base .. "/manga/" .. manga.id .. "?" .. includes:sub(2), function(data, err)
        if not data then return callback(nil, err) end
        local ok,item = pcall(self.parser.manga,data.data)
        if not ok or not item then return callback(nil, "Invalid manga details") end
        callback(item)
    end)
end
function Source:getChapterList(manga, page, callback, order)
    if not manga or not valid(manga.id) then return callback(nil, "Invalid manga ID") end
    self:_list("/manga/" .. manga.id .. "/feed", "&translatedLanguage%5B%5D=" .. encode(self.language) .. "&includes%5B%5D=scanlation_group&order%5Bchapter%5D=" .. (order=="asc" and "asc" or "desc"), page, 100,
        function(entry) return self.parser.chapter(entry, manga.id) end, callback)
end
function Source:getPageList(chapter, callback)
    if not chapter or not valid(chapter.id) then return callback(nil, "Invalid chapter ID") end
    return self.transport:get(base .. "/at-home/server/" .. chapter.id, function(data, err)
        if not data then return callback(nil, err) end
        local ok,pages,parse_err = pcall(self.parser.pages,data)
        if not ok then return callback(nil,"Invalid page response") end
        callback(pages, parse_err)
    end)
end
return Source
