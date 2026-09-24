-- installed[plate] = { colour = 'stock' | preset key | '#RRGGBB', pops = true/false }
local installed = {}
local ready = false -- true once the plates have been loaded from the database

local function cleanPlate(p)
    return (p or ''):gsub('^%s*(.-)%s*$', '%1'):upper()
end

local function isMechanic(src)
    local player = exports.qbx_core:GetPlayer(src)
    local job = player and player.PlayerData and player.PlayerData.job
    return job and Config.MechanicJobs[job.name] == true
end

local presetKeys = {}
for _, c in ipairs(Config.FlameColours) do presetKeys[c.key] = true end

local function validColour(colour)
    if type(colour) ~= 'string' then return nil end
    if presetKeys[colour] then return colour end
    if Config.AllowCustomColour and colour:match('^#%x%x%x%x%x%x$') then return colour:upper() end
    return nil
end

local soundKeys, intensityKeys = {}, {}
for _, t in ipairs(Config.SoundTypes) do soundKeys[t.key] = true end
for k in pairs(Config.Intensity) do intensityKeys[k] = true end

local function clamp(v, lo, hi, def)
    v = tonumber(v)
    if not v or v ~= v then return def end
    return math.max(lo, math.min(hi, v))
end

local function bool(v, def)
    if v == nil then return def end
    return v == true
end

-- Every value the panel can change. Anything a client sends goes through here.
local function sanitize(src, base)
    src = type(src) == 'table' and src or {}
    base = base or {}
    local lc, fs = Config.LaunchControl, Config.FlameSize
    return {
        colour = validColour(src.colour) or base.colour or validColour(Config.DefaultFlameColour) or 'stock',
        pops = bool(src.pops, base.pops ~= nil and base.pops or Config.PopsBangs.DefaultOn == true),
        enabled = bool(src.enabled, base.enabled ~= false),
        launch = bool(src.launch, base.launch == true),
        launchRpm = clamp(src.launchRpm, lc.MinRpm, lc.MaxRpm, base.launchRpm or lc.DefaultRpm),
        launchIntensity = intensityKeys[src.launchIntensity] and src.launchIntensity or base.launchIntensity or 'moderate',
        intensity = intensityKeys[src.intensity] and src.intensity or base.intensity or 'moderate',
        sound = soundKeys[src.sound] and src.sound or base.sound or Config.SoundTypes[1].key,
        size = clamp(src.size, fs.Min, fs.Max, base.size or fs.Default),
        popcorn = bool(src.popcorn, base.popcorn == true),
        silent = bool(src.silent, base.silent == true),
        hideFlames = bool(src.hideFlames, base.hideFlames == true),
        gear = bool(src.gear, base.gear ~= nil and base.gear or Config.GearChange.Enabled),
        compat = bool(src.compat, base.compat == true),
    }
end

local function sanitizeHotbar(h)
    local out = {}
    if type(h) ~= 'table' then return out end
    for i = 1, 3 do
        local slot = h[i] or h[tostring(i)]
        if type(slot) == 'table' then out[i] = sanitize(slot) end
    end
    return out
end

local function defaultSettings()
    local s = sanitize({})
    s.hotbar = {}
    return s
end

local function saveRow(plate, s)
    local stored = {}
    for k, v in pairs(s) do stored[k] = v end
    MySQL.update.await('UPDATE sp_antilag SET flame_colour = ?, pops_bangs = ?, settings = ? WHERE plate = ?',
        { s.colour, s.pops and 1 or 0, json.encode(stored), plate })
end

local function columnExists(column)
    local rows = MySQL.query.await([[SELECT 1 FROM information_schema.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'sp_antilag' AND COLUMN_NAME = ?]], { column })
    return rows and #rows > 0
end

CreateThread(function()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS sp_antilag (
        plate VARCHAR(16) NOT NULL PRIMARY KEY
    )]])
    -- V4.4: upgrade older plate-only tables in place.
    if not columnExists('flame_colour') then
        MySQL.query.await("ALTER TABLE sp_antilag ADD COLUMN flame_colour VARCHAR(16) NOT NULL DEFAULT 'stock'")
    end
    if not columnExists('pops_bangs') then
        MySQL.query.await('ALTER TABLE sp_antilag ADD COLUMN pops_bangs TINYINT(1) NOT NULL DEFAULT 1')
    end
    -- V5.0: full panel settings + hotbar presets as JSON.
    if not columnExists('settings') then
        MySQL.query.await('ALTER TABLE sp_antilag ADD COLUMN settings LONGTEXT NULL')
    end

    local rows = MySQL.query.await('SELECT plate, flame_colour, pops_bangs, settings FROM sp_antilag') or {}
    for _, row in ipairs(rows) do
        local stored = row.settings and json.decode(row.settings) or {}
        if type(stored) ~= 'table' then stored = {} end
        if stored.colour == nil then stored.colour = row.flame_colour end
        if stored.pops == nil then stored.pops = row.pops_bangs == 1 or row.pops_bangs == true end
        local settings = sanitize(stored)
        settings.hotbar = sanitizeHotbar(stored.hotbar)
        installed[cleanPlate(row.plate)] = settings
    end
    ready = true
    -- Anyone who asked before loading finished may have cached "not fitted"; make them re-check.
    TriggerClientEvent('sp_antilag:resync', -1)
