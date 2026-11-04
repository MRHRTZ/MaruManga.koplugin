local Repos=dofile("core/repositories.lua")
local store={data={},readSetting=function(self,k) return self.data[k] end,saveSetting=function(self,k,v) self.data[k]=v end,flush=function() end}
local repos=assert(Repos.open(store)); assert(#repos:list()==1 and repos:list()[1].url==Repos.DEFAULT_URL)
local fallback_sources=repos:list()[1].catalog.sources; assert(#fallback_sources==1 and fallback_sources[1].id=="komiku" and fallback_sources[1].version==2 and fallback_sources[1].profile.api_url=="https://api.komiku.org" and fallback_sources[1].profile.metadata_row_selector=="table.inftable tr")
assert(not repos:add(Repos.DEFAULT_URL))
assert(not repos:add("http://example.org/meta.json")); assert(repos:add("https://example.org/catalog")); assert(not repos:add("https://example.org/../meta.json"))
assert(repos:remove(repos.data.items[1]))
local repo=assert(repos:add("https://example.org/catalog.json")); assert(not repos:add(repo.url))
local valid={schema_version=1,id="x",name="Catalog",version=1,sources={{id="one",name="One",version=1,adapter="generic",base_url="https://example.org",languages={"en"},profile={search_path="/?q={query}",image_hosts={"images.example.org"},script="malicious"}}}}
assert(repos:update(repo,valid)); assert(repo.catalog.sources[1].profile.script==nil and repo.catalog.sources[1].profile.image_hosts[1]=="images.example.org")
valid.id="other"; assert(not repos:update(repo,valid)); valid.id="x"
valid.version=2; assert(repos:update(repo,valid)); valid.version=1; assert(not repos:update(repo,valid))
local retired=assert(Repos.validate({schema_version=1,id="x",name="X",version=1,sources={{id="mangadex",name="M",version=1,adapter="mangadex",base_url="https://evil.org"}}})); assert(#retired.sources==0)
assert(repos:edit(repo,"Updated title","https://example.org/catalog-v2.json"))
assert(repo.title=="Updated title" and repo.url=="https://example.org/catalog-v2.json")
assert(Repos.open(store)); assert(repos:remove(repo)); assert(#repos:list()==1)
print("Repository catalog validation tests passed")

local migration_store={readSetting=function() return {version=1,items={{url=Repos.DEFAULT_URL}}} end,saveSetting=function() end,flush=function() end}
local migrated=assert(Repos.open(migration_store)); assert(#migrated:list()==1 and #migrated.data.items==0)

local default=repos:list()[1]
local refreshed={schema_version=1,id="maru-official",name="Maru Manga Sources",version=2,sources={{id="mangadex",name="MangaDex",version=1,adapter="mangadex",base_url="https://api.mangadex.org"}}}
assert(repos:update(default,refreshed)); local reopened=assert(Repos.open(store)); assert(reopened:list()[1].catalog.version==2 and reopened:list()[1].url==Repos.DEFAULT_URL)
assert(#reopened:list()[1].catalog.sources==1 and reopened:list()[1].catalog.sources[1].id=="komiku")
local stale_store={readSetting=function() return {version=1,items={},default_repository={url=Repos.DEFAULT_URL,catalog={schema_version=1,id="maru-official",name="Maru Manga Sources",version=1,sources={{id="mangadex",name="MangaDex",version=1,adapter="mangadex",base_url="https://api.mangadex.org"}}}}} end,saveSetting=function() end,flush=function() end}
local stale=assert(Repos.open(stale_store)); assert(#stale:list()[1].catalog.sources==1 and stale:list()[1].catalog.sources[1].id=="komiku")
local planned=assert(Repos.validate({schema_version=1,id="planned",name="Prepared",author="MRHRTZ",version="1.12.0",status="Maintenance",sources={{id="adult",name="Adult",version=1,adapter="planned",app_url="https://play.google.com/store/apps/details?id=app",languages={"en","id"},nsfw=true}}}))
assert(planned.author=="MRHRTZ" and planned.status=="Maintenance" and planned.sources[1].nsfw and planned.sources[1].languages[2]=="id")
local komiku={id="komiku",name="Komiku",version=2,adapter="komiku",base_url="https://komiku.org",languages={"id"},profile={api_url="https://api.komiku.org",image_hosts={"thumbnail.komiku.to"},list_selector="div.bge",list_cover_selector="img",metadata_row_selector="table.inftable tr"}}
local catalog=assert(Repos.validate({schema_version=1,id="komiku-test",name="Komiku test",version=1,sources={komiku}})); assert(catalog.sources[1].profile.api_url=="https://api.komiku.org")
komiku.profile.api_url="https://api.evil.invalid"; assert(not Repos.validate({schema_version=1,id="komiku-test",name="Komiku test",version=1,sources={komiku}}))
assert(Repos.versionLess("1.9.0","1.12.0") and not Repos.versionLess("1.12.0","1.9.0"))
