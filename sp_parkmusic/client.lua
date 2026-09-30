local enabled = GetResourceKvpInt('sp_parkmusic_off') ~= 1
local loaded = false
local lastVolume = -1.0
local pendingFadeMs = nil
local nuiReady = false
local tracks = nil
local status = 'starting up'

local function send(data)
    SendNUIMessage(data)
end

local function log(msg, ...)
    print(('[sp_parkmusic] ' .. msg):format(...))
end

-- Accept names written as 'song.mp3', 'music/song.mp3' or 'html/music/song.mp3'.
local function cleanName(name)
    name = tostring(name):gsub('\\', '/')
    name = name:gsub('^%.?/?html/music/', ''):gsub('^music/', '')
    return name
end

-- Only hand the playlist to the page once both the page and the playlist are ready,
-- otherwise the message can be lost while the page is still loading.
local function sendInit()
    if not nuiReady or not tracks then return end
    send({ action = 'init', tracks = tracks, shuffle = Config.Shuffle, generated = Config.GeneratedMusic })
    lastVolume = -1.0 -- resend the current volume to the fresh page
end

local function setTracks(list, from)
    tracks = {}
    for _, name in ipairs(list or {}) do tracks[#tracks + 1] = cleanName(name) end
    if #tracks > 0 then
        log('%d track(s) from %s: %s', #tracks, from, table.concat(tracks, ', '))
    else
        log('No tracks found (%s). %s', from,
            Config.GeneratedMusic and 'Playing generated ambient music.' or 'Music stays silent.')
    end
    sendInit()
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
    if Config.Tracks and #Config.Tracks > 0 then
        setTracks(Config.Tracks, 'Config.Tracks') -- no server round trip needed
    else
        TriggerServerEvent('sp_parkmusic:requestTracks')
    end

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

RegisterNetEvent('sp_parkmusic:tracks', function(list)
    if Config.Tracks and #Config.Tracks > 0 then return end
    setTracks(list, 'the html/music folder')
end)

RegisterNUICallback('ready', function(_, cb)
    nuiReady = true
    sendInit()
    cb('ok')
end)

-- The page reports what it is actually playing (or why a file failed) so it shows in F8.
RegisterNUICallback('status', function(data, cb)
    status = data.message or status
    log(status)
    cb('ok')
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

RegisterCommand(Config.Command .. '_status', function()
    log('version %s | enabled: %s | loaded in: %s | volume: %.2f | tracks: %s | %s',
        GetResourceMetadata(GetCurrentResourceName(), 'version', 0), tostring(enabled), tostring(loaded),
        math.max(lastVolume, 0.0), tracks and table.concat(tracks, ', ') or 'waiting', status)
end, false)

TriggerEvent('chat:addSuggestion', '/' .. Config.Command, 'Toggle the Legion Square park music')
TriggerEvent('chat:addSuggestion', '/' .. Config.Command .. '_status', 'Show park music status in F8')
