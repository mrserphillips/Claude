-- Finds every audio file in html/music/ so tracks never need listing in the config.
local SUPPORTED = { ogg = true, mp3 = true, wav = true, webm = true, opus = true, flac = true }
local UNSUPPORTED = { m4a = true, aac = true, wma = true, mp4 = true, m4b = true }

local resource = GetCurrentResourceName()
local musicDir = GetResourcePath(resource) .. '/html/music'
local tracks = {}

local function log(msg, ...)
    print(('^5[sp_parkmusic]^7 ' .. msg):format(...))
end

local function listFolder()
    local isWindows = package.config:sub(1, 1) == '\\'
    local cmd = isWindows
        and ('dir "' .. musicDir:gsub('/', '\\') .. '" /b /a-d 2>nul')
        or ('ls -1 "' .. musicDir .. '" 2>/dev/null')

    local ok, pipe = pcall(io.popen, cmd)
    if not ok or not pipe then
        log('^1Could not read the music folder (your host blocks folder listing: %s).^7', tostring(pipe))
        return nil
    end

    local names = {}
    for line in pipe:lines() do
        local name = line:gsub('[\r\n]', '')
        if name ~= '' then names[#names + 1] = name end
    end
    pipe:close()
    return names
end

local function buildPlaylist()
    local found = {}

    -- Manual list in config.lua always works, even where folder listing is blocked.
    for _, name in ipairs(Config.Tracks or {}) do found[#found + 1] = name end

    if #found == 0 then
        local names = listFolder()
        if names then
            for _, name in ipairs(names) do
                local ext = (name:match('%.([^%.]+)$') or ''):lower()
                if SUPPORTED[ext] then
                    found[#found + 1] = name
                elseif UNSUPPORTED[ext] then
                    log('^3Skipping "%s": .%s files can\'t play in-game. Convert it to .mp3 or .ogg.^7', name, ext)
                elseif name ~= '.gitkeep' then
                    log('^3Skipping "%s": not an audio file (folders inside music/ are not scanned).^7', name)
                end
            end
        end
    end

    table.sort(found, function(a, b) return a:lower() < b:lower() end)
    return found
end

-- Scan straight away (not in a thread) so the list is ready before any player asks for it.
tracks = buildPlaylist()
log('Music folder: %s', musicDir)
if #tracks > 0 then
    log('^2%d track(s) will play on loop:^7 %s', #tracks, table.concat(tracks, ', '))
else
    log('^3No playable music found - using generated ambient music instead.^7')
end

RegisterNetEvent('sp_parkmusic:requestTracks', function()
    TriggerClientEvent('sp_parkmusic:tracks', source, tracks)
end)

-- Rescan without restarting (server console or admin). New files still need
-- "restart sp_parkmusic" before players can download them.
RegisterCommand('parkmusic_scan', function(src)
    tracks = buildPlaylist()
    log('Rescanned: %d track(s): %s', #tracks, table.concat(tracks, ', '))
    TriggerClientEvent('sp_parkmusic:tracks', -1, tracks)
end, true)
