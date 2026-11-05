local Store=dofile("storage/library.lua")
local settings={readSetting=function(self) return self.data end,saveSetting=function(self,_,v) self.data=v end,flush=function() end}
local s=assert(Store.open(settings))
assert(s:add({id="1",source_id="mangadex",title="Z"})); assert(s:add({id="2",source_id="mangadex",title="A"})); assert(s:list()[1].title=="A")
assert(not s:add({id="../bad",source_id="x",title="bad"}))
local m={id="1",source_id="mangadex",title="Z"}; local c={id="a",name="1"}
assert(s:record(m,c,2,100)); assert(s:record(m,c,4,101)); assert(#s.data.history==1 and s.data.history[1].page==4)
assert(not s:record(m,c,0)); assert(s:remove("mangadex","1")); assert(#s:list()==1)
assert(not Store.open({readSetting=function() return {version=2} end}))
local legacy=assert(Store.open({readSetting=function() return {version=1,manga={},history={},archives={},chapters={}} end}))
assert(type(legacy.data.chapter_sync)=="table")
local renamed=assert(Store.open({readSetting=function() return {version=1,manga={['mangago:8']={id="8",source_id="mangago",title="Legacy",url="https://mangamost.com/comics/8"}},history={{key="mangago:8",manga_id="8",source_id="mangago"}},archives={['/books/8.cbz']={manga={id="8",source_id="mangago"},chapters={{id="96",source_id="mangago"}}}},chapters={['mangago:96']={metadata={manga_id="8"}}},chapter_sync={['mangago:8']={count=1}}} end}))
assert(renamed.data.manga["mangamost:8"].source_id=="mangamost" and renamed.data.manga["mangago:8"]==nil)
assert(renamed.data.history[1].source_id=="mangamost" and renamed.data.history[1].key=="mangamost:8")
assert(renamed.data.archives["/books/8.cbz"].manga.source_id=="mangamost" and renamed.data.archives["/books/8.cbz"].chapters[1].source_id=="mangamost")
assert(renamed.data.chapters["mangamost:96"] and renamed.data.chapter_sync["mangamost:8"])
print("Library persistence tests passed")

assert(s:linkArchive("/tmp/a.cbz",m,c)); assert(s:recordArchivePage("/tmp/a.cbz",7)); assert(s.data.history[1].page==7)
assert(not s:recordArchivePage("/tmp/other.cbz",1))

assert(s:linkArchive("/tmp/b.cbz",m,c,10)); assert(s:recordArchivePage("/tmp/b.cbz",10)); assert(s:chapterStatus("mangadex","a").read); assert(s:setChapterRead("mangadex","a",false)); assert(not s:chapterStatus("mangadex","a").read)

assert(s:unlinkArchive("/tmp/b.cbz")); assert(not s.data.archives["/tmp/b.cbz"])

assert(#s:list("a")==1 and s:list("a")[1].title=="A")

assert(s:add({id="1",source_id="mangadex",title="Z"})); assert(s:list(nil,"recent")[1].title=="Z")

local archived="/old/manga/mangadex/1/chapters/a.cbz"; assert(s:linkArchive(archived,m,c,3)); assert(s:archiveFor("mangadex","1","a")==archived); assert(not s:archiveFor("../bad","1","a"))
local moved="/new/manga/mangadex/1/chapters/a.cbz"; assert(s:linkArchive(moved,m,c,3)); assert(not s.data.archives[archived] and s:archiveFor("mangadex","1","a")==moved)

assert(s:add({id="3",source_id="s",title="M",url="https://example.org/m",author="Author",genres={"Action"}})); assert(s.data.manga["s:3"].url=="https://example.org/m" and s.data.manga["s:3"].genres[1]=="Action")

assert(s:cacheChapters(m,{{id="chapter2",manga_id="1",name="Chapter 2",chapter_number=2}})); assert(s:chapterStatus("mangadex","chapter2").metadata.chapter_number==2)
assert(not s.data.chapter_sync["mangadex:1"])
assert(s:markChaptersSynced(m,2,123,1,2)); assert(s.data.chapter_sync["mangadex:1"].count==2 and s.data.chapter_sync["mangadex:1"].missing_count==1 and s.data.chapter_sync["mangadex:1"].latest_number==2 and s.data.chapter_sync["mangadex:1"].checked_at==123)
assert(not s:markChaptersSynced(m,2,123,3))
assert(not s:markChaptersSynced(m,2,123,1,0/0))
assert(not s:markChaptersSynced(m,-1)); assert(not Store.open({readSetting=function() return {version=1,manga={},history={},archives={},chapters={},chapter_sync="broken"} end}))

local unread=s:list(nil,nil,"unread"); assert(#unread==1 and unread[1].id=="1"); local filtered=s:list(nil,nil,"source","s"); assert(#filtered==1 and filtered[1].source_id=="s")

local merge_manga={id="99",source_id="mangadex",title="Merge"}
assert(s:add(merge_manga))
local shared="/new/manga/mangadex/99/manga.cbz"
local old_chapter={id="legacy",manga_id="99",name="Chapter 1",chapter_number=1}
local new_chapter={id="next",manga_id="99",name="Chapter 2",chapter_number=2}
local new_digest=string.rep("a",64)
local old_path="/new/manga/mangadex/99/chapters/legacy.cbz"
assert(s:linkArchive(old_path,merge_manga,old_chapter,4,new_digest))
assert(s:linkArchive(shared,merge_manga,new_chapter,3,new_digest))
local merged,old_paths=s:mergeArchiveRecords(shared,merge_manga,new_digest)
assert(merged and #old_paths==1 and old_paths[1]==old_path)
assert(s:archiveFor("mangadex","99","legacy")==shared and s:archiveFor("mangadex","99","next")==shared)
assert(s:archiveHasChapter(shared,"legacy") and #s:chaptersInArchive(shared)==2 and not s.data.archives[old_path])
