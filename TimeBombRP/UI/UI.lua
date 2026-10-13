local ADDON, ns = ...
local T, L = ns.Theme, ns.L
local UI = {}; UI.__index = UI; ns.UI = UI
local unpack = unpack or table.unpack

local function clean(value, limit)
    return ns.Util.Clean(tostring(value or ""), limit or 120)
end
local function text(parent, size, color, width, height)
    local label = parent:CreateFontString(nil, "OVERLAY")
    label:SetFont(T.font, size, T.fontFlags)
    label:SetTextColor(unpack(T.colors[color or "ivory"]))
    label:SetJustifyH("LEFT"); label:SetJustifyV("TOP")
    if width then label:SetWidth(width) end
    if height then label:SetHeight(height) end
    return label
end
local function single(label)
    label:SetWordWrap(false); label:SetMaxLines(1)
    return label
end
local function anchor(object, x, y)
    object:SetPoint("TOPLEFT", x, -y)
end
local function panel(parent, width, height, color, edge)
    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetSize(width, height)
    frame:SetBackdrop({ bgFile=T.texture, edgeFile=T.edge, edgeSize=1,
        insets={left=1,right=1,top=1,bottom=1} })
    frame:SetBackdropColor(unpack(T.colors[color or "panel"]))
    frame:SetBackdropBorderColor(unpack(T.colors[edge or "brassDim"]))
    return frame
end
local function tooltip(frame, title, body)
    if not GameTooltip then return end
    GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
    GameTooltip:SetText(title or "", unpack(T.colors.ivory))
    if body and body ~= "" then GameTooltip:AddLine(body, .85, .79, .67, true) end
    GameTooltip:Show()
end
local function hideTooltip()
    if GameTooltip then GameTooltip:Hide() end
end
local function asset(parent, name, width, height, layer)
    local texture = parent:CreateTexture(nil, layer or "ARTWORK")
    texture:SetSize(width, height)
    if texture:SetTexture(T.Asset(name)) == false then texture:SetTexture(T.texture); texture:SetVertexColor(unpack(T.colors.brassDim)) end
    return texture
end
local function button(parent, label, width, callback, hint)
    local frame = CreateFrame("Button", nil, parent, "BackdropTemplate")
    frame:SetSize(width, 26)
    frame:SetBackdrop({bgFile=T.texture,edgeFile=T.edge,edgeSize=1,insets={left=1,right=1,top=1,bottom=1}})
    frame:SetBackdropColor(.18,.105,.065,1); frame:SetBackdropBorderColor(unpack(T.colors.brassDim))
    frame.label = single(text(frame, 11, "ivory", width-10, 15)); frame.label:SetPoint("CENTER",0,0); frame.label:SetJustifyH("CENTER")
    frame.label:SetText(label)
    frame:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(unpack(T.colors.brass))
        if hint then tooltip(self,label,hint) end
    end)
    frame:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(unpack(T.colors.brassDim)); hideTooltip() end)
    frame:SetScript("OnMouseDown", function(self) if self:IsEnabled() then self:SetBackdropColor(.28,.16,.08,1) end end)
    frame:SetScript("OnMouseUp", function(self) self:SetBackdropColor(.18,.105,.065,1) end)
    frame:SetScript("OnEnable", function(self) self:SetAlpha(1) end)
    frame:SetScript("OnDisable", function(self) self:SetAlpha(.42) end)
    frame:SetScript("OnClick", function(self) hideTooltip(); if callback then callback(self) end end)
    return frame
end
local function enable(frame, enabled)
    if enabled then frame:Enable() else frame:Disable() end
end
local function edit(parent, width, placeholder)
    local holder = panel(parent,width,26,"wood","brassDim")
    local box = CreateFrame("EditBox",nil,holder)
    box:SetPoint("TOPLEFT",7,-4); box:SetPoint("BOTTOMRIGHT",-7,4)
    box:SetFont(T.font,12,T.fontFlags); box:SetTextColor(unpack(T.colors.ivory))
    box:SetAutoFocus(false); box:SetMaxBytes(96); box:SetTextInsets(0,0,0,0)
    box:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
    box:SetScript("OnHide", function(self) self:ClearFocus() end)
    box:SetScript("OnEnter", function(self) tooltip(self,placeholder) end)
    box:SetScript("OnLeave",hideTooltip)
    holder.box=box
    return holder
end
local function pulse(texture)
    local group=texture:CreateAnimationGroup()
    local out=group:CreateAnimation("Alpha"); out:SetFromAlpha(1); out:SetToAlpha(.4); out:SetDuration(T.animation.pulse); out:SetOrder(1)
    local incoming=group:CreateAnimation("Alpha"); incoming:SetFromAlpha(.4); incoming:SetToAlpha(1); incoming:SetDuration(T.animation.pulse); incoming:SetOrder(2)
    group:SetLooping("REPEAT")
    return group
end
local function reveal(texture)
    local group=texture:CreateAnimationGroup()
    local a=group:CreateAnimation("Alpha"); a:SetFromAlpha(.25); a:SetToAlpha(1); a:SetDuration(T.animation.reveal); a:SetOrder(1)
    return group
end

function UI:Call(method, ...)
    if self.controller[method] then return self.controller[method](self.controller, ...) end
end
function UI:Player(id)
    for _, p in ipairs(self.view and self.view.players or {}) do if p.id == id then return p end end
end
function UI:Name(id)
    local p = self:Player(id)
    local fallback=p and p.name or id or ""
    return clean(self:Call("DisplayName",id,fallback) or ns.Roleplay:Name(id,fallback,self.controller.isDemo),80)
end
function UI:SavePosition(frame)
    local x,y=frame:GetCenter(); local px,py=UIParent:GetCenter()
    if x and y and px and py then
        local scale=frame:GetScale()
        if frame==self.mini then self.settings.miniX=x*scale-px; self.settings.miniY=y*scale-py
        else self.settings.x=x*scale-px; self.settings.y=y*scale-py end
    end
    self.settings.point="CENTER"
end
function UI:Position(frame, mini)
    frame:ClearAllPoints()
    local scale=math.max(.7,math.min(1.5,tonumber(self.settings.scale) or 1))
    frame:SetScale(scale)
    local x=mini and self.settings.miniX or self.settings.x
    local y=mini and self.settings.miniY or self.settings.y
    frame:SetPoint("CENTER",UIParent,"CENTER",(tonumber(x) or 0)/scale,(tonumber(y) or 0)/scale)
end
function UI:ReleaseFocus()
    if self.nameInput then self.nameInput.box:ClearFocus() end
    if self.inviteInput then self.inviteInput.box:ClearFocus() end
end
function UI:Show()
    self.visible=true
    if self.settings.minimized then self.frame:Hide(); self.mini:Show()
    else self.mini:Hide(); self.frame:Show() end
    if self.miniTop then self:RenderMini(self.wasYourTurn) end
end
function UI:Toggle()
    if self.frame:IsShown() or self.mini:IsShown() then self:Hide() else self:Show() end
end
function UI:Hide()
    self.visible=false; self:ReleaseFocus(); self.frame:Hide(); self.mini:Hide(); hideTooltip()
end
function UI:Minimize()
    self.settings.minimized=true; self:ReleaseFocus(); self:Show()
