-- Optional live network smoke test, run explicitly; not part of the fixture suite.
-- Uses the transport's certificate hostname verification.
local ssl=require("ssl")
local request=dofile("network/secure_request.lua")
local code,body,err=request.fetch("https://api.mangadex.org/ping",{socket=require("socket"),ssl=ssl,http=require("socket.http"),capath="/etc/ssl/certs"})
assert(code==200 and body=="pong",tostring(err or code)); print("Live HTTPS ping passed")
