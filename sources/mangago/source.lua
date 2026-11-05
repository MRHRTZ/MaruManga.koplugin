-- Mangago website scraper for its public server-rendered manga pages.
-- It does not execute page scripts or submit account data.
local here=debug.getinfo(1,"S").source:sub(2):match("^(.*[/\\])") or ""
local Generic=dofile(here.."../generic/source.lua")
local Source=setmetatable({}, {__index=Generic}); Source.__index=Source
local BASE="https://www.mangago.zone"
local function allowed_image_hosts(profile)
    local hosts={}
    for _,host in ipairs(profile.image_hosts or {}) do hosts[host]=true end
    return hosts
end
function Source.new(profile,parser,transport,html)
    assert(type(profile)=="table" and profile.id=="mangago" and profile.base_url==BASE)
    local self=Generic.new(profile,parser,transport)
    self.html=assert(html)
    return setmetatable(self,Source)
end
-- Mangago's current Popular and Latest server-rendered cards contain a work
-- URL and lazy cover only; title text is omitted. Keep these cards navigable
-- with a stable ID label. The detail page supplies the real title on open.
function Source:_list(pattern,query,page,callback)
    if query and query~="" then return Generic._list(self,pattern,query,page,callback) end
    local url=BASE..(pattern:gsub("{page}",tostring(math.max(1,math.floor(tonumber(page) or 1)))))
    self:_get(url,function(body,err)
        if not body then return callback(nil,err) end
        local ok,doc=pcall(self.html.parse,body,math.min(50000,math.max(5000,math.floor(#body/2))))
        if not ok or not doc then return callback(nil,"Invalid Mangago listing response") end
        local sections_ok,sections=pcall(doc.select,doc,".indexlefttop1")
        if not sections_ok or type(sections)~="table" then return callback(nil,"Could not parse Mangago listing") end
        local section
        if pattern==self.profile.latest_path then
            -- The home page presents Featured, Popular, New Comics, then Last Updates.
            section=sections[4]
        elseif #sections>=2 then
            -- /topmanga/ presents a dated random list followed by Yesterday's Top.
            section=sections[2]
        end
        if not section then return callback(nil,"Mangago listing section is unavailable") end
        local ok_nodes,nodes=pcall(section.select,section,".pic_list .flex1.listitem")
        if not ok_nodes or type(nodes)~="table" then return callback(nil,"Could not parse Mangago listing") end
        local items={}
        local allowed=allowed_image_hosts(self.profile)
        for _,node in ipairs(nodes) do
            local link_ok,links=pcall(node.select,node,'a[href*="/work/"]')
            local link=link_ok and links and links[1]
            local href=link and link.attributes and link.attributes.href
            local id=type(href)=="string" and href:match("/work/(%d+)/")
            if id then
                local item={id=id,title="Manga #"..id,url=BASE.."/work/"..id.."/",source_id="mangago"}
                local img_ok,images=pcall(node.select,node,"img")
                local img=img_ok and images and images[1]
                local cover=img and img.attributes and (img.attributes["data-src"] or img.attributes["data-original"] or img.attributes.src)
                local host=type(cover)=="string" and cover:match("^https://([%w%.%-]+)/")
                if host and allowed[host] then item.cover_url=cover end
                items[#items+1]=item
            end
        end
        if #items==0 then return callback(nil,"Mangago returned no readable manga cards") end
        -- Mangago omits pagination markup on these sections. Its public pages
        -- return 12 cards per section; permit the next page when that page is full.
        callback({items=items,page=page or 1,has_next=#items>=12})
    end)
end
function Source:getChapterList(manga,page,callback,order)
    if type(manga)~="table" or type(manga.url)~="string" or not manga.url:match("^https://www%.mangago%.zone/work/%d+/?$") then
        return callback(nil,"Invalid Mangago title URL")
    end
    return Generic.getChapterList(self,manga,page,callback,order)
end
function Source:getPageList(chapter,callback)
    if type(chapter)~="table" or type(chapter.url)~="string" or not chapter.url:match("^https://www%.mangago%.zone/chapter/%d+/%d+/?$") then
        return callback(nil,"Invalid Mangago chapter URL")
    end
    return self:_get(chapter.url,function(body,err)
        if not body then return callback(nil,err) end
        local pages,failure=self.parser:pages(body,chapter.url)
        if pages then return callback(pages) end
        local encrypted=body:match("var%s+imgsrcs%s*=%s*['\"]([^'\"]+)['\"]")
        if not encrypted then return callback(nil,failure) end
        local manifest=dofile(here.."image_manifest.lua")
        local urls,decode_error=manifest.decode(encrypted)
        if not urls then return callback(nil,decode_error) end
        local allowed=allowed_image_hosts(self.profile); local items={}
        for _,image_url in ipairs(urls) do
            local host=image_url:match("^https://([%w%.%-]+)/")
            if not host or not allowed[host] then return callback(nil,"Mangago image host is not permitted") end
            items[#items+1]={index=#items+1,image_url=image_url,headers={},referer=chapter.url}
        end
        callback(items)
    end)
end
return Source