end
function UI:Expand()
    self.settings.minimized=false; self:Show()
end
function UI:Reset()
    self.settings.x=0; self.settings.y=0; self.settings.miniX=0; self.settings.miniY=0; self.settings.scale=1; self.settings.minimized=false
    self:Position(self.frame); self:Position(self.mini,true); self:Show()
end

function UI:BuildChrome()
    local f=panel(UIParent,T.width,T.height,"wood","brass")
    self.frame=f; f:SetFrameStrata("DIALOG"); f:SetClampedToScreen(true); f:SetMovable(true); f:EnableMouse(true)
    local surface=asset(f,"table",T.width-4,T.height-4,"BACKGROUND"); surface:SetPoint("CENTER"); surface:SetAlpha(.75)
    local shade=f:CreateTexture(nil,"BORDER"); shade:SetAllPoints(); shade:SetColorTexture(.035,.015,.018,.3)
    local header=CreateFrame("Frame",nil,f); header:SetPoint("TOPLEFT",1,-1); header:SetSize(T.width-2,40); header:EnableMouse(true)
    header:RegisterForDrag("LeftButton"); header:SetScript("OnDragStart",function() f:StartMoving() end)
    header:SetScript("OnDragStop",function() f:StopMovingOrSizing(); self:SavePosition(f) end)
    local title=text(header,17,"ivory",152,22); anchor(title,15,11); title:SetText(L.TITLE)
    self.tableLabel=single(text(header,11,"muted",315,16)); anchor(self.tableLabel,175,14)
    local actions={{"?","RULES","help"},{"=","HISTORY","history"},{"*","OPTIONS","options"}}
    for i,a in ipairs(actions) do
        local b=button(header,a[1],25,function() self:OpenDrawer(a[3]) end,L[a[2]])
        anchor(b,535+(i-1)*29,8)
    end
    self.connection=button(header,"·",25,nil,L.TRANSPORT_HINT); anchor(self.connection,502,8)
    self.connection:SetScript("OnEnter",function()
        local good=self.controller.isDemo or self.controller.transportStatus=="CONNECTED"
        tooltip(self.connection,good and L.ONLINE or L.OFFLINE,L.TRANSPORT_HINT)
    end)
    local mini=button(header,"_",25,function() self:Minimize() end,L.MINIMIZE); anchor(mini,622,8)
    local close=button(header,"x",25,function() self:Hide() end,L.CLOSE); anchor(close,651,8)
    local line=f:CreateTexture(nil,"ARTWORK"); line:SetColorTexture(unpack(T.colors.brassDim)); line:SetSize(668,1); anchor(line,16,44)
    self.progress=text(f,12,"ivory",662,19); anchor(self.progress,19,53); self.progress:SetJustifyH("CENTER")
    self.banner=panel(f,672,28,"velvet","brassDim"); anchor(self.banner,14,77)
    self.bannerText=single(text(self.banner,11,"ivory",644,16)); anchor(self.bannerText,13,7); self.bannerText:SetJustifyH("CENTER")
    self.status=single(text(f,10,"muted",662,14)); anchor(self.status,18,T.height-16)
    self.status:SetText(L.STATUS_IDLE)
    f:SetScript("OnHide",function() self:ReleaseFocus(); self:HideCardPreview(true); hideTooltip() end)
    self:Position(f)
    -- A named Escape proxy closes our custom overlays first, then the window.
    self.escape=CreateFrame("Frame","TimeBombRPEscape",f)
    self.escape:SetSize(1,1); self.escape:SetPoint("TOPLEFT"); self.escape:Hide()
    self.escape:SetScript("OnHide",function()
        if self.modal and self.modal:IsShown() then self.modal:Hide()
        elseif self.drawer and self.drawer:IsShown() then self.drawer:Hide()
        elseif self.frame:IsShown() then self:Hide() end
        if C_Timer and C_Timer.After then C_Timer.After(0,function() if self.frame:IsShown() then self.escape:Show() end end) end
    end)
    f:HookScript("OnShow",function() self.escape:Show() end)
    if UISpecialFrames then table.insert(UISpecialFrames,"TimeBombRPEscape") end
    -- Also re-arm during mouse interaction for clients restoring a hidden parent.
    f:SetScript("OnMouseDown",function() self.escape:Show() end)
end

function UI:BuildMini()
    local f=CreateFrame("Button",nil,UIParent,"BackdropTemplate"); self.mini=f
    f:SetSize(T.miniWidth,T.miniHeight); f:SetFrameStrata("DIALOG"); f:SetMovable(true); f:SetClampedToScreen(true)
    f:SetBackdrop({bgFile=T.texture,edgeFile=T.edge,edgeSize=1,insets={left=1,right=1,top=1,bottom=1}})
    f:SetBackdropColor(unpack(T.colors.wood)); f:SetBackdropBorderColor(unpack(T.colors.brass))
    local emblem=asset(f,"pliers",32,32); anchor(emblem,6,4); self.miniPulse=pulse(emblem)
    self.miniTop=single(text(f,12,"ivory",274,15)); anchor(self.miniTop,44,5)
    self.miniBottom=single(text(f,10,"muted",274,13)); anchor(self.miniBottom,44,22)
    f:RegisterForDrag("LeftButton"); f:SetScript("OnDragStart",function() self.miniDragged=true; f:StartMoving() end)
    f:SetScript("OnDragStop",function() f:StopMovingOrSizing(); self:SavePosition(f) end)
    f:SetScript("OnClick",function() if self.miniDragged then self.miniDragged=false else self:Expand() end end)
    f:SetScript("OnEnter",function() tooltip(f,L.RESTORE,self.miniHint) end); f:SetScript("OnLeave",hideTooltip)
    f:SetScript("OnHide",function() self.miniPulse:Stop() end)
    self:Position(f,true); f:Hide()
end

function UI:BuildWelcome()
    local f=CreateFrame("Frame",nil,self.frame); self.welcome=f; f:SetAllPoints()
    local chest=asset(f,"chest",190,190); anchor(chest,64,150)
    local ornament=asset(f,"ornament",160,72); anchor(ornament,78,348); ornament:SetAlpha(.6)
    local title=text(f,23,"ivory",370,30); anchor(title,288,151); title:SetText(L.CREATE_TITLE)
    local subtitle=text(f,12,"muted",356,38); anchor(subtitle,290,190); subtitle:SetText(L.CREATE_HINT)
    local label=text(f,11,"muted",330,15); anchor(label,290,238); label:SetText(L.TABLE_NAME)
    self.nameInput=edit(f,333,L.TABLE_NAME); anchor(self.nameInput,290,258); self.nameInput.box:SetText(L.DEFAULT_TABLE)
    local function create()
        local name=clean(self.nameInput.box:GetText(),64); self.nameInput.box:ClearFocus()
        if name=="" then self:Notice("ERROR_TABLE_NAME") else self:Call("Create",name) end
    end
    self.nameInput.box:SetScript("OnEnterPressed",create)
    local createButton=button(f,L.CREATE,333,create); anchor(createButton,290,296)
    local demo4=button(f,L.DEMO4,162,function() self:Call("Demo",4) end); anchor(demo4,290,350)
    local demo8=button(f,L.DEMO8,163,function() self:Call("Demo",8) end); anchor(demo8,460,350)
    local rule=text(f,12,"amber",610,24); anchor(rule,45,420); rule:SetJustifyH("CENTER"); rule:SetText(L.RULESET)
