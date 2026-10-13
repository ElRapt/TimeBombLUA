local ADDON, ns = ...
local U, PREFIX = ns.Util, 'TBRP1'
local App = {}; ns.App=App
local function now() return GetServerTime() end
local function notice(code,detail)
    if App.ui then App.ui:Notice(code,detail) end
end
function App:Active() return self.demo and self.demo:Current() or self.session end
function App:Refresh(view,event)
    if not self.ui then return end
    local manager=self:Active()
    self.id=manager.id; self.pending=not not manager.pending
    view=view or manager:GetView()
    self.ui:Render(view,event)
    self.ui:UpdateInvites(manager.invitations or {}, manager.outgoing or {})
    self:AnnounceCut(view)
end
function App:Action(kind,fields)
    local ok,err=self:Active():Intent(kind,fields)
    if self.demo then self.demo:Pump() end
    self:Refresh(nil,'LOCAL')
    if ok==false and err then notice(err) end
    return ok,err
end
function App:Create(name)
    if self.demo then notice('DEMO_BUSY'); return end
    local ok,err=self.session:Create(U.Clean(name,80)); if ok==false then notice(err) end
    self:Refresh()
end
function App:Invite(name)
    if self.demo then return end
    local target=U.Name(name,self.realm)
    if not target then notice('INVALID_NAME'); return end
    local ok,err=self.session:Invite(target); if ok==false then notice(err) end
    self:Refresh()
end
function App:InviteTarget()
    if not UnitExists('target') or not UnitIsPlayer('target') then notice('NO_TARGET'); return end
    local name,realm=UnitFullName('target'); self:Invite(U.Name(name,realm and realm~='' and realm or self.realm))
end
function App:Accept(sender,nonce)
    if self.demo then return end
    self.session:Accept(sender,nonce); self:Refresh()
end
function App:Decline(sender,nonce) self.session:Decline(sender,nonce); self:Refresh() end
function App:Ready()
    local ready=false
    local v=self:Active():GetView()
    for _,p in ipairs(v and v.players or {}) do if p.id==self.id then ready=not p.ready end end
    self:Action('READY',{ready=ready})
end
function App:Start() self:Action('START') end
function App:Next() self:Action('NEXT') end
function App:Rematch() self:Action('REMATCH') end
function App:Cancel() self:Action('CANCEL') end
function App:Cut(target,slot)
    local manager=self:Active()
    if manager.pending then return end
    local v=manager:GetView()
    if not self.demo and self.settings.autoEmotes and v then
        self.emoteIntent={sessionId=v.sessionId,gameId=v.gameId,round=v.round,revision=v.revision,
            targetId=target,slotId=slot,created=GetTime()}
    end
    local ok=self:Action('CUT',{targetId=target,slotId=slot})
    if ok==false then self.emoteIntent=nil end
end
function App:Leave()
    self.emoteIntent=nil
    if self.demo then self.demo:Close(); self.demo=nil; self.isDemo=false
    else self.session:Leave(); TimeBombRPRecovery=nil end
    self.id=self.session.id; self.pending=false
    self.ui:Render(self.session:GetView(),'LEFT')
end
function App:Demo(count)
    if self.session:GetView() or self.session.sessionId or self.session.pending or U.Count(self.session.departures or {})>0 then notice('DEMO_BUSY'); return end
    self.wire:Clear()
    if self.demo then self.demo:Close(); self.demo=nil end
    self.isDemo=true
    self.demo=ns.Demo.New(tonumber(count),function(view,event)
        if self.demo then self:Refresh(view,event) end
    end,notice)
    self:Refresh(nil,'RESYNC'); self.ui:Show()