end)

lib.callback.register('sp_antilag:isInstalled', function(_, plate)
    local untilTime = GetGameTimer() + 15000
    while not ready and GetGameTimer() < untilTime do Wait(100) end
    return installed[cleanPlate(plate)] or false
end)

RegisterNetEvent('sp_antilag:requestInstall', function(plate)
    local src=source
    plate=cleanPlate(plate)
    if not isMechanic(src) then return end
    if plate=='' then return end
    if not ready then
        return TriggerClientEvent('ox_lib:notify',src,{type='error',description='Anti-lag is still loading, try again in a moment.'})
    end
    if installed[plate] then
        TriggerClientEvent('sp_antilag:setInstalled',src,plate,installed[plate])
        return TriggerClientEvent('ox_lib:notify',src,{type='error',description='This vehicle already has anti-lag fitted.'})
    end
    local count=exports.ox_inventory:Search(src,'count',Config.KitItem) or 0
    if count < 1 then
        return TriggerClientEvent('ox_lib:notify',src,{type='error',description='You do not have an anti-lag kit.'})
    end
    TriggerClientEvent('sp_antilag:beginInstall',src,plate)
end)

RegisterNetEvent('sp_antilag:finishInstall', function(netId, expectedPlate)
    local src=source
    if not isMechanic(src) then return end
    local entity=NetworkGetEntityFromNetworkId(netId)
    if entity==0 or not DoesEntityExist(entity) then return end
    local plate=cleanPlate(GetVehicleNumberPlateText(entity))
    expectedPlate=cleanPlate(expectedPlate)
    if plate=='' or plate~=expectedPlate then return end
    if installed[plate] then return end
    if (exports.ox_inventory:Search(src,'count',Config.KitItem) or 0) < 1 then return end
    if not exports.ox_inventory:RemoveItem(src,Config.KitItem,1) then return end
    local settings=defaultSettings()
    MySQL.query.await('INSERT IGNORE INTO sp_antilag (plate, flame_colour, pops_bangs, settings) VALUES (?, ?, ?, ?)',
        {plate, settings.colour, settings.pops and 1 or 0, json.encode(settings)})
    installed[plate]=settings
    TriggerClientEvent('sp_antilag:setInstalled',-1,plate,settings)
    TriggerClientEvent('ox_lib:notify',src,{type='success',description='Anti-lag fitted successfully.'})
end)


RegisterNetEvent('sp_antilag:remove', function(netId, expectedPlate)
    local src=source
    if not isMechanic(src) then
        return TriggerClientEvent('ox_lib:notify',src,{type='error',description='Only a mechanic can remove anti-lag.'})
    end

    local entity=NetworkGetEntityFromNetworkId(netId)
    if entity==0 or not DoesEntityExist(entity) then
        return TriggerClientEvent('ox_lib:notify',src,{type='error',description='Could not verify the vehicle.'})
    end

    local plate=cleanPlate(GetVehicleNumberPlateText(entity))
    expectedPlate=cleanPlate(expectedPlate)

    if plate=='' or plate~=expectedPlate then
        return TriggerClientEvent('ox_lib:notify',src,{type='error',description='Vehicle verification failed.'})
    end

    if not installed[plate] then
        TriggerClientEvent('sp_antilag:setInstalled',src,plate,false)
        return TriggerClientEvent('ox_lib:notify',src,{type='error',description='This vehicle does not have anti-lag fitted.'})
    end

    MySQL.query.await('DELETE FROM sp_antilag WHERE plate = ?', {plate})
    installed[plate]=nil
    TriggerClientEvent('sp_antilag:setInstalled',-1,plate,false)
    TriggerClientEvent('ox_lib:notify',src,{type='success',description='Anti-lag removed successfully.'})
end)

-- Returns the plate and saved settings when src may change this vehicle's settings.
local function editableVehicle(src, netId, expectedPlate)
    if Config.SettingsPermission=='mechanic' and not isMechanic(src) then
        TriggerClientEvent('ox_lib:notify',src,{type='error',description='Only a mechanic can tune the anti-lag.'})
        return nil
    end
    local entity=NetworkGetEntityFromNetworkId(netId)
    if entity==0 or not DoesEntityExist(entity) then return nil end
    if GetPedInVehicleSeat(entity,-1)~=GetPlayerPed(src) then
        TriggerClientEvent('ox_lib:notify',src,{type='error',description='You must be in the driver seat.'})
        return nil
    end
    local plate=cleanPlate(GetVehicleNumberPlateText(entity))
    if plate=='' or plate~=cleanPlate(expectedPlate) then return nil end
    local current=installed[plate]
    if not current then return nil end
    return plate,current
