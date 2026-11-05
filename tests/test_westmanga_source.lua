local Source=dofile("sources/westmanga/source.lua")
local Parser=dofile("sources/generic/parser.lua")
local html=require("htmlparser"); local url=require("socket.url")
local Repos=dofile("core/repositories.lua")
local decoded={}
package.preload.json=function() return {decode=function(body) assert(decoded[body],"unexpected WestManga fixture response"); return decoded[body] end} end
local store={readSetting=function() end,saveSetting=function() end,flush=function() end}
local catalog=assert(Repos.open(store)):list()[1].catalog
local profile
for _,entry in ipairs(catalog.sources) do if entry.id=="westmanga" then
    assert(entry.adapter=="westmanga" and entry.nsfw==false)
    profile={id=entry.id,name=entry.name,base_url=entry.base_url,api_url=entry.profile.api_url,languages=entry.languages}
    for k,v in pairs(entry.profile) do profile[k]=v end
end end
assert(profile and profile.base_url=="https://www.westmanga.shop")
local parser=Parser.new(html,url.absolute,function(s) return (s:gsub("<[^>]*>","")) end,profile)
local response,requested
local source=Source.new(profile,parser,{get=function(_,u,cb) requested=u; cb(response) end})
assert(dofile("sources/source_interface.lua").validate(source))
decoded.manga={success=true,total=25,page=2,limit=24,totalPages=3,mangas={{id="m-cdn-one-piece",slug="one-piece",title="One Piece",coverUrl="https://cdn.westmanga.shop/mangas/one-piece/cover.webp",synopsis="Pirate story",author="Eiichiro Oda",status="ONGOING",genres={"Adventure"},totalChapters=1214,latestChapter={number=1195,title="Chapter 1195"}}}}
response="manga"
source:searchManga("One Piece",2,function(r) assert(r and #r.items==1 and r.items[1].title=="One Piece" and r.items[1].cover_url and r.page==2 and r.has_next) end)
assert(requested=="https://www.westmanga.shop/api/manga?page=2&limit=24&sort=latest&q=One%20Piece")
source:getPopularManga(1,function(r) assert(r and r.items[1].id=="one-piece") end)
assert(requested=="https://www.westmanga.shop/api/manga?page=1&limit=24&sort=popular")
source:getLatestUpdates(1,function(r) assert(r and r.items[1].id=="one-piece") end)
source:getMangaDetails({id="one-piece",slug="one-piece"},function(r) assert(r and r.description=="Pirate story" and r.author=="Eiichiro Oda" and r.chapters_count==1214 and r.genres[1]=="Adventure") end)
assert(requested=="https://www.westmanga.shop/api/manga?page=1&limit=24&sort=latest&q=one-piece")
decoded.chapters={success=true,total=1214,page=2,limit=60,chapters={{number=1135,slug="chapter-1135",title="Chapter 1135"}}}
response="chapters"
source:getChapterList({id="one-piece",slug="one-piece",url="https://www.westmanga.shop/manga/one-piece"},2,function(r) assert(r and #r.items==1 and r.items[1].chapter_number==1135 and r.has_next) end)
assert(requested=="https://www.westmanga.shop/api/manga?slug=one-piece&chapterPage=2&chapterLimit=60&chapterOrder=desc")
response='<img src="https://proxy.westmanga.shop/api/img-proxy?url=https%3A%2F%2Fcdn.jsdelivr.net%2Fpage-001.jpg"><img src="https://proxy.westmanga.shop/api/img-proxy?url=https%3A%2F%2Fcdn.jsdelivr.net%2Fpage-002.jpg">'
source:getPageList({url="https://www.westmanga.shop/read/one-piece/chapter-1195"},function(r) assert(r and #r==2 and r[1].referer=="https://www.westmanga.shop/read/one-piece/chapter-1195") end)
source:getChapterList({id="bad",url="https://evil.example/manga/one-piece"},1,function(r,e) assert(not r and e) end)
print("WestManga source and pagination tests passed")
