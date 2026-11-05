local responses={}
package.preload.json=function() return {decode=function(body) assert(responses[body],"unexpected fixture body"); return responses[body] end} end
local Source=dofile("sources/mangamost/source.lua")
local Repos=dofile("core/repositories.lua")
local store={readSetting=function() end,saveSetting=function() end,flush=function() end}
local profile
for _,entry in ipairs(assert(Repos.open(store)):list()[1].catalog.sources) do if entry.id=="mangamost" then
    assert(not entry.nsfw and entry.adapter=="mangamost")
    profile={id=entry.id,name=entry.name,base_url=entry.base_url,api_url=entry.profile.api_url,image_hosts=entry.profile.image_hosts}
end end
local requested
local source=Source.new(profile,nil,{get=function(_,url,cb) requested=url; cb("fixture") end})
assert(source:getId()=="mangamost" and source:getName()=="MangaMost" and source:getBaseUrl()=="https://mangamost.com" and source:getLanguages()[1]=="en")
assert(dofile("sources/source_interface.lua").validate(source))
responses.fixture={data={{id=8,title="The Exorcist's Maid",slug="the-exorcists-maid",cover_url="https://mangamost.com/storage/manga/series/8/cover.webp",author_text="Writer",status_text="Ongoing",genres={"Action"}}}}
source:getPopularManga(1,function(r) assert(r and r.items[1].title=="The Exorcist's Maid" and r.items[1].source_id=="mangamost" and r.items[1].cover_url and not r.has_next) end)
assert(requested=="https://mangamost.com/api/v1/comics/trending?limit=30&offset=0")
source:getLatestUpdates(2,function(r) assert(r and r.page==2 and r.items[1].id=="8") end)
assert(requested=="https://mangamost.com/api/v1/comics/new-releases?limit=30&offset=30")
responses.fixture={data={query="maid",series={{id=8,title="The Exorcist's Maid",cover_url="https://mangamost.com/storage/cover.webp"}}}}
source:searchManga("maid & witch",1,function(r) assert(r and #r.items==1 and r.items[1].id=="8" and not r.has_next) end)
assert(requested=="https://mangamost.com/api/v1/search/suggestions?q=maid%20%26%20witch")
responses.fixture={data={id=8,title="The Exorcist's Maid",description="Story",author_text="Writer",status_text="Ongoing",genres={"Action"},chapters_count=31}}
source:getMangaDetails({id=8},function(r) assert(r and r.title=="The Exorcist's Maid" and r.author=="Writer" and r.chapters_count==31) end)
assert(requested=="https://mangamost.com/api/v1/comics/8")
local chapters={}; for i=1,30 do chapters[i]={id=i,manga_series_id=8,chapter_label="Episode "..i,chapter_number=i,published_at="2026-01-01"} end
responses.fixture={data=chapters}
source:getChapterList({id="8"},1,function(r) assert(r and #r.items==30 and r.items[30].manga_id=="8" and r.has_next) end)
assert(requested=="https://mangamost.com/api/v1/comics/8/chapters?limit=30&offset=0")
responses.fixture={data={{id=31,manga_series_id=8,chapter_label="Episode 31",chapter_number=31}}}
source:getChapterList({id="8"},2,function(r) assert(r and #r.items==1 and not r.has_next) end)
assert(requested=="https://mangamost.com/api/v1/comics/8/chapters?limit=30&offset=30")
responses.fixture={data={series={id=8},chapter={id=96},pages={{page_order=1,image_url="https://mangamost.com/storage/manga/series/8/chapters/96/page-0001.webp",referer="https://mangamost.com/comics/8"}}}}
source:getPageList({id="96",manga_id="8"},function(r) assert(r and #r==1 and r[1].index==1 and r[1].referer) end)
assert(requested=="https://mangamost.com/api/v1/comics/8/chapters/96")
source:_get("https://mangamost.com.evil.invalid/api/v1/comics",function(r,e) assert(not r and e) end)
responses.fixture={message="bad",data="not an object"}; source:_get("https://mangamost.com/api/v1/home",function(r,e) assert(not r and e) end)
print("MangaMost API source tests passed")
