local ADDON, ns = ...
ns.VERSION, ns.PROTOCOL, ns.RULESET = '1.0.0', 1, 'TB_RP_NO_RETURN_V1'
ns.Util = {}
local U = ns.Util
function U.Copy(value, seen)
    if type(value) ~= 'table' then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local out = {}; seen[value] = out
    for k, v in pairs(value) do out[U.Copy(k, seen)] = U.Copy(v, seen) end
    return out
end
function U.Count(t) local n=0; for _ in pairs(t or {}) do n=n+1 end; return n end
function U.Clean(value, limit)
    if type(value) ~= 'string' then return '' end
    local s = value:gsub('|', ''):gsub('[%z\1-\31\127]', '')
    limit = limit or 96
    if #s <= limit then return s end
    local cut = limit
    -- Do not split a UTF-8 sequence when trimming received display names.
    while cut > 0 and s:byte(cut+1) and s:byte(cut+1) >= 128 and s:byte(cut+1) < 192 do cut=cut-1 end
    return s:sub(1,cut)
end
local upperToLower = {['À']='à',['Â']='â',['Ä']='ä',['Æ']='æ',['Ç']='ç',['É']='é',['È']='è',['Ê']='ê',['Ë']='ë',['Î']='î',['Ï']='ï',['Ô']='ô',['Ö']='ö',['Œ']='œ',['Ù']='ù',['Û']='û',['Ü']='ü',['Ÿ']='ÿ',['Ñ']='ñ',['Á']='á',['Í']='í',['Ó']='ó',['Ú']='ú',['Å']='å',['Ø']='ø'}
local function lowerName(s)
    s=s:lower()
    for upper,lower in pairs(upperToLower) do s=s:gsub(upper,lower) end
    return s
end
function U.Name(name, realm)
    if type(name) ~= 'string' then return nil end
    name=name:match('^%s*(.-)%s*$')
    if #name==0 or #name>160 or name:find('[%z\1-\31\127|]') then return nil end
    local character, server=name:match('^([^%-]+)%-(.+)$')
    if not character then character=name; server=realm end
    if character:find('%s') or type(server)~='string' or server=='' then return nil end
    server=server:gsub('%s','')
    if server=='' or server:find('[%z\1-\31\127|]') then return nil end
    -- Real names are case-insensitive addresses. Preserve the familiar character
    -- capitalization, canonicalize the realm to avoid mismatching typed invites
    -- against server-supplied sender casing (including French accented names).
    character=lowerName(character)
    local first=character:match('^([%z\1-\127\194-\244][\128-\191]*)')
    if first then
        local capital=first:upper()
        for upper,lower in pairs(upperToLower) do if lower==first then capital=upper;break end end
        character=capital..character:sub(#first+1)
    end
    return character..'-'..lowerName(server)
end

function U.RNG(seed)
    local r={state=math.floor(tonumber(seed) or 1)%2147483647}
    if r.state<1 then r.state=1 end
    function r:Int(n)
        assert(type(n)=='number' and n>=1 and n==math.floor(n), 'invalid random range')
        self.state=(self.state*16807)%2147483647
        return (self.state % n)+1
    end
    function r:Shuffle(values)
        for i=#values,2,-1 do local j=self:Int(i); values[i],values[j]=values[j],values[i] end
        return values
    end
    return r
end
local counter, tokenRandom = 0, U.RNG(7919)
function U.SeedTokens(seed) tokenRandom=U.RNG(seed) end
function U.Token(prefix)
    counter=counter+1
    -- Independent of the deck generator. Tokens encode no face or permutation.
    return (prefix or 't')..string.format('%x%x%x',tokenRandom:Int(2147483646),counter,tokenRandom:Int(2147483646))
end
