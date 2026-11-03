local parser = dofile("sources/mangadex/parser.lua")
local m = parser.manga({id="abc", attributes={title={en="Title"}, tags={}}, relationships={}})
assert(m.title == "Title" and m.cover_url == nil)
local c = parser.chapter({id="c", attributes={chapter="2", title="Test"}, relationships={{type="scanlation_group", attributes={name="Group"}}}}, "abc")
assert(c.name == "Chapter 2: Test" and c.scanlator == "Group")
local pages = assert(parser.pages({baseUrl="https://node.mangadex.network", chapter={hash="ab12", data={"1.jpg", "2.png"}}}))
assert(#pages == 2 and pages[2].image_url == "https://node.mangadex.network/data/ab12/2.png")
assert(not parser.pages({baseUrl="x", chapter={hash="ab", data={"../bad"}}}))
assert(not parser.pages({baseUrl="x", chapter={hash="ab", data={}}}))
print("MangaDex parser tests passed")

assert(not parser.pages({baseUrl="http://unsafe", chapter={hash="ab", data={"1.jpg"}}}))
assert(not parser.pages({baseUrl="https://node.mangadex.network", chapter={hash="../bad", data={"1.jpg"}}}))

local dated=parser.chapter({id="c",attributes={chapter="1",publishAt="2020-01-01T00:00:00+00:00"}},"m"); assert(dated.upload_date==1577836800)

local nonutc=parser.chapter({id="c",attributes={publishAt="2020-01-01T00:00:00+05:00"}},"m"); assert(nonutc.upload_date==nil)

local malformed=parser.manga({id="m",attributes=function() end,relationships={false}}); assert(malformed and malformed.title=="")
assert(not parser.manga({id="m",attributes={},relationships={{type="cover_art",attributes={fileName="../evil"}}}}).cover_url)

local token=assert(parser.pages({baseUrl="https://node.mangadex.network:12345/token",chapter={hash="ab12",data={"1.jpg"}}})); assert(token[1].image_url=="https://node.mangadex.network:12345/token/data/ab12/1.jpg")
assert(not parser.pages({baseUrl="https://node.mangadex.network/../evil",chapter={hash="ab",data={"1.jpg"}}}))

assert(not parser.chapter({id="c",attributes={externalUrl="https://external.example/chapter"}},"m"))
