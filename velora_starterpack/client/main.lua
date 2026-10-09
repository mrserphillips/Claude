--[[
    Velora City — Starter Pack (client)

    No permanent loops: the only loop is the bounded readiness wait that runs
    between "character loaded" and "menu opened", and it exits on success,
    timeout, logout or resource stop. The client never decides rewards; it
    only sends the chosen path key and the server-issued session token.
]]

local RESOURCE = GetCurrentResourceName()

local cfg               -- client-safe config from the server
local uiOpen = false
local claimInFlight = false
local autoOpenGen = 0   -- incrementing cancels any pending auto-open wait

-- Appearance / clothing tracking (so we never interrupt it).
local appearance = {
    started = false,    -- a first-character appearance menu was announced
    startedAt = 0,
    seenFocus = false,  -- NUI focus was observed after it was announced
    finishedAt = 0,
}

local function dbg(msg, ...)
    if cfg and cfg.debug then
        print(('[%s] %s'):format(RESOURCE, msg:format(...)))
    end
end

local function loadConfig()
    if cfg then return cfg end
    local ok, result = pcall(lib.callback.await, 'velora_starterpack:server:getClientConfig', false)
    if ok and type(result) == 'table' then
        cfg = result
    end
    return cfg
end

---------------------------------------------------------------------------
-- NUI focus handling
---------------------------------------------------------------------------
local function releaseFocus()
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
end

local function closeUI(tellServer)
    local wasOpen = uiOpen
    uiOpen = false
    SendNUIMessage({ action = 'close' })
    releaseFocus()
    if wasOpen and tellServer then
        TriggerServerEvent('velora_starterpack:server:closed')
    end
end

local function openUI(payload)
    if type(payload) ~= 'table' then return end
    autoOpenGen += 1 -- cancel any pending auto-open
    uiOpen = true
    SendNUIMessage({ action = 'open', data = payload })
    SetNuiFocus(true, true)
    SetNuiFocusKeepInput(false)
    dbg('UI opened')
end

---------------------------------------------------------------------------
-- Readiness: never interrupt multicharacter, spawn or appearance menus
---------------------------------------------------------------------------
local function isSafeToOpen()
    if not LocalPlayer.state.isLoggedIn then return false, 'not logged in' end
    if not IsScreenFadedIn() then return false, 'screen not faded in' end
    if GetIsLoadingScreenActive() then return false, 'loading screen' end
    if IsPlayerSwitchInProgress() then return false, 'player switch' end
    if IsPauseMenuActive() then return false, 'pause menu' end
    if IsCutsceneActive() then return false, 'cutscene' end

    -- Another resource's UI (multicharacter, appearance/clothing, phone…) has focus.
    if IsNuiFocused() then
        if appearance.started then appearance.seenFocus = true end
        return false, 'nui focused'
    end

    local ped = PlayerPedId()
    if not DoesEntityExist(ped) or IsEntityDead(ped) or not IsEntityVisible(ped) then
        return false, 'ped not ready'
    end

    local now = GetGameTimer()

    -- A first-character appearance menu was announced but hasn't shown yet:
    -- give it up to 20s to grab focus before we assume there is none.
    if appearance.started and not appearance.seenFocus and now - appearance.startedAt < 20000 then
        return false, 'waiting for appearance menu'
    end

    if appearance.finishedAt > 0 and now - appearance.finishedAt < (cfg.autoOpen.afterAppearanceDelay or 0) then
        return false, 'appearance just closed'
    end

    return true
end

local function waitUntilSafe(gen, maxWait)
    local ac = cfg.autoOpen
    local start = GetGameTimer()
    local stableSince

    while gen == autoOpenGen do
        local now = GetGameTimer()
        if now - start > maxWait then
            dbg('Gave up waiting for a safe moment to open')
            return false
        end

        local ok, why = isSafeToOpen()
        if ok then
            stableSince = stableSince or now
            if now - stableSince >= ac.stableFor then return true end
        else
            if stableSince then dbg('Readiness reset: %s', why) end
            stableSince = nil
        end

        Wait(ac.checkInterval)
    end

    return false
end

local function scheduleAutoOpen()
    if not loadConfig() then return end
    if not cfg.enabled or not cfg.autoOpen.enabled then return end

    autoOpenGen += 1
    local gen = autoOpenGen

    CreateThread(function()
        Wait(cfg.autoOpen.delay)
        if gen ~= autoOpenGen or uiOpen then return end

        if not waitUntilSafe(gen, cfg.autoOpen.maxWait) then return end
        if gen ~= autoOpenGen or uiOpen then return end

        local ok, payload = pcall(lib.callback.await, 'velora_starterpack:server:requestOpen', false, true)
        if not ok or not payload then
            dbg('Not eligible for auto-open (already claimed or disabled)')
            return
        end

        -- Final check in case something opened while we were asking the server.
        if gen ~= autoOpenGen or uiOpen or IsNuiFocused() then
            if gen == autoOpenGen and not uiOpen then
                -- Something grabbed focus at the last moment; try again shortly.
                SetTimeout(3000, scheduleAutoOpen)
            end
            return
        end

        openUI(payload)
    end)
end

local function cancelAutoOpen()
    autoOpenGen += 1
end

local function resetAppearance()
    appearance.started = false
    appearance.startedAt = 0
    appearance.seenFocus = false
    appearance.finishedAt = 0
end

