return function(ns,test)
    local mock=assert(loadfile(ns.TestRoot..'/Tests/wow_mock.lua'))()
    for _,path in ipairs({'Localization/Locale.lua','UI/Theme.lua','UI/UI.lua'}) do assert(loadfile(ns.TestRoot..'/TimeBombRP/'..path))('TimeBombRP',ns) end
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
end
