-- Profile-based HTML extraction. No scripts or remote code are evaluated.
local Parser={}
local function first(root,selector)
    if type(selector)~="string" or selector=="" then return nil end
    local ok,nodes=pcall(root.select,root,selector)
    if not ok then return nil end
    return nodes and nodes[1]
end
local function all(root,selector)
    if type(selector)~="string" or selector=="" then return {} end
    local ok,nodes=pcall(root.select,root,selector)
    return ok and nodes or {}
end
local function first_profile(root,selector,selectors)
    if selector then return first(root,selector) end
    for _,candidate in ipairs(selectors or {}) do local node=first(root,candidate); if node then return node end end
end
local function all_profile(root,selector,selectors)
    if selector then return all(root,selector) end
    for _,candidate in ipairs(selectors or {}) do local nodes=all(root,candidate); if #nodes>0 then return nodes end end
    return {}
end
local function text(node,clean)
    if not node then return "" end
    return (clean(node:getcontent() or ""):gsub("^%s+",""):gsub("%s+$",""))
end
local function absolute(resolve,base,ref)
    if type(ref)~="string" or ref=="" then return nil end
    local ok,result=pcall(resolve,base,ref)
    if not ok or type(result)~="string" or #result>8192 or result:find("[%c%s]") or not result:match("^https://") then return nil end
    return result
