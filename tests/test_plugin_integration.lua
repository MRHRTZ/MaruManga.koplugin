-- UI registration and configuration with mocked KOReader widgets.
local settings_file=os.tmpname(); os.remove(settings_file)
local settings_dir=settings_file..".dir"; assert(os.execute("mkdir "..settings_dir)==0)
local store={file=settings_file,data={},backup=function() return false end,readSetting=function(self,k) return self.data[k] end,saveSetting=function(self,k,v) self.data[k]=v end,flush=function() end}
local widgets={}
package.preload["ui/widget/container/widgetcontainer"]=function() return {extend=function(_,v) return v end} end
package.preload["ui/uimanager"]=function() return {show=function(_,w) widgets[#widgets+1]=w end,close=function() end,nextTick=function(_,f) f() end,scheduleIn=function() end,isWidgetShown=function() return true end,getTopmostVisibleWidget=function() return widgets[#widgets] end,setDirty=function() end} end
for _,name in ipairs({"ui/widget/infomessage","ui/widget/buttondialog","ui/widget/trapwidget","ui/widget/confirmbox","ui/widget/menu","ui/widget/inputdialog","ui/widget/multiinputdialog"}) do
    package.preload[name]=function() return {new=function(_,v) return v end} end
end
package.preload["ui/widget/inputdialog"]=function() return {new=function(_,v) v.onShowKeyboard=function() end; return v end} end
package.preload["ui/widget/titlebar"]=function() return {new=function(_,v) return v end} end
local function simple_widget() return {new=function(_,v) return v or {} end} end
for _,name in ipairs({"ui/widget/container/centercontainer","ui/widget/container/framecontainer","ui/widget/horizontalgroup","ui/widget/horizontalspan","ui/widget/imagewidget","ui/widget/container/leftcontainer","ui/widget/overlapgroup","ui/widget/container/rightcontainer","ui/widget/textwidget","ui/widget/scrolltextwidget","ui/widget/verticalgroup","ui/widget/container/underlinecontainer","ui/geometry","ui/gesturerange"}) do
    package.preload[name]=simple_widget
end
package.preload["ui/font"]=function() return {getFace=function(_,name,size) return {name=name,size=size} end} end
package.preload["ui/size"]=function() return {padding={large=8,button=8},margin={title=8},border={window=2},line={medium=1,focus_row=2}} end
package.preload["ffi/blitbuffer"]=function() return {COLOR_DARK_GRAY=1,COLOR_WHITE=2,COLOR_BLACK=3} end
package.preload["ui/widget/container/inputcontainer"]=function()
    local Input={}
    function Input:extend(defaults)
        local class={}
        function class:new(options)
            local instance=setmetatable(options or {},{__index=class})
            for key,value in pairs(defaults or {}) do if instance[key]==nil then instance[key]=value end end
            if class.init then class.init(instance) end
            return instance
        end
        return class
    end
    return Input
end
package.preload["ui/widget/buttondialog"]=function()
    return {new=function(_,options)
        options=options or {}
        function options:reinit() self.item_table=self._added_widgets end
        function options:onClose() if self.tap_close_callback then self.tap_close_callback() end end
        return options
    end}
end
package.preload.device=function() return {screen={getWidth=function() return 600 end,scaleBySize=function(_,size) return size end}} end
package.preload["ui/widget/menu"]=function()
    local Menu={}
    function Menu:new(v)
        v.item_group={}
        for i,item in ipairs(v.item_table) do v.item_group[i]={entry=item,_underline_container={linesize=1}} end
        return v
    end
    function Menu.updateItems() end
    return Menu
end
package.preload.gettext=function() return function(s) return s end end
package.preload.luasettings=function() return {wrap=function() return store end} end
package.preload.datastorage=function() return {getSettingsDir=function() return settings_dir end} end
package.preload["ui/trapper"]=function() return {} end
package.preload.dump=function() return function() return "{}" end end
package.preload["ffi/util"]=function() return {} end
package.preload.json=function() return {decode=function() return {} end} end
package.preload["ffi/sha2"]=function() return {md5=function(s) return "hash" end} end
package.preload.util=function() return {htmlToPlainText=function(s) return s end} end
local plugin=dofile("./main.lua")
local registered=false
plugin.ui={menu={registerToMainMenu=function(_,p) registered=p==plugin end}}; plugin:init(); plugin.default_refresh_started=true
local menu={}; plugin:addToMainMenu(menu); assert(registered and menu.marumanga and menu.marumanga.sorting_hint=="tools" and plugin.config.data.source=="komiku")
local real_refresh=plugin.refreshRepository; local auto_refresh=false
plugin.default_refresh_started=nil; plugin.refreshRepository=function(_,repo,options) assert(repo.url:find("raw.githubusercontent.com",1,true)); auto_refresh=true; options.callback(true) end
plugin:showRepositories(); assert(widgets[#widgets].title=="Repositories")
plugin.repositories.data.default_repository.unreachable=nil; plugin.repositories.data.default_repository.last_error=nil; plugin.refreshRepository=real_refresh
assert(plugin.config:addProfile({id="example",name="Example",base_url="https://example.org",kind="madara"}))
plugin.config.data.source="example"
local source=assert(plugin:source()); assert(source:getName()=="Example" and source:getId()=="example")
plugin:showSources(); assert(#widgets>0 and widgets[#widgets].title=="Sources")
source.transport.get=function(_,url,cb)
    if url:find("post_type",1,true) then cb('<div class="page-item-detail"><div class="item-thumb"><a href="/manga/a">Cover</a></div><div class="post-title"><a>Series</a></div></div>')
    else cb('<div class="post-title"><h1>Series</h1></div><div class="summary__content">Description</div><li class="wp-manga-chapter"><a href="/chapter/1">Chapter 1</a></li>') end
end
plugin:openDiscover(); local source_picker=widgets[#widgets]; assert(source_picker.title=="Discover · Sources" and #source_picker.item_table>=2)
local results; source:searchManga("series",1,function(r) results=r end); assert(results.items[1].title=="Series")
plugin:showManga(results.items[1]); local detail=widgets[#widgets]; assert(detail.title=="Series")
local add,chapters,download_all
for _,item in ipairs(detail.item_table) do if type(item.text)=="string" and item.text:find("Add to library",1,true) then add=item elseif type(item.text)=="string" and item.text=="Chapters" then chapters=item elseif type(item.text)=="string" and item.text=="Download All Chapters" then download_all=item end end
assert(add and chapters and download_all); assert(detail.item_table[6]==download_all and detail.item_table[7]==chapters); add.action(); assert(plugin.library:contains("example",results.items[1].id))
assert(detail.item_table[1].maru_key=="Author" and detail.item_table[1].maru_value=="Unknown")
local has_cover_action=false; for _,item in ipairs(detail.item_table) do if type(item.text)=="string" and item.text:lower():find("view cover",1,true) then has_cover_action=true end end; assert(not has_cover_action)
chapters.action(); local list=widgets[#widgets]; assert(list.title:match("Series") and #list.item_table>=2 and list.page_limit==8)
plugin:loadList("Popular",function(_,cb) cb({items={results.items[1]},has_next=false}) end,function(m) return m.title end)
local popular=widgets[#widgets]; assert(popular.title=="Popular" and popular.item_table[1].maru_manga.title=="Series")
plugin:showLibrary(); local library_menu=widgets[#widgets]; assert(library_menu.title=="Library" and #library_menu.item_table==1 and library_menu.item_table[1].maru_progress:find("Check Updates",1,true))
plugin:openLibrary(); local library_submenu=widgets[#widgets]; assert(library_submenu.item_table[1].text:find("Browse library",1,true) and library_submenu.item_table[2].text:find("Search library",1,true) and library_submenu.item_table[3].text:find("Check Updates",1,true))
plugin:open(); local home=widgets[#widgets]; local home_items=home.current_page.items
assert(home.current_page.title=="MaruManga Downloader" and #home_items==6)
assert(home_items[1].text=="Discover" and home_items[2].text=="Library" and home_items[2].group_end)
assert(home_items[3].text=="Repositories" and home_items[3].group_end)
for _,item in ipairs(home_items) do assert(item.text~="Continue reading" and item.text~="History") end
plugin:about(); local about=home.current_page.items
local update_fields=0
for _,item in ipairs(about) do if item.text:find("Last Update: 2026%-%d%d%-%d%d %d%d:%d%d") then update_fields=update_fields+1 end; assert(not item.text:match("^Time:")) end
assert(update_fields==1)
plugin.panel_enabled=false; plugin.main_menu=nil
local repo=assert(plugin.repositories:add("https://example.org/catalog.json"))
local catalog={schema_version=1,id="fixture",name="Fixture",author="MRHRTZ",version="1.12.0",status="Maintenance",sources={{id="catalogone",name="Catalog One",version=1,adapter="generic",base_url="https://example.org",languages={"en","id"},nsfw=true,profile={search_path="/?q={query}"}}}}
assert(plugin.repositories:update(repo,catalog))
plugin:showRepositories(); local repos_menu=widgets[#widgets]; assert(repos_menu.item_table[5].text:find("Fixture",1,true)); assert(repos_menu.item_group[3]._underline_container.linesize==1); repos_menu.item_table[5].action()
local repo_menu=widgets[#widgets]; assert(repo_menu.title=="Fixture")
assert(repo_menu.item_table[9].text:find("Sources: 1",1,true)); repo_menu.item_table[9].action()
local source_menu=widgets[#widgets]; assert(source_menu.title=="Fixture · Sources · Page 1")
local has_tag=false; for _,item in ipairs(source_menu.item_table) do if item.text:find("NSFW",1,true) and item.text:find("en, id",1,true) then has_tag=true end end; assert(has_tag)
local catalog_source=source_menu.item_table[#source_menu.item_table]; assert(catalog_source.action and catalog_source.state)
plugin:showRepository({url="https://raw.githubusercontent.com/MRHRTZ/example/master/metadata.json",catalog={name="Example",author="Unknown",version=1,status="Unknown",sources={}}})
assert(widgets[#widgets].item_table[2].maru_key=="Author" and widgets[#widgets].item_table[2].maru_value=="MRHRTZ")
plugin:showRepositorySources(repo,"catalog one"); local filtered=widgets[#widgets]
assert(filtered.item_table[1].text:find("Matches: 1",1,true))
assert(filtered.item_table[#filtered.item_table].text:find("Catalog One",1,true))
local search_action; for _,item in ipairs(filtered.item_table) do if item.text:find("Search Sources",1,true) then search_action=item end end
assert(search_action); search_action.action(); assert(widgets[#widgets].title=="Search Sources")
plugin:showRepositorySources(repo,"not-found"); filtered=widgets[#widgets]
assert(filtered.item_table[#filtered.item_table].text=="No matching sources" and filtered.item_table[#filtered.item_table].action==nil)
plugin:showRepositorySources(repo)
plugin:catalogSourceDialog(repo,catalog.sources[1]); actions=widgets[#widgets]; assert(actions.item_table[4].text:find("Install",1,true)); actions.item_table[4].action()
assert(plugin:profile("catalogone").repository_version==1)
catalog.version=2; catalog.sources[1].version=2; assert(plugin.repositories:update(repo,catalog))
plugin:catalogSourceDialog(repo,catalog.sources[1]); actions=widgets[#widgets]; assert(actions.item_table[4].text:find("Update",1,true)); actions.item_table[4].action()
assert(plugin:profile("catalogone").repository_version==2)
local original_source=plugin.source
plugin.source=function() return {getChapterList=function(_,m,_,cb) cb({items={{id="newchapter",manga_id=m.id,name="New chapter"}}}) end} end
plugin.filesystem=function() return {exists=function() return false end,targetFor=function() return "/missing" end} end
plugin.runner=function() return {run=function(_,_,cb) cb(true,{}) end} end
plugin:showUpdates(); local updates=widgets[#widgets]; assert(updates.title=="Library updates" and updates.item_table[1].text=="Not downloaded: 1")
local sync_key=next(plugin.library.data.chapter_sync); assert(sync_key and plugin.library.data.chapter_sync[sync_key].count==1)
plugin:showLibrary(); assert(widgets[#widgets].item_table[1].maru_progress:find("Chapter 0/1 · Update Available",1,true))
local library_item=widgets[#widgets].item_table[1]
assert(library_item.maru_icon=="manga" and library_item.maru_badge=="badge-update" and library_item.maru_title and library_item.maru_progress=="Chapter 0/1 · Update Available")
-- A missing historical chapter must not show an update badge when the latest
-- available chapter is already downloaded.
local library_key,library_manga=next(plugin.library.data.manga)
plugin.library.data.chapter_sync[library_key]={count=25,missing_count=1,latest_number=24}
plugin.library.data.archives["/fixture/latest.cbz"]={manga={source_id=library_manga.source_id,id=library_manga.id},chapter={chapter_number=24}}
plugin:showLibrary()
local latest_row=widgets[#widgets].item_table[1]
assert(latest_row.maru_progress:find("Latest",1,true) and latest_row.maru_badge=="badge-latest")
plugin.library.data.archives["/fixture/latest.cbz"]=nil
plugin.library.data.chapter_sync[library_key]={count=1,missing_count=1}
plugin.filesystem=function() return {exists=function(file) return file=="/missing" end,targetFor=function() return "/missing" end} end
plugin:showUpdates(); updates=widgets[#widgets]; local orphan=false
for _,item in ipairs(updates.item_table) do if item.text:find("Unindexed downloads: 1",1,true) then orphan=true end end
assert(orphan and updates.item_table[1].text=="Not downloaded: 0")
plugin.filesystem=function() return {exists=function() return true end,targetFor=function() return "/missing" end} end
plugin:showUpdates(); updates=widgets[#widgets]; local incomplete=false
for _,item in ipairs(updates.item_table) do if item.text:find("Incomplete downloads: 1",1,true) then incomplete=true end end
assert(incomplete and updates.item_table[1].text=="Not downloaded: 1")
-- Legacy/corrupt archive records must not crash library rendering.
plugin.library.data.archives["/broken/entry.cbz"]={manga={},chapter={chapter_number=1}}
local saved_key,saved_manga=next(plugin.library.data.manga)
saved_manga.genres={"Action",{unexpected=true}}
plugin:showLibrary()
local resilient_library=widgets[#widgets]
assert(resilient_library.title=="Library" and #resilient_library.item_table==1)
assert(resilient_library.item_table[1].maru_meta:find("Action",1,true))
plugin.library.data.archives["/broken/entry.cbz"]=nil
saved_manga.genres={}
plugin.source=original_source
os.remove(settings_dir.."/marumanga.lua"); os.remove(settings_dir.."/marumanga.lua.old"); os.remove(settings_dir.."/marumanga.lua.new"); os.execute("rmdir "..settings_dir)
print("Plugin source integration tests passed")
