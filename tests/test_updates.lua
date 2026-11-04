local Updates=dofile("core/updates.lua")
local mangas={{id="a",source_id="one",title="A"},{id="b",source_id="bad",title="B"}}
local pages={}
local source={getChapterList=function(_,m,page,cb)
    pages[#pages+1]=page
    if page==1 then cb({items={{id="c",manga_id=m.id,name="Chapter 1",chapter_number=1,upload_date=3}},has_next=true})
    else cb({items={{id="c",manga_id=m.id,name="Chapter 1",chapter_number=1},{id="d",manga_id=m.id,name="Chapter 2",chapter_number=2}}}) end
end}
local result,saved,synced,missing,latest
Updates.fetch(mangas,function(id) return id=="one" and source or nil end,function(r) result=r end,{is_downloaded=function(_,ch) return ch.id=="c" end,save_chapters=function(_,list) saved=list; return true end,mark_synced=function(_,count,missing_count,latest_number) synced=count; missing=missing_count; latest=latest_number; return true end})
assert(#result.items==1 and result.items[1].chapter.id=="d" and #result.errors==1)
assert(result.counts["one:a"]==1 and #saved==2 and #pages==2 and synced==2 and missing==1 and latest==2)
local bad={getChapterList=function(_,_,_,cb) cb({items=false}) end}
local bad_marked=false
Updates.fetch({mangas[1]},function() return bad end,function(r) assert(#r.errors==1) end,{mark_synced=function() bad_marked=true end})
assert(not bad_marked)
local save_marked=false
Updates.fetch({mangas[1]},function() return source end,function(r) assert(#r.errors==1) end,{save_chapters=function() return nil,"disk full" end,mark_synced=function() save_marked=true end})
assert(not save_marked)
local many={}; for i=1,30 do many[i]={id=tostring(i),source_id="one",title="X"} end
Updates.fetch(many,function() return {getChapterList=function(_,_,_,cb) cb({items={}}) end} end,function(r) assert(#r.errors==0) end)
print("Library update pagination and reconciliation tests passed")
