-- Optional loopback TLS integration: server has a test-only trusted certificate.
local socket=require("socket"); local ssl=require("ssl")
local forwarded={tcp=function()
    local real=assert(socket.tcp()); local proxy={}
    function proxy:connect(_,_) return real:connect("127.0.0.1",tonumber(assert(os.getenv("TEST_PORT")))) end
    function proxy:settimeout(...) return real:settimeout(...) end
    function proxy:getfd() return real:getfd() end
    function proxy:setfd(fd) return real:setfd(fd) end
    function proxy:close() return real:close() end
    return proxy
end}
local request=dofile("network/secure_request.lua")
local deps={socket=forwarded,ssl=ssl,http=require("socket.http"),capath=assert(os.getenv("TEST_CA_DIR"))}
if os.getenv("TEST_POST")=="1" then deps.method="POST"; deps.body="test=value" end
local status,body,err=request.fetch("https://api.mangadex.org/ping",deps)
if os.getenv("EXPECT_MISMATCH")=="1" then assert(not status and err=="Certificate hostname mismatch",tostring(err))
elseif os.getenv("EXPECT_UNTRUSTED")=="1" then assert(not status and err,tostring(status))
elseif os.getenv("TEST_POST")=="1" then assert(status==200 and body=="POST-OK",tostring(err or body or status))
else assert(status==200 and type(body)=="string",tostring(err or status)) end
print("Loopback TLS test passed")
