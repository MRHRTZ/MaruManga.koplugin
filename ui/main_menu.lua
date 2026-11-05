-- E-ink friendly home dialog with bundled vector icons and a centered mascot.
local ButtonDialog = require("ui/widget/buttondialog")
local CenterContainer = require("ui/widget/container/centercontainer")
local FrameContainer = require("ui/widget/container/framecontainer")
local HorizontalGroup = require("ui/widget/horizontalgroup")
local HorizontalSpan = require("ui/widget/horizontalspan")
local ImageWidget = require("ui/widget/imagewidget")
local InputContainer = require("ui/widget/container/inputcontainer")
local LeftContainer = require("ui/widget/container/leftcontainer")
local OverlapGroup = require("ui/widget/overlapgroup")
local RightContainer = require("ui/widget/container/rightcontainer")
local TextWidget = require("ui/widget/textwidget")
local TextBoxWidget = require("ui/widget/textboxwidget")
local ScrollTextWidget = require("ui/widget/scrolltextwidget")
local VerticalGroup = require("ui/widget/verticalgroup")
local UnderlineContainer = require("ui/widget/container/underlinecontainer")
local UIManager = require("ui/uimanager")
local Device = require("device")
local Font = require("ui/font")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local Blitbuffer = require("ffi/blitbuffer")
local Size = require("ui/size")
local Screen = Device.screen

