local Settings=dofile("storage/settings.lua")
local Repositories=dofile("core/repositories.lua")
local values={}
local store={
    readSetting=function(_,key) return values[key] end,
    saveSetting=function(_,key,value) values[key]=value end,
    flush=function() return true end,
}

-- Fresh installs create Komiku in settings and the bundled catalog separately;
-- their repository identity must agree for the repository UI to list it as
-- installed instead of treating it as an unrelated local profile.
local settings=assert(Settings.open(store))
local repositories=assert(Repositories.open(store))
local repo=repositories.data.default_repository
local komiku_profile
for _,profile in ipairs(settings.data.profiles) do if profile.id=="komiku" then komiku_profile=profile end end
local komiku_entry
for _,entry in ipairs(repo.catalog.sources) do if entry.id=="komiku" then komiku_entry=entry end end
assert(komiku_profile and komiku_entry)
assert(komiku_profile.repository_url==repo.url)
assert(komiku_entry.adapter==komiku_profile.kind)

assert(settings:save())
assert(repositories:save())
local reopened_settings=assert(Settings.open(store))
local reopened_repositories=assert(Repositories.open(store))
assert(reopened_settings.data.profiles[1].repository_url==reopened_repositories.data.default_repository.url)
print("Fresh install source registration tests passed")
