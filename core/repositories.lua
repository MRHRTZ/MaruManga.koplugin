-- Repository catalogs are data; only bundled adapter implementations are executable.
local Repos={}; Repos.__index=Repos
local DEFAULT_URL="https://raw.githubusercontent.com/MRHRTZ/maru-manga-repository/refs/heads/master/metadata.json"
local builtin={id="builtin",name="MaruManga Repository",author="MRHRTZ",builtin=true,url=DEFAULT_URL,catalog={schema_version=1,id="maru-official",name="MaruManga Repository",author="MRHRTZ",version="1.23.2",status="OK",sources={
    {id="komiku",name="Komiku",version="3.0.0",adapter="komiku",base_url="https://komiku.org",languages={"id"},profile={
        api_url="https://api.komiku.org",image_hosts={"thumbnail.komiku.to","thumbnail.komiku.org","img.komiku.org","image.komiku.org","update.komiku.org","komikid.org"},
        list_selector="div.bge",list_link_selector="a",list_title_selector="h3",list_cover_selector="img",title_selector="h1 span[itemprop=\"name\"]",description_selector="p.desc",
        author_selector="span[itemprop=\"author\"] meta[itemprop=\"name\"]",artist_selector="span[itemprop=\"artist\"] meta[itemprop=\"name\"]",status_selector="meta[itemprop=\"creativeWorkStatus\"]",metadata_row_selector="table.inftable tr",
        genre_selector="ul.genre li.genre a span",cover_selector=".ims img",cover_attribute="src",chapter_selector="#Daftar_Chapter tr",chapter_link_selector="a",chapter_attribute="href",page_selector="#Baca_Komik img",page_attribute="src"}}}
}}
builtin.catalog.sources[#builtin.catalog.sources+1]={["id"]="mangarock",["name"]="MangaRock",["version"]="2.0.0",["adapter"]="mangarock",["url"]="https://mangarock.one/",["languages"]={"en"},["metadata"]="mangarock/metadata.json",["base_url"]="https://mangarock.one",["profile"]={["search_path"]="/search?q={query}&page={page}",["popular_path"]="/",["latest_path"]="/updated?page={page}",["list_selector"]=".listupd .bs",["list_link_selector"]="a",["list_title_selector"]=".tt",["list_cover_selector"]="img",["next_selector"]="a[rel=\"next\"]",["title_selector"]="h1.entry-title",["description_selector"]="meta[name=\"description\"]",["cover_selector"]=".seriestucontl .thumb img",["metadata_row_selector"]="table.infotable tr",["genre_selector"]=".seriestugenre a",["chapter_selector"]=".eph-num a",["page_selector"]="img.ts-main-image",["page_attribute"]="src",["image_hosts"]={"llma.zogana.lol"}}}
builtin.catalog.sources[#builtin.catalog.sources+1]={["id"]="mangamost",["name"]="MangaMost",["version"]="3.0.0",["adapter"]="mangamost",["app_url"]="https://play.google.com/store/apps/details?id=baca.read.komik.manga&hl=id",["languages"]={"en"},["nsfw"]=false,["metadata"]="mangamost/metadata.json",["base_url"]="https://mangamost.com",["profile"]={["api_url"]="https://mangamost.com/api/v1",["image_hosts"]={"mangamost.com"}}}
builtin.catalog.sources[#builtin.catalog.sources+1]={["id"]="mangago",["name"]="Mangago",["version"]="1.1.0",["adapter"]="mangago",["languages"]={"en"},["nsfw"]=true,["metadata"]="mangago/metadata.json",["base_url"]="https://www.mangago.zone",["profile"]={["search_path"]="/r/l_search/?name={query}&page={page}",["popular_path"]="/topmanga/?page={page}",["latest_path"]="/?page={page}",["list_selectors"]={"#search_list > li","#topmanga_list > li",".box"},["list_link_selectors"]={".row-1 h2 a","h2 a","a[href*=\"/work/\"]"},["list_title_selector"]=".row-1 h2 a",["list_cover_selectors"]={".left img","img"},["next_selectors"]={".pagination a.next",".pagination a[rel=\"next\"]"},["title_selector"]=".w-title h1",["description_selector"]=".manga_summary",["author_selector"]=".manga_right table tr a[href*=\"/home/people/\"]",["cover_selector"]=".left.cover img",["status_selector"]=".manga_right table tr:first-child td",["genre_selector"]=".manga_right table tr a[href*=\"/genre/\"]",["chapter_selector"]="#chapter_table tbody tr",["chapter_link_selector"]="a.chico",["page_selector"]="#pic_container img",["page_attribute"]="src",["image_hosts"]={"www.mangago.zone","i1.mangapicgallery.com","i2.mangapicgallery.com","i4.mangapicgallery.com","i6.mangapicgallery.com","i8.mangapicgallery.com","i9.mangapicgallery.com","iweb12.mangapicgallery.com","pic1.mangapicgallery.com"}}}
builtin.catalog.sources[#builtin.catalog.sources+1]={["id"]="webtoon",["name"]="WEBTOON",["version"]="1.1.0",["adapter"]="webtoon",["base_url"]="https://www.webtoons.com",["languages"]={"en"},["nsfw"]=false,["metadata"]="webtoon/metadata.json",["profile"]={["locale"]="en",["search_path"]="/en/search?keyword={query}&page={page}",["popular_path"]="/en/ranking?rankingGenre=ALL&page={page}",["latest_path"]="/en/originals?sortOrder=UPDATE&page={page}",["list_selector"]="ul.webtoon_list li",["list_link_selector"]="a._card_item",["list_title_selector"]=".title",["list_cover_selector"]="img",["next_selector"]=".paginate a.pg_next",["title_selector"]=".detail_header h1.subj",["description_selector"]="p.summary",["author_selector"]=".author_area",["genre_selector"]=".detail_header h2.genre",["cover_selector"]=".detail_header .thmb img",["chapter_selector"]="#_listUl ._episodeItem",["chapter_link_selector"]="a.detail_list_link",["page_selector"]="img._images",["page_attribute"]="data-url",["image_hosts"]={"webtoon-phinf.pstatic.net"}}}
builtin.catalog.sources[#builtin.catalog.sources+1]={["id"]="webtoon_id",["name"]="WEBTOON",["version"]="1.0.0",["adapter"]="webtoon",["base_url"]="https://www.webtoons.com",["languages"]={"id"},["nsfw"]=false,["metadata"]="webtoon_id/metadata.json",["profile"]={["locale"]="id",["search_path"]="/id/search?keyword={query}&page={page}",["popular_path"]="/id/ranking?rankingGenre=ALL&page={page}",["latest_path"]="/id/originals?sortOrder=UPDATE&page={page}",["list_selector"]="ul.webtoon_list li",["list_link_selector"]="a._card_item",["list_title_selector"]=".title",["list_cover_selector"]="img",["next_selector"]=".paginate a.pg_next",["title_selector"]=".detail_header h1.subj",["description_selector"]="p.summary",["author_selector"]=".author_area",["genre_selector"]=".detail_header h2.genre",["cover_selector"]=".detail_header .thmb img",["chapter_selector"]="#_listUl ._episodeItem",["chapter_link_selector"]="a.detail_list_link",["page_selector"]="img._images",["page_attribute"]="data-url",["image_hosts"]={"webtoon-phinf.pstatic.net"}}}
builtin.catalog.sources[#builtin.catalog.sources+1]={["id"]="westmanga",["name"]="WestManga",["version"]="1.0.0",["adapter"]="westmanga",["base_url"]="https://www.westmanga.shop",["languages"]={"id"},["nsfw"]=false,["metadata"]="westmanga/metadata.json",["profile"]={["api_url"]="https://www.westmanga.shop/api/manga",["search_path"]="/api/manga?q={query}&page={page}&limit=24&sort=latest",["popular_path"]="/api/manga?page={page}&limit=24&sort=popular",["latest_path"]="/api/manga?page={page}&limit=24&sort=latest",["list_selector"]="a[href^=\"/manga/\"]",["list_link_selector"]="a[href^=\"/manga/\"]",["list_title_selector"]="h1",["title_selector"]="h1",["description_selector"]="meta[name=\"description\"]",["chapter_selector"]="a[href*=\"/read/\"]",["page_selector"]="img[src*=\"/api/img-proxy\"]",["image_hosts"]={"www.westmanga.shop","cdn.westmanga.shop","proxy.westmanga.shop"}}}
local icon_domains={komiku="komiku.org",mangarock="mangarock.one",mangamost="mangamost.com",mangago="www.mangago.zone",webtoon="www.webtoons.com",webtoon_id="www.webtoons.com",westmanga="www.westmanga.shop"}
for _,entry in ipairs(builtin.catalog.sources) do
    local domain=icon_domains[entry.id]
    if domain then entry.icon_url="https://www.google.com/s2/favicons?domain="..domain.."&sz=64" end
end
local function valid_url(url)
    return type(url)=="string" and #url<=2048 and url:match("^https://[%w%.%-]+/[%w%._~/%-]+$") and not url:find("..",1,true)
end
local function valid_version(v)
    if type(v)=="number" then return v>=1 and v%1==0 end -- legacy integer catalogs remain readable
    if type(v)~="string" or #v>32 then return false end
    local major,minor,patch=v:match("^(%d+)%.(%d+)%.(%d+)$")
    if not major then return false end
    local function canonical(n) return n=="0" or n:match("^[1-9]%d*$")~=nil end
    return canonical(major) and canonical(minor) and canonical(patch)
end
local function version_less(a,b)
    if type(a)=="number" and type(b)=="number" then return a<b end
    local function parts(v) local s=tostring(v); local p={}; for n in s:gmatch("%d+") do p[#p+1]=tonumber(n) end; return p end
    local x,y=parts(a),parts(b); for i=1,math.max(#x,#y) do if (x[i] or 0)~=(y[i] or 0) then return (x[i] or 0)<(y[i] or 0) end end
    return false
end
local function valid_icon_url(url,base_url)
    if type(url)~="string" or #url>2048 or url:find("[%c%s#]") then return false end
    local host=url:match("^https://([%w%.%-]+)/")
    local base_host=type(base_url)=="string" and base_url:match("^https://([%w%.%-]+)$")
    if not host or not base_host then return false end
    if host=="www.google.com" then
        local domain=url:match("^https://www%.google%.com/s2/favicons%?domain=([%w%.%-]+)&sz=64$")
        return domain==base_host
    end
    return host==base_host
end
local function validate(catalog)
    if type(catalog)~="table" or catalog.schema_version~=1 or type(catalog.id)~="string" or not catalog.id:match("^[%w_-]+$") or type(catalog.name)~="string" or #catalog.name>100 or catalog.name=="" or not valid_version(catalog.version) or type(catalog.sources)~="table" or #catalog.sources>200 then return nil,"Invalid repository catalog" end
    local out={schema_version=1,id=catalog.id,name=catalog.name,author=type(catalog.author)=="string" and catalog.author:sub(1,100) or "Unknown",version=catalog.version,status=type(catalog.status)=="string" and catalog.status:sub(1,40) or "Unknown",status_message=type(catalog.status_message)=="string" and catalog.status_message:sub(1,500) or nil,sources={}}; local seen={}
    local source_list={}
    for _,item in ipairs(catalog.sources) do
        if type(item)~="table" then return nil,"Invalid repository source" end
        if item.id~="mangadex" and item.adapter~="mangadex" then source_list[#source_list+1]=item end
    end
    for _,item in ipairs(source_list) do
        if type(item)~="table" or type(item.id)~="string" or not item.id:match("^[%w_-]+$") or #item.id>80 or seen[item.id] or type(item.name)~="string" or item.name=="" or #item.name>100 or not valid_version(item.version) or (item.adapter~="mangadex" and item.adapter~="madara" and item.adapter~="generic" and item.adapter~="komiku" and item.adapter~="planned" and item.adapter~="mangago" and item.adapter~="mangamost" and item.adapter~="mangarock" and item.adapter~="webtoon" and item.adapter~="westmanga") or (item.adapter~="planned" and (type(item.base_url)~="string" or not item.base_url:match("^https://[%w%.%-]+$"))) then return nil,"Invalid repository source" end
        if item.adapter=="mangadex" and (item.id~="mangadex" or item.base_url~="https://api.mangadex.org") then return nil,"Invalid MangaDex source" end
        if item.adapter=="komiku" and (item.id~="komiku" or item.base_url~="https://komiku.org" or type(item.profile)~="table" or item.profile.api_url~="https://api.komiku.org") then return nil,"Invalid Komiku source" end
        if item.adapter=="mangamost" and (item.id~="mangamost" or item.base_url~="https://mangamost.com" or type(item.profile)~="table" or item.profile.api_url~="https://mangamost.com/api/v1") then return nil,"Invalid MangaMost source" end
        if item.adapter=="mangago" and (item.id~="mangago" or item.base_url~="https://www.mangago.zone" or type(item.profile)~="table" or item.nsfw~=true) then return nil,"Invalid Mangago source" end
        if item.adapter=="mangarock" and (item.id~="mangarock" or item.base_url~="https://mangarock.one") then return nil,"Invalid MangaRock source" end
        if item.adapter=="webtoon" and ((item.id~="webtoon" and item.id~="webtoon_id") or item.base_url~="https://www.webtoons.com" or type(item.profile)~="table" or item.profile.locale~=(item.id=="webtoon_id" and "id" or "en")) then return nil,"Invalid WEBTOON source" end
        if item.adapter=="webtoon" then for _,host in ipairs(item.profile.image_hosts or {}) do if host~="webtoon-phinf.pstatic.net" then return nil,"Unsupported WEBTOON image host" end end end
        if item.adapter=="westmanga" and (item.id~="westmanga" or item.base_url~="https://www.westmanga.shop" or type(item.profile)~="table" or item.profile.api_url~="https://www.westmanga.shop/api/manga") then return nil,"Invalid WestManga source" end
        if item.adapter=="westmanga" then
            local allowed_hosts={ ["www.westmanga.shop"]=true,["cdn.westmanga.shop"]=true,["proxy.westmanga.shop"]=true }
            for _,host in ipairs(item.profile.image_hosts or {}) do if not allowed_hosts[host] then return nil,"Unsupported WestManga image host" end end
        end
        if item.adapter~="mangadex" and item.id=="mangadex" then return nil,"Reserved source ID" end
        local entry={id=item.id,name=item.name,version=item.version,adapter=item.adapter,base_url=item.base_url,nsfw=item.nsfw==true}
        if item.icon_url~=nil then
            if not valid_icon_url(item.icon_url,item.base_url) then return nil,"Invalid source icon URL" end
            entry.icon_url=item.icon_url
        end
        if item.url and type(item.url)=="string" and item.url:match("^https://[%w%.%-]+") then entry.url=item.url end
        if item.app_url and type(item.app_url)=="string" and item.app_url:match("^https://play%.google%.com/") then entry.app_url=item.app_url end
        local allowed={"api_url","locale","search_path","popular_path","latest_path","list_selector","list_link_selector","list_title_selector","list_cover_selector","list_cover_attribute","latest_selector","latest_label","next_selector","title_selector","description_selector","author_selector","artist_selector","genre_selector","cover_selector","chapter_selector","page_selector","chapter_mode","chapter_ajax_suffix","status_selector","metadata_row_selector","chapter_link_selector","chapter_attribute","page_attribute","cover_attribute","list_link_attribute","next_attribute"}
        if item.profile~=nil and type(item.profile)~="table" then return nil,"Invalid source profile" end
        entry.profile={}
        for _,key in ipairs(allowed) do
            local v=item.profile and item.profile[key]
            if v~=nil then if type(v)~="string" or #v>512 or v:find("[%c]") then return nil,"Invalid source profile" end; entry.profile[key]=v end
        end
        if item.adapter=="komiku" and entry.profile.api_url~="https://api.komiku.org" then return nil,"Invalid Komiku API URL" end
        if item.adapter=="mangamost" and entry.profile.api_url~="https://mangamost.com/api/v1" then return nil,"Invalid MangaMost API URL" end
        if item.adapter=="mangamost" then for _,host in ipairs(item.profile.image_hosts or {}) do if host~="mangamost.com" then return nil,"Unsupported MangaMost image host" end end end
        if item.adapter=="mangago" then
            if item.profile.image_hosts~=nil and type(item.profile.image_hosts)~="table" then return nil,"Invalid Mangago image hosts" end
            local allowed_hosts={ ["www.mangago.zone"]=true,["i1.mangapicgallery.com"]=true,["i2.mangapicgallery.com"]=true,["i4.mangapicgallery.com"]=true,["i6.mangapicgallery.com"]=true,["i8.mangapicgallery.com"]=true,["i9.mangapicgallery.com"]=true,["iweb12.mangapicgallery.com"]=true,["pic1.mangapicgallery.com"]=true }
            for _,host in ipairs(item.profile.image_hosts or {}) do if not allowed_hosts[host] then return nil,"Unsupported Mangago image host" end end
        end
        if item.adapter=="komiku" then
            if item.profile.image_hosts~=nil and type(item.profile.image_hosts)~="table" then return nil,"Invalid Komiku image hosts" end
            local allowed_hosts={ ["thumbnail.komiku.to"]=true,["thumbnail.komiku.org"]=true,["img.komiku.org"]=true,["image.komiku.org"]=true,["update.komiku.org"]=true,["komikid.org"]=true }
            for _,host in ipairs(item.profile.image_hosts or {}) do if not allowed_hosts[host] then return nil,"Unsupported Komiku image host" end end
        end
        local arrays={"list_selectors","list_link_selectors","list_cover_selectors","list_cover_attributes","latest_selectors","next_selectors","page_attributes","image_hosts"}
        for _,key in ipairs(arrays) do
            local values=item.profile and item.profile[key]
            if values~=nil then
                if type(values)~="table" or #values>32 then return nil,"Invalid source profile" end
                entry.profile[key]={}
                for _,value in ipairs(values) do
                    if type(value)~="string" or value=="" or #value>512 or value:find("[%c]") or (key=="image_hosts" and not value:match("^[%w%.%-]+$")) then return nil,"Invalid source profile" end
                    entry.profile[key][#entry.profile[key]+1]=value
                end
            end
        end
        if item.languages~=nil then
            if type(item.languages)~="table" or #item.languages>32 then return nil,"Invalid source languages" end
            entry.languages={}
            for _,language in ipairs(item.languages) do
                if type(language)~="string" or #language<2 or #language>12 or not language:match("^[a-z][a-z%-]*$") then return nil,"Invalid source languages" end
                entry.languages[#entry.languages+1]=language
            end
        end
        if item.adapter=="planned" then entry.planned=true end
        seen[item.id]=true; out.sources[#out.sources+1]=entry
    end
    return out
end
local function merge_builtin_fallback(repo,catalog)
    if not repo or repo.url~=DEFAULT_URL or catalog.id~="maru-official" then return catalog end
    catalog.name="MaruManga Repository"
local fallback=assert(validate(builtin.catalog))
    local present={}; local bundled={}
    for _,entry in ipairs(fallback.sources) do bundled[entry.id]=entry end
    for _,entry in ipairs(catalog.sources) do
        present[entry.id]=true
        if not entry.icon_url and bundled[entry.id] then entry.icon_url=bundled[entry.id].icon_url end
    end
    for _,entry in ipairs(fallback.sources) do
        if not present[entry.id] then
            catalog.sources[#catalog.sources+1]=entry
            present[entry.id]=true
        end
    end
    return catalog
end
function Repos.open(store)
    local raw=store:readSetting("marumanga_repositories") or {version=1,items={}}
    if type(raw)~="table" or raw.version~=1 or type(raw.items)~="table" or #raw.items>50 then return nil,"Invalid repository settings" end
    for _,repo in ipairs(raw.items) do
        if type(repo)~="table" or not valid_url(repo.url) or (repo.title~=nil and (type(repo.title)~="string" or #repo.title>100)) then return nil,"Invalid repository settings" end
        if repo.catalog then local catalog=validate(repo.catalog); if not catalog then return nil,"Invalid saved repository catalog" end; repo.catalog=catalog end
    end
    local default=raw.default_repository
    if default==false then
        -- Explicit false is a persisted user deletion; do not recreate the bundled repository.
    elseif default~=nil then
        if type(default)~="table" or not valid_url(default.url) then return nil,"Invalid default repository" end
        if default.catalog then
            local catalog=validate(default.catalog)
            if not catalog or catalog.id~="maru-official" then return nil,"Invalid default repository catalog" end
            default.catalog=merge_builtin_fallback(default,catalog)
        else default.catalog=assert(validate(builtin.catalog)) end
        default.title=default.title or "MaruManga Repository"
        default.catalog.name="MaruManga Repository"
    else
        default={url=DEFAULT_URL,builtin=true,catalog=assert(validate(builtin.catalog))}
        for i=#raw.items,1,-1 do
            local candidate=raw.items[i]
            if candidate.url==DEFAULT_URL then
                if candidate.catalog and candidate.catalog.id~="maru-official" then return nil,"Invalid default repository catalog" end
                if candidate.catalog then default.catalog=candidate.catalog end
                table.remove(raw.items,i)
            end
        end
        raw.default_repository=default
    end
    if type(default)=="table" then
        default.builtin=true
        default.title=default.title or "MaruManga Repository"
        default.catalog.name="MaruManga Repository"
    end
    return setmetatable({store=store,data=raw},Repos)
end
function Repos:save()
    self.store:saveSetting("marumanga_repositories",self.data)
    local ok,result=pcall(self.store.flush,self.store); if not ok or result==false then return nil,"Unable to save repositories" end
    return true
end
function Repos:list()
    local all={}; if type(self.data.default_repository)=="table" then all[#all+1]=self.data.default_repository end; for _,repo in ipairs(self.data.items) do all[#all+1]=repo end; return all
end
function Repos:add(url)
    if not valid_url(url) then return nil,"Enter a valid HTTPS catalog URL" end
    if url==DEFAULT_URL and type(self.data.default_repository)=="table" then return nil,"Repository already exists" end
    for _,repo in ipairs(self.data.items) do if repo.url==url then return nil,"Repository already exists" end end
    local repo={url=url,title=nil}; self.data.items[#self.data.items+1]=repo
    local ok,err=self:save(); if not ok then table.remove(self.data.items); return nil,err end
    return repo
end
function Repos:edit(repo,title,url)
    if type(title)~="string" or title=="" or #title>100 or title:find("[%c]") then return nil,"Enter a repository title (1–100 characters)" end
    if not valid_url(url) then return nil,"Enter a valid HTTPS catalog URL" end
    local default=self.data.default_repository
    if type(default)=="table" and default~=repo and default.url==url then return nil,"Repository URL already exists" end
    for _,other in ipairs(self.data.items) do if other~=repo and other.url==url then return nil,"Repository URL already exists" end end
    local old_title,old_url=repo.title,repo.url; repo.title,repo.url=title,url
    local ok,err=self:save(); if not ok then repo.title,repo.url=old_title,old_url; return nil,err end
    return true
end
function Repos:update(repo,catalog)
    local clean,err=validate(catalog); if not clean then return nil,err end
    local old=repo.catalog
    if old and clean.id~=old.id then return nil,"Repository identity changed" end
    if old and version_less(clean.version,old.version) then return nil,"Repository version moved backwards" end
    clean=merge_builtin_fallback(repo,clean)
    repo.catalog=clean
    local ok,why=self:save(); if not ok then repo.catalog=old; return nil,why end
    return true
end
function Repos:remove(repo)
    if self.data.default_repository==repo then
        self.data.default_repository=false
        local ok,err=self:save()
        if not ok then self.data.default_repository=repo; return nil,err end
        return true
    end
    for i,item in ipairs(self.data.items) do if item==repo then table.remove(self.data.items,i); local ok,err=self:save(); if not ok then table.insert(self.data.items,i,item); return nil,err end; return true end end
    return nil,"Repository not found"
end
Repos.validate=validate
Repos.versionLess=version_less
Repos.DEFAULT_URL=DEFAULT_URL
return Repos
