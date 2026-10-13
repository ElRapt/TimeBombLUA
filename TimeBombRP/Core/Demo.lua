local ADDON, ns = ...
ns.Demo = {}
function ns.Demo.New(count, changed, notice)
    count = count == 8 and 8 or 4
    local demo={clients={},queue={},clock=1000,index=1}
    local names={'Fantine-Auberdine','ÉléonoreDesBrumes-Auberdine','Marius-Auberdine','Ysandre-Auberdine','Bérénice-Auberdine','Théodore-Auberdine','Léonie-Auberdine','Gaspard-Auberdine'}
    local function report(view,event)
        if demo.clients[demo.index] then changed(demo.clients[demo.index]:GetView(),event) end
    end
    function demo:Pump()
        local count=0
        local ticked=false
        while #self.queue>0 or not ticked do
            if #self.queue==0 then
                ticked=true
                for _,client in ipairs(self.clients) do client:Tick() end
                if #self.queue==0 then break end
            end
            count=count+1; assert(count<10000,'demo routing loop')
            local packet=table.remove(self.queue,1)
            for _,client in ipairs(self.clients) do
                if client.id==packet.target then client:Receive(packet.sender,packet.message) end
            end
        end
        report(nil,'DEMO')
    end
    for i=1,count do
        local id=names[i]
        demo.clients[i]=ns.Session.New({id=id,now=function() return demo.clock end,
            rng=ns.Util.RNG(4903+i),token=ns.Util.Token,
            send=function(target,message)
                local encoded,err=ns.Codec.Encode(message)
                if not encoded then return false,err end
                local decoded=assert(ns.Codec.Decode(encoded))
                demo.queue[#demo.queue+1]={sender=id,target=target,message=decoded}
                return true
            end,
            changed=function(view,event) report(view,event) end,
            notice=notice or function() end})
    end
    local host=demo.clients[1]
    host:Create('Démonstration · '..count)
    for i=2,count do
        host:Invite(names[i]); demo:Pump()
        local invitation=demo.clients[i].invitations[names[1]]
        assert(invitation,'demo invitation missing')
        demo.clients[i]:Accept(names[1],invitation.nonce); demo:Pump()
    end
    for _,client in ipairs(demo.clients) do client:Intent('READY',{ready=true}); demo:Pump() end
    host:Intent('START'); demo:Pump()
    function demo:Current() return self.clients[self.index] end
    function demo:Perspective()
        self.index=self.index%#self.clients+1
        report(nil,'RESYNC')
        return self:Current().id
    end
    function demo:Next()
        local view=self.clients[1]:GetView()
        if not view then return end
        if view.phase=='BETWEEN_ROUNDS' then self.clients[1]:Intent('NEXT')
        elseif view.phase=='LOBBY' then
            for _,client in ipairs(self.clients) do client:Intent('READY',{ready=true}) end
            self:Pump(); self.clients[1]:Intent('START')
        elseif view.phase=='GAME_OVER' then self.clients[1]:Intent('REMATCH')
        elseif view.phase=='ACTIVE' then
            for _,client in ipairs(self.clients) do
                if client.id==view.currentHolderId then
                    for _,player in ipairs(view.players) do
                        if player.id~=client.id and player.id~=view.previousHolderId then
                            for _,slot in ipairs(player.slots) do
                                if not slot.revealed then
                                    client:Intent('CUT',{targetId=player.id,slotId=slot.id})
                                    self:Pump(); return
                                end
                            end
                        end
                    end
                end
            end
        end
        self:Pump()
    end
    function demo:Close() for _,client in ipairs(self.clients) do client:Close() end; self.queue={} end
    return demo
end