---------------------------------------------------------------------------
-- Server → client open (from /starterpack or /startergive)
---------------------------------------------------------------------------
RegisterNetEvent('velora_starterpack:client:open', function(payload)
    if GetInvokingResource() then return end -- only accept from the server
    if not loadConfig() then return end

    if uiOpen then
        openUI(payload) -- refresh with the new session token
        return
    end

    -- If another UI (e.g. appearance) currently has focus, wait for it to close.
    if IsNuiFocused() then
        cancelAutoOpen()
        local gen = autoOpenGen
        CreateThread(function()
            local start = GetGameTimer()
            while IsNuiFocused() and gen == autoOpenGen and GetGameTimer() - start < 120000 do
                Wait(500)
            end
            if gen == autoOpenGen and not uiOpen and not IsNuiFocused() and LocalPlayer.state.isLoggedIn then
                openUI(payload)
            end
        end)
        return
    end

    openUI(payload)
end)

---------------------------------------------------------------------------
-- NUI callbacks
---------------------------------------------------------------------------
RegisterNUICallback('claim', function(data, cb)
    if claimInFlight then
        cb({ ok = false, error = 'busy' })
        return
    end

    if type(data) ~= 'table' or type(data.path) ~= 'string' or type(data.token) ~= 'string' then
        cb({ ok = false, error = 'invalid' })
        return
    end

    claimInFlight = true
    -- Only the path key and server token are sent. Rewards are decided server-side.
    local ok, result = pcall(lib.callback.await, 'velora_starterpack:server:claim', false, {
        path = data.path,
        token = data.token,
    })
    claimInFlight = false

    if not ok or type(result) ~= 'table' then
        result = { ok = false, error = 'no_response', message = 'The server did not respond. Please try again.' }
    end

    if result.message then
        lib.notify({
            title = 'Velora City',
            description = result.message,
            type = result.ok and (result.needsReview and 'warning' or 'success') or 'error',
        })
    end

    cb(result)
end)

RegisterNUICallback('close', function(_, cb)
    if claimInFlight then
        cb({ ok = false })
        return
    end
    closeUI(true)
    cb({ ok = true })
end)

-- Safety net: the UI reports it has hidden itself (e.g. after an error).
RegisterNUICallback('hidden', function(_, cb)
    if uiOpen and not claimInFlight then
        closeUI(true)
    end
    cb({ ok = true })
end)

---------------------------------------------------------------------------
-- Qbox lifecycle
---------------------------------------------------------------------------
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    scheduleAutoOpen()
end)

local function onLogout()
    cancelAutoOpen()
    resetAppearance()
    if uiOpen then closeUI(false) end
end

RegisterNetEvent('QBCore:Client:OnPlayerUnload', onLogout)
RegisterNetEvent('qbx_core:client:playerLoggedOut', onLogout)

AddEventHandler('velora_starterpack:client:appearanceFinished', function()
    appearance.finishedAt = GetGameTimer()
end)

---------------------------------------------------------------------------
-- Exports
---------------------------------------------------------------------------
-- Lets another resource (e.g. your appearance or spawn script) open the menu
-- if the current character is still eligible. Returns true if it opened.
exports('OpenIfEligible', function()
    if uiOpen then return true end
    local ok, payload = pcall(lib.callback.await, 'velora_starterpack:server:requestOpen', false, false)
    if ok and payload and not IsNuiFocused() then
        openUI(payload)
        return true
    end
    return false
end)

exports('IsOpen', function()
    return uiOpen
end)

---------------------------------------------------------------------------
-- Start / stop
---------------------------------------------------------------------------
CreateThread(function()
    -- Always begin with a clean focus state.
    releaseFocus()

    if not loadConfig() then
        print(('^1[%s] Could not load configuration from the server.^7'):format(RESOURCE))
        return
    end

    for _, name in ipairs(cfg.autoOpen.appearanceStartEvents or {}) do
        AddEventHandler(name, function()
            appearance.started = true
            appearance.startedAt = GetGameTimer()
            appearance.seenFocus = false
            dbg('Appearance menu announced via %s', name)
        end)
    end

    for _, name in ipairs(cfg.autoOpen.appearanceFinishEvents or {}) do
        AddEventHandler(name, function()
            appearance.finishedAt = GetGameTimer()
        end)
    end

    if cfg.command and cfg.command.enabled then
        TriggerEvent('chat:addSuggestion', '/' .. cfg.command.name, 'Open the Velora City starter pack menu')
    end
    local admin = cfg.admin.commands
    TriggerEvent('chat:addSuggestion', '/' .. admin.check, 'Admin: check a player\'s starter pack', { { name = 'id', help = 'Server ID or citizenid' } })
    TriggerEvent('chat:addSuggestion', '/' .. admin.reset, 'Admin: reset starter pack eligibility', { { name = 'id', help = 'Server ID or citizenid' }, { name = 'confirm', help = 'Type "confirm" to proceed' } })
    TriggerEvent('chat:addSuggestion', '/' .. admin.give, 'Admin: open the starter pack menu for a player', { { name = 'id', help = 'Server ID' } })

    if cfg.autoOpen.onResourceRestart and LocalPlayer.state.isLoggedIn then
        scheduleAutoOpen()
    end
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= RESOURCE then return end
    cancelAutoOpen()
    if uiOpen then
        SendNUIMessage({ action = 'close' })
    end
    releaseFocus()
end)
