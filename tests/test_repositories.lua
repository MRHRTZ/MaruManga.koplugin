local Repos=dofile("core/repositories.lua")
local store={data={},readSetting=function(self,k) return self.data[k] end,saveSetting=function(self,k,v) self.data[k]=v end,flush=function() end}
local repos=assert(Repos.open(store)); assert(#repos:list()==1 and repos:list()[1].url==Repos.DEFAULT_URL)
local fallback_sources=repos:list()[1].catalog.sources; assert(repos:list()[1].catalog.version=="1.23.3" and repos:list()[1].catalog.name=="Maru Manga Repositories" and #fallback_sources==7 and fallback_sources[1].id=="komiku" and fallback_sources[1].version=="3.0.0" and fallback_sources[1].profile.api_url=="https://api.komiku.org" and fallback_sources[1].profile.metadata_row_selector=="table.inftable tr" and fallback_sources[1].icon_url=="https://www.google.com/s2/favicons?domain=komiku.org&sz=64")
assert(not repos:add(Repos.DEFAULT_URL))
assert(not repos:add("http://example.org/meta.json")); assert(repos:add("https://example.org/catalog")); assert(not repos:add("https://example.org/../meta.json"))
assert(repos:remove(repos.data.items[1]))
local repo=assert(repos:add("https://example.org/catalog.json")); assert(not repos:add(repo.url))
local valid={schema_version=1,id="x",name="Catalog",version=1,sources={{id="one",name="One",version=1,adapter="generic",base_url="https://example.org",icon_url="https://www.google.com/s2/favicons?domain=example.org&sz=64",languages={"en"},profile={search_path="/?q={query}",image_hosts={"images.example.org"},script="malicious"}}}}
assert(repos:update(repo,valid)); assert(repo.catalog.sources[1].icon_url==valid.sources[1].icon_url and repo.catalog.sources[1].profile.script==nil and repo.catalog.sources[1].profile.image_hosts[1]=="images.example.org")
valid.id="other"; assert(not repos:update(repo,valid)); valid.id="x"
valid.version=2; assert(repos:update(repo,valid)); valid.version=1; assert(not repos:update(repo,valid))
local bad_icon={schema_version=1,id="icons",name="Icons",version=1,sources={{id="iconbad",name="Bad Icon",version=1,adapter="generic",base_url="https://example.org",icon_url="https://www.google.com/s2/favicons?domain=elsewhere.org&sz=64"}}}
assert(not Repos.validate(bad_icon))
local retired=assert(Repos.validate({schema_version=1,id="x",name="X",version=1,sources={{id="mangadex",name="M",version=1,adapter="mangadex",base_url="https://evil.org"}}})); assert(#retired.sources==0)
assert(repos:edit(repo,"Updated title","https://example.org/catalog-v2.json"))
assert(repo.title=="Updated title" and repo.url=="https://example.org/catalog-v2.json")
assert(Repos.open(store)); assert(repos:remove(repo)); assert(#repos:list()==1)
local westmanga; for _,entry in ipairs(repos:list()[1].catalog.sources) do if entry.id=="westmanga" then westmanga=entry end end
assert(westmanga and westmanga.adapter=="westmanga" and westmanga.base_url=="https://www.westmanga.shop" and westmanga.profile.api_url=="https://www.westmanga.shop/api/manga")
print("Repository catalog validation tests passed")

local migration_store={readSetting=function() return {version=1,items={{url=Repos.DEFAULT_URL}}} end,saveSetting=function() end,flush=function() end}
local migrated=assert(Repos.open(migration_store)); assert(#migrated:list()==1 and #migrated.data.items==0)

local default=repos:list()[1]
local refreshed={schema_version=1,id="maru-official",name="Maru Manga Repositories",version=2,sources={{id="mangadex",name="MangaDex",version=1,adapter="mangadex",base_url="https://api.mangadex.org"}}}
assert(repos:update(default,refreshed)); local reopened=assert(Repos.open(store)); assert(reopened:list()[1].catalog.version==2 and reopened:list()[1].url==Repos.DEFAULT_URL)
assert(#reopened:list()[1].catalog.sources==7 and reopened:list()[1].catalog.sources[1].id=="komiku" and reopened:list()[1].catalog.sources[1].icon_url==fallback_sources[1].icon_url)
local stale_store={readSetting=function() return {version=1,items={},default_repository={url=Repos.DEFAULT_URL,title="MaruManga Repository",catalog={schema_version=1,id="maru-official",name="MaruManga Repository",version=1,sources={{id="mangadex",name="MangaDex",version=1,adapter="mangadex",base_url="https://api.mangadex.org"}}}}} end,saveSetting=function() end,flush=function() end}
local stale=assert(Repos.open(stale_store)); assert(stale:list()[1].title=="Maru Manga Repositories" and #stale:list()[1].catalog.sources==7 and stale:list()[1].catalog.sources[1].id=="komiku")
local planned=assert(Repos.validate({schema_version=1,id="planned",name="Prepared",author="MRHRTZ",version="1.12.0",status="Maintenance",sources={{id="adult",name="Adult",version=1,adapter="planned",app_url="https://play.google.com/store/apps/details?id=app",languages={"en","id"},nsfw=true}}}))
assert(planned.author=="MRHRTZ" and planned.status=="Maintenance" and planned.sources[1].nsfw and planned.sources[1].languages[2]=="id")
local komiku={id="komiku",name="Komiku",version=2,adapter="komiku",base_url="https://komiku.org",languages={"id"},profile={api_url="https://api.komiku.org",image_hosts={"thumbnail.komiku.to"},list_selector="div.bge",list_cover_selector="img",metadata_row_selector="table.inftable tr"}}
local catalog=assert(Repos.validate({schema_version=1,id="komiku-test",name="Komiku test",version=1,sources={komiku}})); assert(catalog.sources[1].profile.api_url=="https://api.komiku.org")
komiku.profile.api_url="https://api.evil.invalid"; assert(not Repos.validate({schema_version=1,id="komiku-test",name="Komiku test",version=1,sources={komiku}}))
assert(Repos.versionLess("1.9.0","1.12.0") and not Repos.versionLess("1.12.0","1.9.0"))
assert(Repos.versionLess("1.18.0","1.19.0") and not Repos.versionLess(3,"3.0.0"))
assert(not Repos.validate({schema_version=1,id="bad-version",name="Bad",version="1.019.0",sources={}}))
local source_ids={}; for _,entry in ipairs(fallback_sources) do source_ids[entry.id]=entry end
assert(source_ids.mangamost and source_ids.mangamost.adapter=="mangamost" and not source_ids.mangamost.nsfw)
assert(source_ids.mangago and source_ids.mangago.adapter=="mangago" and source_ids.mangago.nsfw and source_ids.mangago.base_url=="https://www.mangago.zone")
assert(source_ids.westmanga and source_ids.westmanga.adapter=="westmanga" and source_ids.westmanga.base_url=="https://www.westmanga.shop")
assert(source_ids.webtoon and source_ids.webtoon.version=="1.1.0" and source_ids.webtoon.profile.locale=="en")
assert(source_ids.webtoon_id and source_ids.webtoon_id.name=="WEBTOON" and source_ids.webtoon_id.adapter=="webtoon" and source_ids.webtoon_id.profile.locale=="id" and source_ids.webtoon_id.languages[1]=="id")
assert(Repos.validate({schema_version=1,id="webtoon-id-test",name="WEBTOON ID test",version="1.0.0",sources={source_ids.webtoon_id}}))
local wrong_webtoon_id={}; for k,v in pairs(source_ids.webtoon_id) do wrong_webtoon_id[k]=v end
wrong_webtoon_id.profile={}; for k,v in pairs(source_ids.webtoon_id.profile) do wrong_webtoon_id.profile[k]=v end
wrong_webtoon_id.profile.locale="en"
assert(not Repos.validate({schema_version=1,id="webtoon-id-test",name="WEBTOON ID test",version="1.0.0",sources={wrong_webtoon_id}}))

local deleted_store={data={},readSetting=function(self,k) return self.data[k] end,saveSetting=function(self,k,v) self.data[k]=v end,flush=function() end}
local deleted_repos=assert(Repos.open(deleted_store)); local default_repo=deleted_repos:list()[1]
assert(default_repo.builtin and default_repo.catalog.name=="Maru Manga Repositories")
assert(deleted_repos:remove(default_repo)); assert(#deleted_repos:list()==0)
local reopened_deleted=assert(Repos.open(deleted_store)); assert(#reopened_deleted:list()==0)
local restored_repo=assert(reopened_deleted:add(Repos.DEFAULT_URL))
assert(reopened_deleted:update(restored_repo,{schema_version=1,id="maru-official",name="Maru Manga Repositories",version="1.23.3",sources={}}))
assert(#reopened_deleted:list()==1 and reopened_deleted:list()[1].url==Repos.DEFAULT_URL and #reopened_deleted:list()[1].catalog.sources==7)