end

function UI:BuildSeat(index)
    local seat=panel(self.tableArea,208,67,"panel","brassDim"); self.seats[index]=seat
    seat.name=single(text(seat,11,"ivory",159,14)); anchor(seat.name,9,7)
    seat.nameHit=CreateFrame("Frame",nil,seat); seat.nameHit:SetPoint("TOPLEFT",5,-2); seat.nameHit:SetSize(198,23); seat.nameHit:EnableMouse(true)
    seat.nameHit:SetScript("OnEnter",function()
        if seat.player then
            local p=seat.player; local info=p.id
            if p.id==self.controller.id then info=info .. "\n" .. L.YOU end
            if self.view and p.id==self.view.hostId then info=info .. "\n" .. L.HOST end
            tooltip(seat.nameHit,self:Name(p.id),clean(info,240))
        end
    end); seat.nameHit:SetScript("OnLeave",hideTooltip)
    seat.token=asset(seat,"pliers",25,25); seat.token:SetPoint("TOPRIGHT",-4,-1); seat.token:Hide(); seat.tokenReveal=reveal(seat.token)
    seat.state=single(text(seat,10,"muted",190,16)); anchor(seat.state,9,33)
    seat.remaining=single(text(seat,9,"muted",66,13)); anchor(seat.remaining,138,26); seat.remaining:SetJustifyH("RIGHT")
    seat.badge=single(text(seat,9,"blue",66,22)); seat.badge:SetPoint("BOTTOMRIGHT",-4,5); seat.badge:SetJustifyH("RIGHT"); seat.badge:SetWordWrap(true); seat.badge:SetMaxLines(2)
    seat.cards={}
    for n=1,5 do
        local card=CreateFrame("Button",nil,seat,"BackdropTemplate"); card.seat=seat; card:SetSize(23,36); anchor(card,8+(n-1)*26,25)
        card:SetBackdrop({bgFile=T.texture,edgeFile=T.edge,edgeSize=1}); card:SetBackdropColor(.05,.03,.025,1); card:SetBackdropBorderColor(unpack(T.colors.brassDim))
        card.texture=asset(card,"card_back",21,34); card.texture:SetPoint("CENTER"); card.flash=reveal(card.texture)
        card.number=single(text(card,8,"ivory",19,10)); card.number:SetPoint("BOTTOM",0,1); card.number:SetJustifyH("CENTER"); card.number:SetText(tostring(n))
        card:SetScript("OnEnter",function()
            if not seat.player or not card.slot then return end
            local reason=self:CardReason(seat.player,card.slot)
            local face=card.slot.revealed and L[card.slot.face or "SAFE"] or L.CARD_HIDDEN
            self:ShowCardPreview(card,seat.player,n,face,reason)
            if not reason then card:SetBackdropBorderColor(unpack(T.colors.brass)) end
        end)
        card:SetScript("OnLeave",function() self:HideCardPreview(); self:PaintSelection() end)
        card:SetScript("OnHide",function() if self.hoveredCard==card then self:HideCardPreview(true) end end)
        card:SetScript("OnClick",function()
            if seat.player and card.slot and not self:CardReason(seat.player,card.slot) then
                self.selection={targetId=seat.player.id,slotId=card.slot.id}; self:PaintSelection(); self:RenderCenter()
            end
        end)
        seat.cards[n]=card
    end
    return seat
end

function UI:BuildCardPreview()
    local f=panel(self.frame,108,184,"wood","brass"); self.cardPreview=f
    f:SetFrameLevel(self.frame:GetFrameLevel()+20); f:EnableMouse(false)
    f.texture=asset(f,"card_back",94,146); anchor(f.texture,7,7)
    f.caption=single(text(f,10,"ivory",100,18)); anchor(f.caption,4,160); f.caption:SetJustifyH("CENTER")
    local function animation(fromScale,toScale,fromAlpha,toAlpha,duration)
        local group=f:CreateAnimationGroup()
        local scale=group:CreateAnimation("Scale"); scale:SetScaleFrom(fromScale,fromScale); scale:SetScaleTo(toScale,toScale)
        scale:SetOrigin("CENTER",0,0); scale:SetDuration(duration); scale:SetSmoothing("OUT")
        local alpha=group:CreateAnimation("Alpha"); alpha:SetFromAlpha(fromAlpha); alpha:SetToAlpha(toAlpha); alpha:SetDuration(duration)
        return group
    end
    f.enter=animation(.65,1,0,1,T.animation.hover)
    f.exit=animation(1,.9,1,0,T.animation.dismiss)
    f.exit:SetScript("OnFinished",function() if not self.hoveredCard then f:Hide() end end)
    f:Hide()
end

function UI:ShowCardPreview(card,player,index,face,reason)
    if player.id==self.controller.id or not card.slot then return end
    self:HideCardPreview(true)
    local f=self.cardPreview; self.hoveredCard=card
    f:ClearAllPoints()
    -- Inspect in the center, leaving names, hand and original click areas unobscured.
    f:SetPoint("TOP",self.center,"TOP",0,-48)
    f.texture:SetTexture(T.Asset(card.slot.revealed and "card_"..string.lower(card.slot.face) or "card_back"))
    f.caption:SetText(string.format(L.CARD_NUMBER,index)); f:Show()
    if not self.settings.reducedMotion then f.enter:Play() end
    tooltip(f,self:Name(player.id).." · "..face,reason)
end

function UI:HideCardPreview(immediate)
    self.hoveredCard=nil; hideTooltip()
    local f=self.cardPreview; if not f then return end
    f.enter:Stop(); f.exit:Stop()
    if immediate or self.settings.reducedMotion then f:Hide()
    elseif f:IsShown() then f.exit:Play() end
end

