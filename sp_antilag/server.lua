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

local function defaultSettings()
    return {
        colour = validColour(Config.DefaultFlameColour) or 'stock',
        pops = Config.PopsBangs.DefaultOn == true
    }
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

    local rows = MySQL.query.await('SELECT plate, flame_colour, pops_bangs FROM sp_antilag') or {}
    for _, row in ipairs(rows) do
        installed[cleanPlate(row.plate)] = {
            colour = validColour(row.flame_colour) or 'stock',
            pops = row.pops_bangs == 1 or row.pops_bangs == true
        }
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
    MySQL.query.await('INSERT IGNORE INTO sp_antilag (plate, flame_colour, pops_bangs) VALUES (?, ?, ?)',
        {plate, settings.colour, settings.pops and 1 or 0})
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

-- V4.4: flame colour / pops & bangs settings. Sender must be in the driver seat of the fitted vehicle.
RegisterNetEvent('sp_antilag:updateSettings', function(netId, expectedPlate, colour, pops)
    local src=source
    if Config.SettingsPermission=='mechanic' and not isMechanic(src) then
        return TriggerClientEvent('ox_lib:notify',src,{type='error',description='Only a mechanic can tune the anti-lag.'})
    end

    local entity=NetworkGetEntityFromNetworkId(netId)
    if entity==0 or not DoesEntityExist(entity) then return end
    if GetPedInVehicleSeat(entity,-1)~=GetPlayerPed(src) then
        return TriggerClientEvent('ox_lib:notify',src,{type='error',description='You must be in the driver seat.'})
    end

    local plate=cleanPlate(GetVehicleNumberPlateText(entity))
    if plate=='' or plate~=cleanPlate(expectedPlate) then return end
    local current=installed[plate]
    if not current then return end

    local newColour=current.colour
    if colour~=nil then
        newColour=validColour(colour)
        if not newColour then
            return TriggerClientEvent('ox_lib:notify',src,{type='error',description='Invalid flame colour.'})
        end
    end
    local newPops=current.pops
    if pops~=nil then newPops=pops==true end

    MySQL.update.await('UPDATE sp_antilag SET flame_colour = ?, pops_bangs = ? WHERE plate = ?',
        {newColour, newPops and 1 or 0, plate})
    current.colour=newColour
    current.pops=newPops
    TriggerClientEvent('sp_antilag:setInstalled',-1,plate,current)
    TriggerClientEvent('ox_lib:notify',src,{type='success',description='Anti-lag settings saved.'})
end)

local rate={}
RegisterNetEvent('sp_antilag:effect', function(netId, clientPlate, kind, withFlame)
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
    TriggerClientEvent('sp_antilag:effect',-1,netId,kind,src,settings.colour,withFlame~=false)
end)

AddEventHandler('playerDropped',function() rate[source]=nil end)

print(('^2[sp_antilag] v%s loaded from %s^7'):format(GetResourceMetadata(GetCurrentResourceName(),'version',0) or '?',GetResourcePath(GetCurrentResourceName())))
