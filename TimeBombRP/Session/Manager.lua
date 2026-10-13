local ADDON, ns = ...
local Session = {}
Session.__index = Session
ns.Session = Session
local U = ns.Util
local PHASES={LOBBY=true,PREPARING=true,ACTIVE=true,BETWEEN_ROUNDS=true,GAME_OVER=true}
local ACTIONS={READY=true,START=true,ACK=true,CUT=true,NEXT=true,REMATCH=true,CANCEL=true}
local FACES={SAFE=true,DEFUSE=true,BOMB=true}
local ROLES={DEFUSER=true,SABOTEUR=true}
local function allowed(value,list)
    if type(value)~="table" or getmetatable(value) then return false end
    for key in pairs(value) do if not list[key] then return false end end
    return true
end
local VIEW_KEYS={sessionId=true,gameId=true,hostId=true,tableName=true,phase=true,revision=true,round=true,cuts=true,defused=true,
    playerCount=true,currentHolderId=true,previousHolderId=true,suspended=true,recovering=true,cancelled=true,winner=true,cause=true,
    players=true,history=true,private=true,discardedRole=true}
local PLAYER_KEYS={id=true,name=true,ready=true,connected=true,remaining=true,slots=true,role=true}
local SLOT_KEYS={id=true,revealed=true,face=true}
local PRIVATE_KEYS={role=true,counts=true,round=true,gameId=true}
local HISTORY_KEYS={round=true,actorId=true,targetId=true,slotId=true,face=true,revision=true}
local function integer(n) return type(n)=="number" and n>=0 and n<9007199254740991 and n%1==0 end
local function address(s) return type(s)=="string" and #s>0 and #s<=128 and not s:find("[%z\1-\32|]") end
local function token(s) return type(s)=="string" and #s>0 and #s<=160 end
local function member(state,id)
    if state and state.players then for i,p in ipairs(state.players) do if p.id==id then return p,i end end end
end
local function same(a,b)
    if type(a)~=type(b) then return false end
    if type(a)~="table" then return a==b end
    for k,v in pairs(a) do if not same(v,b[k]) then return false end end
    for k in pairs(b) do if a[k]==nil then return false end end
    return true
