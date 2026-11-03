local Transport = dofile("network/koreader_transport.lua")
local ui = {scheduled={}}
function ui:initLooper() self.looper={add_callback=function(_, cb) self.job=cb end} end
function ui:setInputTimeout() self.input=true end
function ui:resetInputTimeout() self.input=false end
function ui:scheduleIn(delay, cb) self.scheduled[#self.scheduled+1]=cb end
local options, req
local turbo = {async={HTTPClient=function(ssl, _, limit)
    options=ssl; assert(limit == 2097152)
    return {fetch=function(_, url, request) req=request; return "yielded" end}
end}}
local q = {new=function(opts) return opts end}
local adapter = Transport.new(ui, turbo, {decode=function() end}, q)
local result
adapter.request("https://api.mangadex.org/manga", function(code, body) result={code,body} end)
local co=coroutine.create(ui.job)
assert(coroutine.resume(co)); assert(options.verify_ca and req.allow_redirects == false and ui.input)
assert(coroutine.resume(co, {code=200,body="ok"})); assert(result[1] == 200 and result[2] == "ok" and not ui.input)
print("KOReader transport contract tests passed")
