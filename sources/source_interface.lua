-- Check an adapter before enabling it; no source code is loaded from the network.
local Interface = {}
local required = {"getName", "getId", "getBaseUrl", "getLanguages", "getPopularManga", "getLatestUpdates", "searchManga", "getMangaDetails", "getChapterList", "getPageList"}
function Interface.validate(source)
    if type(source) ~= "table" then return nil, "Source must be a table" end
    for _, name in ipairs(required) do
        if type(source[name]) ~= "function" then return nil, "Missing source method: " .. name end
    end
    local ok, id = pcall(source.getId, source)
    if not ok or type(id) ~= "string" or not id:match("^[%w_%-]+$") then return nil, "Invalid source ID" end
    return true
end
return Interface
