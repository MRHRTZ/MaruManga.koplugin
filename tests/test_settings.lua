local Settings = dofile("storage/settings.lua")
local function store(value)
    return {value=value, readSetting=function(self) return self.value end, saveSetting=function(self, _, v) self.value=v end, flush=function(self) self.flushed=true end}
end
local s=store(nil); local cfg=assert(Settings.open(s)); assert(cfg.data.version == 2 and cfg.data.language == "en" and cfg.data.dns_mode=="auto" and cfg.data.source=="komiku" and cfg.data.profiles[1].id=="komiku")
assert(cfg:setLanguage("ja")); assert(cfg:save()); assert(s.flushed and s.value.language == "ja")
local old=store({language="fr",source="mangadex"}); local migrated=Settings.open(old); assert(migrated.data.language == "fr" and migrated.data.source=="komiku" and migrated.data.profiles[1].id=="komiku")
local broken=store("broken"); local x=Settings.open(broken); assert(not x and broken.value == "broken")
local future=store({version=99}); assert(not Settings.open(future) and future.value.version == 99)
assert(not cfg:setLanguage("../bad")); assert(cfg.data.language == "ja")
print("Settings tests passed")

assert(cfg:addProfile({id="sample",name="Sample",base_url="https://example.org"})); assert(not cfg:addProfile({id="sample",name="Duplicate",base_url="https://example.org"})); assert(not cfg:addProfile({id="bad",name="Bad",base_url="http://example.org"}))

assert(cfg:setNetwork("30","4","Maru/1","/mnt/books",2,true)); assert(cfg.data.timeout==30 and cfg.data.retries==4 and cfg.data.ignore_ssl_certificates==true)
assert(cfg:setNetwork("30","4","Maru/1","/mnt/books",2,false)); assert(cfg.data.ignore_ssl_certificates==false)
assert(not cfg:setNetwork("0","4","Maru/1","/mnt/books")); assert(not cfg:setNetwork("10","3","ok","/a/../b")); assert(not cfg:setNetwork("30","3","ok","",2,"yes"))
assert(cfg:setDns("google") and cfg.data.dns_mode=="google")
assert(cfg:setDns("cloudflare") and cfg.data.dns_mode=="cloudflare")
assert(cfg:setDns("other","9.9.9.9") and cfg.data.dns_server=="9.9.9.9")
assert(not cfg:setDns("other","999.1.1.1"))
assert(cfg:setDns("auto") and cfg.data.dns_mode=="auto" and cfg.data.dns_server==nil)
local migrated=store({version=1,language="en"}); assert(Settings.open(migrated).data.dns_mode=="auto")

local corrupt=store({version=1,profiles={{id="x",name="X",base_url="https://example.org",image_hosts="bad"}}}); assert(not Settings.open(corrupt) and corrupt.value.profiles[1].image_hosts=="bad")
