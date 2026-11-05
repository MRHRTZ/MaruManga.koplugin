local Source=dofile("sources/webtoon/source.lua")
local Parser=dofile("sources/generic/parser.lua")
local html=require("htmlparser"); local url=require("socket.url")
local profile={id="webtoon",name="WEBTOON",base_url="https://www.webtoons.com",languages={"en"},search_path="/en/search?keyword={query}&page={page}",popular_path="/en/ranking?rankingGenre=ALL&page={page}",latest_path="/en/originals?sortOrder=UPDATE&page={page}",list_selector="ul.webtoon_list li",list_link_selector="a._card_item",list_title_selector=".title",list_cover_selector="img",next_selector=".paginate a.pg_next",title_selector=".detail_header h1.subj",description_selector="p.summary",author_selector=".author_area",genre_selector=".detail_header h2.genre",cover_selector=".detail_header .thmb img",chapter_selector="#_listUl ._episodeItem",chapter_link_selector="a.detail_list_link",chapter_title_selector=".subj",page_selector="img._images",page_attribute="data-url",image_hosts={"webtoon-phinf.pstatic.net"}}
local parsed=Parser.new(html,url.absolute,function(s) return (s:gsub("<[^>]*>","")) end,profile)
local body,requested
local source=Source.new(profile,parsed,{get=function(_,u,cb) requested=u; cb(body) end},html)
assert(dofile("sources/source_interface.lua").validate(source))
body='<ul class="webtoon_list"><li><a class="_card_item" href="https://www.webtoons.com/en/romance/sample/list?title_no=11014"><strong class="title">Sample</strong><img src="https://webtoon-phinf.pstatic.net/cover.jpg"></a></li></ul>'
source:searchManga("sample & title",2,function(r) assert(r and r.items[1].title=="Sample" and r.items[1].cover_url and r.page==2) end)
assert(requested=="https://www.webtoons.com/en/search?keyword=sample%20%26%20title&page=2")
body='<ul class="webtoon_list"><li><a class="link _ranking_title_a" href="https://www.webtoons.com/en/fantasy/tower-of-god/list?title_no=95"><strong class="title">Tower of God</strong><img src="https://webtoon-phinf.pstatic.net/tower.jpg"></a></li></ul>'
source:getPopularManga(1,function(r) assert(r and #r.items==1 and r.items[1].title=="Tower of God" and r.items[1].cover_url) end)
assert(requested=="https://www.webtoons.com/en/ranking?rankingGenre=ALL&page=1")
body='<ul class="webtoon_list"><li><a class="link _originals_title_a" href="https://www.webtoons.com/en/comedy/sample/list?title_no=2724"><strong class="title">Vibe Check!</strong><img src="https://webtoon-phinf.pstatic.net/sample.jpg"></a></li></ul>'
source:getLatestUpdates(1,function(r) assert(r and #r.items==1 and r.items[1].title=="Vibe Check!" and r.items[1].cover_url) end)
assert(requested=="https://www.webtoons.com/en/originals?sortOrder=UPDATE&page=1")
local manga={id="11014",title="Sample",url="https://www.webtoons.com/en/romance/sample/list?title_no=11014",source_id="webtoon"}
body='<div class="detail_header"><h1 class="subj">Sample</h1><h2 class="genre">Romance</h2><div class="author_area">Creator <button>author info</button></div><span class="thmb"><img src="https://webtoon-phinf.pstatic.net/cover.jpg"></span></div><p class="summary">Description</p><ul id="_listUl"><li class="_episodeItem"><a class="detail_list_link" href="https://www.webtoons.com/en/romance/sample/episode-10/viewer?title_no=11014&amp;episode_no=10"><span class="subj">Episode 10 — Calm Before the Storm</span><span class="date">Jan 1, 2026</span><span class="like_area">like 1,234</span><span class="tx">#10</span></a></li></ul><div class="paginate"><a class="pg_next" href="?page=2">Next</a></div>'
source:getMangaDetails(manga,function(r) assert(r and r.title=="Sample" and r.description=="Description" and r.cover_url and r.author=="Creator") end)
source:getChapterList(manga,1,function(r) assert(r and #r.items==1 and r.items[1].chapter_number==10 and r.items[1].name=="Episode 10 — Calm Before the Storm" and r.has_next) end)
assert(requested==manga.url.."&page=1")
body='<ul id="_listUl"><li class="_episodeItem"><a class="detail_list_link" href="https://www.webtoons.com/en/romance/sample/episode-1/viewer?title_no=11014&amp;episode_no=1"><span>Episode 1</span></a></li></ul><div class="paginate"><span class="pg_next off">Next</span></div>'
source:getChapterList(manga,2,function(r) assert(r and r.items[1].chapter_number==1 and not r.has_next) end)
assert(requested==manga.url.."&page=2")
body='<img class="_images" data-url="https://webtoon-phinf.pstatic.net/page-001.jpg?type=q90"><img class="_images" data-url="https://webtoon-phinf.pstatic.net/page-002.jpg?type=q90">'
source:getPageList({url="https://www.webtoons.com/en/romance/sample/episode-10/viewer?title_no=11014&episode_no=10"},function(r) assert(r and #r==2 and r[1].image_url:match("page%-001") and r[1].referer) end)

local id_profile={}; for k,v in pairs(profile) do id_profile[k]=v end
id_profile.id="webtoon_id"; id_profile.name="WEBTOON ID"; id_profile.locale="id"
id_profile.search_path="/id/search?keyword={query}&page={page}"
id_profile.popular_path="/id/ranking?rankingGenre=ALL&page={page}"
id_profile.latest_path="/id/originals?sortOrder=UPDATE&page={page}"
local id_source=Source.new(id_profile,Parser.new(html,url.absolute,function(s) return (s:gsub("<[^>]*>","")) end,id_profile),{get=function(_,u,cb) requested=u; cb(body) end},html)
assert(dofile("sources/source_interface.lua").validate(id_source))
body='<ul class="webtoon_list"><li><a class="_card_item" href="https://www.webtoons.com/id/action/lookism/list?title_no=532"><strong class="title">Lookism</strong><img src="https://webtoon-phinf.pstatic.net/cover-id.jpg"></a></li></ul>'
id_source:searchManga("lookism",1,function(r) assert(r and #r.items==1 and r.items[1].title=="Lookism" and r.items[1].source_id=="webtoon_id") end)
assert(requested=="https://www.webtoons.com/id/search?keyword=lookism&page=1")
local id_manga={id="532",title="Lookism",url="https://www.webtoons.com/id/action/lookism/list?title_no=532",source_id="webtoon_id"}
body='<div class="detail_header"><h1 class="subj">Lookism</h1><h2 class="genre">Action</h2><div class="author_area">Park Tae-jun</div><span class="thmb"><img src="https://webtoon-phinf.pstatic.net/cover-id.jpg"></span></div><p class="summary">Indonesian description</p><ul id="_listUl"><li class="_episodeItem"><a class="detail_list_link" href="https://www.webtoons.com/id/action/lookism/ep-624-kim-gabryong-15/viewer?title_no=532&amp;episode_no=625"><span>Episode 625</span></a></li></ul><div class="paginate"><span class="pg_next off">Next</span></div>'
id_source:getMangaDetails(id_manga,function(r) assert(r and r.title=="Lookism" and r.description=="Indonesian description") end)
id_source:getChapterList(id_manga,1,function(r) assert(r and #r.items==1, "rows="..tostring(r and #r.items)); assert(r.items[1].chapter_number==625, "number="..tostring(r.items[1].chapter_number).." url="..tostring(r.items[1].url)); assert(r.items[1].url:match("/id/action/lookism/")) end)
assert(requested==id_manga.url.."&page=1")
body='<img class="_images" data-url="https://webtoon-phinf.pstatic.net/lookism-id-001.png?type=q90">'
id_source:getPageList({url="https://www.webtoons.com/id/action/lookism/ep-624/viewer?title_no=532&episode_no=625"},function(r) assert(r and #r==1 and r[1].image_url:match("lookism%-id%-001") and r[1].referer) end)
print("WEBTOON public-page adapter tests passed")