function UI:BuildTable()
    self.tableArea=CreateFrame("Frame",nil,self.frame); self.tableArea:SetAllPoints(); self.seats={}
    for i=1,8 do self:BuildSeat(i) end
    local c=CreateFrame("Frame",nil,self.tableArea); c:SetSize(244,286); anchor(c,228,114); self.center=c
    self.centerTitle=text(c,15,"ivory",242,39); anchor(self.centerTitle,1,0); self.centerTitle:SetJustifyH("CENTER")
    self.chest=asset(c,"chest",114,114); anchor(self.chest,65,36)
    self.progressDots={}
    for i=1,8 do local dot=asset(c,"progress_off",18,18); anchor(dot,42+(i-1)*20,146); self.progressDots[i]=dot end
    self.lastTitle=text(c,10,"muted",238,14); anchor(self.lastTitle,3,170); self.lastTitle:SetJustifyH("CENTER")
    self.lastFace=text(c,13,"ivory",238,20); anchor(self.lastFace,3,189); self.lastFace:SetJustifyH("CENTER")
    self.centerHint=text(c,10,"muted",240,44); anchor(self.centerHint,2,212); self.centerHint:SetJustifyH("CENTER")
    self.primary=button(c,L.CHOOSE_CARD,240,function() self:PrimaryAction() end); anchor(self.primary,2,256)
    self.lobby=CreateFrame("Frame",nil,c); self.lobby:SetAllPoints()
    self.inviteInput=edit(self.lobby,240,L.INVITE_NAME); anchor(self.inviteInput,2,50)
    self.inviteInput.box:SetMaxBytes(100)
    local function sendInvite()
        local name=clean(self.inviteInput.box:GetText(),100); self.inviteInput.box:ClearFocus()
        if name=="" then self:Notice("ERROR_NAME") else self:Call("Invite",name) end
    end
    self.inviteInput.box:SetScript("OnEnterPressed",sendInvite)
    self.inviteButton=button(self.lobby,L.INVITE,112,sendInvite); anchor(self.inviteButton,2,85)
    self.targetButton=button(self.lobby,L.INVITE_TARGET,120,function() self:Call("InviteTarget") end); anchor(self.targetButton,122,85)
    self.inviteSummary=button(self.lobby,L.INVITATIONS,240,function() self:OpenDrawer("invitations") end); anchor(self.inviteSummary,2,119)
    self.readyLabel=text(self.lobby,12,"muted",236,33); anchor(self.readyLabel,4,164); self.readyLabel:SetJustifyH("CENTER")
    self.readyButton=button(self.lobby,L.SET_READY,240,function() self:Call("Ready") end); anchor(self.readyButton,2,202)
    self.privatePanel=panel(self.tableArea,672,174,"wood","brass"); anchor(self.privatePanel,14,405)
    self.privatePanel:EnableMouse(true)
    self.privatePanel:SetScript("OnEnter",function() tooltip(self.privatePanel,self:Name(self.controller.id),clean(self.controller.id,100)) end)
    self.privatePanel:SetScript("OnLeave",hideTooltip)
    self.handTitle=single(text(self.privatePanel,17,"ivory",410,22)); anchor(self.handTitle,18,12); self.handTitle:SetText(L.YOUR_HAND)
    self.handBadge=single(text(self.privatePanel,11,"amber",200,18)); self.handBadge:SetPoint("TOPRIGHT",-18,-15); self.handBadge:SetJustifyH("RIGHT")
    self.roleIcon=asset(self.privatePanel,"emblem_defuser",48,48); anchor(self.roleIcon,18,58)
    self.roleCaption=text(self.privatePanel,10,"muted",128,14); anchor(self.roleCaption,75,61); self.roleCaption:SetText(L.YOUR_ROLE)
    self.role=single(text(self.privatePanel,13,"ivory",135,20)); anchor(self.role,75,80)
    self.counts=single(text(self.privatePanel,10,"muted",200,16)); anchor(self.counts,18,121)
    self.privateHint=text(self.privatePanel,10,"muted",620,18); anchor(self.privateHint,18,149)
    self.handCards={}
    for i=1,5 do
        local card=CreateFrame("Frame",nil,self.privatePanel); card:SetSize(68,105); anchor(card,239+(i-1)*80,38)
        card.texture=asset(card,"card_back",66,101); card.texture:SetPoint("TOP")
        card.label=single(text(card,10,"ivory",66,15)); card.label:SetPoint("BOTTOM",0,3); card.label:SetJustifyH("CENTER")
        card:EnableMouse(true)
        card:SetScript("OnEnter",function() if card.face then tooltip(card,L[card.face],L.PRIVATE_HINT) end end)
        card:SetScript("OnLeave",hideTooltip); card:Hide(); self.handCards[i]=card
    end
    self:BuildCardPreview()
    self.tableArea:Hide()
end

function UI:CardReason(player,slot)
    local v=self.view
    if not v then return L.ERROR_PHASE end
    if slot.revealed then return L.REVEALED_CARD end
    if v.suspended or v.recovering then return L.ERROR_SUSPENDED end
    if player.connected==false then return L.DISCONNECTED end
    if v.phase~="ACTIVE" then return L.ERROR_PHASE end
    if self.controller.pending then return L.WAITING end
    if v.currentHolderId~=self.controller.id then return L.OTHER_TURN end
    if player.id==self.controller.id then return L.SELF_CARD end
    if player.id==v.previousHolderId then return string.format(L.RETURN_FORBIDDEN,self:Name(player.id)) end
    if not player.remaining or player.remaining<1 then return L.EMPTY_HAND end
    local p=v.private
    if not p or p.round~=v.round or p.gameId~=v.gameId then return L.PRIVATE_SYNC end
end

function UI:PaintSelection()
    for _,seat in ipairs(self.seats) do
        for _,card in ipairs(seat.cards) do
            local selected=self.selection and seat.player and self.selection.targetId==seat.player.id and card.slot and self.selection.slotId==card.slot.id
            card:SetBackdropBorderColor(unpack(T.colors[selected and "ivory" or "brassDim"]))
            card:SetBackdropColor(unpack(T.colors[selected and "brass" or "wood"]))
        end
    end
end

