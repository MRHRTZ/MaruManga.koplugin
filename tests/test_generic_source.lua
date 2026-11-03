local Source=dofile("sources/generic/source.lua"); local interface=dofile("sources/source_interface.lua")
local transport={get=function(self,url,cb) self.url=url; cb("html") end}
local parser={list=function() return {items={},has_next=false} end,details=function(_,_,_,m) return m end,chapters=function() return {} end,pages=function() return {{index=1}} end}
local s=Source.new({id="test",name="Fixture",base_url="https://example.org",search_path="/search?q={query}&p={page}"},parser,transport)
assert(interface.validate(s)); s:searchManga("a & b",2,function(result) assert(result.page==2) end)
assert(transport.url=="https://example.org/search?q=a%20%26%20b&p=2")
s:getPopularManga(1,function(result,err) assert(not result and err) end)
print("Generic source tests passed")

s:getMangaDetails({url="https://example.org.evil.invalid/"},function(result,err) assert(not result and err) end)