end
function Parser.new(html,resolve,clean,profile,digest)
    assert(html and resolve and clean and type(profile)=="table")
    digest=digest or function(value) return value end
    local self={profile=profile}
    local function root(body)
        if type(body)~="string" or #body>2097152 then return nil,"Invalid HTML response" end
        -- Some server-rendered manga pages contain thousands of chapter-row
        -- nodes. Keep parsing bounded but scale the token limit with response
        -- size so large, valid pages are not silently truncated at 5,000 tags.
        local parse_limit=math.min(50000,math.max(5000,math.floor(#body/2)))
        local ok,node=pcall(html.parse,body,parse_limit)
        if not ok or not node then return nil,"Invalid HTML response" end
        return node
    end
    function self:list(body,base)
        local doc,err=root(body); if not doc then return nil,err end
        local items={}
        for _,node in ipairs(all_profile(doc,profile.list_selector,profile.list_selectors)) do
            local link=first_profile(node,profile.list_link_selector,profile.list_link_selectors) or (not profile.list_link_selector and not profile.list_link_selectors and node or nil)
            local href=link and absolute(resolve,base,link.attributes[profile.list_link_attribute or "href"])
            local title=profile.list_title_selector and text(first(node,profile.list_title_selector),clean) or text(link,clean)
            if title=="" then title=text(link,clean) end
            if title=="" and link then local img=first(link,"img"); title=img and img.attributes.alt or "" end
            if href and title~="" then
                local item={id=digest(href),title=title,url=href,source_id=profile.id}
                local cover=first_profile(node,profile.list_cover_selector,profile.list_cover_selectors)
                if not cover and not profile.list_cover_selector and not profile.list_cover_selectors then cover=first(node,"img") end
                if cover then
                    local attributes=profile.list_cover_attributes or {profile.list_cover_attribute or "src","data-src","data-lazy-src","data-original"}
                    for _,attribute in ipairs(attributes) do
                        local raw=cover.attributes[attribute]
                        if type(raw)=="string" and raw~="" then
                            if attribute:find("srcset",1,true) then raw=raw:match("^%s*(%S+)") end
                            item.cover_url=absolute(resolve,base,raw)
                            if item.cover_url then break end
                        end
                    end
                end
                local latest_label=(type(profile.latest_label)=="string" and profile.latest_label or ""):lower()
                if profile.latest_selector or profile.latest_selectors then
                    for _,latest_node in ipairs(all_profile(node,profile.latest_selector,profile.latest_selectors)) do
                        local spans=all(latest_node,"span")
                        local label=#spans>1 and text(spans[1],clean):lower() or ""
                        if latest_label=="" or label:find(latest_label,1,true) then
                            local value=#spans>1 and text(spans[#spans],clean) or text(latest_node,clean)
                            if value~="" then item.latest_chapter=value; break end
                        end
                    end
                end
                items[#items+1]=item
            end
        end
        local nextnode=first_profile(doc,profile.next_selector,profile.next_selectors)
        local nexturl=nextnode and absolute(resolve,base,nextnode.attributes[profile.next_attribute or "href"])
        return {items=items,next_url=nexturl,has_next=nexturl~=nil}
    end
    function self:details(body,base,manga)
        local doc,err=root(body); if not doc then return nil,err end
        local function field(selector)
            local node=first(doc,selector)
            if not node then return "" end
            local value=text(node,clean)
            if value=="" and type(node.attributes)=="table" and type(node.attributes.content)=="string" then value=clean(node.attributes.content) end
            return value
        end
        local item={id=manga.id,url=manga.url,source_id=profile.id,title=field(profile.title_selector),description=field(profile.description_selector),author=field(profile.author_selector),artist=field(profile.artist_selector),status=field(profile.status_selector),genres={}}
        if item.title=="" then item.title=manga.title end
        local cover=first(doc,profile.cover_selector)
        if cover then item.cover_url=absolute(resolve,base,cover.attributes[profile.cover_attribute or "src"]) end
        -- Many server-rendered manga pages expose metadata as ordinary two-cell
        -- table rows. This bounded fallback avoids source-specific :contains()
        -- selectors, which KOReader's bundled HTML parser does not implement.
        for _,row in ipairs(all(doc,profile.metadata_row_selector or "")) do
            local cells=all(row,"td")
            if #cells>=2 then
                local label=text(cells[1],clean):lower():gsub("[%s:：]+$","")
                local value=text(cells[2],clean)
                if value~="" then
                    if item.author=="" and (label=="author" or label=="author(s)" or label=="penulis") then item.author=value end
                    if item.artist=="" and (label=="artist" or label=="illustrator" or label=="artis" or label=="ilustrator") then item.artist=value end
                    if item.status=="" and (label=="status" or label=="serialization status") then item.status=value end
                end
            end
        end
        for _,node in ipairs(all(doc,profile.genre_selector)) do local value=text(node,clean); if value~="" then item.genres[#item.genres+1]=value end end
        return item
    end
    function self:chapters(body,base,manga)
        local doc,err=root(body); if not doc then return nil,err end
        local items={}
        for _,node in ipairs(all(doc,profile.chapter_selector)) do
            local link=profile.chapter_link_selector and first(node,profile.chapter_link_selector) or node
            local href=link and absolute(resolve,base,link.attributes[profile.chapter_attribute or "href"])
            local name=text(link,clean)
            if href and name~="" then
                local number=name:lower():match("chapter%s*(%d+%.?%d*)") or name:lower():match("ch%.?%s*(%d+%.?%d*)")
                items[#items+1]={id=digest(href),manga_id=manga.id,name=name,chapter_number=tonumber(number),url=href}
            end
        end
        return items
    end
    function self:pages(body,base)
        local doc,err=root(body); if not doc then return nil,err end
        local items={}
        for _,node in ipairs(all(doc,profile.page_selector)) do
            local image
            local attributes=profile.page_attribute and {profile.page_attribute} or profile.page_attributes or {"src"}
            for _,name in ipairs(attributes) do
                local raw=node.attributes[name]
                if type(raw)=="string" and raw:match("%S") then image=absolute(resolve,base,raw:match("^%s*(.-)%s*$")); if image then break end end
            end
            if image then items[#items+1]={index=#items+1,image_url=image,headers={},referer=base} end
        end
        if #items==0 then return nil,"Chapter has no images" end
        return items
    end
    return self
end
return Parser
