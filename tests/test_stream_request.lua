local Request=dofile("network/secure_request.lua")
local written=""
local tcp={settimeout=function() return 1 end,connect=function() return 1 end,close=function() end}
local tls={settimeout=function() return 1 end,dohandshake=function() return 1 end,sethost=function() return true end}
local deps={images=true,headers={Referer="https://example.org/",Host="evil",["X-Test"]="ok",["X-Bad"]="bad\r\nvalue"},max_bytes=8,write=function(chunk) written=written..chunk; return true end,
    socket={tcp=function() return tcp end},ssl={wrap=function() return tls end},http={request=function(req)
        assert(req.headers.host=="test.mangadex.network:12345" and req.headers["x-test"]=="ok" and not req.headers["x-bad"])
        local c=req.create(); assert(c:connect("test.mangadex.network",12345)); assert(req.sink("1234")); return 1,200,{["content-type"]="image/jpeg"}
    end}}
local code,meta=Request.fetch("https://test.mangadex.network:12345/data/a/1.jpg",deps)
assert(code==200 and meta.size==4 and meta.prefix=="1234" and written=="1234")
assert(not Request.fetch("https://mangadex.network.evil.example/data/a/1.jpg",deps))
print("Streaming request tests passed")