local MainRow = InputContainer:extend{ text="", icon=nil, image=nil, trailing_icon=nil, state=nil, state_width=nil, callback=nil, hold_callback=nil, separator=false, title=nil, meta=nil, progress=nil, row_height=nil, key=nil, value=nil, no_icon=false }
function MainRow:init()
    local width = assert(self.width)
    local row_height = Screen:scaleBySize(self.row_height or 62)
    local icon_size = Screen:scaleBySize(34)
    local leading_width = (self.key or self.no_icon) and 0 or (self.state_width or icon_size)
    local state=self.state
    if not state and self.image then
        -- Manga covers may be large source images. Do not put their full-size
        -- decoded buffers in KOReader's shared image LRU; repeated discovery
        -- searches can otherwise exhaust its small cache on e-ink devices.
        local ok,image=pcall(ImageWidget.new,ImageWidget,{file=self.image,width=Screen:scaleBySize(42),height=Screen:scaleBySize(58),alpha=true,scale_factor=0,file_do_cache=false})
        if ok then state=image end
    end
    if not state and not self.key and not self.no_icon then state=ImageWidget:new{file=self.icon,width=icon_size,height=icon_size,alpha=true} end
    local trailing
    local trailing_width=0
    if self.trailing_icon then
        trailing_width=Screen:scaleBySize(28)
        trailing=CenterContainer:new{dimen=Geom:new{w=trailing_width,h=row_height},ImageWidget:new{file=self.trailing_icon,width=Screen:scaleBySize(24),height=Screen:scaleBySize(24),alpha=true}}
    end
    local label_width=math.max(Screen:scaleBySize(80),width-leading_width-trailing_width-4*Size.padding.large-Screen:scaleBySize(16))
    local label
    if self.key then
        local key_width=math.min(Screen:scaleBySize(124),math.floor(width*0.34))
        local value_width=math.max(Screen:scaleBySize(80),width-key_width-Screen:scaleBySize(46))
        local value_widget=TextBoxWidget:new{text=self.value or "",face=Font:getFace("infofont",18),width=value_width,padding=0}
        row_height=math.max(row_height,value_widget:getSize().h+Screen:scaleBySize(12))
        label=HorizontalGroup:new{
            align="center",
            TextWidget:new{text=self.key,face=Font:getFace("infofont",18),max_width=key_width,bold=true},
            HorizontalSpan:new{width=Screen:scaleBySize(10)},
            value_widget,
        }
    elseif self.title then
        local title_widget=TextBoxWidget:new{text=self.title,face=Font:getFace("infofont",22),width=label_width,padding=0,bold=true}
        row_height=math.max(row_height,title_widget:getSize().h+Screen:scaleBySize(48))
        label=VerticalGroup:new{
            align="left",
            title_widget,
            TextWidget:new{text=self.meta or "",face=Font:getFace("infofont",18),max_width=label_width},
            TextWidget:new{text=self.progress or "",face=Font:getFace("infofont",18),max_width=label_width,bold=true},
        }
    else
        label=TextBoxWidget:new{text=self.text or "",face=Font:getFace("infofont",24),width=label_width,padding=0}
        row_height=math.max(row_height,label:getSize().h+Screen:scaleBySize(12))
    end
    self.dimen = Geom:new{x=0,y=0,w=width,h=row_height}
    self.ges_events = { TapSelect = { GestureRange:new{ges="tap",range=self.dimen} } }
    if self.hold_callback then self.ges_events.HoldSelect={GestureRange:new{ges="hold",range=self.dimen}} end
    local group={align="center"}
    if not self.key and not self.no_icon then
        group[#group+1]=HorizontalSpan:new{width=Size.padding.large}
        group[#group+1]=CenterContainer:new{dimen=Geom:new{w=leading_width,h=row_height},state}
        group[#group+1]=HorizontalSpan:new{width=Size.padding.large}
    end
    group[#group+1]=label
    if trailing then group[#group+1]=HorizontalSpan:new{width=Size.padding.large}; group[#group+1]=trailing end
    local content=HorizontalGroup:new(group)
    if self.key then
        self[1]=FrameContainer:new{bordersize=0,padding=0,content}
    else
        self.underline = UnderlineContainer:new{
            padding=0,vertical_align="center",color=Blitbuffer.COLOR_DARK_GRAY,linesize=Size.line.medium,
            focus_linesize=Size.line.focus_row,background=Blitbuffer.COLOR_WHITE,
            dimen=Geom:new{x=0,y=0,w=width,h=row_height},content,
        }
        self[1] = FrameContainer:new{bordersize=0,padding=0,self.underline}
    end
end
function MainRow:onTapSelect()
    if self.callback then self.callback() end
    return true
end
function MainRow:onHoldSelect()
    if self.hold_callback then self.hold_callback() end
    return true
end
function MainRow:onFocus()
    if not self.underline then return true end
    self.underline.color=Blitbuffer.COLOR_BLACK
    self.underline.focused=true
    return true
end
function MainRow:onUnfocus()
    if not self.underline then return true end
    self.underline.color=Blitbuffer.COLOR_DARK_GRAY
    self.underline.focused=false
    return true
end
function MainRow:getFocusIndicatorRegion()
    return self.underline and self.underline:getFocusIndicatorRegion()
end
function MainRow:repaintFocusIndicator(bb)
    if self.underline then return self.underline:repaintFocusIndicator(bb) end
end

local CloseButton = InputContainer:extend{callback=nil}
function CloseButton:init()
    local size=Screen:scaleBySize(48)
    self.dimen=Geom:new{x=0,y=0,w=size,h=size}
    self.ges_events={TapSelect={GestureRange:new{ges="tap",range=self.dimen}}}
    self[1]=CenterContainer:new{dimen=self.dimen,ImageWidget:new{file=self.icon,width=Screen:scaleBySize(26),height=Screen:scaleBySize(26),alpha=true}}
end
function CloseButton:onTapSelect()
    if self.callback then self.callback() end
    return true
end

local MangaCard = InputContainer:extend{icon_dir="",image=nil,title="",meta="",progress="",callback=nil,width=0,height=0}
function MangaCard:init()
    self.dimen=Geom:new{x=0,y=0,w=self.width,h=self.height}
    self.ges_events={TapSelect={GestureRange:new{ges="tap",range=self.dimen}}}
    local cover_h=Screen:scaleBySize(150)
    local file=self.image or self.icon_dir.."fallback-cover.svg"
    local ok,image=pcall(ImageWidget.new,ImageWidget,{file=file,width=self.width-Screen:scaleBySize(14),height=cover_h,alpha=true,scale_factor=0,file_do_cache=false})
    if not ok then image=ImageWidget:new{file=self.icon_dir.."fallback-cover.svg",width=self.width-Screen:scaleBySize(14),height=cover_h,alpha=true,scale_factor=0,file_do_cache=false} end
    local function compact(value,limit)
        value=tostring(value or "")
        if #value>limit then return value:sub(1,limit-1).."…" end
        return value
    end
    self[1]=FrameContainer:new{
        bordersize=Size.border.window,padding=Screen:scaleBySize(6),background=Blitbuffer.COLOR_WHITE,
        dimen=Geom:new{w=self.width,h=self.height},
        VerticalGroup:new{
            align="center",
            CenterContainer:new{dimen=Geom:new{w=self.width-Screen:scaleBySize(14),h=cover_h},image},
            TextWidget:new{text=compact(self.title,48),face=Font:getFace("infofont",18),bold=true,max_width=self.width-Screen:scaleBySize(16)},
            TextWidget:new{text=compact(self.meta,58),face=Font:getFace("infofont",15),max_width=self.width-Screen:scaleBySize(16)},
            TextWidget:new{text=compact(self.progress,54),face=Font:getFace("infofont",15),bold=true,max_width=self.width-Screen:scaleBySize(16)},
        }
    }
end
function MangaCard:onTapSelect()
    if self.callback then self.callback() end
    return true
end

local M = {}
function M.new(options)
    options=options or {}
    local _=require("gettext")
    local icon_dir=options.icon_dir or ""
    local width=math.floor(Screen:getWidth()*0.92)
    local dialog
    dialog=ButtonDialog:new{buttons={},width=width,dismissable=false,use_info_style=false,tap_close_callback=options.on_close}
    local inner_width=width-2*Size.border.window-2*Size.padding.button
        -2*(Size.padding.large+Size.margin.title)
    inner_width=math.max(Screen:scaleBySize(180),inner_width)
    dialog.keep_radius=true
    dialog.visible=false
    dialog.icon_dir=icon_dir
    dialog.page_stack={}
    dialog.page_limit=20
    local function runActionSafely(label, callback)
        if not callback then return end
        UIManager:nextTick(function()
            local ok, err = xpcall(callback, function(why)
                return debug.traceback(tostring(why), 2)
            end)
            if not ok then
                local shown = pcall(function()
                    local viewer = require("ui/widget/textviewer"):new{
                        title = _("MaruManga error: ") .. tostring(label or ""),
                        text = tostring(err),
                        alignment = "left",
                        auto_para_direction = false,
                    }
                    UIManager:show(viewer)
                end)
                if not shown then
                    pcall(function()
                        UIManager:show(require("ui/widget/infomessage"):new{
                            text = _("MaruManga action failed: ") .. tostring(label or "") .. "\n" .. tostring(err),
                        })
                    end)
                end
            end
        end)
    end
    local function keepDialogCentered()
        if dialog.movable then
            dialog.movable.unmovable=true
            dialog.movable.ges_events={}
            dialog.movable.key_events={}
            dialog.movable:setMovedOffset(Geom:new{x=0,y=0})
        end
    end
    local function render_page(page)
        local rows={}
        local items=page.items or {}
        local page_limit=page.page_limit or (page.grid and 4) or (items[1] and items[1].maru_title and 3 or dialog.page_limit)
        local page_count=math.max(1,math.ceil(#items/page_limit))
        local page_index=math.max(1,math.min(page.page_index or 1,page_count))
        page.page_index=page_index
        local first=(page_index-1)*page_limit+1
        local last=math.min(#items,first+page_limit-1)
        local back
        if page.backable then
            back=CloseButton:new{icon=icon_dir.."back.svg",callback=function()
                if page.on_back then pcall(page.on_back) end
                dialog:goBack()
            end}
        end
        local close=CloseButton:new{icon=icon_dir.."close.svg",callback=function()
            if page.on_close then pcall(page.on_close) end
            dialog:onClose()
        end}
        local title_text=page.page_title and (page.page_title.." · Page "..page_index.." / "..page_count) or page.title or "MaruManga Downloader"
        local left_reserved=page.backable and Screen:scaleBySize(56) or Screen:scaleBySize(12)
        local right_reserved=page.header_action and Screen:scaleBySize(108) or Screen:scaleBySize(56)
        local title_width=math.max(Screen:scaleBySize(120),inner_width-2*math.max(left_reserved,right_reserved))
        local title=TextWidget:new{text=title_text,face=Font:getFace("tfont",24),max_width=title_width}
        local header={
            dimen=Geom:new{w=inner_width,h=Screen:scaleBySize(56)},
            CenterContainer:new{dimen=Geom:new{w=inner_width,h=Screen:scaleBySize(56)},title},
        }
        if page.backable then header[#header+1]=LeftContainer:new{dimen=Geom:new{w=inner_width,h=Screen:scaleBySize(56)},back} end
        local right_items={}
        if page.header_action then
            right_items[#right_items+1]=CloseButton:new{icon=page.header_action.icon or icon_dir.."downloads.svg",callback=page.header_action.callback}
        end
        right_items[#right_items+1]=close
        local right_group=#right_items==1 and right_items[1] or HorizontalGroup:new{align="center",right_items[1],right_items[2]}
        header[#header+1]=RightContainer:new{dimen=Geom:new{w=inner_width,h=Screen:scaleBySize(56)},right_group}
        rows[#rows+1]=OverlapGroup:new(header)
        if page.mascot then
            rows[#rows+1]=CenterContainer:new{
                dimen=Geom:new{w=inner_width,h=Screen:scaleBySize(116)},
                -- The transparent mascot PNG is square. Keep the widget square
                -- and ask ImageWidget to fit while preserving its aspect ratio.
                ImageWidget:new{file=page.mascot,width=Screen:scaleBySize(108),height=Screen:scaleBySize(108),alpha=true,scale_factor=0},
            }
        end
        if page_index==1 and (page.hero or page.hero_icon) then
            local visual
            if page.hero then
                local ok,image=pcall(ImageWidget.new,ImageWidget,{file=page.hero,width=Screen:scaleBySize(118),height=Screen:scaleBySize(124),alpha=true,scale_factor=0})
                if ok then visual=image end
            end
            if not visual then visual=ImageWidget:new{file=icon_dir.."details.svg",width=Screen:scaleBySize(72),height=Screen:scaleBySize(72),alpha=true} end
            -- Keep tall covers fully inside a compact row. Oversized custom
            -- dialogs trigger ButtonDialog's grid-scroll path, which assumes
            -- native button rows and can crash on mixed custom widgets.
            rows[#rows+1]=CenterContainer:new{dimen=Geom:new{w=inner_width,h=Screen:scaleBySize(132)},visual}
        end
        if page_index==1 and page.description then
            rows[#rows+1]=UnderlineContainer:new{
                padding=0,vertical_align="center",color=Blitbuffer.COLOR_DARK_GRAY,linesize=Size.line.medium,
                background=Blitbuffer.COLOR_WHITE,dimen=Geom:new{w=inner_width,h=Screen:scaleBySize(8)},
                HorizontalSpan:new{width=inner_width},
            }
            rows[#rows+1]=LeftContainer:new{
                dimen=Geom:new{w=inner_width,h=Screen:scaleBySize(30)},
                TextWidget:new{text=require("gettext")("Description"),face=Font:getFace("infofont",18),bold=true,max_width=inner_width-Screen:scaleBySize(20)},
            }
            local description_width=inner_width-Screen:scaleBySize(16)
            local description_face=Font:getFace("infofont",18)
            local measured=TextBoxWidget:new{text=page.description,face=description_face,width=description_width,padding=0}
            local natural_height=measured:getSize().h
            local description_height=math.min(natural_height,Screen:scaleBySize(84))
            local description_widget=natural_height>description_height and ScrollTextWidget:new{
                text=page.description,face=description_face,width=description_width,height=description_height,scroll_by_pan=true,dialog=dialog,
            } or measured
            rows[#rows+1]=LeftContainer:new{
                dimen=Geom:new{w=inner_width,h=description_height+Screen:scaleBySize(6)},
                description_widget,
            }
        end
        if page.grid then
            local card_width=math.floor((inner_width-Screen:scaleBySize(12))/2)
            local card_height=Screen:scaleBySize(246)
            local index=first
            while index<=last do
                local function make_card(item_index)
                    local item=items[item_index]
                    return MangaCard:new{icon_dir=icon_dir,image=item.maru_image,title=item.maru_title or item.text,
                        meta=item.maru_meta or "",progress=item.maru_progress or "",width=card_width,height=card_height,
                        callback=function() runActionSafely(item.text,item.action) end}
                end
                local left=make_card(index)
                local right=index+1<=last and make_card(index+1) or HorizontalSpan:new{width=card_width}
                rows[#rows+1]=HorizontalGroup:new{align="center",left,HorizontalSpan:new{width=Screen:scaleBySize(12)},right}
                index=index+2
            end
        else
            for i=first,last do
                local menu_item=items[i]
                rows[#rows+1]=MainRow:new{
                    text=menu_item.text,icon=menu_item.icon or icon_dir.."details.svg",image=menu_item.maru_image,
                    trailing_icon=menu_item.maru_badge and (icon_dir..menu_item.maru_badge..".svg") or nil,state=menu_item.state,
                    state_width=menu_item.maru_state_width,separator=menu_item.group_end==true,
                    hold_callback=menu_item.hold_callback and function() runActionSafely(menu_item.text,menu_item.hold_callback) end or nil,
                    key=menu_item.maru_key,value=menu_item.maru_value,no_icon=menu_item.maru_no_icon,
                    title=menu_item.maru_title,meta=menu_item.maru_meta,progress=menu_item.maru_progress,
                    row_height=menu_item.maru_key and 52 or (menu_item.maru_title and 124 or nil),
                    width=inner_width,callback=function() runActionSafely(menu_item.text,menu_item.action) end,
                }
            end
        end
        if page_index>1 then
            rows[#rows+1]=MainRow:new{text=_("Previous page").." ("..page_index.."/"..page_count..")",icon=icon_dir.."previous-page.svg",width=inner_width,callback=function()
                runActionSafely(_("Previous page"),function()
                    page.page_index=page_index-1; dialog:renderCurrentPage()
                end)
            end}
        end
        if page_index<page_count then
            rows[#rows+1]=MainRow:new{text=_("Next page").." ("..page_index.."/"..page_count..")",icon=icon_dir.."next-page.svg",width=inner_width,callback=function()
                runActionSafely(_("Next page"),function()
                    page.page_index=page_index+1; dialog:renderCurrentPage()
                end)
            end}
        elseif page.external_next then
            rows[#rows+1]=MainRow:new{text=page.external_next.text or _("Load more results"),icon=icon_dir.."next-page.svg",width=inner_width,callback=function()
                if page.external_next.action then UIManager:nextTick(page.external_next.action) end
            end}
        end
        -- ButtonDialog's `reinit` rebuilds its inner MovableContainer. Replace
        -- the visible instance through UIManager so the old frame cannot remain
        -- painted underneath the new page. Reuse this same dialog object.
        local was_visible=dialog.visible
        if was_visible then UIManager:close(dialog); dialog.visible=false end
        dialog._added_widgets=rows
        dialog:reinit()
        if dialog.movable and dialog.movable[1] then dialog.movable[1].radius=Screen:scaleBySize(12) end
        keepDialogCentered()
        if was_visible then UIManager:show(dialog); dialog.visible=true end
        UIManager:setDirty(dialog,"ui")
        if page.on_page then UIManager:nextTick(function()
            if dialog.visible and dialog.current_page==page then page.on_page(first,last) end
        end) end
    end
    function dialog:renderCurrentPage()
        render_page(self.current_page)
    end
    function dialog:setPage(title,items,settings)
        settings=settings or {}
        if settings.root then
            self.page_stack={}
        elseif settings.push~=false and self.current_page then
            self.page_stack[#self.page_stack+1]=self.current_page
        end
        self.current_page={title=title,items=items or {},mascot=settings.mascot,hero=settings.hero,hero_icon=settings.hero_icon,description=settings.description,on_page=settings.on_page,on_back=settings.on_back,on_close=settings.on_close,header_action=settings.header_action,page_limit=settings.page_limit,page_index=1,grid=settings.grid,page_title=settings.page_title,external_next=settings.external_next,backable=not settings.root}
        if settings.root then self.root_page=self.current_page end
        self:renderCurrentPage()
        if settings.show then UIManager:show(self); self.visible=true end
        return self
    end
    function dialog:goBack()
        if #self.page_stack>0 then
            self.current_page=table.remove(self.page_stack)
            self:renderCurrentPage()
        elseif self.root_page and self.current_page~=self.root_page then
            self.current_page=self.root_page
            self.page_stack={}
            self:renderCurrentPage()
        end
    end
    dialog:setPage(options.title or "MaruManga Downloader",options.items or {},{root=true,mascot=options.mascot,show=false})
    return dialog
end
return M
