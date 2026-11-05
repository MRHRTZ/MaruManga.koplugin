local Source=dofile("sources/mangarock/source.lua")
local Parser=dofile("sources/mangarock/parser.lua")
local html=require("htmlparser"); local url=require("socket.url")
local Repos=dofile("core/repositories.lua")
local store={readSetting=function() end,saveSetting=function() end,flush=function() end}
local catalog=assert(Repos.open(store)):list()[1].catalog
local profile
for _,entry in ipairs(catalog.sources) do
    if entry.id=="mangarock" then
        profile={id=entry.id,name=entry.name,base_url=entry.base_url}
        for k,v in pairs(entry.profile) do profile[k]=v end
    end
end
assert(profile)
local parser=Parser.new(html,url.absolute,function(s) return (s:gsub("<[^>]*>","")) end,profile)
local body,requested
local source=Source.new(profile,parser,{get=function(_,u,cb) requested=u; cb(body) end})
assert(dofile("sources/source_interface.lua").validate(source))
body='<div class="listupd"><div class="bs"><a href="/manga/test-book"><img src="https://llma.zogana.lol/cover.jpg"><div class="tt">Test Book</div></a></div></div><a rel="next" href="?page=2">Next</a>'
source:searchManga("a & b",2,function(r) assert(r and #r.items==1 and r.items[1].title=="Test Book" and r.has_next) end)
assert(requested=="https://mangarock.one/search?q=a%20%26%20b&page=2")
body='<div class="popularslider"><div class="bs"><a href="/manga/popular"><div class="tt">Popular</div></a></div></div><div class="listupd"><div class="bs"><a href="/manga/unrelated"><div class="tt">Unrelated</div></a></div></div><a rel="next" href="?page=2">Next</a>'
source:getPopularManga(1,function(r) assert(r and #r.items==1 and r.items[1].title=="Popular" and not r.has_next) end)
assert(requested=="https://mangarock.one/")
source:getPopularManga(2,function(r) assert(r and #r.items==0 and not r.has_next) end)
local manga={id="test",url="https://mangarock.one/manga/test-book"}
body='<h1 class="entry-title">Test Book</h1><meta name="description" content="Story"><div class="seriestucontl"><div class="thumb"><img src="https://llma.zogana.lol/cover.jpg"></div></div><table class="infotable"><tr><td>Author</td><td>Writer</td></tr><tr><td>Status</td><td>Ongoing</td></tr></table>'
source:getMangaDetails(manga,function(r) assert(r and r.title=="Test Book" and r.description=="Story" and r.author=="Writer" and r.status=="Ongoing" and r.cover_url) end)
local function batch(more,offset,chapter)
    return '<span class="chapter-batch-meta" data-has-more="'..more..'" data-next-offset="'..offset..'"></span><div class="eph-num"><a href="/read/test-book/en/chapter-'..chapter..'">Chapter '..chapter..'</a></div>'
end
body=batch("true",100,10)
source:getChapterList(manga,1,function(r) assert(r and r.has_next and r.items[1].chapter_number==10) end)
assert(requested:match("offset=0$"))
body=batch("false",101,2)
source:getChapterList(manga,2,function(r) assert(r and not r.has_next and r.page==2 and r.items[1].chapter_number==2) end)
assert(requested:match("offset=100$"))
source:getChapterList(manga,3,function(r,e) assert(not r and e) end)
for _,invalid in ipairs({'<html>challenge</html>',batch("true",0,1),batch("true",100,1):gsub('/en/','/es/'),batch("true",100,1):gsub('test%-book/en','other/en')}) do
    body=invalid; source:getChapterList(manga,1,function(r,e) assert(not r and e) end)
end
body='<img class="ts-main-image" src="https://llma.zogana.lol/001.jpg"><img class="ts-main-image" src="https://llma.zogana.lol/002.jpg"><img src="https://ads.invalid/ad.jpg">'
source:getPageList({url="https://mangarock.one/read/test-book/en/chapter-1"},function(r) assert(r and #r==2 and r[2].index==2 and r[1].referer) end)
source:getChapterList({url="https://evil.invalid/manga/test"},1,function(r,e) assert(not r and e) end)
source:_get("https://mangarock.one.evil.invalid/",function(r,e) assert(not r and e) end)
print("MangaRock source and pagination tests passed")
