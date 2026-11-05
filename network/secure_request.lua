-- HTTPS API request performed in a KOReader subprocess. Fail closed when
-- LuaSec cannot authenticate the chain and hostname unless the user explicitly
-- enables the compatibility option to skip certificate validation.
local M = {}
local function certificate_matches(cert,host)
    if not cert or type(host)~="string" or not host:match("^[%w%.%-]+$") then return false end
    local function matches(pattern)
        if type(pattern)~="string" or pattern:find("[%z%c]") then return false end
        pattern=pattern:lower(); local name=host:lower()
        if pattern:sub(1,2)=="*." then
            local suffix=name:match("^[^.]+%.(.+)$")
            return suffix~=nil and suffix==pattern:sub(3)
        end
        return pattern==name
    end
    local ok,extensions=pcall(function() return cert:extensions() end)
    if not ok or type(extensions)~="table" then return false end
    local san=extensions["2.5.29.17"]
    if san then
        if type(san)~="table" or type(san.dNSName)~="table" then return false end
        for _,name in ipairs(san.dNSName) do if matches(name) then return true end end
        return false
    end
    local subject_ok,subject=pcall(function() return cert:subject() end)
    if not subject_ok or type(subject)~="table" then return false end
    for _,entry in ipairs(subject) do if entry.name=="commonName" and matches(entry.value) then return true end end
    return false
end
function M.fetch(url, dependencies)
    local socket, ssl, http = dependencies.socket, dependencies.ssl, dependencies.http
    local max = dependencies.max_bytes or 2097152
    local method=dependencies.method or "GET"
    if method~="GET" and method~="POST" then return nil,nil,"Unsupported HTTP method" end
    local body=dependencies.body or ""
    if method=="POST" and (type(body)~="string" or #body>65536) then return nil,nil,"Invalid request body" end
    if type(url) ~= "string" or #url>8192 or url:find("[%c%s]") or url:find("#",1,true) then return nil, nil, "Unsupported URL" end
    local host,port=url:match("^https://([%w%.%-]+):(%d+)/")
    if not host then host=url:match("^https://([%w%.%-]+)/") end
    port=port and tonumber(port) or 443
    if not host or port<1 or port>65535 then return nil, nil, "Unsupported URL" end
    if dependencies.allowed_hosts then
        if not dependencies.allowed_hosts[host] then return nil, nil, "Host is not permitted for this source" end
    elseif dependencies.images then
        if not (host == "uploads.mangadex.org" or host == "mangadex.network" or host:match("%.mangadex%.network$")) then return nil, nil, "Unsupported image server" end
    elseif host ~= "api.mangadex.org" then return nil, nil, "Unsupported API URL" end
    local chunks, total, prefix = {}, 0, ""
    local function sink(chunk, err)
        if err then return nil, err end
        if chunk then
            total = total + #chunk
            if total > max then return nil, "Response too large" end
            if #prefix < 32 then prefix = (prefix .. chunk):sub(1, 32) end
            if dependencies.write then
                local ok, why = dependencies.write(chunk)
                if not ok then return nil, why or "File write failed" end
            else
                chunks[#chunks+1] = chunk
            end
        end
        return 1
    end
    local expected_host = host
    local connect_host=host
    if dependencies.resolve then
        local resolved,resolve_error=dependencies.resolve(host)
        if not resolved then return nil,nil,"DNS lookup failed: "..tostring(resolve_error or "no address") end
        if type(resolved)~="string" or not resolved:match("^%d+%.%d+%.%d+%.%d+$") then return nil,nil,"DNS returned an invalid address" end
        connect_host=resolved
    end
    local function create()
        local tcp = assert(socket.tcp())
        local proxy = {}
        function proxy:settimeout(_) return tcp:settimeout(dependencies.timeout or 15) end
        function proxy:connect(host, port)
            if host ~= expected_host then return nil, "Unexpected host" end
            local ok, err = tcp:connect(connect_host, port); if not ok then return nil, err end
            local tls; tls, err = ssl.wrap(tcp, {mode="client",protocol="any",verify=dependencies.ignore_ssl_certificates and "none" or "peer",cafile=dependencies.cafile,capath=dependencies.capath,options={"all","no_sslv2","no_sslv3"}})
            if not tls then return nil, err end
            tcp = tls
            if tls.sni then tls:sni(host) end
            tls:settimeout(dependencies.timeout or 15)
            local expected_during_handshake = false
            if tls.sethost and not dependencies.ignore_ssl_certificates then
                local set, why = tls:sethost(host)
                if not set then return nil, why or "Hostname verification unavailable" end
                expected_during_handshake = true
            end
            ok, err = tls:dohandshake(); if not ok then return nil, err end
            if dependencies.ignore_ssl_certificates then
                -- Explicit compatibility mode skips CA and hostname checks.
                -- HTTPS and the source host allowlist remain enforced above.
            elseif not expected_during_handshake then
                local cert = tls:getpeercertificate()
                local match
                if cert and cert.checkhost then
                    match = cert:checkhost(host)
                elseif cert and cert.extensions and cert.subject then
                    match = certificate_matches(cert,host)
                else
                    return nil, "Hostname verification unavailable"
                end
                if not match then return nil, "Certificate hostname mismatch" end
            end
            return 1
        end
        function proxy:send(...) return tcp:send(...) end
        function proxy:receive(...) return tcp:receive(...) end
        function proxy:close() return tcp:close() end
        function proxy:getfd() return tcp:getfd() end
        function proxy:dirty() return tcp:dirty() end
        return proxy
    end
    local request_headers={host=port==443 and host or (host .. ":" .. port), accept=dependencies.images and "image/*" or (dependencies.accept or "application/json"), ["user-agent"]=dependencies.user_agent or "MaruMangaDownloader/0.1 (KOReader)", connection="close"}
    if type(dependencies.headers)=="table" then
        for name,value in pairs(dependencies.headers) do
            if type(name)=="string" and name:match("^[%w%-]+$") and type(value)=="string" and #value<=4096 and not value:find("[%c]") then
                local lower=name:lower()
                if lower~="host" and lower~="connection" and lower~="content-length" then request_headers[lower]=value end
            end
        end
    end
    if type(dependencies.referer)=="string" and dependencies.referer:match("^https://") and not dependencies.referer:find("[\r\n]") then request_headers.referer=dependencies.referer end
    local source
    if method=="POST" then
        request_headers["content-length"]=tostring(#body)
        if not request_headers["content-type"] then request_headers["content-type"]="application/x-www-form-urlencoded" end
        local sent=false
        source=function() if sent then return nil end; sent=true; return body end
    end
    local success, code, headers = http.request({url=url, port=port, method=method, source=source, create=create, sink=sink, redirect=false, headers=request_headers})
    if not success then return nil, nil, tostring(code or "Connection failed") end
    if dependencies.write then return tonumber(code), {size=total, prefix=prefix, content_type=headers and headers["content-type"], cached=headers and type(headers["x-cache"])=="string" and headers["x-cache"]:upper():match("^HIT")~=nil or false}, nil, headers end
    return tonumber(code), table.concat(chunks), nil, headers
end
return M
