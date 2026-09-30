-- Finds every audio file in html/music/ so tracks never need listing in the config.
local EXTENSIONS = { ogg = true, mp3 = true, wav = true, webm = true }
local tracks = {}

local function scanMusicFolder()
    local dir = GetResourcePath(GetCurrentResourceName()) .. '/html/music'
    local isWindows = package.config:sub(1, 1) == '\\'
    local cmd = isWindows
        and ('dir "' .. dir:gsub('/', '\\') .. '" /b /a-d 2>nul')
        or ('ls -1 "' .. dir .. '" 2>/dev/null')

    local found = {}
    local pipe = io.popen(cmd)
    if pipe then
        for name in pipe:lines() do
            name = name:gsub('[\r\n]', '')
            local ext = name:match('%.([^%.]+)$')
            if ext and EXTENSIONS[ext:lower()] then found[#found + 1] = name end
        end
        pipe:close()
    end
    table.sort(found, function(a, b) return a:lower() < b:lower() end)
    return found
end

CreateThread(function()
    tracks = scanMusicFolder()
    if #tracks > 0 then
        print(('[sp_parkmusic] %d track(s) found in html/music/: %s'):format(#tracks, table.concat(tracks, ', ')))
    else
        print('[sp_parkmusic] html/music/ is empty - using generated ambient music')
    end
end)

RegisterNetEvent('sp_parkmusic:requestTracks', function()
    TriggerClientEvent('sp_parkmusic:tracks', source, tracks)
end)
