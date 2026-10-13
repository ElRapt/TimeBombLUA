return function(ns,test)
    local U=ns.Util
    local function equal(a,b) return assert(ns.Codec.Encode(a)==ns.Codec.Encode(b),"values differ") end
    local function simulation(count,wire)
        local sim={clock=1000,clients={},queue={},traffic={},wires={},notices={}}
        function sim:Make(id)
            local manager
            local function send(target,envelope)
                local raw=assert(ns.Codec.Encode(envelope))
                local packet={sender=id,target=target,message=assert(ns.Codec.Decode(raw))}
                self.traffic[#self.traffic+1]=U.Copy(packet)
                if self.filter and self.filter(packet)==false then return true end
                if wire then return self.wires[id]:Send(target,envelope) end
                self.queue[#self.queue+1]=packet; return true
            end
            manager=ns.Session.New({id=id,now=function() return self.clock end,send=send,rng=U.RNG(33),
                token=U.Token,notice=function(code) self.notices[#self.notices+1]=code end})
            self.clients[id]=manager
            if wire then self.wires[id]=ns.Wire.New({now=function() return self.clock end,
                rawSend=function(target,fragment) self.queue[#self.queue+1]={sender=id,target=target,fragment=fragment}; return true end,
                receive=function(sender,envelope) manager:Receive(sender,envelope) end,
                notice=function(code) self.notices[#self.notices+1]=code end}) end
            return manager
        end
        function sim:Pump()
            local guard=0
            while #self.queue>0 do
                guard=guard+1; assert(guard<10000,"network loop")
                local p=table.remove(self.queue,1)
                if self.clients[p.target] then
                    if p.fragment then self.wires[p.target]:Receive(p.sender,p.fragment)
                    else self.clients[p.target]:Receive(p.sender,p.message) end
                end
            end
        end
        function sim:Step(seconds)
            local rounds=math.ceil(seconds/(wire and .1 or 1))
            for _=1,rounds do
                self.clock=self.clock+(wire and .1 or 1)
                for _,c in pairs(self.clients) do c:Tick() end
                if wire then for _,w in pairs(self.wires) do w:Tick() end end
                self:Pump()
            end
        end
        for i=1,count do sim:Make("Player"..i.."-Realm") end
        sim.host=sim.clients["Player1-Realm"]
        assert(sim.host:Create("Éléonore |cffFF0000 taverne"))
        function sim:Join(i)
            local id="Player"..i.."-Realm"
            assert(self.host:Invite(id)); if wire then self:Step(3) else self:Pump() end
            local inv=self.clients[id].invitations[self.host.id]; assert(inv,"missing invitation")
            assert(self.clients[id]:Accept(self.host.id,inv.nonce))
            if wire then self:Step(8) else self:Pump() end
            assert(self.clients[id].view,"join was not acknowledged")
        end
        function sim:Start(n)
            for i=2,n do self:Join(i) end
            for i=1,n do assert(self.clients["Player"..i.."-Realm"]:Intent("READY",{ready=true})) end
            if wire then self:Step(15) else self:Pump() end
            assert(self.host:Intent("START"))
            if wire then
                local started=self.clock
                for _=1,450 do
                    self:Step(.1)
                    local active=true; for _,c in pairs(self.clients) do if c.view.phase~="ACTIVE" then active=false end end
                    if active then self.preparationElapsed=self.clock-started; break end
                end
            else self:Pump(); self:Step(2) end
            local debug=self.host.state.phase.." revision="..self.host.state.revision.." acks="..U.Count(self.host.state.acks).." notices="..table.concat(self.notices,",")
            if wire then
                for id,c in pairs(self.clients) do debug=debug.." "..id..":"..tostring(c.view and c.view.phase).."/"..self.wires[id].queuedBytes end
                for _,q in ipairs(self.wires[self.host.id].queue) do debug=debug.." ["..q.target..","..q.kind..","..q.next.."/"..#q.fragments.."]" end
            end
            assert(self.host.state.phase=="ACTIVE",debug)
            for i=1,n do assert(self.clients["Player"..i.."-Realm"].view.phase=="ACTIVE","client not active") end
        end
        function sim:Cut()
            local s=self.host.state
            for _,p in ipairs(s.players) do
                if p.id~=s.currentHolderId and p.id~=s.previousHolderId then
                    for _,slot in ipairs(p.slots) do if not slot.revealed and slot.face~="BOMB" then
                        local actor=self.clients[s.currentHolderId]
                        assert(actor:Intent("CUT",{targetId=p.id,slotId=slot.id})); return actor,p.id,slot.id
                    end end
                end
            end
            error("no test cut")
        end
        return sim
    end
    test("codec safe roundtrip, accented strings and shared string tokens",function()
        local value={name="Éléonore-Auberdine",same="Éléonore-Auberdine",[12]=false,arr={3,true,"\0:\255"}}
        equal(value,assert(ns.Codec.Decode(assert(ns.Codec.Encode(value)))))
        assert(not ns.Codec.Decode('return os.execute("anything")'))
        assert(not ns.Codec.Decode("m2:s1:ai1:s1:ai2:"))
        assert(not ns.Codec.Decode("s999999:"))
        assert(not ns.Codec.Decode("r1:"))
        assert(not ns.Codec.Encode(0/0)); assert(not ns.Codec.Encode(1.5))
        local cycle={}; cycle.self=cycle; assert(not ns.Codec.Encode(cycle))
        assert(not ns.Codec.Encode(string.rep("a",4097)))
    end)
    test("wire fragments reassemble out of order, duplicates deliver once",function()
        local clock,fragments,received=0,{},{}
        local a=ns.Wire.New({now=function() return clock end,rawSend=function(_,f) assert(#f<=240); fragments[#fragments+1]=f; return true end,receive=function() end})
        local b=ns.Wire.New({now=function() return clock end,rawSend=function() return true end,receive=function(sender,msg) received[#received+1]=msg end})
        local message={text=string.rep("é",1500),n=24}
        assert(a:Send("B-Realm",message))
        for _=1,20 do clock=clock+1; a:Tick() end
        assert(#a.queue==0 and #fragments>10)
        for i=#fragments,1,-1 do b:Receive("A-Realm",fragments[i]); b:Receive("A-Realm",fragments[i]) end
        assert(#received==1); equal(message,received[1])
        for _,f in ipairs(fragments) do b:Receive("A-Realm",f) end
        assert(#received==1)
    end)
    test("wire rejects oversized and flooding fragments and expires partials",function()
        local clock=0
        local w=ns.Wire.New({now=function() return clock end,rawSend=function() return true end,receive=function() error("unexpected") end})
        assert(not w:Receive("A-Realm",string.rep("x",241)))
        for i=1,100 do w:Receive("A-Realm","1:"..string.format("%x",i)..":1:3:abcd") end
        assert(w.partialCount<=4 and w.partialBytes<=800)
        clock=91; w:Tick(); assert(w.partialCount==0 and w.partialBytes==0)
    end)
    test("real sender, nonce, capacity and concurrent final-seat acceptance",function()
        local s=simulation(9)
        for i=2,7 do s:Join(i) end
        s.host:Invite("Player8-Realm"); s.host:Invite("Player9-Realm"); s:Pump()
        for i=8,9 do local c=s.clients["Player"..i.."-Realm"]; assert(c:Accept(s.host.id,c.invitations[s.host.id].nonce)) end
        s:Pump(); assert(#s.host.state.players==8)
        local joined=0; for i=8,9 do if s.clients["Player"..i.."-Realm"].view then joined=joined+1 end end
        assert(joined==1); assert(ns.Engine.Validate(s.host.state))
    end)
    test("concurrent READY intentions do not lose readiness",function()
        local s=simulation(4); for i=2,4 do s:Join(i) end
        for _,c in pairs(s.clients) do c:Intent("READY",{ready=true}) end
        s:Pump(); for _,p in ipairs(s.host.state.players) do assert(p.ready) end
        assert(s.host:Intent("START")); s:Pump(); s:Step(2); assert(s.host.state.phase=="ACTIVE")
    end)
    test("incompatible invitations, forged nonce and expiry never join",function()
        local s=simulation(4); local client=s.clients["Player2-Realm"]
        s.host:Invite(client.id); s.queue[1].message.version="99"; s:Pump()
        local inv=client.invitations[s.host.id]; assert(inv and not inv.compatible)
        assert(not client:Accept(s.host.id,inv.nonce)); assert(#s.host.state.players==1)
        local fake=client:Envelope("JOIN",{nonce="forged"}); fake.sessionId=s.host.sessionId
        assert(not s.host:Receive(client.id,fake)); assert(#s.host.state.players==1)
        s:Step(61); assert(client.invitations[s.host.id]==nil)
    end)
    test("lost JOINED retries the same nonce without allocating another seat",function()
        local s=simulation(4); local client=s.clients["Player2-Realm"]; local lost=false
        s.filter=function(p) if p.message.kind=="JOINED" and not lost then lost=true; return false end end
        s.host:Invite(client.id); s:Pump(); client:Accept(s.host.id,client.invitations[s.host.id].nonce); s:Pump()
        assert(not client.view and #s.host.state.players==2)
        s:Step(13); assert(client.view and #s.host.state.players==2 and s.host.outgoing[client.id].status=="ACCEPTED")
    end)
    test("payload recipient projections never include hidden faces or remote roles",function()
        local s=simulation(8); s:Start(8)
        for _,packet in ipairs(s.traffic) do
            local v=packet.message.payload.view
            if v then
                assert(v.rngState==nil and v.discardedRole==nil)
                for _,p in ipairs(v.players) do
                    assert(p.role==nil and p.counts==nil)
                    for _,slot in ipairs(p.slots or {}) do assert(slot.face==nil) end
                end
                if v.private then
                    assert(v.private.role and v.private.counts and not v.private.slots)
                    local own=ns.Engine.GetViewForPlayer(s.host.state,packet.target)
                    equal(v.private.counts,own.private.counts)
                end
            end
        end
        assert(s.host.view~=s.host.state and s.host.view.rngState==nil)
    end)
    test("duplicate CUT and lost RESULT retry have exactly one effect",function()
        local s=simulation(4); s:Start(4)
        local actor=s.clients[s.host.state.currentHolderId]
        -- Force the remote case without changing game state when host holds first.
        if actor==s.host then s:Cut(); s:Pump(); actor=s.clients[s.host.state.currentHolderId] end
        local before=s.host.state.revision
        local lost=false
        s.filter=function(packet) if packet.message.kind=="RESULT" and packet.target==actor.id and not lost then lost=true; return false end end
        s:Cut(); local request=U.Copy(actor.request.intent); s:Pump()
        local count=#s.host.state.history; assert(lost and count>0)
        local envelope=actor:Envelope("INTENT",request,request.requestId)
        s.host:Receive(actor.id,envelope); s:Pump(); s:Step(11)
        assert(#s.host.state.history==count and s.host.state.revision==before+1)
        assert(not actor.pending)
    end)
    test("forged actor and forbidden immediate return cannot mutate state",function()
        local s=simulation(4); s:Start(4); s:Cut(); s:Pump()
        local st=s.host.state; local before=assert(ns.Codec.Encode(ns.Engine.GetViewForPlayer(st,s.host.id)))
        local actor=s.clients[st.currentHolderId]; local target
        for _,p in ipairs(st.players) do if p.id==st.previousHolderId then target=p end end
        actor:Intent("CUT",{targetId=target.id,slotId=target.slots[1].id}); s:Pump()
        assert(before==ns.Codec.Encode(ns.Engine.GetViewForPlayer(st,s.host.id)))
        local forged=actor:Envelope("INTENT",{kind="CANCEL",gameId=st.gameId,round=st.round,revision=st.revision,requestId="forged",actorId=s.host.id},"forged")
        assert(not s.host:Receive("Stranger-Realm",forged)); assert(before==ns.Codec.Encode(ns.Engine.GetViewForPlayer(st,s.host.id)))
    end)
    test("dropped PATCH and out-of-order update repair converge",function()
        local s=simulation(4); s:Start(4)
        local victim="Player4-Realm"
        s.filter=function(p) if p.target==victim and p.message.kind=="PATCH" then return false end end
        s:Cut(); s:Pump(); s.filter=nil
        s:Cut(); s:Pump(); s:Step(1)
        equal(s.clients[victim].view,ns.Engine.GetViewForPlayer(s.host.state,victim))
    end)
    test("client reload restores own seat and preserves pliers restriction",function()
        local s=simulation(4); s:Start(4); s:Cut(); s:Pump()
        local id="Player3-Realm"; local checkpoint=s.clients[id]:Checkpoint(); local before=s.host.state.revision
        assert(checkpoint.state==nil and checkpoint.view.rngState==nil)
        local client=s:Make(id); assert(client:Restore(checkpoint)); s:Pump()
        assert(s.host.state.revision==before)
        equal(client.view,ns.Engine.GetViewForPlayer(s.host.state,id))
    end)
    test("host reload reconciles all clients before restoring play",function()
        local s=simulation(4); s:Start(4); s:Cut(); s:Pump()
        local cp=s.host:Checkpoint(); local pair={cp.state.currentHolderId,cp.state.previousHolderId}
        local restored=s:Make(s.host.id); s.host=restored; assert(restored:Restore(cp)); assert(restored.state.suspended)
        s:Pump(); assert(not restored.state.suspended and not restored.state.recovering)
        equal(pair,{restored.state.currentHolderId,restored.state.previousHolderId})
        for id,c in pairs(s.clients) do equal(c.view,ns.Engine.GetViewForPlayer(restored.state,id)) end
    end)
    test("older host checkpoint suspends instead of rolling clients back",function()
        local s=simulation(4); s:Start(4); local cp=s.host:Checkpoint(); s:Cut(); s:Pump()
        local cutRevision=s.host.state.revision
        local restored=s:Make(s.host.id); s.host=restored; assert(restored:Restore(cp)); s:Pump()
        assert(restored.diverged and restored.state.suspended=="RECOVERY_DIVERGED")
        for id,c in pairs(s.clients) do if id~=restored.id then assert(c.view.revision==cutRevision and c.view.suspended) end end
        assert(restored:Intent("CANCEL")); s:Pump()
        for _,c in pairs(s.clients) do assert(c.view.cancelled and c.view.phase=="GAME_OVER") end
    end)
    test("checkpoint identity mismatch and corrupt authoritative state rejected",function()
        local s=simulation(4); s:Start(4); local cp=s.host:Checkpoint()
        local stranger=ns.Session.New({id="Other-Realm",now=function() return 1 end,send=function() return true end})
        assert(not stranger:Restore(cp))
        cp.state.previousHolderId="unknown"
        local host=s:Make(s.host.id); assert(not host:Restore(cp))
        assert(host.quarantined and host.view.suspended=="INVALID_CHECKPOINT" and host.view.private==nil and host:Checkpoint()==nil)
        assert(host:Intent("CANCEL")); s:Pump()
        for _,c in pairs(s.clients) do assert(c.view==nil) end
    end)
    test("checkpoint expires after twelve hours and PREPARING saves latest revision",function()
        local s=simulation(4); for i=2,4 do s:Join(i) end
        for _,c in pairs(s.clients) do c:Intent("READY",{ready=true}) end; s:Pump()
        s.host:Intent("START"); s.host:Tick()
        assert(s.host.state.phase=="PREPARING")
        local cp=s.host:Checkpoint(); assert(cp.view.revision==cp.state.revision)
        local restored=s:Make(s.host.id); assert(restored:Restore(cp)); restored:Close()
        s.clock=s.clock+43201; local ok,err=restored:Restore(cp); assert(not ok and err=="CHECKPOINT_EXPIRED")
    end)
    test("malformed authenticated projections rejected before reaching UI",function()
        local s=simulation(4); s:Start(4); local c=s.clients["Player2-Realm"]
        local original=U.Copy(c.view)
        local corruptions={
            function(v) v.private.counts="bad" end,
            function(v) v.players[1].slots[1].face="BOMB" end,
            function(v) v.players[1].remaining="five" end,
            function(v) v.players[1].connected={} end,
            function(v) v.rngState=42 end,
            function(v) v.private.mapping={SAFE=1} end,
            function(v) v.history={{face="EVIL"}} end,
        }
        for _,mutate in ipairs(corruptions) do
            local v=U.Copy(original); mutate(v)
            assert(not c:Receive(s.host.id,s.host:Envelope("SNAPSHOT",{view=v})))
            equal(c.view,original)
        end
    end)
    test("runtime invariant failure quarantines then permits secret-free closure",function()
        local s=simulation(4); s:Start(4)
        s.host.state.players[1].slots[1].face="INVALID"
        s.host:Intent("NEXT"); s:Pump()
        assert(s.host.quarantined and s.host.state==nil and s.host.view.private==nil)
        assert(s.host:Intent("CANCEL")); s:Pump()
        for _,c in pairs(s.clients) do assert(c.view==nil) end
    end)
    test("disconnect suspends and reconnect repairs without changing roles",function()
        local s=simulation(4); s:Start(4)
        local missing=s.clients["Player4-Realm"]; s.clients[missing.id]=nil
        s:Step(46); assert(s.host.state.suspended=="PLAYER_TIMEOUT")
        s.clients[missing.id]=missing; missing:Send(s.host.id,"RESUME",{knownRevision=missing.view.revision,knownGameId=missing.view.gameId}); s:Pump()
        assert(not s.host.state.suspended); equal(missing.view,ns.Engine.GetViewForPlayer(s.host.state,missing.id))
    end)
    test("rematch rejects old action and regenerates identifiers",function()
        local s=simulation(4); s:Start(4)
        local old=s.host.state.gameId; local request={kind="CUT",gameId=old,round=1,revision=s.host.state.revision,requestId="old-action",targetId="Player2-Realm",slotId="old-slot"}
        s.host:Intent("CANCEL"); s:Pump(); s.host:Intent("REMATCH"); s:Pump()
        assert(s.host.state.gameId~=old and s.host.state.previousHolderId==nil)
        local rev=s.host.state.revision; s.host:ApplyIntent(s.host.id,request); assert(rev==s.host.state.revision)
        for _,c in pairs(s.clients) do assert(c.view.private==nil) end
    end)
    test("consecutive fresh tables advance a dedicated RNG stream",function()
        local random,seed=math.random,math.randomseed
        local s=simulation(4); s:Start(4)
        local function pattern(state)
            local out={}
            for _,p in ipairs(state.players) do
                out[#out+1]=p.role
                for _,slot in ipairs(p.slots) do out[#out+1]=slot.face end
            end
            return table.concat(out,",")
        end
        local first=pattern(s.host.state); local firstRng=s.host.state.rngState
        s.host:Leave(); s:Pump(); s:Step(16); assert(s.host:Create("Fresh")); s:Start(4)
        assert(pattern(s.host.state)~=first and s.host.state.rngState~=firstRng)
        assert(math.random==random and math.randomseed==seed)
    end)
    test("lost departure and terminal ACK retry safely then erase tombstones",function()
        local s=simulation(4); s:Start(4)
        local leaver=s.clients["Player4-Realm"]; local lostLeave,lostAck=false,false
        s.filter=function(p)
            if p.message.kind=="LEAVE" and not lostLeave then lostLeave=true; return false end
            if p.message.kind=="TERMINAL_ACK" and not lostAck then lostAck=true; return false end
        end
        leaver:Leave(); s:Pump(); assert(not s.host.state.cancelled)
        s:Step(6); assert(s.host.state.cancelled and lostAck)
        local revision=s.host.state.revision; s:Step(6)
        assert(s.host.state.revision==revision and U.Count(leaver.departures)==0)
        s.filter=nil; s.host:Leave(); s:Pump()
        for _,c in pairs(s.clients) do assert(not c.view) end
        s:Step(46); for _,c in pairs(s.clients) do assert(U.Count(c.tombstones)==0 and U.Count(c.departures)==0) end
    end)
    test("Wire session purge removes secret queues but retains terminal delivery",function()
        local w=ns.Wire.New({now=function() return 100 end,rawSend=function() return true end,receive=function() end})
        w:Send("A-Realm",{kind="SNAPSHOT",sessionId="old",payload={secret="private"}})
        w:Send("A-Realm",{kind="CLOSED",sessionId="old",payload={}})
        w:PurgeSession("old"); assert(#w.queue==1 and w.queue[1].kind=="CLOSED")
        w:Clear(); assert(w.queuedBytes==0 and #w.queue==0)
    end)
    test("eight clients play through actual throttled fragmented Wire",function()
        local s=simulation(8,true); s:Start(8)
        print(string.format("INFO eight-client preparation: %.1fs at 800B/s",s.preparationElapsed))
        assert(not s.host.state.suspended,"throughput caused false disconnect")
        local before=s.clock; s:Cut(); s:Step(20)
        for id,c in pairs(s.clients) do
            assert(not c.view.suspended,"false suspension")
            equal(c.view,ns.Engine.GetViewForPlayer(s.host.state,id))
            assert(s.wires[id].queuedBytes<10000,"unbounded snapshot accumulation "..s.wires[id].queuedBytes)
        end
        for _,code in ipairs(s.notices) do assert(code~="PLAYER_TIMEOUT" and code~="HOST_TIMEOUT" and code~="NO_RESPONSE",code) end
    end)
end
