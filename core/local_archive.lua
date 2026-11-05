-- Resolve an indexed archive first, then inspect the current storage location.
local M={}
function M.resolve(library,fs,manga,chapter)
    local indexed=library:archiveFor(manga.source_id,manga.id,chapter.id)
    if indexed and fs.exists(indexed) and (not library.archiveHasChapter or library:archiveHasChapter(indexed,chapter.id)) then return indexed,true end
    local current=fs.targetFor(manga.source_id,manga.id,chapter.id,manga.title)
    if current and fs.exists(current) then
        if not library.archiveHasChapter then return current,library.data and library.data.archives and library.data.archives[current]~=nil end
        if library:archiveHasChapter(current,chapter.id) then return current,true end
        return current,false
    end
    local legacy=fs.legacyTargetFor and fs.legacyTargetFor(manga.source_id,manga.id,chapter.id)
    if legacy and fs.exists(legacy) then return legacy,library.data.archives[legacy]~=nil end
    return indexed or current,false
end
return M
