local ADDON, ns = ...
local Engine = {}
ns.Engine = Engine

local ROLES = {
    [4] = { DEFUSER = 3, SABOTEUR = 2 },
    [5] = { DEFUSER = 3, SABOTEUR = 2 },
    [6] = { DEFUSER = 4, SABOTEUR = 2 },
    [7] = { DEFUSER = 5, SABOTEUR = 3 },
    [8] = { DEFUSER = 5, SABOTEUR = 3 },
}
local PHASES = { LOBBY = true, PREPARING = true, ACTIVE = true, BETWEEN_ROUNDS = true, GAME_OVER = true }
local FACES = { SAFE = true, DEFUSE = true, BOMB = true }
local CAMPS = { DEFUSER = true, SABOTEUR = true }
local function integer(value, low, high)
    return type(value) == "number" and value == math.floor(value) and value >= low and value <= high
end
local function identifier(value)
    return type(value) == "string" and #value > 0 and #value <= 128 and not value:find("[%z\1-\31\127]")
end
local function array(value, max)
    if type(value) ~= "table" or getmetatable(value) then return false end
    local count = 0
    for key in pairs(value) do
        if not integer(key, 1, max) then return false end
        count = count + 1
    end
    if count > max then return false end
    for i = 1, count do if value[i] == nil then return false end end
    return true, count
end
local function findPlayer(state, id)
    for _, player in ipairs(state.players or {}) do
        if player.id == id then return player end
    end
end
local function counts()
    return { SAFE = 0, DEFUSE = 0, BOMB = 0 }
end
local function remaining(player)
    local total, result = 0, counts()
    for _, slot in ipairs(player.slots or {}) do
        if not slot.revealed then
            total = total + 1
            result[slot.face] = result[slot.face] + 1
        end
    end
    return total, result
end