end

local saveRate={}
local function saveLimited(src)
    local now=os.clock()
    if saveRate[src] and now-saveRate[src]<0.5 then return true end
    saveRate[src]=now
    return false
end

-- V5.0: whole-panel save. `changes` may hold any settings field plus `hotbar`.
RegisterNetEvent('sp_antilag:saveSettings', function(netId, expectedPlate, changes, message)
    local src=source
    if saveLimited(src) or type(changes)~='table' then return end
    local plate,current=editableVehicle(src,netId,expectedPlate)
    if not plate then return end

    if changes.colour~=nil and not validColour(changes.colour) then
        return TriggerClientEvent('ox_lib:notify',src,{type='error',description='Invalid flame colour.'})
    end
    local updated=sanitize(changes,current)
    updated.hotbar=changes.hotbar~=nil and sanitizeHotbar(changes.hotbar) or current.hotbar or {}

    saveRow(plate,updated)
    installed[plate]=updated
    TriggerClientEvent('sp_antilag:setInstalled',-1,plate,updated)
    TriggerClientEvent('ox_lib:notify',src,{type='success',description=type(message)=='string' and message:sub(1,80) or 'Anti-lag settings saved.'})
end)

-- Kept for anything still calling the V4.4 event.
RegisterNetEvent('sp_antilag:updateSettings', function(netId, expectedPlate, colour, pops)
    local src=source
    if saveLimited(src) then return end
    local plate,current=editableVehicle(src,netId,expectedPlate)
    if not plate then return end
    if colour~=nil and not validColour(colour) then
        return TriggerClientEvent('ox_lib:notify',src,{type='error',description='Invalid flame colour.'})
    end
    local updated=sanitize({colour=colour,pops=pops},current)
    updated.hotbar=current.hotbar or {}
    saveRow(plate,updated)
    installed[plate]=updated
    TriggerClientEvent('sp_antilag:setInstalled',-1,plate,updated)
    TriggerClientEvent('ox_lib:notify',src,{type='success',description='Anti-lag settings saved.'})
end)

-- What nearby players need to draw/hear a shot. `look` comes from the driver so unsaved
-- test-mode colours show for everyone too; it is re-validated here.
local function sanitizeLook(look, saved)
    look=type(look)=='table' and look or {}
    local fs=Config.FlameSize
    return {
        colour=validColour(look.colour) or saved.colour,
        size=clamp(look.size,fs.Min,fs.Max,saved.size or fs.Default),
        silent=bool(look.silent,saved.silent==true),
        hide=bool(look.hide,saved.hideFlames==true),
        sound=soundKeys[look.sound] and look.sound or saved.sound,
        compat=bool(look.compat,saved.compat==true),
    }
end

local rate={}
RegisterNetEvent('sp_antilag:effect', function(netId, clientPlate, kind, withFlame, look)
    local src=source
    if kind~='pop' and kind~='bang' and kind~='mega' and kind~='big' then return end
    local now=os.clock()
    if rate[src] and now-rate[src] < 0.07 then return end
    rate[src]=now
    local plate=cleanPlate(clientPlate)
    local settings=plate~='' and installed[plate]
    if not settings then return end
    local entity=NetworkGetEntityFromNetworkId(netId)
    if entity==0 or not DoesEntityExist(entity) then return end
    local serverPlate=cleanPlate(GetVehicleNumberPlateText(entity))
    if serverPlate~=plate then return end
    TriggerClientEvent('sp_antilag:effect',-1,netId,kind,src,sanitizeLook(look,settings),withFlame~=false)
end)

AddEventHandler('playerDropped',function() rate[source]=nil; saveRate[source]=nil end)

-- exports['sp_antilag']:SetSettings(plate, { colour = 'blue', intensity = 'max', ... })
exports('SetSettings', function(plate, changes)
    plate=cleanPlate(plate)
    local current=installed[plate]
    if not current or type(changes)~='table' then return false end
    local updated=sanitize(changes,current)
    updated.hotbar=current.hotbar or {}
    saveRow(plate,updated)
    installed[plate]=updated
    TriggerClientEvent('sp_antilag:setInstalled',-1,plate,updated)
    return true
end)

exports('GetSettings', function(plate) return installed[cleanPlate(plate)] or false end)


print(('^2[sp_antilag] v%s loaded from %s^7'):format(GetResourceMetadata(GetCurrentResourceName(),'version',0) or '?',GetResourcePath(GetCurrentResourceName())))
