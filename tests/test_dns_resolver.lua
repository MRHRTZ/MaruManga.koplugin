local DNS=dofile("network/dns_resolver.lua")
local seen_server
local fake={udp=function()
    local u={}
    function u:settimeout() return true end
    function u:setpeername(server,port) seen_server=server; assert(port==53); return true end
    function u:send(query)
        self.query=query
        local question=query:sub(13)
        self.response=query:sub(1,2)..string.char(129,128,0,1,0,1,0,0,0,0)..question..string.char(192,12,0,1,0,1,0,0,0,60,0,4,93,184,216,34)
        return #query
    end
    function u:receive() return self.response end
    function u:close() return true end
    return u
end}
local ip=assert(DNS.resolve("example.com","google",nil,fake,100))
assert(ip=="93.184.216.34" and seen_server=="8.8.8.8")
assert(DNS.resolve("example.com","google",nil,{udp=function() error("cache was not used") end},101)==ip)
assert(DNS.resolve("komiku.org","cloudflare",nil,fake,200)==ip and seen_server=="1.1.1.1")
assert(DNS.resolve("manga.example","other","9.9.9.9",fake,300)==ip and seen_server=="9.9.9.9")
local result,err=DNS.resolve("example.com","other","not-an-ip",fake,400)
assert(result==nil and err=="Invalid DNS configuration")
assert(DNS.validIPv4("1.1.1.1") and not DNS.validIPv4("256.1.1.1") and not DNS.validIPv4("1.1.1"))
print("DNS resolver tests passed")