end
function App:DemoNext() if self.demo then self.demo:Next(); self:Refresh() end end
function App:DemoPerspective() if self.demo then self.demo:Perspective(); self:Refresh(nil,'RESYNC') end end
function App:ResetUI() self.ui:Reset() end
function App:SetOption(key,value)
    local allowed={sound=true,reducedMotion=true,autoExpand=true,ignoreInvites=true,autoEmotes=true,scale=true}
    if not allowed[key] then return end
    if key=='scale' then value=math.max(.7,math.min(1.5,tonumber(value) or 1)) else value=not not value end
    self.settings[key]=value; self.session.ignoreInvites=self.settings.ignoreInvites
end
function App:DisplayName(id,fallback)
    return ns.Roleplay:Name(id,fallback,self.isDemo)
end
function App:AnnounceCut(v)
    local intent=self.emoteIntent
    if not intent then return end
    if self.demo or not self.settings.autoEmotes or not v or v.cancelled or v.sessionId~=intent.sessionId
        or v.gameId~=intent.gameId or GetTime()-intent.created>60 then self.emoteIntent=nil; return end
    -- Match our explicit local intention against an accepted public record.
    -- Repairs can confirm it; reloads, duplicate packets and other clients cannot replay it.
    for _,record in ipairs(v.history or {}) do
        if record.actorId==self.session.id and record.targetId==intent.targetId and record.slotId==intent.slotId
            and record.round==intent.round and record.revision>intent.revision then
            self.emoteIntent=nil
            local result=ns.LocaleEnglish['EMOTE_'..record.face] and ns.L['EMOTE_'..record.face]
            if not result then return end
            if not C_ChatInfo or not C_ChatInfo.SendChatMessage
                or (C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown()) then
                notice('EMOTE_UNAVAILABLE'); return
            end
            -- WoW supplies the actor prefix; TRP3 applies the actor's RP name in chat.
            -- One EMOTE contains both public facts, with no timer or chat-box overwrite.
            local message=string.format(ns.L.EMOTE_CUT,self:DisplayName(record.targetId),result)
            C_ChatInfo.SendChatMessage(U.Clean(message,250),'EMOTE')
            return
        end
    end
end
function App:TransportAvailable()
    if not self.prefixReady then return false,'PREFIX_FAILED' end
    if C_ChatInfo.AreOutgoingAddonChatMessagesRestricted and C_ChatInfo.AreOutgoingAddonChatMessagesRestricted() then return false,'API_RESTRICTED' end
    if C_ChatInfo.InChatMessagingLockdown and C_ChatInfo.InChatMessagingLockdown() then return false,'API_LOCKDOWN' end
    return true,'CONNECTED'
