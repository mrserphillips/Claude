local enabled = GetResourceKvpInt('sp_parkmusic_off') ~= 1
local loaded = false
local lastVolume = -1.0
local pendingFadeMs = nil

local function send(data)
    SendNUIMessage(data)
end

local function targetVolume()
    if not enabled or not loaded then return 0.0 end

    local ped = PlayerPedId()
    if Config.MuteInVehicle and IsPedInAnyVehicle(ped, false) then return 0.0 end

    local dist = #(GetEntityCoords(ped) - Config.Center)
    if dist <= Config.FullVolumeRadius then return Config.Volume end
    if dist >= Config.FadeOutRadius then return 0.0 end

    local t = (dist - Config.FullVolumeRadius) / (Config.FadeOutRadius - Config.FullVolumeRadius)
    return Config.Volume * (1.0 - t) ^ 2 -- ease off so it drifts away softly
end

local function onSpawned()
    loaded = true
    lastVolume = -1.0
    pendingFadeMs = Config.SpawnFadeInMs -- next volume change uses the slow spawn fade
end

CreateThread(function()
    while not NetworkIsSessionStarted() do Wait(250) end
    TriggerServerEvent('sp_parkmusic:requestTracks')

    -- Resource restarted while already in game.
    if LocalPlayer.state.isLoggedIn then onSpawned() end

    while true do
        local vol = targetVolume()
        if math.abs(vol - lastVolume) > 0.005 then
            send({ action = 'volume', volume = vol, fadeMs = pendingFadeMs or Config.FadeMs })
            pendingFadeMs = nil
            lastVolume = vol
        end
        Wait(Config.CheckIntervalMs)
    end
end)

RegisterNetEvent('sp_parkmusic:tracks', function(tracks)
    print(('[sp_parkmusic] %d track(s) received from server'):format(#tracks))
    send({ action = 'init', tracks = tracks, shuffle = Config.Shuffle })
end)

RegisterNetEvent('QBCore:Client:OnPlayerLoaded', onSpawned)
AddEventHandler('playerSpawned', onSpawned)

RegisterNetEvent('QBCore:Client:OnPlayerUnload', function()
    loaded = false
end)

RegisterCommand(Config.Command, function()
    enabled = not enabled
    SetResourceKvpInt('sp_parkmusic_off', enabled and 0 or 1)
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(enabled and 'Park music ~g~on' or 'Park music ~r~off')
    EndTextCommandThefeedPostTicker(false, false)
end, false)

TriggerEvent('chat:addSuggestion', '/' .. Config.Command, 'Toggle the Legion Square park music')
