local Client = dofile("network/client.lua")
local pending, requests, results = {}, {}, {}
local client = Client.new({
    request=function(url, callback) requests[#requests+1]={url=url, callback=callback} end,
    schedule=function(delay, callback) pending[#pending+1]={delay=delay, callback=callback} end,
    decode=function(body) if body == "bad" then error("bad JSON") end; return {value=body} end,
})
client:get("https://api.mangadex.org/manga", function(data, err) results[#results+1]=data or err end)
client:get("https://api.mangadex.org/chapter", function(data, err) results[#results+1]=data or err end)
assert(#requests == 1)
requests[1].callback(429, "", nil, {["retry-after"]="45"})
assert(#pending == 1 and pending[1].delay == 45)
table.remove(pending,1).callback()
requests[2].callback(200, "ok")
assert(results[1].value == "ok" and #requests == 2)
table.remove(pending,1).callback()
assert(#requests == 3)
requests[3].callback(200, "bad")
assert(results[2] == "Invalid JSON response")
client:get("http://api.mangadex.org/manga", function(data, err) assert(not data and err) end)
print("Network queue tests passed")
