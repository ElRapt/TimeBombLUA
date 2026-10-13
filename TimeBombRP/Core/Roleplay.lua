local ADDON, ns = ...
local U = ns.Util
local RP = {}; ns.Roleplay = RP

-- Display-only adapter. Network identities always remain canonical Name-Realm.
local function plain(value)
    if type(value) ~= 'string' then return '' end
    value = value:gsub('|c%x%x%x%x%x%x%x%x', ''):gsub('|cn[^:]+:', ''):gsub('|r', '')
        :gsub('|T.-|t', ''):gsub('|A.-|a', ''):gsub('|H.-|h(.-)|h', '%1')
    return U.Clean(value, 80):match('^%s*(.-)%s*$')
end

function RP:Invalidate() self.identities = nil end

function RP:Name(id, fallback, demo)
    fallback = plain(fallback or id)
    if fallback==id then fallback=fallback:match('^[^-]+') or fallback end
    if demo or type(id) ~= 'string' then return fallback end
    local api = TRP3_API
    local register = api and api.register
    if not register or type(register.getUnitRPNameWithID) ~= 'function' then return fallback end
    local canonical = U.Name(id)
    if not canonical then return fallback end
    local unitID = api.globals and api.globals.player_id
    if unitID and U.Name(unitID) == canonical then
        local getter=api.profile and api.profile.getPlayerCurrentProfile
        local profile=type(getter)=='function' and getter()
        if not profile or not profile.player then return fallback end
    else
        local list = type(register.getCharacterList) == 'function' and register.getCharacterList()
        if type(list)~='table' then return fallback end
        if not self.identities then
            self.identities = {}
            for key in pairs(list) do
                local normalized = U.Name(key)
                if normalized then self.identities[normalized] = key end
            end
        end
        unitID = self.identities[canonical] or id
    end
    local name = plain(register.getUnitRPNameWithID(unitID, fallback))
    return name ~= '' and name or fallback
end

function RP:Connect(onChange)
    if self.connected then return end
    local api, addon = TRP3_API, TRP3_Addon
    if not api or type(api.RegisterCallback) ~= 'function' or not addon or not addon.Events then return end
    local function refresh()
        self:Invalidate()
        onChange()
    end
    for _,event in ipairs({'REGISTER_DATA_UPDATED', 'REGISTER_PROFILES_LOADED', 'WORKFLOW_ON_LOADED'}) do
        if addon.Events[event] then api.RegisterCallback(addon, addon.Events[event], refresh) end
    end
    self.connected = true
end
