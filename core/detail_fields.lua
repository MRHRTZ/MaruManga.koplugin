local M = {}

function M.genreNames(genres)
    if type(genres) ~= "table" then return "" end
    local names = {}
    for _, genre in ipairs(genres) do
        local name
        if type(genre) == "string" then
            name = genre
        elseif type(genre) == "table" then
            name = genre.name or genre.title or genre.label or genre.slug
        end
        if type(name) == "string" and name:gsub("%s+", "") ~= "" then
            names[#names + 1] = name
        end
    end
    return table.concat(names, ", ")
end

return M
