return function(ns,test)
    local mock=assert(loadfile(ns.TestRoot..'/Tests/wow_mock.lua'))()
    for _,path in ipairs({'Localization/Locale.lua','Core/Roleplay.lua','UI/Theme.lua','UI/UI.lua'}) do assert(loadfile(ns.TestRoot..'/TimeBombRP/'..path))('TimeBombRP',ns) end
    local controller={id='Fantine-Auberdine',transportStatus='CONNECTED',pending=false,isDemo=true}
    local calls={}
    for _,name in ipairs({'Create','Invite','InviteTarget','Accept','Decline','Ready','Start','Next','Rematch','Cancel','Leave','Cut','Demo','DemoNext','DemoPerspective','ResetUI','Emote','SetOption'}) do
        controller[name]=function(_,...) calls[#calls+1]={name,...} end
    end
    local ui=ns.UI.New(controller,{scale=1,sound=false})
    test('UI: native call signatures, all drawers and fixed frame allocation for 4/8 seats',function()
        ui:Show(); assert(ui.frame:IsShown())
        for _,n in ipairs({4,8}) do
            local demo=ns.Demo.New(n,function() end,function() end)
            controller.id=demo.clients[1].id
            local view=demo.clients[1]:GetView()
            ui:Render(view,'SNAPSHOT')
            local count=#mock.objects
            for i=1,80 do ui:Render(view,'SNAPSHOT') end
            assert(#mock.objects==count,'frames grow with snapshots')
            for _,kind in ipairs({'help','history','options','invitations'}) do ui:OpenDrawer(kind);ui.drawer:Hide() end
            ui:Minimize();assert(ui.mini:IsShown() and not ui.frame:IsShown())
            ui:Expand();assert(ui.frame:IsShown() and not ui.mini:IsShown())
            ui:ConfirmCancel();assert(ui.modal:IsShown());ui.modal:Hide()
            ui:ConfirmLeave();assert(ui.modal:IsShown());ui.modal:Hide()
            demo:Close()
        end
    end)
    test('UI: legal local selection, explicit confirmation, no forbidden self/return actions',function()
        local demo=ns.Demo.New(4,function() end,function() end)
        local v=demo.clients[1]:GetView()
        for _,c in ipairs(demo.clients) do if c.id==v.currentHolderId then controller.id=c.id;v=c:GetView() end end
        ui:Render(v,'SNAPSHOT');calls={}
        local picked
        for _,seat in ipairs(ui.seats) do
            if seat.player and seat.player.id~=controller.id then
                local c=seat.cards[1]; c:Fire('OnClick'); picked=seat.player.id;break
            end
        end
        assert(ui.selection and ui.selection.targetId==picked)
        assert(#calls==0,'optimistic network action')
        ui:PrimaryAction();assert(#calls==1 and calls[1][1]=='Cut')
        local p=ui:Player(controller.id);assert(ui:CardReason(p,p.slots[1]))
        v.previousHolderId=picked;ui:Render(v,'SNAPSHOT');p=ui:Player(picked);assert(ui:CardReason(p,p.slots[1]))
        controller.pending=true;ui:Render(v,'PENDING');assert(not ui.primary:IsEnabled());controller.pending=false
        v=ns.Util.Copy(v);v.round=v.round+1;ui:Render(v,'SNAPSHOT');assert(ui.selection==nil)
        assert(ui.counts:GetText()=='','old private histogram displayed after round change')
        demo:Close()
    end)
    test('UI: invitation acceptance explicit, expiry, no repeated reopening, confirmations',function()
        ui:Render(nil);controller.isDemo=false;calls={}
        local inv={nonce='n1',sessionId='s',tableName='Une table',playerCount=3,compatible=true,version=ns.VERSION,ruleset=ns.RULESET,status='PENDING'}
        ui:UpdateInvites({['Hôte-Realm']=inv},{})
        assert(ui.invitePopup:IsShown() and #calls==0)
        ui.accept:Fire('OnClick');assert(calls[1][1]=='Accept' and calls[1][2]=='Hôte-Realm')
        ui:UpdateInvites({['Hôte-Realm']=inv},{});assert(not ui.invitePopup:IsShown())
        inv.nonce='n2';inv.compatible=false;ui:UpdateInvites({['Hôte-Realm']=inv},{});assert(not ui.accept:IsEnabled())
        ui:UpdateInvites({},{});assert(not ui.invitePopup:IsShown())
    end)
    test('Core: Retail initialization, numeric API enums, ordered reload save and demo isolation',function()
        function GetTime() return mock.clock end
        function GetServerTime() return 1802380000 end
        function GetNormalizedRealmName() return 'Auberdine' end
        function UnitFullName() return 'Fantine','Auberdine' end
        function GetBuildInfo() return '12.1.5','70340','Oct 13 2026',120105 end
        function UnitExists() return false end
        function UnitIsPlayer() return false end
        local sent,restricted=0,false
        C_ChatInfo={RegisterAddonMessagePrefix=function() return 0 end,SendAddonMessage=function() sent=sent+1;return 0 end,
            AreOutgoingAddonChatMessagesRestricted=function() return restricted end,InChatMessagingLockdown=function() return false end}
        Enum={RegisterAddonMessagePrefixResult={Success=0,DuplicatePrefix=1},SendAddonMessageResult={Success=0}}
        assert(loadfile(ns.TestRoot..'/TimeBombRP/Core/Main.lua'))('TimeBombRP',ns)
        ns.App:Initialize();assert(ns.App.prefixReady)
        assert(ns.App:TransportAvailable())
        restricted=true;assert(not ns.App:TransportAvailable());restricted=false
        ns.App:Demo(8);assert(ns.App.isDemo and ns.App:Active():GetView().phase=='ACTIVE')
        ns.App:DemoNext();ns.App:DemoPerspective();assert(sent==0)
        assert(ns.App.session:Checkpoint()==nil)
        ns.App:Leave();assert(not ns.App.isDemo)
        ns.App:Create('Test');assert(ns.App.session:GetView().phase=='LOBBY')
        ns.App:Leave();assert(not ns.App.session:GetView())
    end)

    test('UI: own hand visualizes only the private histogram, without slot positions',function()
        local d=ns.Demo.New(8,function() end,function() end)
        controller.id=d.clients[1].id;controller.isDemo=true
        local v=d.clients[1]:GetView();ui:Render(v,'SNAPSHOT')
        local counts={SAFE=0,DEFUSE=0,BOMB=0}
        for _,card in ipairs(ui.handCards) do
            if card:IsShown() then
                assert(card.face and not card.slot and not card.id)
                counts[card.face]=counts[card.face]+1
            end
        end
        for face,n in pairs(counts) do assert(n==v.private.counts[face]) end
        for _,seat in ipairs(ui.seats) do assert(not seat.player or seat.player.id~=controller.id) end
        v.private.round=v.round+1;ui:Render(v,'SNAPSHOT')
        for _,card in ipairs(ui.handCards) do assert(not card:IsShown() and card.face==nil) end
        v.private.round=v.round;v.private.counts={SAFE=0,DEFUSE=0,BOMB=0};ui:Render(v,'SNAPSHOT')
        assert(ui.privateHint:GetText()==ns.L.PRIVATE_NONE)
        d:Close()
    end)
    test('UI: animated hover preserves secrecy and clicks, with reduced-motion and lifecycle cleanup',function()
        local d=ns.Demo.New(4,function() end,function() end)
        local v=d.clients[1]:GetView();controller.id=v.currentHolderId;controller.isDemo=true
        for _,client in ipairs(d.clients) do if client.id==controller.id then v=client:GetView() end end
        ui.settings.reducedMotion=false;ui:Render(v,'SNAPSHOT');ui:Show()
        local card=ui.seats[1].cards[1];local allocated=#mock.objects
        for i=1,80 do
            card:Fire('OnEnter');assert(ui.cardPreview:IsShown() and ui.cardPreview.enter.playing)
            assert(ui.cardPreview.texture.texture==ns.Theme.Asset('card_back'))
            assert(ui.cardPreview.EnableMouseArgs[1]==false)
            card:Fire('OnLeave');assert(ui.cardPreview.exit.playing)
            ui.cardPreview.exit:Fire('OnFinished');assert(not ui.cardPreview:IsShown())
        end
        assert(#mock.objects==allocated,'hover allocates new frames/animations')
        card:Fire('OnEnter');card:Fire('OnClick');assert(ui.selection.slotId==card.slot.id)
        card:Fire('OnLeave');card:Fire('OnEnter');ui.cardPreview.exit:Fire('OnFinished')
        assert(ui.cardPreview:IsShown(),'old exit callback hides a new hover')
        card.slot.revealed=true;card.slot.face='DEFUSE';card:Fire('OnEnter')
        assert(ui.cardPreview.texture.texture==ns.Theme.Asset('card_defuse'))
        ui.settings.reducedMotion=true;card:Fire('OnEnter')
        assert(ui.cardPreview:IsShown() and not ui.cardPreview.enter.playing)
        card:Fire('OnLeave');assert(not ui.cardPreview:IsShown())
        card:Fire('OnEnter');ui:Minimize();assert(not ui.cardPreview:IsShown())
        ui:Expand();card:Fire('OnEnter');ui:OpenDrawer('help');assert(not ui.cardPreview:IsShown());ui.drawer:Hide()
        card:Fire('OnEnter');v=ns.Util.Copy(v);v.revision=v.revision+1;ui:Render(v,'SNAPSHOT')
        assert(not ui.cardPreview:IsShown())
        ui.settings.reducedMotion=false;d:Close()
    end)
    test('RP: optional TRP names normalize realms, strip markup and refresh on profile updates',function()
        local rp=ns.Roleplay;rp:Invalidate();rp.connected=nil
        TRP3_API=nil;TRP3_Addon=nil
        assert(rp:Name('Marius-auberdine')=='Marius')
        assert(rp:Name('Marius-auberdine','Anne-Marie')=='Anne-Marie')
        local names={['Marius-Auberdine']='|cffff0000Marius|r |Tbad:30|tDenis',
            ['Fantine-LesSentinelles']='Fantine Bell'}
        local callbacks={};local list={['Fantine-LesSentinelles']={}}
        TRP3_API={globals={player_id='Marius-Auberdine'},profile={getPlayerCurrentProfile=function() return {player={}} end},register={
            getCharacterList=function() return list end,
            getUnitRPNameWithID=function(id,fallback) return names[id] or fallback end},
            RegisterCallback=function(_,event,fn) callbacks[event]=fn end}
        TRP3_Addon={Events={REGISTER_DATA_UPDATED='data',REGISTER_PROFILES_LOADED='profiles',WORKFLOW_ON_LOADED='loaded'}}
        assert(rp:Name('Marius-auberdine')=='Marius Denis')
        assert(rp:Name('fantine-lessentinelles')=='Fantine Bell')
        assert(rp:Name('Fantine-lessentinelles',nil,true)=='Fantine')
        local refreshed=0;rp:Connect(function() refreshed=refreshed+1 end)
        names['Fantine-LesSentinelles']='Fantine Mercier';callbacks.data()
        assert(refreshed==1 and rp:Name('Fantine-lessentinelles')=='Fantine Mercier')
        TRP3_API.profile.getPlayerCurrentProfile=function() return nil end
        assert(rp:Name('Marius-auberdine')=='Marius','TRP startup without current profile')
        list=nil;rp:Invalidate();assert(rp:Name('Fantine-lessentinelles')=='Fantine','TRP startup without registry')
        TRP3_API=nil;TRP3_Addon=nil;rp:Invalidate();rp.connected=nil
    end)
    test('Core: confirmed cut emits once on EMOTE, remote clients wait for host acceptance',function()
        local app=ns.App;local original=app.session;local sent={}
        C_ChatInfo.SendChatMessage=function(text,channel) sent[#sent+1]={text,channel} end
        local d=ns.Demo.New(4,function() end,function() end)
        local function attach()
            local view=d.clients[1]:GetView()
            for _,client in ipairs(d.clients) do
                client.changed=function() end
                if client.id==view.currentHolderId then app.session=client end
            end
            app.session.changed=function(v,e) app:Refresh(v,e) end
            app:Refresh(nil,'SNAPSHOT')
        end
        local function cut()
            local v=app.session:GetView()
            for _,p in ipairs(v.players) do
                if p.id~=app.session.id and p.id~=v.previousHolderId then
                    for _,slot in ipairs(p.slots) do
                        if not slot.revealed then app:Cut(p.id,slot.id);return end
                    end
                end
            end
            error('no legal test cut')
        end
        app.settings.autoEmotes=true;attach();cut();d:Pump()
        assert(#sent==1 and sent[1][2]=='EMOTE')
        local record=app.session:GetView().history[1]
        assert(sent[1][1]==string.format(ns.L.EMOTE_CUT,app:DisplayName(record.targetId),ns.L['EMOTE_'..record.face]))
        assert(#sent[1][1]<=250 and not sent[1][1]:find('|',1,true))
        app:Refresh(nil,'CUT');app:Refresh(nil,'SNAPSHOT');assert(#sent==1,'replayed cut emote')
        if d.clients[1]:GetView().phase=='ACTIVE' then
            attach();assert(app.session~=d.clients[1],'fixture must exercise remote intention')
            cut();assert(#sent==1,'announced before host accepted')
            d:Pump();assert(#sent==2)
            app:Refresh(nil,'SNAPSHOT');assert(#sent==2)
        else error('fixture ended before remote cut') end
        app.emoteIntent=nil;app:Refresh(nil,'RECOVERING');assert(#sent==2,'reload replay')
        app.session=original;app.emoteIntent=nil;d:Close();app:Refresh(nil,'RESYNC')
    end)
    test('Core: automatic emotes reject stale, foreign, disabled, demo and locked-chat events',function()
        local app=ns.App;local sent={};local original=app.session;local oldLock=C_ChatInfo.InChatMessagingLockdown
        C_ChatInfo.SendChatMessage=function(text,channel) sent[#sent+1]={text,channel} end
        local v={sessionId='s',gameId='g',round=1,revision=2,history={
            {actorId='Marius-auberdine',targetId='Fantine-auberdine',slotId='slot',round=1,revision=2,face='DEFUSE'}}}
        app.session={id='Marius-auberdine'}
        local function stage() app.emoteIntent={sessionId='s',gameId='g',round=1,revision=1,targetId='Fantine-auberdine',slotId='slot',created=mock.clock} end
        stage();app.settings.autoEmotes=false;app:AnnounceCut(v);assert(#sent==0 and not app.emoteIntent)
        app.settings.autoEmotes=true;stage();app.demo={};app:AnnounceCut(v);app.demo=nil;assert(#sent==0)
        stage();C_ChatInfo.InChatMessagingLockdown=function() return true end;app:AnnounceCut(v);assert(#sent==0 and not app.emoteIntent)
        C_ChatInfo.InChatMessagingLockdown=oldLock
        stage();app.emoteIntent.created=mock.clock-61;app:AnnounceCut(v);assert(#sent==0 and not app.emoteIntent)
        stage();v.history[1].actorId='Other-auberdine';app:AnnounceCut(v);assert(#sent==0)
        v.history[1].actorId='Marius-auberdine';stage();v.history[1].revision=1;app:AnnounceCut(v);assert(#sent==0)
        v.history[1].revision=2;stage();v.cancelled=true;app:AnnounceCut(v);assert(#sent==0)
        v.cancelled=nil
        for _,face in ipairs({'SAFE','DEFUSE','BOMB'}) do
            stage();v.history[1].face=face;app:AnnounceCut(v)
            assert(sent[#sent][1]=='coupe chez Fantine. '..ns.L['EMOTE_'..face])
        end
        assert(#sent==3)
        app.session=original;app.emoteIntent=nil
    end)
end
