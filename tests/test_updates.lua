local Updates=dofile("core/updates.lua")
local mangas={{id="a",source_id="one",title="A"},{id="b",source_id="bad",title="B"}}
local source={getChapterList=function(_,m,_,cb) cb({items={{id="c",manga_id=m.id,name="Chapter 1",upload_date=3}}}) end}
local result; Updates.fetch(mangas,function(id) return id=="one" and source or nil end,function(r) result=r end)
assert(#result.items==1 and result.items[1].manga.id=="a" and #result.errors==1)
print("Library update tests passed")

local bad={getChapterList=function(_,_,_,cb) cb({items=false}) end}; Updates.fetch({mangas[1]},function() return bad end,function(r) assert(#r.errors==1) end)
