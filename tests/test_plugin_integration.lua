-- UI registration and configuration with mocked KOReader widgets.
local settings_file=os.tmpname(); os.remove(settings_file)
local store={file=settings_file,data={},backup=function() return false end,readSetting=function(self,k) return self.data[k] end,saveSetting=function(self,k,v) self.data[k]=v end,flush=function() end}
local widgets={}
package.preload["ui/widget/container/widgetcontainer"]=function() return {extend=function(_,v) return v end} end
package.preload["ui/uimanager"]=function() return {show=function(_,w) widgets[#widgets+1]=w end,close=function() end,nextTick=function(_,f) f() end,scheduleIn=function() end} end
for _,name in ipairs({"ui/widget/infomessage","ui/widget/trapwidget","ui/widget/confirmbox","ui/widget/menu","ui/widget/inputdialog","ui/widget/multiinputdialog"}) do
    package.preload[name]=function() return {new=function(_,v) return v end} end
end
package.preload.gettext=function() return function(s) return s end end
package.preload.luasettings=function() return {open=function() return store end} end
package.preload.datastorage=function() return {getSettingsDir=function() return "/tmp" end} end
package.preload["ui/trapper"]=function() return {} end
package.preload.dump=function() return function() return "{}" end end
package.preload["ffi/util"]=function() return {} end
package.preload.json=function() return {decode=function() return {} end} end
package.preload["ffi/sha2"]=function() return {md5=function(s) return "hash" end} end
package.preload.util=function() return {htmlToPlainText=function(s) return s end} end
local plugin=dofile("./main.lua")
plugin.ui={menu={registerToMainMenu=function() end}}; plugin:init()
local menu={}; plugin:addToMainMenu(menu); assert(menu.marumanga and plugin.config.data.source=="mangadex")
assert(plugin.config:addProfile({id="example",name="Example",base_url="https://example.org",kind="madara"}))
plugin.config.data.source="example"
local source=assert(plugin:source()); assert(source:getName()=="Example" and source:getId()=="example")
plugin:showSources(); assert(#widgets>0 and widgets[#widgets].title=="Sources")
source.transport.get=function(_,url,cb)
    if url:find("post_type",1,true) then cb('<div class="page-item-detail"><div class="item-thumb"><a href="/manga/a">Cover</a></div><div class="post-title"><a>Series</a></div></div>')
    else cb('<div class="post-title"><h1>Series</h1></div><div class="summary__content">Description</div><li class="wp-manga-chapter"><a href="/chapter/1">Chapter 1</a></li>') end
end
local results; source:searchManga("series",1,function(r) results=r end); assert(results.items[1].title=="Series")
plugin:showManga(results.items[1]); local detail=widgets[#widgets]; assert(detail.title=="Series")
local add,chapters
for _,item in ipairs(detail.item_table) do if item.text=="Add to library" then add=item elseif item.text=="Chapters" then chapters=item end end
assert(add and chapters); add.action(); assert(plugin.library:contains("example",results.items[1].id))
chapters.action(); local list=widgets[#widgets]; assert(list.title:match("Series") and #list.item_table>=2)
plugin:showLibrary(); local library_menu=widgets[#widgets]; assert(library_menu.title=="Library" and #library_menu.item_table==4)
os.remove(settings_file); os.remove(settings_file..".old"); os.remove(settings_file..".new")
print("Plugin source integration tests passed")
