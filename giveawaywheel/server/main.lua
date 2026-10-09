math.randomseed(GetGameTimer())

-- Entrants[citizenid] = { source = src, name = 'First Last', citizenid = citizenid }
local Entrants = {}
-- Ordered list of citizenids so wheel order is stable and identical for every client
local EntrantOrder = {}
local SpinInProgress = false

-- Different servers grant "admin" through different systems (raw server.cfg aces,
-- qbx_core's own permission list, txAdmin, ...) so this tries all the common ones
-- rather than assuming one. Run /giveawaydebug in-game if this still says no perms.
local function IsAdmin(src)
    -- 1) raw FiveM ace groups, e.g. server.cfg: add_principal identifier.xxx group.admin
    for group in pairs(Config.AdminGroups) do
        if IsPlayerAceAllowed(src, ('group.%s'):format(group)) then
            return true
        end
    end

    -- 2) qbx_core's Player.PlayerData.permission field
    local ok, Player = pcall(function() return exports.qbx_core:GetPlayer(src) end)
    if ok and Player and Player.PlayerData and Config.AdminGroups[Player.PlayerData.permission] then
        return true
    end

    -- 3) qbx_core:HasPermission export (deprecated, but some servers still rely on it)
    for group in pairs(Config.AdminGroups) do
        local okPerm, hasPerm = pcall(function() return exports.qbx_core:HasPermission(src, group) end)
        if okPerm and hasPerm then
            return true
        end
    end

    return false
end

local function GetEntrantList()
    local list = {}
    for _, citizenid in ipairs(EntrantOrder) do
        local entrant = Entrants[citizenid]
        if entrant then
            list[#list + 1] = {
                name = entrant.name,
                id = entrant.source,
            }
        end
    end
    return list
end

local function ClearEntrants()
    Entrants = {}
    EntrantOrder = {}
end

local function RemoveEntrantBySource(src)
    for citizenid, entrant in pairs(Entrants) do
        if entrant.source == src then
            Entrants[citizenid] = nil
            for i, cid in ipairs(EntrantOrder) do
                if cid == citizenid then
                    table.remove(EntrantOrder, i)
                    break
                end
            end
            return
        end
    end
end

RegisterNetEvent('giveaway:server:signup', function()
    local src = source

    if SpinInProgress then
        Config.Notify(src, 'The wheel is currently spinning, try again after.', 'error')
        return
    end

    local Player = exports.qbx_core:GetPlayer(src)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid
    if Entrants[citizenid] then
        Config.Notify(src, 'You are already signed up for the giveaway.', 'error')
        return
    end

    local charName = ('%s %s'):format(Player.PlayerData.charinfo.firstname, Player.PlayerData.charinfo.lastname)

    Entrants[citizenid] = {
        source = src,
        name = charName,
        citizenid = citizenid,
    }
    EntrantOrder[#EntrantOrder + 1] = citizenid

    Config.Notify(src, ('You signed up for the giveaway! (%d entrants)'):format(#EntrantOrder), 'success')
end)

AddEventHandler('playerDropped', function()
    if Config.RemoveOnDisconnect then
        RemoveEntrantBySource(source)
    end
end)

RegisterCommand(Config.Commands.spin, function(src)
    if src == 0 then return end -- must be run in-game, not server console

    if not IsAdmin(src) then
        Config.Notify(src, 'You do not have permission to do that.', 'error')
        return
    end

    if SpinInProgress then
        Config.Notify(src, 'The wheel is already spinning.', 'error')
        return
    end

    local list = GetEntrantList()
    if #list < Config.MinEntrants then
        Config.Notify(src, ('Need at least %d entrants to spin (currently %d).'):format(Config.MinEntrants, #list), 'error')
        return
    end

    SpinInProgress = true

    local winnerIndex = math.random(1, #list) -- 1-based, chosen server-side so it can't be manipulated client-side
    local winner = list[winnerIndex]

    -- broadcast the same entrant list + same winner index to every client so everyone's
    -- wheel spins the same amount and lands on the same name
    TriggerClientEvent('giveaway:client:spin', -1, list, winnerIndex, Config.SpinDurationMs)

    TriggerClientEvent('ox_lib:notify', -1, {
        title = 'Giveaway',
        description = ('The wheel is spinning! %d entrants...'):format(#list),
        type = 'inform',
    })

    SetTimeout(Config.SpinDurationMs + 1000, function()
        SpinInProgress = false
        if Config.ClearAfterSpin then
            ClearEntrants()
        end
        print(('[giveaway] winner: %s (ID: %d)'):format(winner.name, winner.id))
    end)
end, false)

RegisterCommand(Config.Commands.clear, function(src)
    if src == 0 then return end
    if not IsAdmin(src) then
        Config.Notify(src, 'You do not have permission to do that.', 'error')
        return
    end
    ClearEntrants()
    Config.Notify(src, 'Giveaway sign-up list cleared.', 'success')
end, false)

RegisterCommand(Config.Commands.list, function(src)
    if src == 0 then return end
    if not IsAdmin(src) then
        Config.Notify(src, 'You do not have permission to do that.', 'error')
        return
    end

    local list = GetEntrantList()
    if #list == 0 then
        Config.Notify(src, 'No one has signed up yet.', 'inform')
        return
    end

    local names = {}
    for _, e in ipairs(list) do
        names[#names + 1] = ('%s (ID: %d)'):format(e.name, e.id)
    end
    Config.Notify(src, table.concat(names, ', '), 'inform')
end, false)

-- Not permission-gated on purpose: run this yourself to see exactly why IsAdmin()
-- is or isn't granting you access, then report the printed line back if it's wrong.
RegisterCommand('giveawaydebug', function(src)
    if src == 0 then return end

    local aceResults = {}
    for group in pairs(Config.AdminGroups) do
        aceResults[#aceResults + 1] = ('group.%s=%s'):format(group, tostring(IsPlayerAceAllowed(src, 'group.' .. group)))
    end

    local ok, Player = pcall(function() return exports.qbx_core:GetPlayer(src) end)
    local permField = 'n/a'
    if ok and Player and Player.PlayerData then
        permField = tostring(Player.PlayerData.permission)
    end

    local hasPermResults = {}
    for group in pairs(Config.AdminGroups) do
        local okPerm, hasPerm = pcall(function() return exports.qbx_core:HasPermission(src, group) end)
        hasPermResults[#hasPermResults + 1] = ('%s=%s'):format(group, okPerm and tostring(hasPerm) or 'export missing')
    end

    local msg = ('IsAdmin result: %s | ACE: %s | PlayerData.permission: %s | HasPermission: %s')
        :format(tostring(IsAdmin(src)), table.concat(aceResults, ', '), permField, table.concat(hasPermResults, ', '))

    print(('[giveaway debug] src %d -> %s'):format(src, msg))
    Config.Notify(src, msg, 'inform')
end, false)
