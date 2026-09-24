local installed = {}

local function cleanPlate(p)
    return (p or ''):gsub('^%s*(.-)%s*$', '%1'):upper()
end

local function isMechanic(src)
    local player = exports.qbx_core:GetPlayer(src)
    local job = player and player.PlayerData and player.PlayerData.job
    return job and Config.MechanicJobs[job.name] == true
end

CreateThread(function()
    MySQL.query.await([[CREATE TABLE IF NOT EXISTS sp_antilag (
        plate VARCHAR(16) NOT NULL PRIMARY KEY
    )]])
    local rows=MySQL.query.await('SELECT plate FROM sp_antilag') or {}
    for _,row in ipairs(rows) do installed[cleanPlate(row.plate)] = true end
end)

lib.callback.register('sp_antilag:isInstalled', function(_, plate)
    return installed[cleanPlate(plate)] == true
end)

RegisterNetEvent('sp_antilag:requestInstall', function(plate)
    local src=source
    plate=cleanPlate(plate)
    if not isMechanic(src) then return end
    if plate=='' then return end
    if installed[plate] then
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
    MySQL.query.await('INSERT IGNORE INTO sp_antilag (plate) VALUES (?)',{plate})
    installed[plate]=true
    TriggerClientEvent('sp_antilag:setInstalled',-1,plate,true)
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
        return TriggerClientEvent('ox_lib:notify',src,{type='error',description='This vehicle does not have anti-lag fitted.'})
    end

    MySQL.query.await('DELETE FROM sp_antilag WHERE plate = ?', {plate})
    installed[plate]=nil
    TriggerClientEvent('sp_antilag:setInstalled',-1,plate,false)
    TriggerClientEvent('ox_lib:notify',src,{type='success',description='Anti-lag removed successfully.'})
end)

local rate={}
RegisterNetEvent('sp_antilag:effect', function(netId, clientPlate, kind)
    local src=source
    if kind~='pop' and kind~='bang' and kind~='mega' then return end
    local now=os.clock()
    if rate[src] and now-rate[src] < 0.07 then return end
    rate[src]=now
    local plate=cleanPlate(clientPlate)
    if plate=='' or not installed[plate] then return end
    local entity=NetworkGetEntityFromNetworkId(netId)
    if entity==0 or not DoesEntityExist(entity) then return end
    local serverPlate=cleanPlate(GetVehicleNumberPlateText(entity))
    if serverPlate~=plate then return end
    TriggerClientEvent('sp_antilag:effect',-1,netId,kind,src)
end)

AddEventHandler('playerDropped',function() rate[source]=nil end)
