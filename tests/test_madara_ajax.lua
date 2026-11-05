local Source=dofile("sources/generic/source.lua")
local transport={post=function(self,url,body,headers,cb) self.url=url; assert(body=="" and headers["X-Requested-With"]=="XMLHttpRequest"); cb("html") end}
local parser={chapters=function() return {{id="2",name="Chapter 2",chapter_number=2},{id="1",name="Chapter 1",chapter_number=1}} end}
local s=Source.new({id="x",name="X",base_url="https://example.org",chapter_mode="ajax"},parser,transport)
s:getChapterList({id="m",url="https://example.org/manga/m"},1,function(result) assert(result.items[1].chapter_number==1) end,"asc")
assert(transport.url=="https://example.org/manga/m/ajax/chapters/")
print("Generic AJAX chapter tests passed")

local template={id="x",name="X",base_url="https://example.org",search_path="/page/{page}/?s={query}&post_type=wp-manga",popular_path="/manga/?m_orderby=views"}; local t={get=function(self,url,cb) self.url=url; cb("x") end}; local p={list=function() return {items={}} end}; local source=Source.new(template,p,t); source:searchManga("abc",2,function() end); assert(t.url=="https://example.org/page/2/?s=abc&post_type=wp-manga"); source:getPopularManga(1,function() end); assert(t.url=="https://example.org/manga/?m_orderby=views")
