local socket=require("socket"); local ssl=require("ssl"); local json=require("cjson")
local forwarded={gettime=socket.gettime,tcp=function()
    local real=assert(socket.tcp()); local proxy={}
    function proxy:connect() return real:connect("127.0.0.1",tonumber(assert(os.getenv("TEST_PORT")))) end
    function proxy:settimeout(...) return real:settimeout(...) end
    function proxy:getfd() return real:getfd() end
    function proxy:setfd(fd) return real:setfd(fd) end
    function proxy:close() return real:close() end
    return proxy
end}
local Secure=dofile("network/secure_request.lua"); local Client=dofile("network/client.lua")
local transport=Client.new({decode=json.decode,schedule=function(_,f) f() end,request=function(url,cb,opts)
    local code,body,err,headers=Secure.fetch(url,{socket=forwarded,ssl=ssl,http=require("socket.http"),capath=assert(os.getenv("TEST_CA_DIR"))})
    cb(code,body,err,headers)
end})
local parser=dofile("sources/mangadex/parser.lua"); local Source=dofile("sources/mangadex/source.lua"); local source=Source.new(transport,parser,"en")
local manga,detail,chapters,pages
source:searchManga("Fixture",1,function(result,err) assert(result,err); manga=result.items[1] end)
assert(manga and manga.title=="Fixture")
source:getMangaDetails(manga,function(result,err) assert(result,err); detail=result end)
assert(detail.description=="Description")
source:getChapterList(detail,1,function(result,err) assert(result,err); chapters=result.items end)
assert(chapters[1].scanlator=="Group")
source:getPageList(chapters[1],function(result,err) assert(result,err); pages=result end)
assert(#pages==2 and pages[1].image_url=="https://node.mangadex.network:12345/token/data/ab12/1.jpg")
if os.getenv("TEST_FULL")=="1" then
    local ffi=require("ffi"); ffi.libc="GNU"; ffi.loadlib=function() return ffi.load(assert(os.getenv("LIBARCHIVE_PATH"))) end
    ffi.cdef[[int link(const char *,const char *);]]
    package.path=assert(os.getenv("KOREADER_BASE")) .. "/?.lua;" .. package.path
    local archiver=require("ffi/archiver"); local integrity=dofile("reader/archive_integrity.lua")
    local stager=dofile("reader/chapter_stager.lua"); local builder=dofile("reader/cbz_builder.lua")
    local validator=dofile("reader/image_validation.lua"); local reader=dofile("reader/chapter_reader.lua")
    local Downloader=dofile("network/image_downloader.lua"); package.preload.json=function() return json end
    local prefix=os.tmpname(); os.remove(prefix); assert(os.execute("mkdir " .. prefix)==0)
    local fs={verifyEntry=integrity.verifyEntry,targetFor=function() return prefix .. ".cbz" end,
        exists=function(p) local f=io.open(p,"rb"); if f then f:close(); return true end; return false end,
        prepare=function() return {target=prefix .. ".cbz",staging=prefix} end,remove=os.remove,
        publishNoReplace=function(a,b) if ffi.C.link(a,b)~=0 then return false end; os.remove(a); return true end}
    local trapper={wrap=function(_,f) f() end,dismissableRunInSubprocess=function(_,f) return true,f() end}
    local function dependencies() return {socket=forwarded,ssl=ssl,http=require("socket.http"),capath=assert(os.getenv("TEST_CA_DIR"))} end
    local downloader=Downloader.new(trapper,Secure,dependencies)
    local result,opened
    reader.open({fs=fs,archiver=archiver,stager=stager,build=builder.build,validate=validator.validate,download=downloader,
        removeDir=function() end,library={linkArchive=function() return true end},source={getPageList=function(_,_,cb) cb(pages) end},
        openDocument=function(file) opened=file end},detail,chapters[1],function(ok,err) assert(ok,err); result=ok end)
    assert(result and opened==prefix .. ".cbz")
    local archive=archiver.Reader:new(); assert(archive:open(opened)); local entry=archive:next(); assert(entry and entry.path=="000001.jpg"); archive:close()
    os.remove(opened); os.execute("rmdir " .. prefix)
    print("MangaDex fixture through HTTPS download and real archive passed")
else print("MangaDex browsing over real loopback HTTPS passed") end