function UI:RenderSeats(animate)
    local v=self.view; local players=v.players or {}
    local order={}; local me
    for _,p in ipairs(players) do if p.id==self.controller.id then me=p else order[#order+1]=p end end
    if me and v.phase=="LOBBY" then order[#order+1]=me end
    local rows=math.max(2,math.ceil(#order/2)); local spacing=rows==4 and 71 or (rows==3 and 95 or 139)
    for i,seat in ipairs(self.seats) do
        local p=order[i]; seat.player=p
        if not p then seat:Hide()
        else
            seat:Show(); seat:ClearAllPoints()
            local col=(i-1)%2; local row=math.floor((i-1)/2)
            seat.column=col
            local top=rows==2 and 145 or (rows==3 and 120 or 113)
            anchor(seat,col==0 and 14 or 478,top+row*spacing)
            seat.name:SetText(self:Name(p.id))
            seat.name:SetTextColor(unpack(T.colors[p.connected==false and "muted" or "ivory"]))
            seat.token:SetShown(p.id==v.currentHolderId)
            if animate and p.id==v.currentHolderId and p.id~=self.lastHolder then seat.tokenReveal:Play() end
            seat:SetBackdropBorderColor(unpack(T.colors[p.id==v.currentHolderId and "brass" or "brassDim"]))
            local badge=""
            if p.connected==false then badge=L.DISCONNECTED
            elseif p.id==v.previousHolderId and v.phase~="LOBBY" and v.phase~="GAME_OVER" then badge=L.RETURN_BADGE
            elseif p.id==self.controller.id then badge=L.YOU
            elseif p.id==v.hostId then badge=L.HOST end
            seat.badge:SetText(badge)
            seat.remaining:SetText(v.phase~="LOBBY" and v.phase~="GAME_OVER" and string.format(L.REMAINING,p.remaining or 0) or "")
            if v.phase~="LOBBY" and v.phase~="GAME_OVER" and (p.remaining or 0)==0 and badge=="" then seat.badge:SetText(L.EMPTY_HAND) end
            if v.phase=="LOBBY" then
                seat.state:Show(); seat.state:SetText((p.ready and "✓ " or "○ ") .. (p.ready and L.READY or L.NOT_READY))
                seat.state:SetTextColor(unpack(T.colors[p.ready and "green" or "muted"]))
            elseif v.phase=="GAME_OVER" and not v.cancelled and p.role then
                seat.state:Show(); seat.state:SetText(L[p.role]); seat.state:SetTextColor(unpack(T.colors.ivory))
            else seat.state:Hide() end
            for n,card in ipairs(seat.cards) do
                local slot=p.slots and p.slots[n]
                local old=card.slot
                card.slot=slot
                if slot and v.phase~="LOBBY" and v.phase~="GAME_OVER" then
                    card:Show()
                    local face=slot.revealed and slot.face or nil
                    card.texture:SetTexture(T.Asset(face and "card_" .. string.lower(face) or "card_back"))
                    local legal=not self:CardReason(p,slot)
                    card:SetAlpha(slot.revealed and .78 or legal and 1 or .62)
                    if animate and old and old.id==slot.id and not old.revealed and slot.revealed then card.flash:Play() end
                else card:Hide() end
            end
            if v.phase~="LOBBY" and v.phase~="GAME_OVER" and (not p.slots or #p.slots==0) then
                seat.state:Show(); seat.state:SetText(L.EMPTY_HAND)
            end
        end
    end
    self:PaintSelection()
end

function UI:PrimaryAction()
    local v=self.view; if not v or self.controller.pending then return end
    if v.phase=="LOBBY" then self:Call("Start")
    elseif v.phase=="BETWEEN_ROUNDS" then self:Call("Next")
    elseif v.phase=="GAME_OVER" then self:Call("Rematch")
    elseif v.phase=="ACTIVE" and self.selection then
        local p=self:Player(self.selection.targetId)
        if not p then return end
        for _,slot in ipairs(p.slots or {}) do
            if slot.id==self.selection.slotId and not self:CardReason(p,slot) then
                self:Call("Cut",p.id,slot.id); self:RenderCenter(); return
            end
        end
    end
end

function UI:RenderCenter()
    local v=self.view; if not v then return end
    local phase=v.phase; local host=v.hostId==self.controller.id; local blocked=v.suspended or v.recovering or self.controller.pending
    self.lobby:SetShown(phase=="LOBBY")
    self.chest:SetShown(phase~="LOBBY")
    self.lastTitle:SetShown(phase~="LOBBY"); self.lastFace:SetShown(phase~="LOBBY"); self.centerHint:SetShown(phase~="LOBBY")
    for i,dot in ipairs(self.progressDots) do
        dot:SetShown(phase~="LOBBY" and i<=(v.playerCount or #v.players))
        dot:SetTexture(T.Asset(i<=(v.defused or 0) and "progress_on" or "progress_off"))
        dot:ClearAllPoints(); anchor(dot,(244-(v.playerCount or #v.players)*20)/2+(i-1)*20,146)
    end
    local title=L.ACTIVE; local hint=""; local primary=L.CHOOSE_CARD; local allowed=false
    if phase=="LOBBY" then
        title=L.LOBBY; local ready=0; local connected=true
        for _,p in ipairs(v.players or {}) do if p.ready then ready=ready+1 end; if p.connected==false then connected=false end end
        self.readyLabel:SetText(string.format(L.READY_COUNT,ready,#v.players))
        local me=self:Player(self.controller.id); self.readyButton.label:SetText(me and me.ready and L.UNREADY or L.SET_READY)
        enable(self.readyButton,not blocked); enable(self.inviteButton,host and not blocked); enable(self.targetButton,host and not blocked)
        self.inviteInput:SetAlpha(host and 1 or .4); self.inviteInput.box:SetEnabled(host)
        primary=host and L.START or L.WAIT_HOST; allowed=host and ready==#v.players and ready>=4 and ready<=8 and connected
    elseif phase=="PREPARING" then title=L.PREPARING; hint=L.PREPARING_HINT; primary=L.WAITING
    elseif phase=="BETWEEN_ROUNDS" then title=L.BETWEEN_ROUNDS; hint=L.BETWEEN_HINT; primary=host and L.NEXT or L.WAIT_HOST; allowed=host
    elseif phase=="GAME_OVER" then
        title=v.cancelled and L.CANCELLED or (v.winner and string.format(L.WINNER,L[v.winner]) or L.GAME_OVER)
        hint=v.cancelled and L.CANCELLED_HINT or (v.cause=="BOMB" and L.CAUSE_BOMB or (v.cause=="DEFUSED" and L.CAUSE_DEFUSED or L.CAUSE_ROUNDS))
        if v.discardedRole then hint=hint .. "\n" .. string.format(L.DISCARDED_ROLE,L[v.discardedRole]) end
        primary=host and L.REMATCH or L.WAIT_HOST; allowed=host
    else
        title=v.currentHolderId==self.controller.id and L.YOUR_TURN or string.format(L.HOLDER,self:Name(v.currentHolderId))
        hint=v.currentHolderId==self.controller.id and L.TURN_HINT or ""
        if self.selection then primary=string.format(L.CUT,self:Name(self.selection.targetId)); allowed=v.currentHolderId==self.controller.id end
    end
    local last=v.history and v.history[#v.history]
    self.lastTitle:SetText(last and L.LAST_REVEAL or "")
    self.lastFace:SetText(last and L[last.face or "SAFE"] or L.NO_REVEAL)
    self.lastFace:SetTextColor(unpack(T.colors[last and (last.face=="BOMB" and "red" or last.face=="DEFUSE" and "green" or "ivory") or "muted"]))
    if v.suspended then title=L.SUSPENDED; hint=L.SUSPENDED_HINT end
    if v.recovering then title=L.RECOVERING; hint=L.RECOVERING_HINT end
    if self.controller.pending then primary=L.WAITING end
    self.centerTitle:SetText(title); self.centerHint:SetText(hint); self.primary.label:SetText(primary); enable(self.primary,allowed and not blocked)
end

function UI:RenderPrivate()
    local v=self.view; local p=v.private
    local valid=p and p.role and p.counts and p.round==v.round and p.gameId==v.gameId and not v.cancelled
    self.roleIcon:SetShown(valid and true or false); self.roleCaption:SetShown(valid and true or false)
    for _,card in ipairs(self.handCards) do card.face=nil; card:Hide() end
    local me=self:Player(self.controller.id)
    local badge=me and me.connected==false and L.DISCONNECTED or v.currentHolderId==self.controller.id and L.YOUR_TURN or ""
    if v.phase=="LOBBY" then badge=me and me.ready and L.READY or L.NOT_READY end
    if badge=="" and v.previousHolderId==self.controller.id and v.phase~="GAME_OVER" then badge=L.RETURN_BADGE end
    self.handBadge:SetText(badge)
    self.handTitle:SetText(L.YOUR_HAND.." · "..self:Name(self.controller.id))
    if valid then
        self.roleIcon:SetTexture(T.Asset(p.role=="SABOTEUR" and "emblem_saboteur" or "emblem_defuser"))
        self.role:SetText(L[p.role]); local counts=p.counts
        local total=(counts.SAFE or 0)+(counts.DEFUSE or 0)+(counts.BOMB or 0)
        self.counts:SetText(string.format(L.HAND_COUNT,total))
        self.privateHint:SetText(total>0 and L.PRIVATE_HINT or L.PRIVATE_NONE)
        local i=0
        -- This is a grouped histogram, never a mapping to public slot handles.
        for _,face in ipairs({"DEFUSE","SAFE","BOMB"}) do
            for _=1,counts[face] or 0 do
                i=i+1; local card=self.handCards[i]
                if card then
                    card.face=face; card.texture:SetTexture(T.Asset("card_"..string.lower(face))); card.label:SetText(L[face.."_SHORT"])
                    card:ClearAllPoints(); anchor(card,239+(5-total)*40+(i-1)*80,38); card:Show()
                end
            end
        end
    else
        self.role:SetText(""); self.counts:SetText("")
        self.privateHint:SetText((v.phase=="LOBBY" or v.cancelled) and L.PRIVATE_EMPTY or L.PRIVATE_SYNC)
    end
end

function UI:RenderMini(yourTurn)
    local v=self.view
    if not v then self.miniTop:SetText(L.TITLE); self.miniBottom:SetText(L.CREATE_HINT); self.miniHint=L.RESTORE
    else
        local prefix=yourTurn and (L.YOUR_TURN .. " · ") or ""
        self.miniTop:SetText(prefix .. (v.phase=="LOBBY" and string.format(L.SEATS,#v.players) or string.format(L.PROGRESS_MINI,v.round or 0,v.defused or 0,v.playerCount or #v.players)))
        self.miniBottom:SetText(v.suspended and L.SUSPENDED or v.recovering and L.RECOVERING or (v.currentHolderId and string.format(L.HOLDER,self:Name(v.currentHolderId)) or clean(v.tableName)))
        self.miniHint=v.previousHolderId and string.format(L.RETURN_PUBLIC,self:Name(v.previousHolderId)) or L.RULESET
    end
    if yourTurn and not self.settings.reducedMotion and self.mini:IsShown() then self.miniPulse:Play() else self.miniPulse:Stop() end
end

function UI:Render(view,event)
    local old=self.view
    local changed=not old or not view or old.gameId~=view.gameId or old.round~=view.round or old.revision~=view.revision
    if changed then self.selection=nil; self:HideCardPreview(true) end
    local eventKind=type(event)=="table" and (event.kind or event.type) or event
    local animate=not self.settings.reducedMotion and old and view and old.gameId==view.gameId and old.round==view.round and eventKind=="CUT"
    self.view=view
    self.welcome:SetShown(not view); self.tableArea:SetShown(view~=nil)
    if view then
        self.tableLabel:SetText(self.controller.isDemo and (L.DEMO .. " · " .. #view.players) or clean(view.tableName,80))
        if view.phase=="LOBBY" then self.progress:SetText(string.format(L.SEATS,#view.players) .. "  ·  " .. L.RULESET)
        else self.progress:SetText(string.format(L.PROGRESS,view.round or 0,view.cuts or 0,view.playerCount or #view.players,view.defused or 0,view.playerCount or #view.players)) end
        local banner=L.RULESET
        if view.recovering then banner=L.RECOVERING_HINT
        elseif view.suspended then banner=L.SUSPENDED_HINT
        elseif view.previousHolderId and view.phase~="GAME_OVER" then banner=string.format(view.currentHolderId==self.controller.id and L.RETURN_FORBIDDEN or L.RETURN_PUBLIC,self:Name(view.previousHolderId))
        end
        if not self.controller.isDemo and self.controller.transportStatus and self.controller.transportStatus~="CONNECTED" then banner=L.ERROR_TRANSPORT end
        self.bannerText:SetText(banner)
        self:RenderSeats(animate); self:RenderCenter(); self:RenderPrivate()
    else
        self.tableLabel:SetText(L.SUBTITLE); self.progress:SetText(L.TITLE)
        self.bannerText:SetText(self.controller.transportStatus and self.controller.transportStatus~="CONNECTED" and L.ERROR_TRANSPORT or L.RULESET)
    end
    local yourTurn=view and view.phase=="ACTIVE" and view.currentHolderId==self.controller.id and not view.suspended and not view.recovering
    if yourTurn and not self.wasYourTurn and old and eventKind~="SNAPSHOT" and eventKind~="RECOVERING" then
        if self.settings.sound and PlaySound then PlaySound(T.sounds.turn,"Master") end
        if self.settings.autoExpand and self.visible then self:Expand() end
    end
    self:RenderMini(yourTurn); self.wasYourTurn=yourTurn; self.lastHolder=view and view.currentHolderId
    local online=self.controller.isDemo or self.controller.transportStatus=="CONNECTED"
    self.connection.label:SetText(online and "·" or "!"); self.connection.label:SetTextColor(unpack(T.colors[online and "green" or "red"]))
    if self.drawer:IsShown() then self:RefreshDrawer() end
    if self.frame:IsShown() then self.escape:Show() end
end

function UI:BuildDrawer()
    local f=panel(self.frame,672,384,"wood","brass"); self.drawer=f; anchor(f,14,78); f:SetFrameLevel(self.frame:GetFrameLevel()+30); f:EnableMouse(true)
    self.drawerTitle=text(f,18,"ivory",555,26); anchor(self.drawerTitle,17,14)
    local back=button(f,L.BACK,70,function() f:Hide(); self.escape:Show() end); anchor(back,586,11)
    local scroll=CreateFrame("ScrollFrame",nil,f); self.drawerScroll=scroll; scroll:SetSize(612,314); anchor(scroll,18,54)
    local child=CreateFrame("Frame",nil,scroll); child:SetSize(606,314); scroll:SetScrollChild(child); self.drawerContent=child
    self.drawerText=text(child,12,"ivory",597); anchor(self.drawerText,0,0); self.drawerText:SetSpacing(4)
    local function shift(delta)
        local max=math.max(0,child:GetHeight()-scroll:GetHeight())
        scroll:SetVerticalScroll(math.max(0,math.min(max,scroll:GetVerticalScroll()+delta)))
    end
    scroll:EnableMouseWheel(true); scroll:SetScript("OnMouseWheel",function(_,delta) shift(-delta*36) end)
    self.scrollUp=button(f,"↑",24,function() shift(-100) end); anchor(self.scrollUp,638,56)
    self.scrollDown=button(f,"↓",24,function() shift(100) end); anchor(self.scrollDown,638,339)
    local options=CreateFrame("Frame",nil,f); self.options=options; options:SetSize(636,315); anchor(options,18,51)
    self.checks={}
    local optionKeys={{"sound","OPTION_SOUND"},{"reducedMotion","OPTION_MOTION"},{"autoExpand","OPTION_EXPAND"},{"ignoreInvites","OPTION_IGNORE"},{"autoEmotes","OPTION_EMOTES"}}
    for i,pair in ipairs(optionKeys) do
        local key,labelKey=pair[1],pair[2]
        local check=button(options,"",23,function()
            local value=not self.settings[key]; self.settings[key]=value; self:Call("SetOption",key,value); self:HideCardPreview(true); self:RefreshDrawer(); self:RenderMini(self.wasYourTurn)
        end)
        anchor(check,0,(i-1)*29); check:SetHeight(23)
        local label=text(options,12,"ivory",565,20); anchor(label,33,4+(i-1)*29); label:SetText(L[labelKey])
        self.checks[key]=check
    end
    local scaleTitle=text(options,11,"muted",170,17); anchor(scaleTitle,0,157); scaleTitle:SetText(L.OPTION_SCALE)
    self.scaleValue=text(options,11,"ivory",70,17); anchor(self.scaleValue,512,157)
    local slider=CreateFrame("Slider",nil,options,"BackdropTemplate"); self.scaleSlider=slider
    slider:SetSize(300,16); anchor(slider,184,156); slider:SetOrientation("HORIZONTAL"); slider:SetMinMaxValues(.7,1.5); slider:SetValueStep(.05); slider:SetObeyStepOnDrag(true)
    slider:SetBackdrop({bgFile=T.texture,edgeFile=T.edge,edgeSize=1}); slider:SetBackdropColor(unpack(T.colors.panel)); slider:SetBackdropBorderColor(unpack(T.colors.brassDim))
    slider:SetThumbTexture(T.texture); slider:GetThumbTexture():SetVertexColor(unpack(T.colors.brass)); slider:GetThumbTexture():SetSize(10,18)
    slider:SetScript("OnValueChanged",function(_,value)
        value=math.floor(value*20+.5)/20
        self.settings.scale=value; self.scaleValue:SetText(string.format(L.SCALE_VALUE,math.floor(value*100+.5)))
        self:Position(self.frame); self:Position(self.mini,true)
    end)
    local reset=button(options,L.RESET_UI,585,function() self:Call("ResetUI"); self:RefreshDrawer() end); anchor(reset,0,185)
    self.demo4=button(options,L.DEMO4,268,function() self:Call("Demo",4) end); anchor(self.demo4,0,222)
    self.demo8=button(options,L.DEMO8,302,function() self:Call("Demo",8) end); anchor(self.demo8,283,222)
    self.demoNext=button(options,L.DEMO_NEXT,268,function() self:Call("DemoNext") end); anchor(self.demoNext,0,222)
    self.demoPerspective=button(options,L.DEMO_PERSPECTIVE,302,function() self:Call("DemoPerspective") end); anchor(self.demoPerspective,283,222)
    self.leaveButton=button(options,L.LEAVE,268,function() self:ConfirmLeave() end); anchor(self.leaveButton,0,263)
    self.cancelButton=button(options,L.CANCEL_GAME,302,function() self:ConfirmCancel() end); anchor(self.cancelButton,283,263)
    f:Hide()
end

function UI:OpenDrawer(kind)
    self:ReleaseFocus(); self:HideCardPreview(true); self.drawerKind=kind; self.drawerScroll:SetVerticalScroll(0); self.drawer:Show(); self:RefreshDrawer(); self.escape:Show()
end
function UI:RefreshDrawer()
    local kind=self.drawerKind or "help"; local isOptions=kind=="options"
    self.options:SetShown(isOptions); self.drawerScroll:SetShown(not isOptions); self.scrollUp:SetShown(not isOptions); self.scrollDown:SetShown(not isOptions)
    if isOptions then
        self.drawerTitle:SetText(L.OPTIONS)
        for key,check in pairs(self.checks) do check.label:SetText(self.settings[key] and "✓" or "") end
        self.scaleSlider:SetValue(self.settings.scale or 1)
        enable(self.leaveButton,self.view~=nil)
        enable(self.cancelButton,self.view~=nil and self.view.hostId==self.controller.id and self.view.phase~="GAME_OVER")
        self.demo4:SetShown(not self.controller.isDemo); self.demo8:SetShown(not self.controller.isDemo)
        enable(self.demo4,not self.view); enable(self.demo8,not self.view)
        self.demoNext:SetShown(self.controller.isDemo and true or false); self.demoPerspective:SetShown(self.controller.isDemo and true or false)
        return
    end
    local body=""
    if kind=="help" then self.drawerTitle:SetText(L.RULES); body=L.HELP_TEXT
    elseif kind=="history" then
        self.drawerTitle:SetText(L.HISTORY)
        local rows={}
        for i=#(self.view and self.view.history or {}),1,-1 do
            local h=self.view.history[i]
            rows[#rows+1]=string.format(L.HISTORY_ITEM,h.round or 0,self:Name(h.actorId),self:Name(h.targetId),L[h.face or "SAFE"])
        end
        body=#rows>0 and table.concat(rows,"\n\n") or L.NO_HISTORY
    elseif kind=="invitations" then
        self.drawerTitle:SetText(L.INVITATIONS)
        local rows={}
        for target,invite in pairs(self.outgoing or {}) do
            rows[#rows+1]=self:Name(target) .. " (" .. clean(target,100) .. ")  ·  " .. L[type(invite)=="table" and invite.status or invite or "PENDING"]
        end
        table.sort(rows)
        body=(#rows>0 and table.concat(rows,"\n\n") or L.NO_INVITATIONS) .. "\n\n" .. L.NO_RESPONSE_HINT
    end
    self.drawerText:SetText(body); self.drawerContent:SetHeight(math.max(314,self.drawerText:GetStringHeight()+15))
end

function UI:BuildModal()
    local shade=CreateFrame("Frame",nil,self.frame); self.modal=shade; shade:SetAllPoints(); shade:SetFrameLevel(self.frame:GetFrameLevel()+70); shade:EnableMouse(true)
    local bg=shade:CreateTexture(nil,"BACKGROUND"); bg:SetAllPoints(); bg:SetColorTexture(0,0,0,.75)
    local f=panel(shade,430,190,"wood","brass"); f:SetPoint("CENTER")
    self.modalTitle=text(f,17,"ivory",386,28); anchor(self.modalTitle,22,20)
    self.modalBody=text(f,12,"muted",386,64); anchor(self.modalBody,22,61)
    local stay=button(f,L.KEEP_PLAYING,184,function() shade:Hide(); self.confirmAction=nil; self.escape:Show() end); anchor(stay,22,140)
    self.modalConfirm=button(f,L.CONFIRM,184,function()
        local action=self.confirmAction; self.confirmAction=nil; shade:Hide(); self.drawer:Hide(); self.escape:Show()
        if action then action() end
    end); anchor(self.modalConfirm,224,140)
    shade:Hide()
end
function UI:ConfirmLeave()
    if not self.view then return end
    self:Expand(); self:ReleaseFocus(); self:HideCardPreview(true); self.modalTitle:SetText(L.LEAVE_TITLE); self.modalBody:SetText(L.LEAVE_BODY); self.modalConfirm.label:SetText(L.YES_LEAVE)
    self.confirmAction=function() self:Call("Leave") end; self.modal:Show(); self.escape:Show()
end
function UI:ConfirmCancel()
    if not self.view or self.view.hostId~=self.controller.id then return end
    self:ReleaseFocus(); self:HideCardPreview(true); self.modalTitle:SetText(L.CANCEL_TITLE); self.modalBody:SetText(L.CANCEL_BODY); self.modalConfirm.label:SetText(L.YES_CANCEL)
    self.confirmAction=function() self:Call("Cancel") end; self.modal:Show(); self.escape:Show()
end

function UI:BuildInvitation()
    local f=panel(UIParent,400,220,"wood","brass"); self.invitePopup=f; f:SetPoint("TOP",UIParent,"TOP",0,-155); f:SetFrameStrata("DIALOG"); f:SetFrameLevel(120); f:SetClampedToScreen(true); f:EnableMouse(true)
    local icon=asset(f,"chest",52,52); anchor(icon,17,11)
    local title=text(f,17,"ivory",299,22); anchor(title,78,17); title:SetText(L.INVITE_TITLE)
    self.inviteFrom=single(text(f,11,"ivory",300,18)); anchor(self.inviteFrom,79,43)
    self.inviteTable=single(text(f,12,"ivory",364,18)); anchor(self.inviteTable,18,78)
    local rule=text(f,12,"amber",364,19); anchor(rule,18,103); rule:SetText(L.RULESET)
    self.inviteCompatibility=text(f,10,"muted",364,17); anchor(self.inviteCompatibility,18,128)
    local hint=text(f,10,"muted",364,29); anchor(hint,18,147); hint:SetText(L.INVITE_EXPLAIN)
    self.accept=button(f,L.ACCEPT,172,function()
        local invite=self.currentInvite
        if invite then self.dismissedInvites[invite.nonce]=true; self.currentInvite=nil; f:Hide(); self:Expand(); self:Call("Accept",invite.sender,invite.nonce) end
    end); anchor(self.accept,18,184)
    local decline=button(f,L.DECLINE,172,function()
        local invite=self.currentInvite
        if invite then self.dismissedInvites[invite.nonce]=true; self.currentInvite=nil; f:Hide(); self:Call("Decline",invite.sender,invite.nonce) end
    end); anchor(decline,210,184)
    f:SetScript("OnEnter",function() if self.currentInvite then tooltip(f,clean(self.currentInvite.sender,100)) end end); f:SetScript("OnLeave",hideTooltip)
    f:Hide()
end

function UI:ShowInvitation(sender,invite)
    if not invite or not invite.nonce or self.dismissedInvites[invite.nonce] or self.settings.ignoreInvites or self.view then return end
    if self.currentInvite and self.currentInvite.nonce~=invite.nonce then return end
    self.currentInvite={sender=sender,nonce=invite.nonce}
    self.inviteFrom:SetText(string.format(L.INVITE_FROM,self:Name(sender)))
    self.inviteTable:SetText(string.format(L.INVITE_SEATS,clean(invite.tableName,64),tonumber(invite.playerCount or invite.occupied) or 1))
    local compatible=invite.compatible~=false and (not invite.ruleset or invite.ruleset==ns.RULESET) and (not invite.version or invite.version==ns.VERSION)
    self.inviteCompatibility:SetText(compatible and L.INVITE_COMPATIBLE or L.INVITE_INCOMPATIBLE); enable(self.accept,compatible)
    self.invitePopup:Show()
end

function UI:UpdateInvites(incoming,outgoing)
    self.outgoing=outgoing or {}
    if self.currentInvite then
        local current=incoming and incoming[self.currentInvite.sender]
        if not current or current.nonce~=self.currentInvite.nonce or current.status=="EXPIRED" or self.view then
            self.currentInvite=nil; self.invitePopup:Hide()
        end
    end
    if not self.currentInvite and not self.view then
        local names={}; for sender in pairs(incoming or {}) do names[#names+1]=sender end; table.sort(names)
        for _,sender in ipairs(names) do
            local invite=incoming[sender]
            if invite.status~="EXPIRED" and invite.status~="DECLINED" and not self.dismissedInvites[invite.nonce] then self:ShowInvitation(sender,invite); break end
        end
    end
    if self.drawer:IsShown() and self.drawerKind=="invitations" then self:RefreshDrawer() end
    -- These are local display records only; retain a bounded number of dismissed nonces.
    local count=0; for _ in pairs(self.dismissedInvites) do count=count+1 end
    if count>64 then self.dismissedInvites={} end
    if self.frame:IsShown() then self.escape:Show() end
end

local noticeAliases={
    RETURN_FORBIDDEN="ERROR_RETURN", SELF_TARGET="ERROR_SELF", NOT_HOLDER="ERROR_TURN", INVALID_SLOT="ERROR_SLOT", SLOT_REVEALED="ERROR_SLOT",
    WRONG_PHASE="ERROR_PHASE", STALE_GAME="ERROR_STALE", STALE_ROUND="ERROR_STALE", STALE_REVISION="ERROR_STALE", SUSPENDED="ERROR_SUSPENDED", INVALID_STATE="ERROR_RECOVERY",
    INVALID_TARGET="ERROR_NAME", NOT_HOST="ERROR_NOT_HOST", HOST_ONLY="ERROR_NOT_HOST", NOT_MEMBER="ERROR_BUSY", TABLE_FULL="ERROR_FULL", BUSY="ERROR_BUSY", NO_TARGET="ERROR_NO_TARGET",
    NOT_READY="ERROR_NOT_READY", INVALID_PLAYER_COUNT="ERROR_CAPACITY", PLAYER_COUNT="ERROR_CAPACITY", INVALID_COUNT="ERROR_CAPACITY", INVALID_INVITE="ERROR_INVITE",
    INVITE_SENT="INFO_INVITE_SENT", INVITE_PENDING="INFO_INVITE_SENT", INVITE_ACCEPTED="ACCEPTED", INVITE_DECLINED="INFO_DECLINED", INVITE_EXPIRED="EXPIRED",
    INVITE_INCOMPATIBLE="ERROR_INCOMPATIBLE", NO_RESPONSE="ERROR_TIMEOUT", JOINED="INFO_JOINED", LEFT="INFO_LEFT", CLOSED="INFO_CANCELLED",
    HOST_TIMEOUT="ERROR_SUSPENDED", PLAYER_TIMEOUT="ERROR_SUSPENDED", RECONNECTED="CONNECTED", RECOVERING="RECOVERING", SYNCING="PRIVATE_SYNC",
    NETWORK_BUSY="ERROR_WAIT", MALFORMED="ERROR_NETWORK",
    API_UNAVAILABLE="ERROR_TRANSPORT", PREFIX_FAILED="ERROR_TRANSPORT",
    SEND_FAILED="ERROR_TRANSPORT", TARGET_OFFLINE="ERROR_TIMEOUT", THROTTLED="ERROR_WAIT", DEMO_BUSY="ERROR_DEMO_ACTIVE",
    REQUEST_TIMEOUT="ERROR_TIMEOUT", VERSION_MISMATCH="ERROR_INCOMPATIBLE",
}
function UI:Notice(code,detail)
    local key=noticeAliases[code] or code
    local message=ns.LocaleEnglish[key] and L[key] or L.NOTICE_GENERIC
    -- Details may be internal protocol diagnostics, never stringify unknown payloads.
    -- Only display a sanitized address when the code explicitly describes an invite.
    if type(detail)=="string" and (code=="INVITE_SENT" or code=="INVITE_DECLINED" or code=="INVITE_ACCEPTED") then
        message=string.format(L.NOTICE_DETAIL,message,clean(detail,96))
    end
    self.status:SetText(message); self.status:SetTextColor(unpack(T.colors.amber))
end

function UI.New(controller,settings)
    local self=setmetatable({controller=controller,settings=settings or {},visible=false,outgoing={},dismissedInvites={}},UI)
    self:BuildChrome(); self:BuildMini(); self:BuildWelcome(); self:BuildTable(); self:BuildDrawer(); self:BuildModal(); self:BuildInvitation()
    self:Render(nil); self:Hide()
    return self
end
