-- UI registration and configuration with mocked KOReader widgets.
local settings_file=os.tmpname(); os.remove(settings_file)
local settings_dir=settings_file..".dir"; assert(os.execute("mkdir "..settings_dir)==0)
local store={file=settings_file,data={},backup=function() return false end,readSetting=function(self,k) return self.data[k] end,saveSetting=function(self,k,v) self.data[k]=v end,flush=function() end}
local widgets={}
package.preload["ui/widget/container/widgetcontainer"]=function() return {extend=function(_,v) return v end} end
package.preload["ui/uimanager"]=function() return {show=function(_,w) widgets[#widgets+1]=w end,close=function() end,nextTick=function(_,f) f() end,scheduleIn=function() end,isWidgetShown=function() return true end,getTopmostVisibleWidget=function() return widgets[#widgets] end,setDirty=function() end} end
for _,name in ipairs({"ui/widget/infomessage","ui/widget/buttondialog","ui/widget/trapwidget","ui/widget/confirmbox","ui/widget/menu","ui/widget/inputdialog"}) do
    package.preload[name]=function() return {new=function(_,v) return v end} end
end
package.preload["ui/widget/multiinputdialog"]=function() return {new=function(_,v)
    v.added={}; function v:addWidget(widget) self.added[#self.added+1]=widget end
    function v:getFields() local result={}; for i,field in ipairs(self.fields or {}) do result[i]=field.text end; return result end
    return v
end} end
package.preload["ui/widget/checkbutton"]=function() return {new=function(_,v) return v end} end
package.preload["ui/widget/inputdialog"]=function() return {new=function(_,v) v.onShowKeyboard=function() end; return v end} end
package.preload["ui/widget/titlebar"]=function() return {new=function(_,v) return v end} end
local function simple_widget() return {new=function(_,v) return v or {} end} end
for _,name in ipairs({"ui/widget/container/centercontainer","ui/widget/container/framecontainer","ui/widget/horizontalgroup","ui/widget/horizontalspan","ui/widget/imagewidget","ui/widget/container/leftcontainer","ui/widget/overlapgroup","ui/widget/container/rightcontainer","ui/widget/textwidget","ui/widget/scrolltextwidget","ui/widget/verticalgroup","ui/widget/verticalspan","ui/widget/container/underlinecontainer","ui/geometry","ui/gesturerange"}) do
    package.preload[name]=simple_widget
end
package.preload["ui/widget/textboxwidget"]=function() return {new=function(_,options)
    local lines=math.max(1,math.ceil(#(options.text or "")/40))
    return {getSize=function() return {h=lines*22,w=options.width} end}
end} end
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
package.preload.device=function() return {screen={getWidth=function() return 600 end,getHeight=function() return 900 end,scaleBySize=function(_,size) return size end}} end
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
local menu={}; plugin:addToMainMenu(menu); assert(registered and menu.marumanga and menu.marumanga.text=="MaruManga" and menu.marumanga.sorting_hint=="tools" and plugin.config.data.source=="komiku")
plugin:openSettings()
local settings_menu=widgets[#widgets]
assert(settings_menu.title=="Settings" and #settings_menu.item_table==5)
assert(settings_menu.item_table[1].text=="Network" and settings_menu.item_table[1].group_end)
assert(settings_menu.item_table[2].text=="Download")
assert(settings_menu.item_table[3].text=="Storage")
assert(settings_menu.item_table[4].text=="Migrate")
assert(settings_menu.item_table[5].text=="Uninstall" and settings_menu.item_table[5].group_end)
local bundled_repo; for _,candidate in ipairs(plugin.repositories:list()) do if candidate.builtin then bundled_repo=candidate end end
assert(bundled_repo and #plugin.config.data.auto_installed_source_ids>=4)
assert(plugin:profile("komiku").repository_url==bundled_repo.url)
for _,catalog in ipairs(plugin:sourceCatalogs()) do
    if catalog.local_profiles then
        for _,source in ipairs(catalog.catalog.sources) do assert(source.id~="komiku") end
    end
end
for _,entry in ipairs(bundled_repo.catalog.sources) do if entry.adapter~="planned" and entry.adapter~="mangadex" then assert(plugin:profile(entry.id)) end end
local default_profile_count=#plugin.config.data.profiles; assert(plugin:installDefaultCatalogSources() and #plugin.config.data.profiles==default_profile_count)
assert(plugin:profile("mangago") and plugin:profile("mangago").enabled==false)
local real_refresh=plugin.refreshRepository; local auto_refresh=false
plugin.default_refresh_started=nil; plugin.refreshRepository=function(_,repo,options) assert(repo.url:find("raw.githubusercontent.com",1,true)); auto_refresh=true; options.callback(true) end
plugin:showRepositories(); assert(widgets[#widgets].title=="Repositories (1)")
plugin.repositories.data.default_repository.unreachable=nil; plugin.repositories.data.default_repository.last_error=nil; plugin.refreshRepository=real_refresh
assert(plugin.config:addProfile({id="example",name="Example",base_url="https://example.org",kind="generic",search_path="/?q={query}&page={page}",popular_path="/popular?page={page}",latest_path="/latest?page={page}",list_selector="article",list_link_selector="a",list_title_selector="span",list_cover_selector="img",title_selector="h1",description_selector=".summary__content",chapter_selector="li.chapter a",page_selector=".reader img"}))
plugin.config.data.source="example"
local source=assert(plugin:source()); assert(source:getName()=="Example" and source:getId()=="example")
plugin:showSources(); assert(#widgets>0 and widgets[#widgets].title=="Sources")
source.transport.get=function(_,url,cb)
    if url:find("?q=",1,true) then cb('<article><a href="/manga/a"><img src="/cover.jpg"><span>Series</span></a></article>')
    else cb('<h1>Series</h1><div class="summary__content">Description</div><li class="chapter"><a href="/chapter/1">Chapter 1</a></li>') end
end
plugin:openDiscover(); local discover=widgets[#widgets]; assert(discover.title=="Discover" and #discover.item_table==4)
local manage_item=discover.item_table[4]; assert(manage_item.text=="Manage Sources" and manage_item.group_end); manage_item.action()
local manage_menu=widgets[#widgets]; assert(manage_menu.title=="Manage Sources" and #manage_menu.item_table==#plugin.config.data.profiles+2)
local example_item; for _,item in ipairs(manage_menu.item_table) do if item.text:find("Example",1,true) then example_item=item end end
assert(example_item and example_item.state and example_item.action); example_item.action()
manage_menu=widgets[#widgets]
for _,item in ipairs(manage_menu.item_table) do if item.text=="Save" then item.action() end end
assert(plugin:profile("example").enabled==false and plugin.config.data.source=="komiku")
local saved_enabled={}
for _,profile in ipairs(plugin.config.data.profiles) do saved_enabled[profile]=profile.enabled; profile.enabled=profile.id=="komiku" end
local discover_sources={}; plugin:withDiscoverSource("Search",function(id) discover_sources[#discover_sources+1]=id end)
assert(#discover_sources==1 and discover_sources[1]=="komiku")
plugin:openDiscover()
local search_menu=widgets[#widgets]; search_menu.item_table[1].action()
local search_source_menu=widgets[#widgets]
assert(search_source_menu.title=="Search · Sources" and search_source_menu.item_table[1].text=="All Manga")
for profile,enabled in pairs(saved_enabled) do profile.enabled=enabled end
plugin.config.data.profiles[#plugin.config.data.profiles].enabled=true
plugin.config.data.source="example"; assert(plugin.config:save())
plugin.panel_enabled=false; plugin.main_menu=nil
plugin.cacheCover=function(_,manga,callback) callback(nil) end
local previous_profiles,previous_source_method=plugin.config.data.profiles,plugin.source
local pending_search,search_calls={},{}
local fake_sources={
    first={getLanguages=function() return {"en"} end,searchManga=function(_,query,page,callback)
        assert(query=="two words" and page==2); search_calls.first=true; pending_search.first=callback
    end},
    second={getLanguages=function() return {"id"} end,searchManga=function(_,query,page,callback)
        assert(query=="two words" and page==2); search_calls.second=true; pending_search.second=callback
    end},
}
plugin.config.data.profiles={{id="first",name="First",enabled=true},{id="disabled",name="Disabled",enabled=false},{id="second",name="Second",enabled=true}}
plugin.source=function(_,id) return fake_sources[id] end
plugin:searchAllManga("two words",2)
assert(widgets[#widgets].text=="Searching manga... (1/2)" and search_calls.first and not search_calls.second)
pending_search.first({items={{id="a",source_id="first",title="First title"}},has_next=true})
assert(widgets[#widgets].text=="Searching manga... (2/2)" and search_calls.second)
pending_search.second({items={{id="b",source_id="second",title="Second title"}},has_next=false})
local combined_search=widgets[#widgets]
assert(combined_search.title=="Search" and #combined_search.item_table==2 and combined_search.page_limit==4)
assert(combined_search.item_table[1].maru_manga.source_id=="first" and combined_search.item_table[2].maru_manga.source_id=="second")
plugin.config.data.profiles,plugin.source=previous_profiles,previous_source_method
source=assert(plugin:source("example"))
source.transport.get=function(_,url,cb)
    if url:find("?q=",1,true) then cb('<article><a href="/manga/a"><img src="/cover.jpg"><span>Series</span></a></article>')
    else cb('<h1>Series</h1><div class="summary__content">Description</div><li class="chapter"><a href="/chapter/1">Chapter 1</a></li>') end
end
local results; source:searchManga("series",1,function(r) results=r end); assert(results.items[1].title=="Series")
local original_details_for_ui=source.getMangaDetails
source.getMangaDetails=function(_,manga,callback) callback({id=manga.id,title=manga.title,source_id=manga.source_id,description="",genres={}}) end
plugin:showManga(results.items[1]); source.getMangaDetails=original_details_for_ui
local detail=widgets[#widgets]; assert(detail.title=="Series")
local add,chapters,download_all
for _,item in ipairs(detail.item_table) do if type(item.text)=="string" and item.text:find("Add to library",1,true) then add=item elseif type(item.text)=="string" and item.text=="Chapters" then chapters=item elseif type(item.text)=="string" and item.text=="Download All Chapters" then download_all=item end end
assert(add and chapters and download_all); assert(detail.item_table[6]==download_all and detail.item_table[7]==chapters); add.action(); assert(plugin.library:contains("example",results.items[1].id))
assert(detail.item_table[1].maru_key=="Author" and detail.item_table[1].maru_value=="Unknown")
local has_cover_action=false; for _,item in ipairs(detail.item_table) do if type(item.text)=="string" and item.text:lower():find("view cover",1,true) then has_cover_action=true end end; assert(not has_cover_action)
source.getChapterList=function(_,manga,page,callback) callback({items={{id="chapter-1",manga_id=manga.id,name="Chapter 1"}},has_next=false}) end
chapters.action(); local list=widgets[#widgets]; assert(list.title:match("Series") and #list.item_table>=2 and list.page_limit>6 and list.fill_height)
assert(widgets[#widgets-1].text=="Loading chapters...")
list.item_table[1].action(); list=widgets[#widgets]
assert(list.title:match("Series") and widgets[#widgets-1].text=="Loading chapters...")
source.getChapterList=function(_,manga,page,callback) callback({items={},has_next=false}) end
plugin:chapters(results.items[1],1); local empty_chapters=widgets[#widgets]
assert(empty_chapters.item_table[2].text=="No chapters found")
local page_calls={}
plugin.main_menu={visible=true,setPage=function(_,title,items,settings)
    page_calls[#page_calls+1]={title=title,items=items,settings=settings}
    return page_calls[#page_calls]
end}
plugin.panel_enabled=true
source.getChapterList=function(_,manga,page,callback) callback({items={{id="chapter-1",manga_id=manga.id,name="Chapter 1"}},has_next=false}) end
plugin:chapters(results.items[1],1,"desc")
assert(page_calls[#page_calls].settings.push==true)
page_calls[#page_calls].items[1].action()
assert(page_calls[#page_calls].settings.push==false,"sorting must replace the chapter page, not add a back-stack entry")
local saved_cache_cover,saved_details=plugin.cacheCover,source.getMangaDetails
plugin.cacheCover=function(_,manga,callback) callback(nil) end
source.getMangaDetails=function(_,manga,callback) callback({id=manga.id,source_id=manga.source_id,title=manga.title,description="",genres={}}) end
local back_test_manga={id="back-stack-test",source_id="example",title="Back Stack Test"}
plugin:showManga(back_test_manga)
assert(page_calls[#page_calls].settings.push==true,"opening details from results should push a page")
local add_to_library
for _,item in ipairs(page_calls[#page_calls].items) do if item.text=="Add to library" then add_to_library=item end end
assert(add_to_library); add_to_library.action()
assert(page_calls[#page_calls].settings.push==false,"adding to library should replace the detail page")
local has_remove_from_library=false
for _,item in ipairs(page_calls[#page_calls].items) do if item.text=="Remove from library" then has_remove_from_library=true end end
assert(has_remove_from_library)
assert(plugin.library:remove("example","back-stack-test"))
plugin.cacheCover,source.getMangaDetails=saved_cache_cover,saved_details
plugin.main_menu=nil; plugin.panel_enabled=false
plugin:loadList("Popular",function(_,cb) cb({items={results.items[1]},has_next=false}) end,function(m) return m.title end)
local popular=widgets[#widgets]; assert(popular.title=="Popular" and popular.item_table[1].maru_manga.title=="Series" and popular.page_limit==4)
results.items[1].latest_chapter="Chapter 23"
results.items[1].status="Ongoing"
plugin:loadList("Search",function(_,cb) cb({items={results.items[1]},has_next=false}) end,function(m) return m.title end)
assert(widgets[#widgets].item_table[1].maru_progress=="Ongoing · Chapter 23")
results.items[1].status="End"
plugin:loadList("Popular",function(_,cb) cb({items={results.items[1]},has_next=false}) end,function(m) return m.title end)
assert(widgets[#widgets].item_table[1].maru_progress=="End · Chapter 23")
results.items[1].status=nil
results.items[1].cover_url="https://example.org/list-cover.jpg"
local original_cache,original_details=plugin.cacheCover,source.getMangaDetails
plugin.cacheCover=function(_,manga,callback)
    callback(manga.cover_url=="https://example.org/detail-cover.jpg" and "/cache/detail-cover.jpg" or nil)
end
source.getMangaDetails=function(_,manga,callback) callback({cover_url="https://example.org/detail-cover.jpg"}) end
plugin:loadList("Popular",function(_,cb) cb({items={results.items[1]},has_next=false}) end,function(m) return m.title end)
local cover_page={}; plugin.main_menu={visible=true,current_page=cover_page,renderCurrentPage=function() end}
plugin:prefetchVisibleCovers(widgets[#widgets].item_table,1,1,cover_page)
assert(widgets[#widgets].item_table[1].maru_image=="/cache/detail-cover.jpg" and widgets[#widgets].item_table[1].maru_cover_detail_attempted)
plugin.main_menu=nil
plugin.cacheCover,source.getMangaDetails=original_cache,original_details
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
plugin.panel_enabled=false; plugin:openSettings(); local settings_menu=widgets[#widgets]
assert(settings_menu.title=="Settings" and #settings_menu.item_table==5)
assert(settings_menu.item_table[1].text=="Network" and settings_menu.item_table[1].group_end)
assert(settings_menu.item_table[2].text=="Download" and settings_menu.item_table[3].text=="Storage")
assert(settings_menu.item_table[4].text=="Migrate")
assert(settings_menu.item_table[5].text=="Uninstall")
settings_menu.item_table[5].action(); local first_uninstall=widgets[#widgets]
assert(first_uninstall.ok_text=="Uninstall" and first_uninstall.cancel_text=="Cancel")
first_uninstall.ok_callback(); local uninstall_choices=widgets[#widgets]
assert(uninstall_choices.title=="Uninstall MaruManga Downloader" and #uninstall_choices.buttons==3)
assert(uninstall_choices.buttons[1][1].text=="Cancel" and uninstall_choices.buttons[2][1].text=="Keep data")
assert(uninstall_choices.buttons[3][1].text=="Uninstall")
uninstall_choices.buttons[1][1].callback()
plugin.panel_enabled=false; plugin.main_menu=nil
local repo=assert(plugin.repositories:add("https://example.org/catalog.json"))
local catalog={schema_version=1,id="fixture",name="Fixture",author="MRHRTZ",version="1.12.0",status="Maintenance",sources={{id="catalogone",name="Catalog One",version=1,adapter="generic",base_url="https://example.org",languages={"en","id"},nsfw=true,profile={search_path="/?q={query}",popular_path="/popular",latest_path="/latest",list_selector="article",chapter_selector=".chapters a",page_selector=".reader img"}}}}
assert(plugin.repositories:update(repo,catalog))
plugin:showRepositories(); local repos_menu=widgets[#widgets]; assert(repos_menu.item_table[5].text:find("Fixture",1,true)); assert(repos_menu.item_group[3]._underline_container.linesize==1); repos_menu.item_table[5].action()
local repo_menu=widgets[#widgets]; assert(repo_menu.title=="Fixture")
assert(repo_menu.item_table[9].text:find("Sources: 1",1,true)); repo_menu.item_table[9].action()
local source_menu=widgets[#widgets]; assert(source_menu.title=="Fixture · Sources")
local has_tag=false; for _,item in ipairs(source_menu.item_table) do if item.text:find("NSFW",1,true) and item.text:find("EN%-ID") then has_tag=true end end; assert(has_tag)
local catalog_source=source_menu.item_table[#source_menu.item_table]; assert(catalog_source.action and catalog_source.state)
plugin:catalogSourceDialog(repo,{id="incomplete",name="Incomplete",version=1,adapter="generic",base_url="https://example.org",profile={search_path="/"}})
local unsupported_source=widgets[#widgets]; assert(unsupported_source.item_table[3].text:find("Unsupported",1,true))
for _,item in ipairs(unsupported_source.item_table) do assert(not (item.action and item.text=="Install")) end
plugin:catalogSourceDialog(repo,{id="madara-ready",name="Madara ready",version=1,adapter="madara",base_url="https://example.org",profile={search_path="/?q={query}",popular_path="/popular",latest_path="/latest",list_selector="article",chapter_selector=".chapters a",page_selector=".reader img"}})
local madara_source=widgets[#widgets]; local madara_install=false
for _,item in ipairs(madara_source.item_table) do if item.text=="Install" and item.action then madara_install=true end end
assert(madara_install)
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
library_item.action()
local manga_actions=widgets[#widgets]; local verify_action=false
for _,action in ipairs(manga_actions.item_table or {}) do if action.text=="Verify Download" and action.action then verify_action=true end end
assert(verify_action,"Library manga actions should expose per-title download verification")
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
saved_manga.status="Ongoing"
plugin:showLibrary()
local resilient_library=widgets[#widgets]
assert(resilient_library.title=="Library" and #resilient_library.item_table==1)
assert(resilient_library.item_table[1].maru_meta:find("Action",1,true))
assert(resilient_library.item_table[1].maru_progress:find("Ongoing · Chapter ",1,true))
plugin.library.data.archives["/broken/entry.cbz"]=nil
saved_manga.genres={}; saved_manga.status=nil
plugin.source=original_source
os.remove(settings_dir.."/marumanga.lua"); os.remove(settings_dir.."/marumanga.lua.old"); os.remove(settings_dir.."/marumanga.lua.new"); os.execute("rmdir "..settings_dir)
print("Plugin source integration tests passed")