end
local sendCodes={[1]='SEND_FAILED',[2]='SEND_FAILED',[3]='THROTTLED',[4]='SEND_FAILED',[5]='SEND_FAILED',[6]='INVALID_NAME',[7]='SEND_FAILED',[8]='THROTTLED',[9]='SEND_FAILED',[10]='SEND_FAILED',[11]='API_LOCKDOWN',[12]='TARGET_OFFLINE'}
function App:Initialize()
    self.realm=GetNormalizedRealmName()
    local name,realm=UnitFullName('player')
    self.id=assert(U.Name(name,realm and realm~='' and realm or self.realm))
    U.SeedTokens(now()+math.floor(GetTime()*1000))
    TimeBombRPDB=type(TimeBombRPDB)=='table' and TimeBombRPDB or {}
    self.settings=TimeBombRPDB
    if self.settings.autoEmotes==nil then self.settings.autoEmotes=true end
    self.settings.scale=math.max(.7,math.min(1.5,tonumber(self.settings.scale) or 1))
    local api=C_ChatInfo
    if api and api.RegisterAddonMessagePrefix then
        local result=api.RegisterAddonMessagePrefix(PREFIX)
        local enums=Enum and Enum.RegisterAddonMessagePrefixResult
        self.prefixReady=result==(enums and enums.Success or 0) or result==(enums and enums.DuplicatePrefix or 1)
    end
    self.wire=ns.Wire.New({now=GetTime,notice=notice,rawSend=function(target,fragment)
        local allowed,code=self:TransportAvailable()
        if not allowed then return false,code end
        local result=C_ChatInfo.SendAddonMessage(PREFIX,fragment,'WHISPER',target)
        local success=Enum and Enum.SendAddonMessageResult and Enum.SendAddonMessageResult.Success or 0
        if result==success then return true end
        return false,sendCodes[result] or 'SEND_FAILED'
    end,receive=function(sender,envelope)
        if not self.demo then self.session:Receive(sender,envelope) end
    end})
    self.session=ns.Session.New({id=self.id,now=now,rng=U.RNG(now()+math.floor(GetTime()*997)),token=U.Token,
        send=function(target,envelope) return self.wire:Send(target,envelope) end,
        changed=function(view,event)
            if not self.demo then
                if not view and event=='CLOSED' then self.wire:PurgeSession(); TimeBombRPRecovery=nil end
                self:Refresh(view,event)
            end
        end,
        notice=notice})
    self.session.ignoreInvites=not not self.settings.ignoreInvites
    self.ui=ns.UI.New(self,self.settings)
    ns.Roleplay:Connect(function() self:Refresh(nil,'NAMES') end)
    self.transportStatus=select(2,self:TransportAvailable())
    if TimeBombRPRecovery then
        local ok,err=self.session:Restore(TimeBombRPRecovery)
        if ok==false then TimeBombRPRecovery=nil; notice(err or 'INVALID_CHECKPOINT') end
    end
    self:Refresh(nil,'RESYNC')
    local _,_,_,build=GetBuildInfo()
    if WOW_PROJECT_ID and WOW_PROJECT_MAINLINE and WOW_PROJECT_ID~=WOW_PROJECT_MAINLINE then notice('WRONG_CLIENT')
    elseif tonumber(build)~=120105 then notice('BUILD_MISMATCH',tostring(build)) end
    local lastTick=GetTime()
    self.ticker=C_Timer.NewTicker(.1,function()
        self.wire:Tick()
        if GetTime()-lastTick>=1 then
            lastTick=GetTime()
            if not self.demo then
                ns.Roleplay:Connect(function() self:Refresh(nil,'NAMES') end)
                self.session:Tick()
                self.pending=not not self.session.pending
                local status=select(2,self:TransportAvailable())
                if status~=self.transportStatus then self.transportStatus=status; self:Refresh(nil,'CONNECTION') end
                self.ui:UpdateInvites(self.session.invitations or {},self.session.outgoing or {})
            end
        end
    end)
    SLASH_TIMEBOMBRP1='/timebomb'; SLASH_TIMEBOMBRP2='/tb'
    SlashCmdList.TIMEBOMBRP=function(input)
        local command,arg=input:match('^(%S*)%s*(.-)$'); command=command:lower()
        if command=='invite' then self:Invite(arg)
        elseif command=='leave' then
            if self.ui.ConfirmLeave then self.ui:ConfirmLeave() else self.ui:Show(); notice('CONFIRM_LEAVE') end
        elseif command=='resetui' then self:ResetUI()
        elseif command=='demo' then self:Demo(tonumber(arg))
        else self.ui:Toggle() end
    end
end
local events=CreateFrame('Frame')
events:RegisterEvent('ADDON_LOADED')
events:RegisterEvent('PLAYER_LOGOUT')
events:RegisterEvent('CHAT_MSG_ADDON')
events:SetScript('OnEvent',function(_,event,...)
    if event=='ADDON_LOADED' then
        local name=...; if name==ADDON then events:UnregisterEvent('ADDON_LOADED'); App:Initialize() end
    elseif event=='PLAYER_LOGOUT' then
        if App.session then TimeBombRPRecovery=App.session:Checkpoint() end
        if App.ticker then App.ticker:Cancel() end
    elseif event=='CHAT_MSG_ADDON' and App.wire then
        local prefix,message,channel,sender=...
        if prefix==PREFIX and channel=='WHISPER' and not App.demo then
            local identity=U.Name(sender,App.realm)
            if identity then App.wire:Receive(identity,message) end
        end
    end
end)
