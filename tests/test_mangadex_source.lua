local Parser = dofile("sources/mangadex/parser.lua")
local Source = dofile("sources/mangadex/source.lua")
local transport = {}
function transport:get(url, callback) self.url = url; callback(self.response, self.err) end
local source = Source.new(transport, Parser, "en")
transport.response = {data={{id="id",attributes={title={en="Test"}}}}, offset=20, total=50}
source:searchManga("a & b", 2, function(result, err) assert(not err and result.items[1].title == "Test" and result.has_next) end)
assert(transport.url:find("offset=20", 1, true) and transport.url:find("a%20%26%20b", 1, true))
local id = "01234567-89ab-cdef-0123-456789abcdef"
transport.response = {data={}, offset=0, total=0}
source:getChapterList({id=id}, 1, function(result) assert(not result.has_next) end)
assert(transport.url:find("translatedLanguage%5B%5D=en", 1, true))
source:getPageList({id="../bad"}, function(result, err) assert(not result and err) end)
transport.response = nil; transport.err = "HTTP 429"
source:getPopularManga(1, function(result, err) assert(not result and err == "HTTP 429") end)
print("MangaDex source tests passed")

transport.err=nil; transport.response={data={},offset="bad",total=1}
source:getPopularManga(1,function(result,err) assert(not result and err=="Invalid list pagination") end)
local faulty=Source.new(transport,{manga=function() error("bad parser") end,pages=function() error("bad parser") end},"en")
transport.response={data={{}},offset=0,total=1}; faulty:getPopularManga(1,function(result,err) assert(not result and err=="Invalid source response") end)
transport.response={}; faulty:getPageList({id=id},function(result,err) assert(not result and err=="Invalid page response") end)
