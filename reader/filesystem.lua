-- Filesystem adapter for a private, plugin-owned staging tree.
local FS = {}
function FS.new(lfs, link, root, remove_file)
    remove_file=remove_file or os.remove
    assert(lfs and link and type(root)=="string" and root~="")
    local self={root=root}
    local function mkdir(path)
        local mode=lfs.attributes(path,"mode")
        if mode=="directory" then return true end
        if mode then return nil, "Path is not a directory" end
        return lfs.mkdir(path)
    end
    function self.targetFor(source, manga, chapter)
        for _, part in ipairs({source,manga,chapter}) do
            if type(part)~="string" or not part:match("^[%w_-]+$") then return nil,"Invalid identifier" end
        end
        return root .. "/manga/" .. source .. "/" .. manga .. "/chapters/" .. chapter .. ".cbz"
    end
    function self.coverDir(source,manga)
        for _,part in ipairs({source,manga}) do if type(part)~="string" or not part:match("^[%w_-]+$") then return nil,"Invalid identifier" end end
        local parent=root
        for _,part in ipairs({false,"manga",source,manga}) do
            if part then parent=parent .. "/" .. part end
            local ok,err=mkdir(parent); if not ok then return nil,err end
        end
        return parent
    end
    function self.prepare(source, manga, chapter)
        local target, why = self.targetFor(source,manga,chapter)
        if not target then return nil, why end
        local parent=root
        for _, part in ipairs({false,"manga",source,manga,"chapters"}) do
            if part then parent=parent .. "/" .. part end
            local ok,err=mkdir(parent); if not ok then return nil,err end
        end
        local staging=parent .. "/." .. chapter .. ".staging"
        if lfs.attributes(target) then return nil,"Chapter already exists" end
        local ok,err=lfs.mkdir(staging)
        if not ok then return nil,err or "Staging directory already exists" end
        return {target=target,staging=staging}
    end
    function self.cleanupTemporary(source,manga,chapter)
        local target,err=self.targetFor(source,manga,chapter); if not target then return nil,err end
        if type(lfs.symlinkattributes)~="function" then return nil,"Safe cleanup is unavailable" end
        local parent=root
        for _,part in ipairs({"manga",source,manga,"chapters"}) do
            parent=parent .. "/" .. part
            local parent_mode=lfs.symlinkattributes(parent,"mode")
            if parent_mode and parent_mode~="directory" then return nil,"Unsafe staging parent" end
        end
        local staging=parent .. "/." .. chapter .. ".staging"
        local mode=lfs.symlinkattributes(staging,"mode")
        local candidates={}
        if mode then
            if mode~="directory" then return nil,"Unsafe staging path" end
            local ok,iterator,state=pcall(lfs.dir,staging)
            if not ok or not iterator then return nil,"Cannot inspect staging directory" end
            for name in iterator,state do
                if name~="." and name~=".." then
                    if not name:match("^%d%d%d%d%d%d%.image$") then return nil,"Unexpected staging file" end
                    local file=staging .. "/" .. name
                    if lfs.symlinkattributes(file,"mode")~="file" then return nil,"Unsafe staging file" end
                    candidates[#candidates+1]=file
                end
            end
        end
        local part=target .. ".part"; local part_mode=lfs.symlinkattributes(part,"mode")
        if part_mode and part_mode~="file" then return nil,"Unsafe incomplete archive" end
        for _,file in ipairs(candidates) do if not remove_file(file) then return nil,"Cannot remove staging file" end end
        if mode and not lfs.rmdir(staging) then return nil,"Cannot remove staging directory" end
        if part_mode and not remove_file(part) then return nil,"Cannot remove incomplete archive" end
        return true
    end
    function self.clearSourceCovers(source)
        if type(source)~="string" or not source:match("^[%w_-]+$") then return nil,"Invalid source" end
        if type(lfs.symlinkattributes)~="function" then return nil,"Safe cache cleanup is unavailable" end
        local manga_root=root .. "/manga"
        local source_root=manga_root .. "/" .. source
        local root_mode=lfs.symlinkattributes(manga_root,"mode")
        if not root_mode then return 0 end
        if root_mode~="directory" then return nil,"Unsafe cache parent" end
        local mode=lfs.symlinkattributes(source_root,"mode")
        if not mode then return 0 end
        if mode~="directory" then return nil,"Unsafe source cache" end
        local ok,iterator,state=pcall(lfs.dir,source_root)
        if not ok or not iterator then return nil,"Cannot inspect source cache" end
        local removed=0
        for id in iterator,state do
            if id~="." and id~=".." and id:match("^[%w_-]+$") then
                local dir=source_root .. "/" .. id
                if lfs.symlinkattributes(dir,"mode")=="directory" then
                    for _,ext in ipairs({"jpg","png","gif","webp"}) do
                        local file=dir .. "/cover." .. ext
                        if lfs.symlinkattributes(file,"mode")=="file" then
                            if not remove_file(file) then return nil,"Cannot remove cached cover" end
                            removed=removed+1
                        end
                    end
                end
            end
        end
        return removed
    end
    function self.exists(path) return lfs.attributes(path) ~= nil end
    function self.remove(path) return remove_file(path) end
    function self.publishNoReplace(source, target)
        local ok=link(source,target)
        if not ok then return nil,"Cannot safely publish chapter" end
        remove_file(source)
        return true
    end
    return self
end
return FS
