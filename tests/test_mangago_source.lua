local Source=dofile("sources/mangago/source.lua")
local Parser=dofile("sources/generic/parser.lua")
local html=require("htmlparser"); local url=require("socket.url")
local Repos=dofile("core/repositories.lua")
local store={readSetting=function() end,saveSetting=function() end,flush=function() end}
local catalog=assert(Repos.open(store)):list()[1].catalog
local profile
for _,entry in ipairs(catalog.sources) do if entry.id=="mangago" then
    assert(entry.nsfw and entry.adapter=="mangago")
    profile={id=entry.id,name=entry.name,base_url=entry.base_url,languages=entry.languages}
    for k,v in pairs(entry.profile) do profile[k]=v end
end end
assert(profile and profile.base_url=="https://www.mangago.zone")
local clean=function(s) return (s:gsub("<[^>]*>","")) end
local parser=Parser.new(html,url.absolute,clean,profile)
local requested,body
local source=Source.new(profile,parser,{get=function(_,u,cb) requested=u; cb(body) end},html)
assert(source:getId()=="mangago" and source:getBaseUrl()=="https://www.mangago.zone")
assert(dofile("sources/source_interface.lua").validate(source))
body='<ul id="search_list"><li><div class="box"><div class="left"><img src="https://i2.mangapicgallery.com/cover.jpg"></div><div class="row-1"><h2><a href="/work/50093/">Sample title</a></h2></div></div></li></ul><div class="pagination" total="2"><a class="next" href="?page=2">Next</a></div>'
source:searchManga("sample & title",1,function(r) assert(r and #r.items==1 and r.items[1].title=="Sample title" and r.items[1].url:match("50093") and r.items[1].cover_url and r.has_next) end)
assert(requested=="https://www.mangago.zone/r/l_search/?name=sample%20%26%20title&page=1")
body='<div class="indexlefttop1"><h2>Featured Manga</h2><div class="pic_list"><div class="flex1 listitem"><a href="https://www.mangago.zone/work/73740/"><img data-src="https://i4.mangapicgallery.com/cover.jpg"></a></div></div></div><div class="indexlefttop1"><h2>Popular Manga</h2><div class="pic_list"><div class="flex1 listitem"><a href="https://www.mangago.zone/work/42563/"><img data-src="https://i4.mangapicgallery.com/popular.jpg"></a></div></div></div>'
profile.popular_path="/topmanga/?page={page}"
body='<div class="indexlefttop1"><h2>Random day</h2></div><div class="indexlefttop1"><h2>Yesterday\'s Top</h2><div class="pic_list"><div class="flex1 listitem"><a href="https://www.mangago.zone/work/42563/"><img data-src="https://i4.mangapicgallery.com/popular.jpg"></a></div></div></div>'
source:getPopularManga(1,function(r) assert(r and #r.items==1 and r.items[1].title=="Manga #42563" and r.items[1].cover_url) end)
assert(requested=="https://www.mangago.zone/topmanga/?page=1")
profile.latest_path="/?page={page}"
body='<div class="indexlefttop1"><h2>Featured</h2></div><div class="indexlefttop1"><h2>Popular</h2></div><div class="indexlefttop1"><h2>New Comics</h2></div><div class="indexlefttop1"><h2>Last Updates</h2><div class="pic_list"><div class="flex1 listitem"><a href="https://www.mangago.zone/work/45912/"><img data-src="https://i4.mangapicgallery.com/latest.jpg"></a></div></div></div>'
source:getLatestUpdates(1,function(r) assert(r and #r.items==1 and r.items[1].title=="Manga #45912" and r.items[1].cover_url) end)
assert(requested=="https://www.mangago.zone/?page=1")
local manga={id="sample_title",url="https://www.mangago.zone/work/50093/",source_id="mangago",title="Sample title"}
body='<div class="w-title"><h1>Sample title</h1></div><div id="information"><div class="left cover"><img src="https://i2.mangapicgallery.com/cover.jpg"></div><div class="manga_summary">A sample story</div></div><table id="chapter_table"><tbody><tr><td><a class="chico" href="/chapter/50093/2328498/">Ch.12</a></td><td>Team</td><td>Today</td></tr></tbody></table>'
source:getMangaDetails(manga,function(r) assert(r and r.title=="Sample title" and r.description=="A sample story" and r.cover_url) end)
source:getChapterList(manga,1,function(r) assert(r and #r.items==1 and r.items[1].chapter_number==12 and r.items[1].url:match("2328498")) end)
body='<div id="pic_container"><img src="https://i2.mangapicgallery.com/chapter/page.jpg"></div>'
source:getPageList({url="https://www.mangago.zone/chapter/50093/2328498/"},function(r) assert(r and #r==1 and r[1].image_url:match("page%.jpg")) end)
body='<script>var imgsrcs="not a valid manifest";</script>'
source:getPageList({url="https://www.mangago.zone/chapter/50093/2328498/"},function(r,e) assert(not r and e:match("Invalid encrypted image manifest")) end)
source:getChapterList({id="x",url="https://evil.invalid/work/50093/"},1,function(r,e) assert(not r and e) end)
print("Mangago website source tests passed")
