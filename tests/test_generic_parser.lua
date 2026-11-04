local parser=dofile("sources/generic/parser.lua")
local html=require("htmlparser"); local url=require("socket.url")
local clean=function(s) return (s:gsub("<[^>]*>","")) end
local p=parser.new(html,url.absolute,clean,{id="fixture",list_selector=".book",list_link_selector="a",next_selector="a.next",title_selector="h1",description_selector=".desc",chapter_selector="a.chapter",page_selector="img.page",page_attribute="data-src"})
local results=assert(p:list('<div class="book"><a href="/book/a"><img data-src="https://cdn.example.org/cover.jpg"/><span>Title</span></a></div><a class="next" href="?p=2">Next</a>',"https://example.org/list"))
assert(results.items[1].url=="https://example.org/book/a" and results.items[1].cover_url=="https://cdn.example.org/cover.jpg" and results.has_next)
local detail_html='<h1>Title</h1><p class="desc">Description</p><meta itemprop="creativeWorkStatus" content="Ongoing"/><div class="cover"><img src="https://cdn.example.org/detail.jpg"/></div><table class="info"><tr><td>Author:</td><td>Writer</td></tr><tr><td>Artist:</td><td>Illustrator</td></tr><tr><td>Status:</td><td>Ongoing</td></tr></table>'
local metadata_parser=parser.new(html,url.absolute,clean,{id="fixture",title_selector="h1",description_selector=".desc",status_selector='meta[itemprop=creativeWorkStatus]',cover_selector=".cover img",metadata_row_selector="table.info tr"})
local details=assert(metadata_parser:details(detail_html,"https://example.org/book/a",results.items[1]))
assert(details.title=="Title" and details.description=="Description" and details.author=="Writer" and details.artist=="Illustrator" and details.status=="Ongoing" and details.cover_url=="https://cdn.example.org/detail.jpg")
local chapters=assert(p:chapters('<a class="chapter" href="/chapter/1">Chapter 1</a>',details.url,details)); assert(chapters[1].manga_id==details.id)
local pages=assert(p:pages('<img class="page" data-src="/img/1.jpg"/><img class="page" data-src="/img/2.jpg"/>',chapters[1].url)); assert(#pages==2 and pages[2].index==2)
assert(not p:pages('<p>nothing</p>',chapters[1].url))
local large_html=string.rep("<i>noise</i>",3000)..'<div class="book"><a href="/book/large">Large page</a></div>'
local large=assert(p:list(large_html,"https://example.org/list")); assert(large.items[1] and large.items[1].url=="https://example.org/book/large")
print("Generic HTML profile tests passed")