end
local function delta(old,new)
    local changes={}
    local function walk(a,b,path)
        if same(a,b) then return end
        if type(a)=="table" and type(b)=="table" then
            for k,v in pairs(b) do local p=U.Copy(path); p[#p+1]=k; walk(a[k],v,p) end
            for k in pairs(a) do if b[k]==nil then local p=U.Copy(path); p[#p+1]=k; changes[#changes+1]={path=p,remove=true} end end
        else changes[#changes+1]={path=path,value=U.Copy(b)} end
    end
    walk(old,new,{})
    return {baseRevision=old.revision,changes=changes}
end
local function patched(view,payload)
    if type(payload)~="table" or payload.baseRevision~=view.revision or type(payload.changes)~="table" or #payload.changes>128 then return nil end
    local result=U.Copy(view)
    for _,change in ipairs(payload.changes) do
        if type(change)~="table" or type(change.path)~="table" or #change.path<1 or #change.path>8 then return nil end
        local target=result
        for i=1,#change.path-1 do
            local key=change.path[i]
            if type(key)~="string" and not integer(key) then return nil end
            if type(target[key])~="table" then return nil end
            target=target[key]
        end
        local key=change.path[#change.path]
        if type(key)~="string" and not integer(key) then return nil end
        if change.remove then target[key]=nil else target[key]=U.Copy(change.value) end
    end
    return result
end
local function validView(v,id,host,session)
    if not allowed(v,VIEW_KEYS) or v.hostId~=host or v.sessionId~=session or not token(v.gameId)
        or not integer(v.revision) or not PHASES[v.phase] or not integer(v.round)
        or v.round>4 or type(v.tableName)~="string" or #v.tableName>96
        or not integer(v.cuts) or v.cuts>8 or not integer(v.defused) or v.defused>8
        or type(v.players)~="table" or #v.players<1 or #v.players>8 or U.Count(v.players)~=#v.players
        or v.playerCount~=#v.players or v.cuts>v.playerCount or v.defused>v.playerCount
        or type(v.history)~="table" or #v.history>32 or U.Count(v.history)~=#v.history then return false end
    if (v.suspended~=nil and type(v.suspended)~="boolean" and not token(v.suspended))
        or (v.recovering~=nil and type(v.recovering)~="boolean") or (v.cancelled~=nil and type(v.cancelled)~="boolean")
        or (v.winner~=nil and not ROLES[v.winner]) or (v.discardedRole~=nil and not ROLES[v.discardedRole])
        or (v.cause~=nil and v.cause~="DEFUSED" and v.cause~="BOMB" and v.cause~="TIMEOUT" and v.cause~="CANCELLED") then return false end
    local found,ids,own=false,{},nil
    for _,p in ipairs(v.players) do
        if not allowed(p,PLAYER_KEYS) or not address(p.id) or ids[p.id] or type(p.name)~="string" or #p.name>128
            or type(p.ready)~="boolean" or type(p.connected)~="boolean" or not integer(p.remaining) or p.remaining>5 then return false end
        ids[p.id]=true; if p.id==id then found=true; own=p end
        if p.role and (not ROLES[p.role] or v.phase~="GAME_OVER" or v.cancelled) then return false end
        if type(p.slots)~="table" or #p.slots>5 or U.Count(p.slots)~=#p.slots then return false end
        local hidden,handles=0,{}
        for _,slot in ipairs(p.slots) do
            if not allowed(slot,SLOT_KEYS) or not token(slot.id) or handles[slot.id] or type(slot.revealed)~="boolean"
                or (slot.revealed and not FACES[slot.face]) or (not slot.revealed and slot.face~=nil) then return false end
            handles[slot.id]=true; if not slot.revealed then hidden=hidden+1 end
        end
        if hidden~=p.remaining then return false end
    end
    if not ids[host] or (v.currentHolderId and not ids[v.currentHolderId]) or (v.previousHolderId and not ids[v.previousHolderId]) then return false end
    for _,record in ipairs(v.history) do
        if not allowed(record,HISTORY_KEYS) or not ids[record.actorId] or not ids[record.targetId] or record.actorId==record.targetId
            or not token(record.slotId) or not FACES[record.face] or not integer(record.round) or record.round<1 or record.round>4
            or not integer(record.revision) or record.revision>v.revision then return false end
    end
    if v.private then
        local p=v.private
        if not allowed(p,PRIVATE_KEYS) or p.gameId~=v.gameId or p.round~=v.round or not ROLES[p.role] or not allowed(p.counts,FACES) then return false end
        local count=0
        for face in pairs(FACES) do if not integer(p.counts[face]) or p.counts[face]>5 then return false end; count=count+p.counts[face] end
        if not own or count~=own.remaining or v.phase=="LOBBY" or v.cancelled then return false end
    end
    if (v.discardedRole or v.winner) and (v.phase~="GAME_OVER" or v.cancelled) then return false end
    return found
end
function Session.New(opts)
    return setmetatable({id=opts.id,now=opts.now,send=opts.send,changed=opts.changed or function() end,
        notice=opts.notice or function() end,token=opts.token or U.Token,rng=opts.rng or U.RNG(1),invitations={},outgoing={},
        pending=false,seen={},seenOrder={},lastSeen={},sentViews={},snapshotAt={},solicitations={},departures={},tombstones={},lastBeat=opts.now(),ignoreInvites=false},Session)
end
function Session:Envelope(kind,payload,requestId)
    local s=self.state or self.view
    return {v=ns.PROTOCOL,version=ns.VERSION,ruleset=ns.RULESET,kind=kind,
        sessionId=self.sessionId or "",gameId=s and s.gameId or "",round=s and s.round or 0,
        revision=s and s.revision or 0,requestId=requestId or self.token("msg"),payload=payload or {}}
end
function Session:Send(target,kind,payload,requestId)
    local ok=self.send(target,self:Envelope(kind,payload,requestId))
    if ok==false then self.notice("NETWORK_BUSY",target) end
    return ok~=false
end
function Session:GetView() return self.view and U.Copy(self.view) or nil end
function Session:Install(view,event)
    self.view=U.Copy(view)
    if self.view then
        self.view.tableName=U.Clean(self.view.tableName,96)
        for _,p in ipairs(self.view.players) do p.name=U.Clean(p.name,128) end
    end
    self.changed(self:GetView(),event)
end
function Session:Create(tableName)
    if self.sessionId or self.joinAttempt then return false,"BUSY" end
    local state,err=ns.Engine.New({sessionId=self.token("session"),gameId=self.token("game"),hostId=self.id,
        tableName=U.Clean(tableName or "Time Bomb RP",80),players={{id=self.id,name=self.id,ready=false,connected=true}},rng=U.RNG(self.rng:Int(2147483646))})
    if not state then self.notice(err); return false,err end
    self.state=state; self.hostId=self.id; self.sessionId=state.sessionId; self.lastSeen[self.id]=self.now()
    self:Broadcast("CREATE"); return true
end
function Session:Invite(target)
    if not self.state or self.hostId~=self.id then return false,"NOT_HOST" end
    if self.state.phase~="LOBBY" then return false,"BUSY" end
    if not address(target) or target==self.id then return false,"INVALID_TARGET" end
    if member(self.state,target) then return false,"ALREADY_JOINED" end
    if #self.state.players>=8 then self.notice("TABLE_FULL"); return false,"TABLE_FULL" end
    local old=self.outgoing[target]
    if old and self.now()-old.sent<15 then return false,"RATE_LIMIT" end
    if U.Count(self.outgoing)>=16 and not old then return false,"NETWORK_BUSY" end
    local invite={nonce=self.token("invite"),sent=self.now(),expires=self.now()+60,status="SENT",sessionId=self.sessionId}
    self.outgoing[target]=invite
    self:Send(target,"INVITE",{nonce=invite.nonce,tableName=self.state.tableName,playerCount=#self.state.players})
    self.notice("INVITE_SENT",target); self.changed(self:GetView(),"INVITES"); return true
end
function Session:Accept(sender,nonce)
    local inv=self.invitations[sender]
    if self.sessionId or self.joinAttempt then return false,"BUSY" end
    if not inv or inv.nonce~=nonce or inv.expires<self.now() then return false,"INVITE_EXPIRED" end
    if not inv.compatible then return false,"INVITE_INCOMPATIBLE" end
    self.joinAttempt={sender=sender,nonce=nonce,sessionId=inv.sessionId,tries=1,last=self.now()}
    self.hostId=sender; self.sessionId=inv.sessionId; self.pending=true
    self:Send(sender,"JOIN",{nonce=nonce}); return true
end
function Session:Decline(sender,nonce)
    local inv=self.invitations[sender]
    if not inv or inv.nonce~=nonce then return false,"INVITE_EXPIRED" end
    local envelope=self:Envelope("DECLINE",{nonce=nonce}); envelope.sessionId=inv.sessionId
    self.send(sender,envelope); self.invitations[sender]=nil; self.changed(self:GetView(),"INVITES"); return true
end
function Session:Snapshot(target,kind,extra)
    local view=ns.Engine.GetViewForPlayer(self.state,target)
    if not view then return end
    self.sentViews[target]=U.Copy(view); self.snapshotAt[target]=self.now()
    if target==self.id then self:Install(view,kind or "SNAPSHOT")
    else self:Send(target,kind or "SNAPSHOT",{view=view,nonce=extra}) end
end
function Session:Broadcast(event)
    if not self.state then return end
    -- The only serialization boundary is an explicit per-recipient projection.
    for _,p in ipairs(self.state.players) do
        if p.id~=self.id then
            local view=ns.Engine.GetViewForPlayer(self.state,p.id)
            local previous=self.sentViews[p.id]
            if previous and same(previous,view) then
                -- JOINED already installed this projection for the new seat.
            elseif (event=="CUT" or event=="ACK") and previous and previous.gameId==view.gameId and previous.round==view.round then
                self:Send(p.id,"PATCH",delta(previous,view))
                self.sentViews[p.id]=U.Copy(view)
            else self:Snapshot(p.id) end
        end
    end
    self:Snapshot(self.id,event)
end
function Session:Remember(sender,id,response)
    local key=sender.."/"..id
    self.seen[key]=response; self.seenOrder[#self.seenOrder+1]=key
    while #self.seenOrder>256 do self.seen[table.remove(self.seenOrder,1)]=nil end
end
function Session:ApplyIntent(sender,intent)
    if not self.state or not member(self.state,sender) then return end
    local key=sender.."/"..intent.requestId
    if self.seen[key] then
        local old=self.seen[key]
        if sender==self.id then self:Result(intent.requestId,old)
        else self:Send(sender,"RESULT",old,intent.requestId) end
        return
    end
    if self.diverged and sender==self.id and intent.kind=="CANCEL" then
        self.state.revision=math.max(self.state.revision,self.maxObservedRevision or 0)
    end
    local ok,result=ns.Engine.Apply(self.state,sender,intent)
    local reply={ok=ok==true,code=ok and "OK" or result,revision=self.state.revision,gameId=self.state.gameId}
    self:Remember(sender,intent.requestId,reply)
    if ok then
        if intent.kind=="ACK" and self.state.phase=="PREPARING" then self:Snapshot(self.id,"ACK")
        else self:Broadcast(intent.kind) end
    elseif result=="INVALID_STATE" then
        self:Quarantine("INVALID_STATE")
    end
    if sender==self.id then self:Result(intent.requestId,reply)
    else self:Send(sender,"RESULT",reply,intent.requestId) end
end
function Session:Intent(kind,fields)
    if not self.view or not ACTIONS[kind] then return false,"NOT_MEMBER" end
    if self.quarantined then
        if kind=="CANCEL" and self.hostId==self.id then return self:Leave() end
        return false,"INVALID_STATE"
    end
    if self.pending then return false,"PENDING" end
    local intent={kind=kind,gameId=self.view.gameId,round=self.view.round,revision=self.view.revision,requestId=self.token("req")}
    fields=fields or {}
    intent.targetId=fields.targetId; intent.slotId=fields.slotId; intent.ready=fields.ready
    if kind=="REMATCH" then intent.newGameId=self.token("game") end
    self.pending=true; self.request={intent=intent,last=self.now(),tries=1}
    if self.hostId==self.id then self:ApplyIntent(self.id,intent)
    else self:Send(self.hostId,"INTENT",intent,intent.requestId) end
    self.changed(self:GetView(),"PENDING"); return true
end
function Session:Result(requestId,result)
    if not self.request or self.request.intent.requestId~=requestId then return end
    local action=self.request.intent.kind
    self.pending=false; self.request=nil
    if not result.ok and result.code~="ALREADY_ACKED" and result.code~="NO_CHANGE" then self.notice(result.code) end
    if action~="ACK" and action~="READY" and self.hostId~=self.id and self.view and result.revision>self.view.revision then
        self.repairRevision=result.revision; self.repairAt=self.now()+12
    end
    self.changed(self:GetView(),"RESULT")
end
function Session:Connection(sender)
    self.lastSeen[sender]=self.now()
    if not self.state then return end
    local p=member(self.state,sender)
    if p and p.connected==false then
        p.connected=true
        if self.recovery then return end
        self.state.revision=self.state.revision+1
        local all=true
        for _,row in ipairs(self.state.players) do if row.connected==false then all=false end end
        if all and self.state.suspended=="PLAYER_TIMEOUT" and not self.state.recovering then self.state.suspended=nil end
        self:Broadcast("RECONNECTED")
    end
end
function Session:Diverged(knownRevision)
    local first=not self.diverged
    if self.state then self.state.suspended="RECOVERY_DIVERGED"; self.state.recovering=true end
    if self.view then self.view.suspended="RECOVERY_DIVERGED"; self.view.recovering=true end
    self.diverged=true
    self.maxObservedRevision=math.max(self.maxObservedRevision or 0,knownRevision or 0)
    if self.state and first then for _,p in ipairs(self.state.players) do if p.id~=self.id then self:Send(p.id,"SUSPEND",{reason="RECOVERY_DIVERGED"}) end end end
    self.notice("RECOVERY_DIVERGED"); self.changed(self:GetView(),"SUSPENDED")
end
function Session:Receive(sender,e)
    if not address(sender) or type(e)~="table" or not integer(e.v)
        or type(e.version)~="string" or #e.version>32 or type(e.ruleset)~="string" or #e.ruleset>64
        or type(e.kind)~="string" or #e.kind>24
        or type(e.payload)~="table" or not token(e.requestId) or not integer(e.revision) or not integer(e.round)
        or type(e.sessionId)~="string" or #e.sessionId>160 or type(e.gameId)~="string" or #e.gameId>160 then return false end
    if not ns.Codec.Encode(e) then return false end
    local compatible=e.v==ns.PROTOCOL and e.version==ns.VERSION and e.ruleset==ns.RULESET
    local p=e.payload
    if compatible and e.kind=="TERMINAL_ACK" then
        local terminal=self.departures[e.requestId]
        if terminal and terminal.target==sender and terminal.envelope.sessionId==e.sessionId then self.departures[e.requestId]=nil; return true end
        return false
    end
    local tombstone=self.tombstones[sender.."/"..e.requestId]
    if compatible and tombstone and tombstone.sessionId==e.sessionId and (e.kind=="LEAVE" or e.kind=="CLOSED") then
        if self.now()-tombstone.last>=1 then self.send(sender,tombstone.ack); tombstone.last=self.now() end
        return true
    end
    if e.kind=="INVITE" then
        if not token(p.nonce) or not token(e.sessionId) or type(p.tableName)~="string" or not integer(p.playerCount) or p.playerCount>8 then return false end
        if self.ignoreInvites or self.sessionId then return false end
        local last=self.solicitations[sender]
        if last and self.now()-last<15 then return false end
        if U.Count(self.solicitations)>=32 and not last then return false end
        if U.Count(self.invitations)>=8 and not self.invitations[sender] then return false end
        self.solicitations[sender]=self.now()
        self.invitations[sender]={nonce=p.nonce,sessionId=e.sessionId,tableName=U.Clean(p.tableName,80),playerCount=p.playerCount,
            version=e.version,ruleset=e.ruleset,compatible=compatible,expires=self.now()+60,status=compatible and "PENDING" or "INCOMPATIBLE"}
        local response=self:Envelope("INVITE_SEEN",{nonce=p.nonce,status=compatible and "PENDING" or "INCOMPATIBLE"}); response.sessionId=e.sessionId
        self.send(sender,response); self.changed(self:GetView(),"INVITES"); return true
    end
    if e.sessionId~=self.sessionId or not self.sessionId then return false end
    if e.kind=="INVITE_SEEN" or e.kind=="DECLINE" then
        local out=self.outgoing[sender]
        if not out or out.nonce~=p.nonce or out.expires<self.now() or out.status=="ACCEPTED" then return false end
        out.status=e.kind=="DECLINE" and "DECLINED" or (p.status=="INCOMPATIBLE" and "INCOMPATIBLE" or "PENDING")
        self.changed(self:GetView(),"INVITES"); return true
    end
    if not compatible then return false end
    if e.kind=="JOIN" and self.state then
        local out=self.outgoing[sender]
        if not out or out.nonce~=p.nonce then return false end
        if member(self.state,sender) then self:Snapshot(sender,"JOINED",p.nonce); return true end
        if out.expires<self.now() or out.status=="DECLINED" or out.status=="INCOMPATIBLE" or self.state.phase~="LOBBY" then
            self:Send(sender,"JOIN_REJECT",{nonce=p.nonce,code="INVITE_EXPIRED"}); return false
        end
        if #self.state.players>=8 then out.status="FULL"; self:Send(sender,"JOIN_REJECT",{nonce=p.nonce,code="TABLE_FULL"}); return false end
        self.state.players[#self.state.players+1]={id=sender,name=sender,ready=false,connected=true}
        self.state.playerCount=#self.state.players
        self.state.revision=self.state.revision+1; out.status="PENDING"; self.lastSeen[sender]=self.now()
        self:Snapshot(sender,"JOINED",p.nonce); self:Broadcast("JOIN"); return true
    end
    if sender==self.hostId and self.hostId~=self.id then
        if e.kind=="JOIN_REJECT" and self.joinAttempt and p.nonce==self.joinAttempt.nonce then
            local code=p.code; self:Close(); self.notice(code); return true
        end
        if e.kind=="JOINED" then
            if self.joinAttempt and p.nonce~=self.joinAttempt.nonce then return false end
            if not self.joinAttempt and not self.view then return false end
            if not validView(p.view,self.id,self.hostId,self.sessionId) then return false end
            self.joinAttempt=nil; self.pending=false; self.invitations={}; self.lastSeen[sender]=self.now()
            if not self.view or p.view.revision>=self.view.revision then self:Install(p.view,"JOINED") end
            self:Send(sender,"JOIN_ACK",{nonce=p.nonce}); return true
        end
        if not self.view then return false end
        self.lastSeen[sender]=self.now()
        if e.kind=="SNAPSHOT" then
            if not validView(p.view,self.id,self.hostId,self.sessionId) or p.view.revision<self.view.revision then return false end
            if self.diverged and not p.view.cancelled then return false end
            self:Install(p.view,"SNAPSHOT"); return true
        elseif e.kind=="PATCH" then
            if self.diverged then return false end
            if e.revision<=self.view.revision then return true end
            local view=patched(self.view,p)
            if not view or view.revision~=e.revision or not validView(view,self.id,self.hostId,self.sessionId) then
                self:Send(sender,"RESYNC",{knownRevision=self.view.revision}); self.notice("SYNCING"); return false
            end
            self:Install(view,"CUT"); return true
        elseif e.kind=="RESULT" then
            if type(p.ok)~="boolean" or not integer(p.revision) or type(p.code)~="string" then return false end
            self:Result(e.requestId,p); return true
        elseif e.kind=="HEARTBEAT" then
            self:Send(sender,"PONG",{knownRevision=self.view.revision,knownGameId=self.view.gameId}); return true
        elseif e.kind=="RECOVER" then
            self.view.suspended="RECOVERING"; self.view.recovering=true
            self:Send(sender,"RECONCILE",{knownRevision=self.view.revision,knownGameId=self.view.gameId})
            self.changed(self:GetView(),"RECOVERING"); return true
        elseif e.kind=="SUSPEND" then
            self.diverged=true
            self.view.suspended=(p.reason=="INVALID_CHECKPOINT" or p.reason=="INVALID_STATE") and p.reason or "RECOVERY_DIVERGED"
            self.view.recovering=true; self.changed(self:GetView(),"SUSPENDED"); return true
        elseif e.kind=="CLOSED" then self:TerminalAck(sender,e); self:Close(); self.notice("CLOSED"); return true end
        return false
    end
    if not self.state or not member(self.state,sender) then return false end
    self:Connection(sender)
    if e.kind=="INTENT" then
        if not ACTIONS[p.kind] or not token(p.requestId) or p.requestId~=e.requestId or not integer(p.round) or not integer(p.revision) or not token(p.gameId) then return false end
        -- Actor identity always comes from the transport, never this payload.
        if (p.targetId and not address(p.targetId)) or (p.slotId and not token(p.slotId)) or (p.ready~=nil and type(p.ready)~="boolean") then return false end
        self:ApplyIntent(sender,p); return true
    elseif e.kind=="JOIN_ACK" then
        local out=self.outgoing[sender]
        if out and out.nonce==p.nonce then out.status="ACCEPTED"; self.notice("INVITE_ACCEPTED",sender); self.changed(self:GetView(),"INVITES") end
        return true
    elseif e.kind=="RESYNC" then
        if not self.diverged then self:Snapshot(sender) end; return true
    elseif e.kind=="PONG" or e.kind=="RESUME" or e.kind=="RECONCILE" then
        if not integer(p.knownRevision) or not token(p.knownGameId) then return false end
        local limit=self.recoveryRevision or self.state.revision
        if p.knownRevision>limit then self:Diverged(p.knownRevision); return false end
        if self.recovery and self.recovery[sender]~=nil then self.recovery[sender]=true end
        if self.recovery and not self.diverged then
            local complete=true; for _,yes in pairs(self.recovery) do if not yes then complete=false end end
            if complete then
                self.state.recovering=nil; self.state.suspended=nil; self.state.revision=self.state.revision+1
                self.recovery=nil; self.recoveryRevision=nil; self:Broadcast("RECOVERED")
            end
        elseif not self.diverged and (e.kind=="RESUME" or (self.sentViews[sender] and p.knownRevision<self.sentViews[sender].revision
            and self.now()-(self.snapshotAt[sender] or 0)>45)) then self:Snapshot(sender) end
        return true
    elseif e.kind=="LEAVE" then
        self:TerminalAck(sender,e)
        if self.state.phase=="LOBBY" then
            local _,index=member(self.state,sender); table.remove(self.state.players,index); self.state.playerCount=#self.state.players; self.state.revision=self.state.revision+1
            self.lastSeen[sender]=nil; self.sentViews[sender]=nil; self.outgoing[sender]=nil; self:Broadcast("LEFT")
        else
            ns.Engine.Apply(self.state,self.id,{kind="CANCEL",gameId=self.state.gameId,requestId=self.token("cancel")})
            local row=member(self.state,sender); row.connected=false; self:Broadcast("CANCEL")
        end
        return true
    end
    return false
end
function Session:Tick()
    local now=self.now()
    for id,d in pairs(self.departures) do
        if now>=d.expires then self.departures[id]=nil
        elseif now-d.last>=5 and d.tries<3 then d.tries=d.tries+1; d.last=now; self.send(d.target,d.envelope) end
    end
    for key,t in pairs(self.tombstones) do if now>=t.expires then self.tombstones[key]=nil end end
    for sender,inv in pairs(self.invitations) do if inv.expires<now then self.invitations[sender]=nil; self.notice("INVITE_EXPIRED",sender); self.changed(self:GetView(),"INVITES") end end
    for sender,time in pairs(self.solicitations) do if now-time>120 then self.solicitations[sender]=nil end end
    for target,out in pairs(self.outgoing) do
        if out.expires<now and (out.status=="SENT" or out.status=="PENDING") then
            out.status=out.status=="SENT" and "NO_RESPONSE" or "EXPIRED"; self.notice(out.status=="NO_RESPONSE" and "NO_RESPONSE" or "INVITE_EXPIRED",target); self.changed(self:GetView(),"INVITES")
        elseif now-out.sent>180 and out.status~="ACCEPTED" then self.outgoing[target]=nil end
    end
    if self.joinAttempt and now-self.joinAttempt.last>=12 then
        local j=self.joinAttempt
        if j.tries>=3 then self:Close(); self.notice("NO_RESPONSE")
        else j.tries=j.tries+1; j.last=now; self:Send(j.sender,"JOIN",{nonce=j.nonce}) end
    end
    if self.request and now-self.request.last>=10 then
        local r=self.request
        if r.tries>=3 then
            if r.intent.kind=="ACK" then self.lastAck=nil end
            self.pending=false; self.request=nil; self.notice("NO_RESPONSE"); self:Send(self.hostId,"RESYNC",{knownRevision=self.view.revision}); self.changed(self:GetView(),"RESULT")
        else r.tries=r.tries+1; r.last=now; self:Send(self.hostId,"INTENT",r.intent,r.intent.requestId) end
    end
    if self.view and self.view.phase=="PREPARING" and not self.pending and self.view.private then
        local ack=self.view.gameId.."/"..self.view.round
        if self.lastAck~=ack then self.lastAck=ack; self:Intent("ACK") end
    end
    if not self.sessionId or not self.view or self.quarantined then return end
    if self.repairAt and now>=self.repairAt then
        if self.view.revision<(self.repairRevision or 0) then self:Send(self.hostId,"RESYNC",{knownRevision=self.view.revision}) end
        self.repairAt=nil; self.repairRevision=nil
    end
    if now-self.lastBeat>=10 then
        self.lastBeat=now
        if self.state then
            for _,p in ipairs(self.state.players) do
                if p.id~=self.id then
                    if self.recovery and not self.recovery[p.id] then self:Send(p.id,"RECOVER",{knownRevision=self.recoveryRevision})
                    else self:Send(p.id,"HEARTBEAT") end
                end
            end
        else self:Send(self.hostId,"PONG",{knownRevision=self.view.revision,knownGameId=self.view.gameId}) end
    end
    if self.state then
        local changed=false
        for _,p in ipairs(self.state.players) do
            if p.id~=self.id and p.connected~=false and now-(self.lastSeen[p.id] or now)>45 then p.connected=false; changed=true; self.notice("PLAYER_TIMEOUT",p.id) end
        end
        if changed then
            if self.state.phase~="LOBBY" and self.state.phase~="GAME_OVER" and not self.state.suspended then self.state.suspended="PLAYER_TIMEOUT" end
            self.state.revision=self.state.revision+1; self:Broadcast("CONNECTION")
        end
    elseif self.lastSeen[self.hostId] and now-self.lastSeen[self.hostId]>45 and self.view.suspended~="HOST_TIMEOUT" and not self.diverged then
        self.view.suspended="HOST_TIMEOUT"; self.notice("HOST_TIMEOUT"); self.changed(self:GetView(),"CONNECTION")
    end
end
function Session:Checkpoint()
    if not self.sessionId or not self.view or self.quarantined then return nil end
    return {schema=1,version=ns.VERSION,ruleset=ns.RULESET,id=self.id,hostId=self.hostId,sessionId=self.sessionId,savedAt=self.now(),
        view=self.state and ns.Engine.GetViewForPlayer(self.state,self.id) or U.Copy(self.view),state=self.state and U.Copy(self.state) or nil,seen=U.Copy(self.seen),seenOrder=U.Copy(self.seenOrder)}
end
function Session:Restore(cp)
    if self.sessionId then return false,"BUSY" end
    if type(cp)=="table" and type(cp.savedAt)=="number" and cp.savedAt==cp.savedAt
        and (self.now()-cp.savedAt>43200 or cp.savedAt-self.now()>300) then
        self.notice("CHECKPOINT_EXPIRED"); return false,"CHECKPOINT_EXPIRED"
    end
    if type(cp)~="table" or cp.schema~=1 or cp.version~=ns.VERSION or cp.ruleset~=ns.RULESET or cp.id~=self.id
        or type(cp.savedAt)~="number" or cp.savedAt~=cp.savedAt or cp.savedAt<0 or cp.savedAt==math.huge
        or not address(cp.hostId) or not token(cp.sessionId) or not validView(cp.view,self.id,cp.hostId,cp.sessionId) then
        self.notice("INVALID_CHECKPOINT"); return false,"INVALID_CHECKPOINT"
    end
    if cp.hostId==self.id then
        if type(cp.state)~="table" or cp.state.hostId~=self.id or cp.state.sessionId~=cp.sessionId or not ns.Engine.Validate(cp.state)
            or cp.state.revision~=cp.view.revision or cp.state.gameId~=cp.view.gameId then
            self.hostId=cp.hostId; self.sessionId=cp.sessionId; self:Install(cp.view,"RESTORE")
            self:Quarantine("INVALID_CHECKPOINT"); return false,"INVALID_CHECKPOINT"
        end
        self.state=U.Copy(cp.state); self.state.suspended="RECOVERING"; self.state.recovering=true
        self.recoveryRevision=self.state.revision; self.recovery={}
        self.seen=type(cp.seen)=="table" and U.Copy(cp.seen) or {}; self.seenOrder=type(cp.seenOrder)=="table" and U.Copy(cp.seenOrder) or {}
        if #self.seenOrder>256 or U.Count(self.seen)>256 then self.seen={}; self.seenOrder={} end
        for _,p in ipairs(self.state.players) do self.lastSeen[p.id]=self.now(); if p.id~=self.id then self.recovery[p.id]=false end end
    end
    self.hostId=cp.hostId; self.sessionId=cp.sessionId; self.lastSeen[self.hostId]=self.now()
    local view=U.Copy(cp.view); view.suspended="RECOVERING"; view.recovering=true; self:Install(view,"RESTORE")
    if self.state then
        if U.Count(self.recovery)==0 then self.state.suspended=nil; self.state.recovering=nil; self.recovery=nil; self.recoveryRevision=nil; self:Broadcast("RECOVERED")
        else for id in pairs(self.recovery) do self:Send(id,"RECOVER",{knownRevision=self.recoveryRevision}) end end
    else self:Send(self.hostId,"RESUME",{knownRevision=self.view.revision,knownGameId=self.view.gameId}) end
    self.notice("RECOVERING"); return true
end
function Session:Leave()
    if self.sessionId then
        if self.hostId==self.id then for _,p in ipairs((self.state or self.view).players) do if p.id~=self.id then self:Terminal(p.id,"CLOSED") end end
        elseif self.hostId then self:Terminal(self.hostId,"LEAVE") end
    end
    self:Close(); self.notice("LEFT"); return true
end
function Session:Quarantine(reason)
    -- Retain only the previously verified public membership for a safe closure.
    -- Never project, deserialize again, or export the corrupted authoritative data.
    self.state=nil; self.quarantined=true; self.diverged=true; self.pending=false; self.request=nil
    self.view.private=nil; self.view.suspended=reason; self.view.recovering=true
    for _,p in ipairs(self.view.players) do if p.id~=self.id then self:Send(p.id,"SUSPEND",{reason=reason}) end end
    self.notice(reason); self.changed(self:GetView(),"SUSPENDED")
end
function Session:Terminal(target,kind)
    local envelope=self:Envelope(kind,{reason=kind=="CLOSED" and "HOST_LEFT" or "PLAYER_LEFT"})
    if U.Count(self.departures)<8 then self.departures[envelope.requestId]={target=target,envelope=envelope,last=self.now(),expires=self.now()+20,tries=1} end
    self.send(target,envelope)
end
function Session:TerminalAck(sender,envelope)
    local ack={v=ns.PROTOCOL,version=ns.VERSION,ruleset=ns.RULESET,kind="TERMINAL_ACK",sessionId=envelope.sessionId,
        gameId="",round=0,revision=0,requestId=envelope.requestId,payload={}}
    if U.Count(self.tombstones)<16 then self.tombstones[sender.."/"..envelope.requestId]={sessionId=envelope.sessionId,ack=ack,last=self.now(),expires=self.now()+45} end
    self.send(sender,ack)
end
function Session:Close()
    self.state=nil; self.view=nil; self.hostId=nil; self.sessionId=nil; self.request=nil; self.joinAttempt=nil
    self.pending=false; self.invitations={}; self.outgoing={}; self.seen={}; self.seenOrder={}; self.lastSeen={}; self.sentViews={}; self.snapshotAt={}
    self.recovery=nil; self.recoveryRevision=nil; self.diverged=nil; self.quarantined=nil; self.lastAck=nil; self.maxObservedRevision=nil; self.repairAt=nil; self.repairRevision=nil
    self.changed(nil,"CLOSED")
end
