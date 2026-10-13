return function(ns, test)
    local E, U = ns.Engine, ns.Util
    local requestCounter = 0
    local function equal(a, b)
        if type(a) ~= type(b) then return false end
        if type(a) ~= "table" then return a == b end
        for k, v in pairs(a) do if not equal(v, b[k]) then return false end end
        for k in pairs(b) do if a[k] == nil then return false end end
        return true
    end
    local function valid(s)
        local ok, code = E.Validate(s)
        assert(ok, "invalid engine state: " .. tostring(code))
    end
    local function intent(s, kind, fields)
        requestCounter = requestCounter + 1
        local i = { kind = kind, gameId = s.gameId, round = s.round, revision = s.revision, requestId = "r" .. requestCounter }
        for k, v in pairs(fields or {}) do i[k] = v end
        return i
    end
    local function apply(s, actor, kind, fields)
        local ok, event = E.Apply(s, actor, intent(s, kind, fields))
        assert(ok, "rejected " .. kind .. ": " .. tostring(event))
        valid(s)
        return event
    end
    local function reject(s, actor, kind, fields, code)
        local before = U.Copy(s)
        local ok, got = E.Apply(s, actor, intent(s, kind, fields))
        assert(not ok and got == code, "expected " .. code .. ", got " .. tostring(got))
        assert(equal(before, s), "rejected request mutated authoritative state")
    end
    local function lobby(n, seed)
        local players = {}
        for i = 1, n do players[i] = { id = "P" .. i .. "-Realm", name = "Joueur " .. i, ready = true, connected = true } end
        return assert(E.New({ sessionId = "session", gameId = "game", hostId = players[1].id,
            tableName = "Le coffret", players = players, rng = U.RNG(seed or 2417) }))
    end
    local function ack(s)
        -- All clients acknowledge the same round despite different current revisions.
        local revision = s.revision
        for _, p in ipairs(s.players) do apply(s, p.id, "ACK", { revision = revision }) end
        assert(s.phase == "ACTIVE")
    end
    local function game(n, seed)
        local s = lobby(n, seed)
        apply(s, s.hostId, "START", { firstHolderId = s.hostId })
        ack(s)
        return s
    end
    local function player(s, id)
        for _, p in ipairs(s.players) do if p.id == id then return p end end
    end
    local function hidden(p)
        for _, slot in ipairs(p.slots) do if not slot.revealed then return slot end end
    end
    local function choose(s, wanted)
        for _, target in ipairs(E.LegalTargets(s, s.currentHolderId)) do
            for _, slot in ipairs(player(s, target).slots) do
                if not slot.revealed and (not wanted or slot.face == wanted) then return target, slot.id end
            end
        end
    end
    local function cut(s, target, slot)
        return apply(s, s.currentHolderId, "CUT", { targetId = target, slotId = slot })
    end
    local function chooseSafe(s)
        local id, slot = choose(s, "SAFE")
        if not id then id, slot = choose(s, "DEFUSE") end
        assert(id, "all legal cards are bomb in selected fixture")
        return id, slot
    end
    local function reach(s, targetRound)
        while s.round < targetRound and s.phase ~= "GAME_OVER" do
            if s.phase == "BETWEEN_ROUNDS" then apply(s, s.hostId, "NEXT"); ack(s)
            else local id, slot = chooseSafe(s); cut(s, id, slot) end
        end
        assert(s.round == targetRound and s.phase == "ACTIVE", "fixture ended before target round")
    end
    -- Swap only unrevealed cards: constructs another valid deal without changing
    -- card totals or introducing an impossible card into the game.
    local function setFace(s, target, slotId, face)
        local slot
        for _, candidate in ipairs(player(s, target).slots) do if candidate.id == slotId then slot = candidate end end
        assert(slot and not slot.revealed)
        if slot.face ~= face then
            local other
            for _, p in ipairs(s.players) do
                for _, c in ipairs(p.slots) do if not c.revealed and c.face == face then other = c; break end end
                if other then break end
            end
            assert(other, "requested face unavailable")
            slot.face, other.face = other.face, slot.face
        end
        valid(s)
    end

    test("Engine: 4–8 role decks, discarded roles, cable totals and private preparation", function()
        local roleDecks = { [4]={3,2}, [5]={3,2}, [6]={4,2}, [7]={5,3}, [8]={5,3} }
        for n = 4, 8 do
            local s = lobby(n)
            assert(s.phase == "LOBBY" and s.round == 0)
            apply(s, s.hostId, "START", { firstHolderId = s.hostId })
            assert(s.phase == "PREPARING" and not s.previousHolderId)
            reject(s, s.currentHolderId, "CUT", {}, "WRONG_PHASE")
            local roles, cards = { DEFUSER=0, SABOTEUR=0 }, { SAFE=0, DEFUSE=0, BOMB=0 }
            for _, p in ipairs(s.players) do
                roles[p.role] = roles[p.role] + 1
                assert(#p.slots == 5)
                for _, slot in ipairs(p.slots) do cards[slot.face] = cards[slot.face] + 1 end
            end
            if s.discardedRole then roles[s.discardedRole] = roles[s.discardedRole] + 1 end
            assert(roles.DEFUSER == roleDecks[n][1] and roles.SABOTEUR == roleDecks[n][2])
            assert((s.discardedRole ~= nil) == (n == 4 or n == 7))
            assert(cards.SAFE == 4*n-1 and cards.DEFUSE == n and cards.BOMB == 1)
            ack(s)
        end
    end)

    test("Engine: readiness concurrency, authority, capacities and random holder", function()
        local s = lobby(4)
        for _, p in ipairs(s.players) do p.ready = false end
        reject(s, s.hostId, "START", {}, "NOT_READY")
        for _, p in ipairs(s.players) do apply(s, p.id, "READY", { ready=true, revision=0 }) end
        reject(s, s.players[2].id, "START", {}, "HOST_ONLY")
        reject(s, "Outsider-Realm", "READY", { ready=true }, "NOT_MEMBER")
        s.players[2].connected = false
        reject(s, s.hostId, "START", {}, "DISCONNECTED")
        s.players[2].connected = true
        apply(s, s.hostId, "START")
        assert(player(s, s.currentHolderId) and not s.previousHolderId)
        local small = lobby(3)
        reject(small, small.hostId, "START", {}, "PLAYER_COUNT")
        local oversized = lobby(8)
        local opts = { sessionId="s",gameId="g",hostId=oversized.hostId,players=oversized.players }
        opts.players[9] = {id="P9-Realm", name="9"}
        assert(not E.New(opts))
    end)

    test("Engine: A→B→A forbidden, A→B→C→A legal and rejection atomicity", function()
        local s = game(4)
        local a,b,c = s.players[1].id,s.players[2].id,s.players[3].id
        local bslot = hidden(player(s,b)).id
        setFace(s,b,bslot,"SAFE"); cut(s,b,bslot)
        assert(s.previousHolderId == a and s.currentHolderId == b)
        reject(s,b,"CUT",{targetId=a,slotId=hidden(player(s,a)).id},"RETURN_FORBIDDEN")
        local cslot = hidden(player(s,c)).id
        setFace(s,c,cslot,"SAFE"); cut(s,c,cslot)
        reject(s,c,"CUT",{targetId=b,slotId=hidden(player(s,b)).id},"RETURN_FORBIDDEN")
        local aslot = hidden(player(s,a)).id
        setFace(s,a,aslot,"SAFE"); cut(s,a,aslot)
        assert(s.currentHolderId == a and s.previousHolderId == c)
    end)

    test("Engine: malformed/stale/foreign/own/revealed cuts cannot transfer pliers", function()
        local s = game(4)
        local a,b,c = s.players[1].id,s.players[2].id,s.players[3].id
        reject(s,a,"CUT",{targetId=a,slotId=hidden(player(s,a)).id},"SELF_TARGET")
        reject(s,b,"CUT",{targetId=c,slotId=hidden(player(s,c)).id},"NOT_HOLDER")
        reject(s,a,"CUT",{targetId=b,slotId="unknown"},"INVALID_SLOT")
        reject(s,a,"CUT",{targetId="Ghost-Realm",slotId="unknown"},"INVALID_TARGET")
        reject(s,a,"CUT",{targetId=b,slotId=12},"INVALID_REQUEST")
        reject(s,a,"CUT",{gameId="old",targetId=b,slotId="unknown"},"STALE_GAME")
        reject(s,a,"CUT",{round=0,targetId=b,slotId="unknown"},"STALE_ROUND")
        reject(s,a,"CUT",{revision=s.revision-1,targetId=b,slotId="unknown"},"STALE_REVISION")
        local bslot = hidden(player(s,b)).id
        setFace(s,b,bslot,"SAFE")
        local duplicate = intent(s,"CUT",{targetId=b,slotId=bslot})
        assert(E.Apply(s,a,duplicate)); valid(s)
        local before = U.Copy(s)
        local ok, code = E.Apply(s,a,duplicate)
        assert(not ok and code == "STALE_REVISION" and equal(before,s))
        local cslot = hidden(player(s,c)).id; setFace(s,c,cslot,"SAFE"); cut(s,c,cslot)
        local aslot = hidden(player(s,a)).id; setFace(s,a,aslot,"SAFE"); cut(s,a,aslot)
        reject(s,a,"CUT",{targetId=b,slotId=bslot},"SLOT_REVEALED")
        s.suspended = "MISSING_PLAYER"
        reject(s,a,"CUT",{targetId=b,slotId=hidden(player(s,b)).id},"SUSPENDED")
    end)

    test("Engine: redistribution conserves deck, roles, progress and forbidden predecessor", function()
        for n=4,8 do
            local s = game(n)
            local roles, oldHandles = {}, {}
            for _,p in ipairs(s.players) do roles[p.id]=p.role; for _,slot in ipairs(p.slots) do oldHandles[slot.id]=true end end
            local id, slot = choose(s,"DEFUSE")
            if not id then id,slot=choose(s); setFace(s,id,slot,"DEFUSE") end
            cut(s,id,slot)
            while s.phase=="ACTIVE" do local t,h=chooseSafe(s); cut(s,t,h) end
            assert(s.phase=="BETWEEN_ROUNDS")
            local holder, previous, defused = s.currentHolderId,s.previousHolderId,s.defused
            local stillHidden = {SAFE=0,DEFUSE=0,BOMB=0}
            for _,p in ipairs(s.players) do for _,c in ipairs(p.slots) do if not c.revealed then stillHidden[c.face]=stillHidden[c.face]+1 end end end
            apply(s,s.hostId,"NEXT")
            assert(s.currentHolderId==holder and s.previousHolderId==previous and s.defused==defused)
            local redealt={SAFE=0,DEFUSE=0,BOMB=0}
            for _,p in ipairs(s.players) do
                assert(p.role==roles[p.id] and #p.slots==4)
                for _,c in ipairs(p.slots) do assert(not oldHandles[c.id]); redealt[c.face]=redealt[c.face]+1 end
            end
            assert(equal(stillHidden,redealt))
            ack(s)
            reject(s,holder,"CUT",{targetId=previous,slotId=hidden(player(s,previous)).id},"RETURN_FORBIDDEN")
            -- Serialization/reload must preserve the restriction and exact card order.
            local restored=U.Copy(s); valid(restored)
            assert(equal(E.GetViewForPlayer(s,holder),E.GetViewForPlayer(restored,holder)))
            reject(restored,holder,"CUT",{targetId=previous,slotId=hidden(player(restored,previous)).id},"RETURN_FORBIDDEN")
        end
    end)

    test("Engine: immediate bomb and defusal take priority at a round boundary", function()
        for n=4,8 do
            local bomb=game(n)
            for _=1,n-1 do local id,slot=chooseSafe(bomb); cut(bomb,id,slot) end
            local id,slot=choose(bomb); setFace(bomb,id,slot,"BOMB"); cut(bomb,id,slot)
            assert(bomb.phase=="GAME_OVER" and bomb.cause=="BOMB" and bomb.winner=="SABOTEUR")
            reject(bomb,bomb.hostId,"NEXT",{},"WRONG_PHASE")
            local win=game(n)
            for _=1,n do local t,h=choose(win); setFace(win,t,h,"DEFUSE"); cut(win,t,h) end
            assert(win.cuts==n and win.phase=="GAME_OVER" and win.cause=="DEFUSED" and win.winner=="DEFUSER")
            local view=E.GetViewForPlayer(win,win.hostId)
            for _,p in ipairs(view.players) do assert(p.role) end
            assert(view.discardedRole==win.discardedRole)
        end
    end)

    test("Engine: last fourth-round defusal wins, exhaustion loses and no fifth round", function()
        for n=4,8 do
            local win=game(n)
            -- Place N-1 defusals during round one, keeping the final one hidden.
            for i=1,n do local t,h=choose(win); setFace(win,t,h,i<n and "DEFUSE" or "SAFE"); cut(win,t,h) end
            reach(win,4)
            for _=1,n-1 do local t,h=choose(win); setFace(win,t,h,"SAFE"); cut(win,t,h) end
            local t,h=choose(win); setFace(win,t,h,"DEFUSE"); cut(win,t,h)
            assert(win.round==4 and win.cuts==n and win.winner=="DEFUSER" and win.cause=="DEFUSED")
            reject(win,win.hostId,"NEXT",{},"WRONG_PHASE")
            local lose=game(n)
            reach(lose,4)
            while lose.phase=="ACTIVE" do
                local target,handle=chooseSafe(lose)
                if lose.defused==n-1 then setFace(lose,target,handle,"SAFE") end
                cut(lose,target,handle)
            end
            assert(lose.round==4 and lose.cuts==n and lose.cause=="TIMEOUT" and lose.winner=="SABOTEUR")
            reject(lose,lose.hostId,"NEXT",{},"WRONG_PHASE")
        end
    end)

    test("Engine: every player projection, including host, has no hidden face positions", function()
        for n=4,8 do
            local s=game(n)
            -- Canary fields must not survive the explicit projection allowlist.
            s.seed="NEVER_SEND"; s.players[1].secretMapping="NEVER_SEND"
            for _,owner in ipairs(s.players) do
                local v=E.GetViewForPlayer(s,owner.id)
                assert(v.private.role==owner.role and v.private.round==s.round and v.private.gameId==s.gameId)
                assert(not v.rngState and not v.seed and not v.discardedRole and not v.initialHolderId and not v.acks)
                local expected={SAFE=0,DEFUSE=0,BOMB=0}
                for _,slot in ipairs(owner.slots) do expected[slot.face]=expected[slot.face]+1 end
                assert(equal(v.private.counts,expected))
                for _,p in ipairs(v.players) do
                    assert(not p.role and not p.secretMapping and not p.counts)
                    for _,slot in ipairs(p.slots) do assert(not slot.face and type(slot.id)=="string") end
                end
                v.private.counts.SAFE=99; v.players[1].slots[1].revealed=true
                assert(not s.players[1].slots[1].revealed)
            end
            local target,handle=chooseSafe(s); local ownerBefore=E.GetViewForPlayer(s,target)
            local event=cut(s,target,handle)
            local ownerAfter=E.GetViewForPlayer(s,target)
            assert(ownerAfter.private.counts[event.face]==ownerBefore.private.counts[event.face]-1)
            for _,p in ipairs(ownerAfter.players) do for _,slot in ipairs(p.slots) do assert((slot.face~=nil)==slot.revealed) end end
            assert(not event.rngState and not event.private and not event.role)
            assert(not E.GetViewForPlayer(s,"Outsider-Realm"))
        end
    end)

    test("Engine: cancellation destroys secrets; rematch clears holders and invalidates old actions", function()
        local s=game(4)
        local target,handle=chooseSafe(s); local old=intent(s,"CUT",{targetId=target,slotId=handle})
        cut(s,target,handle)
        s.suspended="OFFLINE"
        reject(s,s.players[2].id,"CANCEL",{},"HOST_ONLY")
        apply(s,s.hostId,"CANCEL")
        assert(s.cancelled and not s.winner and not s.discardedRole)
        local view=E.GetViewForPlayer(s,s.hostId)
        assert(not view.private and not view.discardedRole)
        for _,p in ipairs(s.players) do assert(not p.role and not p.slots) end
        apply(s,s.hostId,"REMATCH",{newGameId="next-game"})
        assert(s.phase=="LOBBY" and not s.currentHolderId and not s.previousHolderId and #s.history==0)
        for _,p in ipairs(s.players) do assert(not p.ready) end
        local before=U.Copy(s)
        local ok,code=E.Apply(s,s.hostId,old)
        assert(not ok and code=="STALE_GAME" and equal(before,s))
        for _,p in ipairs(s.players) do apply(s,p.id,"READY",{ready=true}) end
        apply(s,s.hostId,"START"); ack(s)
        assert(not s.previousHolderId and s.gameId=="next-game")
    end)

    test("Engine: authoritative checkpoint corruption is rejected before any transition", function()
        local good=game(4)
        local mutations={
            function(s) s.rngState=0 end,
            function(s) s.players[1].slots[1].face="UNKNOWN" end,
            function(s) s.players[2].id=s.players[1].id end,
            function(s) s.players[1].slots[1].id=s.players[2].slots[1].id end,
            function(s) s.defused=2 end,
            function(s) s.previousHolderId=s.players[2].id end,
            function(s) s.currentHolderId=s.players[2].id end,
            function(s) s.players[1].slots[1].revealed=true end,
            function(s) s.players[1].role="INVENTED" end,
            function(s) s.discardedRole=nil end,
            function(s) s.phase="ACTIVE";s.acks[s.players[2].id]=false end,
            function(s) s.phase="PREPARING" end,
            function(s) s.cancelled="yes" end,
            function(s) s.players[1].slots[99]={id="x",face="SAFE",revealed=false} end,
        }
        for _,mutate in ipairs(mutations) do
            local s=U.Copy(good); mutate(s); assert(not E.Validate(s))
            local before=U.Copy(s)
            local ok,code=E.Apply(s,s.hostId,intent(s,"CANCEL"))
            assert(not ok and code=="INVALID_STATE" and equal(before,s))
        end
    end)

    test("Engine: generated reachable games always have legal targets for N=4..8", function()
        local emptyHolder=false
        for n=4,8 do
            for seed=1,60 do
                local s=game(n,seed*701+31)
                local choices=U.RNG(seed*13)
                local roles={}
                for _,p in ipairs(s.players) do roles[p.id]=p.role end
                while s.phase~="GAME_OVER" do
                    if s.phase=="BETWEEN_ROUNDS" then apply(s,s.hostId,"NEXT");ack(s)
                    else
                        local targets=E.LegalTargets(s,s.currentHolderId)
                        assert(#targets>0,"reachable state without legal target")
                        local holder=player(s,s.currentHolderId)
                        if not hidden(holder) then emptyHolder=true end
                        for _,id in ipairs(targets) do
                            assert(id~=s.currentHolderId and id~=s.previousHolderId and hidden(player(s,id)))
                        end
                        local candidates={}
                        for _,id in ipairs(targets) do
                            for _,slot in ipairs(player(s,id).slots) do
                                if not slot.revealed and slot.face~="BOMB" then candidates[#candidates+1]={id,slot.id} end
                            end
                        end
                        if #candidates==0 then
                            local id,slot=choose(s); cut(s,id,slot)
                        else
                            local selected=candidates[choices:Int(#candidates)]
                            cut(s,selected[1],selected[2])
                        end
                    end
                end
                for _,p in ipairs(s.players) do assert(p.role==roles[p.id],"role changed between rounds") end
                valid(s)
            end
        end
        assert(emptyHolder,"generated paths must actually exercise empty-handed holders")
    end)

    test("Engine: exhaustive symmetric hand-count paths prove no anti-return deadlock", function()
        -- Faces can end a game early, so ignoring them explores a superset of all
        -- reachable nonterminal states. Symmetric adversaries are interchangeable.
        for n=4,8 do
            for round=1,4 do
                local width=6-round
                local seen={}
                local function visit(holder,previous,others,cuts)
                    table.sort(others)
                    local key=holder..":"..tostring(previous)..":"..table.concat(others,",")..":"..cuts
                    if seen[key] then return end
                    seen[key]=true
                    if cuts==n then return end
                    local available=0
                    for _,amount in ipairs(others) do if amount>0 then available=available+1 end end
                    assert(available>0,"deadlock in exhaustive count traversal")
                    for index,amount in ipairs(others) do
                        if amount>0 then
                            local nextOthers={}
                            for i,value in ipairs(others) do if i~=index then nextOthers[#nextOthers+1]=value end end
                            if previous~=nil then nextOthers[#nextOthers+1]=previous end
                            visit(amount-1,holder,nextOthers,cuts+1)
                        end
                    end
                end
                local others={}
                local previous
                if round>1 then previous=width end
                for _=1,n-(previous and 2 or 1) do others[#others+1]=width end
                visit(width,previous,others,0)
            end
        end
    end)
end
