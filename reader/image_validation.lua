-- Checks MIME type, size and image signature before a page can be archived.
local M = {}
local types = { ["image/jpeg"]="jpg", ["image/png"]="png", ["image/gif"]="gif", ["image/webp"]="webp" }
function M.validate(content_type, size, prefix, limit)
    local mime = type(content_type) == "string" and content_type:lower():match("^%s*([^;%s]+)")
    local ext = types[mime]
    if not ext then return nil, "Unsupported image content type" end
    if type(size) ~= "number" or size <= 0 or size > (limit or 20971520) then return nil, "Invalid image size" end
    if type(prefix) ~= "string" then return nil, "Missing image signature" end
    local valid = (ext == "jpg" and prefix:sub(1,3) == "\255\216\255") or
        (ext == "png" and prefix:sub(1,8) == "\137PNG\r\n\26\n") or
        (ext == "gif" and (prefix:sub(1,6) == "GIF87a" or prefix:sub(1,6) == "GIF89a")) or
        (ext == "webp" and prefix:sub(1,4) == "RIFF" and prefix:sub(9,12) == "WEBP")
    if not valid then return nil, "Image signature does not match content type" end
    return ext
end
return M
