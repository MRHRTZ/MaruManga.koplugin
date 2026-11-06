local Source=dofile("sources/komiku/source.lua")
local Parser=dofile("sources/komiku/parser.lua")
local Interface=dofile("sources/source_interface.lua")
local html=require("htmlparser"); local url=require("socket.url")
local function plain_text(value) return (value:gsub("<[^>]*>","")) end
local profile={id="komiku",name="Komiku",base_url="https://komiku.org",api_url="https://api.komiku.org",languages={"id"},title_selector="h1",description_selector="#Sinopsis > p",author_selector="table.inftable tr > td:contains(Author) + td",artist_selector="table.inftable tr > td:contains(Artist) + td",status_selector="table.inftable tr > td:contains(Status) + td"}
local parser=Parser.new(html,url.absolute,plain_text,profile,function(value) return value end)
assert(profile.list_selector=="div.bge" and profile.list_link_selector=="a" and profile.list_title_selector=="h3" and profile.list_cover_selector=="img")
assert(profile.chapter_selector=="#Daftar_Chapter tr" and profile.chapter_link_selector=="a" and profile.chapter_attribute=="href")
assert(profile.page_selector=="#Baca_Komik img" and profile.page_attribute=="src")
local function response(body) return function(_,request_url,callback) callback(body) end end
local list_html='<div class="bge"><a href="/manga/naruto/"><img src="https://thumbnail.komiku.org/naruto.jpg"><h3>Naruto</h3></a><div class="new1"><a><span>Awal:</span><span>Chapter 1</span></a></div><div class="new1"><a><span>Terbaru:</span><span>Chapter 23</span></a></div></div>'
local transport={get=response(list_html)}
local source=Source.new(profile,parser,transport)
assert(Interface.validate(source)); assert(source:getLanguages()[1]=="id")
source:searchManga("one piece & more",2,function(result) assert(result.page==2 and #result.items==1 and result.items[1].url=="https://komiku.org/manga/naruto/" and result.items[1].id=="naruto" and result.items[1].id:match("^[%w_-]+$") and result.items[1].cover_url=="https://thumbnail.komiku.org/naruto.jpg" and result.items[1].latest_chapter=="Chapter 23") end)
source:getPopularManga(3,function(result) assert(result.page==3) end)

local chapter_html='<h1>Naruto</h1><div id="Sinopsis"><p>Shinobi story</p></div><table id="Daftar_Chapter"><tr><td class="judulseries"><a href="/manga/naruto/chapter-10/">Chapter 10</a></td></tr><tr><td class="judulseries"><a href="/manga/naruto/chapter-2/">Chapter 2</a></td></tr></table>'
local details_html='<h1><span itemprop="name">Naruto</span></h1><p class="desc" itemprop="description">Shinobi story</p><meta itemprop="creativeWorkStatus" content="Ongoing"><section id="Informasi"><div class="ims"><img src="https://thumbnail.komiku.to/naruto.jpg?w=500" itemprop="image"></div></section><table class="inftable"><tr><td>Author:</td><td>Masashi Kishimoto</td></tr><tr><td>Artist:</td><td>Masashi Kishimoto</td></tr><tr><td>Status:</td><td>Ongoing</td></tr><tr><td>Genre:</td><td><ul class="genre"><li class="genre"><a><span>Action</span></a></li></ul></td></tr></table>'
transport.get=response(details_html)
source:getMangaDetails({id="naruto",title="Naruto",source_id="komiku",url="https://komiku.org/manga/naruto/"},function(detail) assert(detail.title=="Naruto" and detail.author=="Masashi Kishimoto" and detail.artist=="Masashi Kishimoto" and detail.status=="Ongoing" and detail.cover_url=="https://thumbnail.komiku.to/naruto.jpg?w=500" and detail.genres[1]=="Action") end)
transport.get=response(chapter_html)
transport.get=response(chapter_html)
source:getChapterList({id="n",url="https://komiku.org/manga/naruto/"},1,function(result) assert(#result.items==2 and result.items[1].chapter_number==10 and result.items[2].chapter_number==2) end)
source:getChapterList({id="n",url="https://komiku.org/manga/naruto/"},1,function(result) assert(result.items[1].chapter_number==2 and result.items[2].chapter_number==10) end,"asc")
local page_html='<div id="Baca_Komik"><img src="https://thumbnail.komiku.org/page1.jpg"><img src="https://thumbnail.komiku.org/komiku-promosi.png"><img src="https://thumbnail.komiku.org/page2.jpg"></div>'
transport.get=response(page_html)
source:getPageList({url="https://komiku.org/manga/naruto/chapter-2/"},function(pages) assert(#pages==2 and pages[1].index==1 and pages[2].index==2 and pages[1].referer=="https://komiku.org/manga/naruto/chapter-2/" and pages[1].headers["Accept-Language"]:match("id%-ID")) end)
source:getMangaDetails({id="x",url="https://komiku.org.evil.invalid/manga/x"},function(item,err) assert(not item and err) end)
source:getPageList({url="https://evil.invalid/chapter"},function(pages,err) assert(not pages and err) end)

local requests={}; local url_transport={get=function(_,request_url,callback) requests[#requests+1]=request_url; callback({items={},has_next=false}) end}
local url_source=Source.new(profile,{list=function() return {items={},has_next=false} end},url_transport)
url_source:searchManga("a b",2,function() end); assert(requests[1]=="https://api.komiku.org/manga/page/2/?s=a%20b")
url_source:getLatestUpdates(4,function() end); assert(requests[2]=="https://api.komiku.org/manga/page/4/?orderby=modified")
url_source:getPopularManga(2,function() end); assert(requests[3]=="https://api.komiku.org/other/hot/page/2/?orderby=meta_value_num")
print("Komiku adapter tests passed")
