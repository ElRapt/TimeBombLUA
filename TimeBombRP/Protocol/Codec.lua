local ADDON, ns = ...
local Codec = {}
ns.Codec = Codec
local MAX_BYTES, MAX_DEPTH, MAX_ITEMS, MAX_STRING = 32768, 12, 2048, 4096
-- Stable protocol vocabulary saves the small-envelope overhead on WoW's narrow
-- addon channel. Codes are local constants, never remotely supplied dictionaries.
local vocabulary={"v","version","ruleset","kind","sessionId","gameId","round","revision","requestId","payload",
    "view","hostId","tableName","phase","cuts","defused","playerCount","currentHolderId","previousHolderId","suspended",
    "recovering","cancelled","winner","cause","players","history","private","id","name","ready","connected","remaining",
    "slots","revealed","face","role","counts","SAFE","DEFUSE","BOMB","DEFUSER","SABOTEUR","nonce","knownRevision",
    "knownGameId","baseRevision","changes","path","value","remove","ok","code","targetId","slotId","actorId","status",
    "SNAPSHOT","PATCH","INTENT","RESULT","HEARTBEAT","PONG","RESYNC","ACK","READY","JOIN","JOINED","JOIN_ACK",
    "INVITE","INVITE_SEEN","LOBBY","PREPARING","ACTIVE","BETWEEN_ROUNDS","GAME_OVER","TB_RP_NO_RETURN_V1","1.0.0","OK"}
local symbols,words={},{}
for i,word in ipairs(vocabulary) do local code=string.char(i+32); symbols[word]=code; words[code]=word end
local function integer(n)
    return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge and n % 1 == 0 and math.abs(n) <= 9007199254740991
end

-- A bounded length-prefixed grammar, with packet-local string references. No
-- evaluation, metatables, object hooks, or executable deserialization is used.
function Codec.Encode(value)
    local out, bytes, items, seen, strings, stringCount = {}, 0, 0, {}, {}, 0
    local function put(s)
        bytes = bytes + #s
        if bytes > MAX_BYTES then error("SIZE", 0) end
        out[#out + 1] = s
    end
    local function write(v, depth)
        items = items + 1
        if items > MAX_ITEMS then error("ITEMS", 0) end
        if depth > MAX_DEPTH then error("DEPTH", 0) end
        local t = type(v)
        if t == "nil" then put("z")
        elseif t == "boolean" then put(v and "t" or "f")
        elseif t == "number" then
            if not integer(v) then error("NUMBER", 0) end
            put("i" .. string.format("%.0f", v) .. ":")
        elseif t == "string" then
            if #v > MAX_STRING then error("STRING", 0) end
            if symbols[v] then put("k"..symbols[v])
            elseif strings[v] then put("r" .. strings[v] .. ":")
            else
                stringCount = stringCount + 1; strings[v] = stringCount
                put("s" .. #v .. ":" .. v)
            end
        elseif t == "table" then
            if getmetatable(v) or seen[v] then error("TABLE", 0) end
            seen[v] = true
            local keys = {}
            for k in pairs(v) do
                if type(k) ~= "string" and not integer(k) then error("KEY", 0) end
                keys[#keys + 1] = k
                if #keys > MAX_ITEMS then error("ITEMS", 0) end
            end
            table.sort(keys, function(a, b)
                if type(a) ~= type(b) then return type(a) < type(b) end
                return a < b
            end)
            put("m" .. #keys .. ":")
            for _, k in ipairs(keys) do write(k, depth + 1); write(v[k], depth + 1) end
            seen[v] = nil
        else error("TYPE", 0) end
    end
    local ok, err = pcall(write, value, 0)
    if not ok then return nil, err end
    return table.concat(out)
end

function Codec.Decode(data)
    if type(data) ~= "string" or #data > MAX_BYTES then return nil, "SIZE" end
    local pos, items, strings = 1, 0, {}
    local function count(signed)
        local stop = data:find(":", pos, true)
        if not stop or stop - pos > 17 then error("LENGTH", 0) end
        local text = data:sub(pos, stop - 1)
        if not text:match(signed and "^%-?%d+$" or "^%d+$") then error("NUMBER", 0) end
        local n = tonumber(text)
        if not integer(n) then error("NUMBER", 0) end
        pos = stop + 1
        return n
    end
    local function read(depth)
        items = items + 1
        if items > MAX_ITEMS then error("ITEMS", 0) end
        if depth > MAX_DEPTH then error("DEPTH", 0) end
        local kind = data:sub(pos, pos); pos = pos + 1
        if kind == "z" then return nil
        elseif kind == "t" then return true
        elseif kind == "f" then return false
        elseif kind == "i" then return count(true)
        elseif kind == "k" then
            local word=words[data:sub(pos,pos)]; pos=pos+1
            if not word then error("VOCABULARY",0) end
            return word
        elseif kind == "s" then
            local n = count(false)
            if n > MAX_STRING or pos + n - 1 > #data then error("STRING", 0) end
            local s = data:sub(pos, pos + n - 1); pos = pos + n
            strings[#strings + 1] = s
            return s
        elseif kind == "r" then
            local n = count(false)
            if n < 1 or not strings[n] then error("REFERENCE", 0) end
            return strings[n]
        elseif kind == "m" then
            local n, value = count(false), {}
            if n > MAX_ITEMS then error("ITEMS", 0) end
            for _ = 1, n do
                local k, v = read(depth + 1), read(depth + 1)
                if type(k) ~= "string" and not integer(k) then error("KEY", 0) end
                if value[k] ~= nil or v == nil then error("DUPLICATE_OR_NIL", 0) end
                value[k] = v
            end
            return value
        end
        error("TAG", 0)
    end
    local ok, value = pcall(read, 0)
    if not ok then return nil, value end
    if pos ~= #data + 1 then return nil, "TRAILING" end
    return value
end
