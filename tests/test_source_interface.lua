local Interface = dofile("sources/source_interface.lua")
local Source = dofile("sources/generic/source.lua")
local parser={list=function() return {items={}} end,details=function() return {} end,chapters=function() return {} end,pages=function() return {} end}
local transport={get=function(_,_,callback) callback("html") end}
local instance=Source.new({id="fixture",name="Fixture",base_url="https://example.org"},parser,transport)
assert(Interface.validate(instance))
local ok, err = Interface.validate({getId=function() return "x" end})
assert(not ok and err:find("Missing source method", 1, true))
assert(not Interface.validate(nil))
print("Source interface tests passed")
