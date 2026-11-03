local Store=dofile("storage/library.lua")
local settings={readSetting=function(self) return self.data end,saveSetting=function(self,_,v) self.data=v end,flush=function() end}
local s=assert(Store.open(settings))
assert(s:add({id="1",source_id="mangadex",title="Z"})); assert(s:add({id="2",source_id="mangadex",title="A"})); assert(s:list()[1].title=="A")
assert(not s:add({id="../bad",source_id="x",title="bad"}))
local m={id="1",source_id="mangadex",title="Z"}; local c={id="a",name="1"}
assert(s:record(m,c,2,100)); assert(s:record(m,c,4,101)); assert(#s.data.history==1 and s.data.history[1].page==4)
assert(not s:record(m,c,0)); assert(s:remove("mangadex","1")); assert(#s:list()==1)
assert(not Store.open({readSetting=function() return {version=2} end}))
print("Library persistence tests passed")

assert(s:linkArchive("/tmp/a.cbz",m,c)); assert(s:recordArchivePage("/tmp/a.cbz",7)); assert(s.data.history[1].page==7)
assert(not s:recordArchivePage("/tmp/other.cbz",1))

assert(s:linkArchive("/tmp/b.cbz",m,c,10)); assert(s:recordArchivePage("/tmp/b.cbz",10)); assert(s:chapterStatus("mangadex","a").read); assert(s:setChapterRead("mangadex","a",false)); assert(not s:chapterStatus("mangadex","a").read)

assert(s:unlinkArchive("/tmp/b.cbz")); assert(not s.data.archives["/tmp/b.cbz"])

assert(#s:list("a")==1 and s:list("a")[1].title=="A")

assert(s:add({id="1",source_id="mangadex",title="Z"})); assert(s:list(nil,"recent")[1].title=="Z")

local archived="/old/manga/mangadex/1/chapters/a.cbz"; assert(s:linkArchive(archived,m,c,3)); assert(s:archiveFor("mangadex","1","a")==archived); assert(not s:archiveFor("../bad","1","a"))

assert(s:add({id="3",source_id="s",title="M",url="https://example.org/m",author="Author",genres={"Action"}})); assert(s.data.manga["s:3"].url=="https://example.org/m" and s.data.manga["s:3"].genres[1]=="Action")

assert(s:cacheChapters(m,{{id="chapter2",manga_id="1",name="Chapter 2",chapter_number=2}})); assert(s:chapterStatus("mangadex","chapter2").metadata.chapter_number==2)

local unread=s:list(nil,nil,"unread"); assert(#unread==1 and unread[1].id=="1"); local filtered=s:list(nil,nil,"source","s"); assert(#filtered==1 and filtered[1].source_id=="s")