-- These are the rule-level targets. Phase, connection and recovery gates are
-- checked by Apply; an empty-handed holder can still use the pliers.
function Engine.LegalTargets(state, actorId)
    local targets = {}
    if type(state) ~= "table" or actorId ~= state.currentHolderId then return targets end
    for _, player in ipairs(state.players or {}) do
        if player.id ~= actorId and player.id ~= state.previousHolderId then
            for _, slot in ipairs(player.slots or {}) do
                if not slot.revealed then
                    targets[#targets + 1] = player.id
                    break
                end
            end
        end
    end
    return targets
end

-- Validate authoritative checkpoints, including card conservation and the
-- entire public chain of pliers transfers. No secret is included in an error.
function Engine.Validate(state)
    if type(state) ~= "table" or getmetatable(state) then return false, "INVALID_STATE" end
    if not identifier(state.sessionId) or not identifier(state.gameId) or not identifier(state.hostId)
        or type(state.tableName) ~= "string" or #state.tableName > 96
        or not PHASES[state.phase] or not integer(state.revision, 0, 2147483646)
        or not integer(state.rngState, 1, 2147483646) then return false, "INVALID_HEADER" end
    if state.suspended ~= nil and type(state.suspended) ~= "boolean" and not identifier(state.suspended) then
        return false, "INVALID_SUSPENSION"
    end
    if state.recovering ~= nil and type(state.recovering) ~= "boolean" then return false, "INVALID_RECOVERY" end
    if state.cancelled ~= nil and type(state.cancelled) ~= "boolean" then return false, "INVALID_CANCELLATION" end
    local valid, n = array(state.players, 8)
    if not valid or n < 1 then return false, "INVALID_PLAYERS" end
    if state.playerCount ~= n then return false, "INVALID_PLAYER_COUNT" end
    local members = {}
    for _, player in ipairs(state.players) do
        if type(player) ~= "table" or getmetatable(player) or not identifier(player.id) or members[player.id]
            or type(player.name) ~= "string" or #player.name > 128
            or type(player.ready) ~= "boolean" or type(player.connected) ~= "boolean" then
            return false, "INVALID_PLAYER"
        end
        members[player.id] = player
    end
    if not members[state.hostId] then return false, "MISSING_HOST" end
    local historyOK, totalCuts = array(state.history, 32)
    if not historyOK then return false, "INVALID_HISTORY" end
    if state.phase == "LOBBY" then
        if state.round ~= 0 or state.cuts ~= 0 or state.defused ~= 0 or totalCuts ~= 0
            or state.currentHolderId ~= nil or state.previousHolderId ~= nil or state.initialHolderId ~= nil
            or state.discardedRole ~= nil or state.winner ~= nil or state.cancelled or state.cause ~= nil
            or state.acks ~= nil then return false, "INVALID_LOBBY" end
        for _, player in ipairs(state.players) do
            if player.role ~= nil or player.slots ~= nil then return false, "LOBBY_SECRET" end
        end
        return true
    end
    if state.cancelled then
        if state.phase ~= "GAME_OVER" or state.winner ~= nil or state.cause ~= "CANCELLED"
            or state.discardedRole ~= nil or state.acks ~= nil then return false, "INVALID_CANCELLATION" end
        for _, player in ipairs(state.players) do
            if player.role ~= nil or player.slots ~= nil then return false, "CANCELLED_SECRET" end
        end
        if not integer(state.round, 0, 4) or not integer(state.cuts, 0, n) or not integer(state.defused, 0, n) then
            return false, "INVALID_CANCELLATION"
        end
        -- Cancelled records retain only the public log. They cannot be resumed.
        for _, record in ipairs(state.history) do
            if type(record) ~= "table" or not members[record.actorId] or not members[record.targetId]
                or not FACES[record.face] or not identifier(record.slotId)
                or not integer(record.round, 1, 4) or not integer(record.revision, 1, state.revision) then
                return false, "INVALID_HISTORY"
            end
        end
        return true
    end
    if n < 4 or not integer(state.round, 1, 4) or not integer(state.cuts, 0, n)
        or not integer(state.defused, 0, n) or totalCuts ~= (state.round - 1) * n + state.cuts
        or not members[state.initialHolderId] or not members[state.currentHolderId]
        or (state.previousHolderId ~= nil and not members[state.previousHolderId]) then
        return false, "INVALID_ROUND"
    end
    if (state.phase == "ACTIVE" or state.phase == "PREPARING") and state.cuts >= n then
        return false, "INVALID_ACTIVE_ROUND"
    end
    if state.phase == "PREPARING" and state.cuts ~= 0 then return false, "INVALID_PREPARATION" end
    if state.phase == "BETWEEN_ROUNDS" and (state.cuts ~= n or state.round >= 4) then
        return false, "INVALID_ROUND_BOUNDARY"
    end
    local roleCounts = { DEFUSER = 0, SABOTEUR = 0 }
    local expectedDiscard = (n == 4 or n == 7)
    if expectedDiscard then
        if not CAMPS[state.discardedRole] then return false, "INVALID_DISCARDED_ROLE" end
        roleCounts[state.discardedRole] = 1
    elseif state.discardedRole ~= nil then return false, "INVALID_DISCARDED_ROLE" end
    local conserved, currentSlots, currentRevealed, handles = counts(), {}, {}, {}
    for _, player in ipairs(state.players) do
        if not CAMPS[player.role] then return false, "INVALID_ROLE" end
        roleCounts[player.role] = roleCounts[player.role] + 1
        local slotsOK, slotCount = array(player.slots, 5)
        if not slotsOK or slotCount ~= 6 - state.round then return false, "INVALID_HAND_SIZE" end
        for _, slot in ipairs(player.slots) do
            if type(slot) ~= "table" or getmetatable(slot) or not identifier(slot.id) or handles[slot.id]
                or not FACES[slot.face] or type(slot.revealed) ~= "boolean" then return false, "INVALID_SLOT_STATE" end
            handles[slot.id] = true
            currentSlots[slot.id] = { owner = player.id, face = slot.face, revealed = slot.revealed }
            if slot.revealed then currentRevealed[slot.id] = true
            else conserved[slot.face] = conserved[slot.face] + 1 end
        end
    end
    if roleCounts.DEFUSER ~= ROLES[n].DEFUSER or roleCounts.SABOTEUR ~= ROLES[n].SABOTEUR then
        return false, "ROLE_CONSERVATION"
    end
    local expectedHolder, expectedPrevious = state.initialHolderId, nil
    local historyHandles, lastRevision, bombFound = {}, 0, false
    local defused = 0
    for index, record in ipairs(state.history) do
        if type(record) ~= "table" or getmetatable(record) or not members[record.actorId]
            or not members[record.targetId] or record.actorId ~= expectedHolder
            or record.targetId == record.actorId or record.targetId == expectedPrevious
            or not identifier(record.slotId) or historyHandles[record.slotId]
            or not FACES[record.face] or record.round ~= math.floor((index - 1) / n) + 1
            or not integer(record.revision, lastRevision + 1, state.revision) then return false, "INVALID_HISTORY" end
        historyHandles[record.slotId] = true
        lastRevision = record.revision
        if record.round == state.round then
            local slot = currentSlots[record.slotId]
            if not slot or slot.owner ~= record.targetId or slot.face ~= record.face or not slot.revealed then
                return false, "HISTORY_SLOT_MISMATCH"
            end
            currentRevealed[record.slotId] = nil
        elseif currentSlots[record.slotId] then return false, "REUSED_HANDLE" end
        if record.face == "DEFUSE" then defused = defused + 1 end
        if record.face == "BOMB" then
            if index ~= totalCuts then return false, "CUT_AFTER_BOMB" end
            bombFound = true
        end
        if defused == n and index ~= totalCuts then return false, "CUT_AFTER_DEFUSAL" end
        conserved[record.face] = conserved[record.face] + 1
        expectedPrevious, expectedHolder = record.actorId, record.targetId
    end
    if next(currentRevealed) then return false, "UNLOGGED_REVEAL" end
    if state.currentHolderId ~= expectedHolder or state.previousHolderId ~= expectedPrevious then
        return false, "INVALID_HOLDER_CHAIN"
    end
    if conserved.SAFE ~= 4 * n - 1 or conserved.DEFUSE ~= n or conserved.BOMB ~= 1 or state.defused ~= defused then
        return false, "CARD_CONSERVATION"
    end
    if type(state.acks) ~= "table" or getmetatable(state.acks) then return false, "INVALID_ACKS" end
    for id, acked in pairs(state.acks) do
        if not members[id] or type(acked) ~= "boolean" then return false, "INVALID_ACKS" end
    end
    if state.phase ~= "PREPARING" then
        for id in pairs(members) do if state.acks[id] ~= true then return false, "MISSING_ACK" end end
    else
        local pending = false
        for id in pairs(members) do if state.acks[id] ~= true then pending = true end end
        if not pending then return false, "INVALID_PREPARATION" end
    end
    if state.phase == "GAME_OVER" then
        if state.cause == "BOMB" then
            if not bombFound or state.winner ~= "SABOTEUR" then return false, "INVALID_RESULT" end
        elseif state.cause == "DEFUSED" then
            if defused ~= n or bombFound or state.winner ~= "DEFUSER" then return false, "INVALID_RESULT" end
        elseif state.cause == "TIMEOUT" then
            if state.round ~= 4 or state.cuts ~= n or defused >= n or bombFound or state.winner ~= "SABOTEUR" then
                return false, "INVALID_RESULT"
            end
        else return false, "INVALID_RESULT" end
    elseif bombFound or defused >= n or state.winner ~= nil or state.cause ~= nil then
        return false, "MISSING_RESULT"
    end
    if (state.phase == "ACTIVE" or state.phase == "PREPARING") and #Engine.LegalTargets(state, state.currentHolderId) == 0 then
        return false, "NO_LEGAL_TARGET"
    end
    return true
end

function Engine.New(opts)
    if type(opts) ~= "table" or type(opts.players) ~= "table" then return nil, "INVALID_OPTIONS" end
    local playersOK, playerCount = array(opts.players, 8)
    if not playersOK then return nil, "INVALID_PLAYERS" end
    local state = {
        sessionId = opts.sessionId, gameId = opts.gameId, hostId = opts.hostId,
        tableName = ns.Util.Clean(opts.tableName or "Time Bomb RP", 96),
        phase = "LOBBY", revision = 0, round = 0, cuts = 0, defused = 0,
        playerCount = playerCount, players = {}, history = {},
        rngState = type(opts.rng) == "table" and opts.rng.state or 1,
    }
    for _, player in ipairs(opts.players) do
        if type(player) ~= "table" then return nil, "INVALID_PLAYER" end
        state.players[#state.players + 1] = {
            id = player.id, name = ns.Util.Clean(player.name or player.id or "", 128),
            ready = player.ready == true, connected = player.connected ~= false,
        }
    end
    local valid, code = Engine.Validate(state)
    if not valid then return nil, code end
    return state
end

local function freshHands(state, deck, rng)
    rng:Shuffle(deck)
    local cursor = 1
    for _, player in ipairs(state.players) do
        player.slots = {}
        for _ = 1, 6 - state.round do
            player.slots[#player.slots + 1] = {
                id = ns.Util.Token("c"), face = deck[cursor], revealed = false,
            }
            cursor = cursor + 1
        end
    end
    state.rngState = rng.state
    state.acks = {}
    for _, player in ipairs(state.players) do state.acks[player.id] = false end
    state.phase = "PREPARING"
end
local function scope(state, intent, round, revision)
    if intent.gameId ~= state.gameId then return false, "STALE_GAME" end
    if round and intent.round ~= state.round then return false, "STALE_ROUND" end
    if revision and intent.revision ~= state.revision then return false, "STALE_REVISION" end
    return true
end
local function transition(state, actorId, intent)
    local player = findPlayer(state, actorId)
    if not player then return false, "NOT_MEMBER" end
    local kind = intent.kind
    if kind ~= "CANCEL" and kind ~= "REMATCH" and kind ~= "ACK" and (state.suspended or state.recovering) then
        return false, "SUSPENDED"
    end
    local valid, code = scope(state, intent, kind == "CUT" or kind == "ACK" or kind == "NEXT", kind == "CUT")
    if not valid then return false, code end
    if kind == "READY" then
        if state.phase ~= "LOBBY" then return false, "WRONG_PHASE" end
        if type(intent.ready) ~= "boolean" then return false, "INVALID_REQUEST" end
        if player.ready == intent.ready then return false, "NO_CHANGE" end
        player.ready = intent.ready
    elseif kind == "START" then
        if actorId ~= state.hostId then return false, "HOST_ONLY" end
        if state.phase ~= "LOBBY" then return false, "WRONG_PHASE" end
        local n = #state.players
        if n < 4 or n > 8 then return false, "PLAYER_COUNT" end
        for _, participant in ipairs(state.players) do
            if not participant.ready then return false, "NOT_READY" end
            if not participant.connected then return false, "DISCONNECTED" end
        end
        if intent.firstHolderId ~= nil and not findPlayer(state, intent.firstHolderId) then return false, "INVALID_HOLDER" end
        local rng = ns.Util.RNG(state.rngState)
        -- The starting convention is chosen before any role or cable is drawn.
        state.currentHolderId = intent.firstHolderId or state.players[rng:Int(n)].id
        state.initialHolderId = state.currentHolderId
        state.previousHolderId = nil
        local roles, deck = {}, {}
        for _, camp in ipairs({ "DEFUSER", "SABOTEUR" }) do
            for _ = 1, ROLES[n][camp] do roles[#roles + 1] = camp end
        end
        rng:Shuffle(roles)
        for index, participant in ipairs(state.players) do participant.role = roles[index] end
        state.discardedRole = roles[n + 1]
        for _ = 1, 4 * n - 1 do deck[#deck + 1] = "SAFE" end
        for _ = 1, n do deck[#deck + 1] = "DEFUSE" end
        deck[#deck + 1] = "BOMB"
        state.round, state.cuts, state.defused = 1, 0, 0
        freshHands(state, deck, rng)
    elseif kind == "ACK" then
        if state.phase ~= "PREPARING" then return false, "WRONG_PHASE" end
        if state.acks[actorId] then return false, "ALREADY_ACKED" end
        state.acks[actorId] = true
        local all = true
        for _, participant in ipairs(state.players) do if not state.acks[participant.id] then all = false end end
        if all then state.phase = "ACTIVE" end
    elseif kind == "CUT" then
        if state.phase ~= "ACTIVE" then return false, "WRONG_PHASE" end
        if not identifier(intent.requestId) or not identifier(intent.targetId) or not identifier(intent.slotId) then
            return false, "INVALID_REQUEST"
        end
        if actorId ~= state.currentHolderId then return false, "NOT_HOLDER" end
        if intent.targetId == actorId then return false, "SELF_TARGET" end
        if intent.targetId == state.previousHolderId then return false, "RETURN_FORBIDDEN" end
        local target = findPlayer(state, intent.targetId)
        if not target then return false, "INVALID_TARGET" end
        if not player.connected or not target.connected then return false, "DISCONNECTED" end
        local chosen
        for _, slot in ipairs(target.slots) do if slot.id == intent.slotId then chosen = slot; break end end
        if not chosen then return false, "INVALID_SLOT" end
        if chosen.revealed then return false, "SLOT_REVEALED" end
        chosen.revealed = true
        state.previousHolderId, state.currentHolderId = actorId, target.id
        state.cuts = state.cuts + 1
        if chosen.face == "DEFUSE" then state.defused = state.defused + 1 end
        state.history[#state.history + 1] = {
            round = state.round, actorId = actorId, targetId = target.id, slotId = chosen.id,
            face = chosen.face, revision = state.revision + 1,
        }
        -- Immediate effects precede both the round boundary and fourth-round exhaustion.
        if chosen.face == "BOMB" then
            state.phase, state.winner, state.cause = "GAME_OVER", "SABOTEUR", "BOMB"
        elseif state.defused == state.playerCount then
            state.phase, state.winner, state.cause = "GAME_OVER", "DEFUSER", "DEFUSED"
        elseif state.cuts == state.playerCount then
            if state.round == 4 then
                state.phase, state.winner, state.cause = "GAME_OVER", "SABOTEUR", "TIMEOUT"
            else state.phase = "BETWEEN_ROUNDS" end
        end
    elseif kind == "NEXT" then
        if actorId ~= state.hostId then return false, "HOST_ONLY" end
        if state.phase ~= "BETWEEN_ROUNDS" then return false, "WRONG_PHASE" end
        for _, participant in ipairs(state.players) do if not participant.connected then return false, "DISCONNECTED" end end
        local deck = {}
        for _, participant in ipairs(state.players) do
            for _, slot in ipairs(participant.slots) do if not slot.revealed then deck[#deck + 1] = slot.face end end
        end
        local rng = ns.Util.RNG(state.rngState)
        state.round, state.cuts = state.round + 1, 0
        freshHands(state, deck, rng)
    elseif kind == "CANCEL" then
        if actorId ~= state.hostId then return false, "HOST_ONLY" end
        if state.phase == "GAME_OVER" then return false, "WRONG_PHASE" end
        state.phase, state.cancelled, state.cause = "GAME_OVER", true, "CANCELLED"
        state.winner, state.discardedRole, state.acks = nil, nil, nil
        state.suspended, state.recovering = nil, nil
        for _, participant in ipairs(state.players) do participant.role, participant.slots = nil, nil end
    elseif kind == "REMATCH" then
        if actorId ~= state.hostId then return false, "HOST_ONLY" end
        if state.phase ~= "GAME_OVER" then return false, "WRONG_PHASE" end
        local nextId = intent.newGameId or ns.Util.Token("g")
        if not identifier(nextId) or nextId == state.gameId then return false, "INVALID_GAME_ID" end
        state.gameId = nextId
        state.phase, state.round, state.cuts, state.defused = "LOBBY", 0, 0, 0
        state.currentHolderId, state.previousHolderId, state.initialHolderId = nil, nil, nil
        state.cancelled, state.winner, state.cause, state.discardedRole = nil, nil, nil, nil
        state.suspended, state.recovering, state.acks, state.history = nil, nil, nil, {}
        for _, participant in ipairs(state.players) do
            participant.role, participant.slots, participant.ready = nil, nil, false
        end
    else return false, "UNKNOWN_INTENT" end
    return true
end

function Engine.Apply(state, actorId, intent)
    local valid = Engine.Validate(state)
    if not valid then return false, "INVALID_STATE" end
    if type(intent) ~= "table" or getmetatable(intent) or type(intent.kind) ~= "string" or not identifier(actorId) then
        return false, "INVALID_REQUEST"
    end
    -- Commit only after every rule and invariant succeeds. A malformed request,
    -- stale click or forbidden return cannot advance either RNG or revision.
    local candidate = ns.Util.Copy(state)
    local accepted, code = transition(candidate, actorId, intent)
    if not accepted then return false, code end
    candidate.revision = candidate.revision + 1
    local consistent = Engine.Validate(candidate)
    if not consistent then return false, "INVALID_STATE" end
    for key in pairs(state) do state[key] = nil end
    for key, value in pairs(candidate) do state[key] = value end
    local event = {
        kind = intent.kind, actorId = actorId, revision = state.revision, round = state.round,
        phase = state.phase, currentHolderId = state.currentHolderId, previousHolderId = state.previousHolderId,
        winner = state.winner, cause = state.cause,
    }
    if intent.kind == "CUT" then
        local record = state.history[#state.history]
        event.targetId, event.slotId, event.face = record.targetId, record.slotId, record.face
    end
    return true, event
end

function Engine.GetViewForPlayer(state, playerId)
    if not findPlayer(state, playerId) then return nil, "NOT_MEMBER" end
    local view = {
        sessionId = state.sessionId, gameId = state.gameId, hostId = state.hostId, tableName = state.tableName,
        phase = state.phase, revision = state.revision, round = state.round, cuts = state.cuts,
        defused = state.defused, playerCount = #state.players, currentHolderId = state.currentHolderId,
        previousHolderId = state.previousHolderId, suspended = state.suspended, recovering = state.recovering,
        cancelled = state.cancelled, winner = state.winner, cause = state.cause, players = {}, history = {},
    }
    local exposeRoles = state.phase == "GAME_OVER" and not state.cancelled
    for _, player in ipairs(state.players) do
        local total, composition = remaining(player)
        local public = {
            id = player.id, name = player.name, ready = player.ready, connected = player.connected,
            remaining = total, slots = {},
        }
        for _, slot in ipairs(player.slots or {}) do
            local projected = { id = slot.id, revealed = slot.revealed }
            if slot.revealed then projected.face = slot.face end
            public.slots[#public.slots + 1] = projected
        end
        if exposeRoles then public.role = player.role end
        view.players[#view.players + 1] = public
        if player.id == playerId and player.role then
            view.private = { role = player.role, counts = composition, round = state.round, gameId = state.gameId }
        end
    end
    for _, record in ipairs(state.history) do
        view.history[#view.history + 1] = {
            round = record.round, actorId = record.actorId, targetId = record.targetId,
            slotId = record.slotId, face = record.face, revision = record.revision,
        }
    end
    if exposeRoles then view.discardedRole = state.discardedRole end
    return view
end
