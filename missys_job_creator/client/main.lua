MJC = MJC or {}
MJC.Client = MJC.Client or {}
MJC.Client.state = MJC.Client.state or { jobs = {}, businesses = {}, npcs = {}, shops = {}, activities = {} }
MJC.Client.creatorOpen = false

local function notify(message, kind)
    exports.qbx_core:Notify(message, kind or 'inform', 4500, nil, Config.NotifyPosition)
end
MJC.Client.notify = notify

function MJC.Client.setState(state)
    if MJC.Client.clearPoints then MJC.Client.clearPoints() end
    MJC.Client.state = state or MJC.Client.state
    if MJC.Client.refreshWorld then MJC.Client.refreshWorld() end
    if MJC.Client.refreshPoints then MJC.Client.refreshPoints() end
    if MJC.Client.refreshBlips then MJC.Client.refreshBlips() end
end

function MJC.Client.closeNui()
    MJC.Client.creatorOpen = false
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'close' })
end

function MJC.Client.openAdmin()
    local data = lib.callback.await('missys_job_creator:server:bootstrap', false)

    -- If ACE is unavailable/misconfigured, ask txAdmin to authenticate this player
    -- and retry once. txAdmin performs the actual identifier/admin verification.
    if (not data or not data.admin) and Config.AllowTxAdmin then
        TriggerServerEvent('txsv:checkIfAdmin')
        Wait(1200)
        data = lib.callback.await('missys_job_creator:server:bootstrap', false)
    end

    if not data or not data.admin then return notify('You do not have permission to use the job creator.', 'error') end
    MJC.Client.setState(data.state)
    MJC.Client.creatorOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'openAdmin', payload = data })
end

function MJC.Client.openCustomerShop(shopId)
    local response = lib.callback.await('missys_job_creator:server:businessShopView', false, shopId)
    if not response or not response.ok then return notify(response and response.error or 'Shop unavailable.', 'error') end
    MJC.Client.creatorOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'openCustomerShop', payload = response.data })
end

RegisterNetEvent('missys_job_creator:client:openCreator', MJC.Client.openAdmin)
RegisterNetEvent('missys_job_creator:client:state', function(state) MJC.Client.setState(state) end)
RegisterNetEvent('missys_job_creator:client:activity', function(key, npcId)
    TriggerEvent(('missys_job_creator:activity:%s'):format(key or 'unknown'), npcId)
    TriggerEvent('missys_job_creator:activity', key, npcId)
end)

RegisterNUICallback('close', function(_, cb)
    MJC.Client.closeNui()
    cb({ ok = true })
end)

local function mutation(callback, payload, cb)
    local response = lib.callback.await(callback, false, payload)
    if response and response.ok then
        notify('Saved.', 'success')
        local bootstrap = lib.callback.await('missys_job_creator:server:bootstrap', false)
        if bootstrap and bootstrap.state then MJC.Client.setState(bootstrap.state) end
        cb({ ok = true, id = response.id, state = bootstrap and bootstrap.state or MJC.Client.state, qbxJobs = bootstrap and bootstrap.qbxJobs or nil })
    else
        cb({ ok = false, error = response and response.error or 'Action failed.' })
    end
end

RegisterNUICallback('saveJob', function(data, cb) mutation('missys_job_creator:server:saveJob', data, cb) end)
RegisterNUICallback('savePoint', function(data, cb) mutation('missys_job_creator:server:savePoint', data, cb) end)
RegisterNUICallback('deletePoint', function(data, cb) mutation('missys_job_creator:server:deletePoint', data.id, cb) end)
RegisterNUICallback('saveBlip', function(data, cb) mutation('missys_job_creator:server:saveBlip', data, cb) end)
RegisterNUICallback('deleteBlip', function(data, cb) mutation('missys_job_creator:server:deleteBlip', data.id, cb) end)
RegisterNUICallback('saveFleet', function(data, cb) mutation('missys_job_creator:server:saveFleet', data, cb) end)
RegisterNUICallback('deleteFleet', function(data, cb) mutation('missys_job_creator:server:deleteFleet', data.id, cb) end)
RegisterNUICallback('saveNpc', function(data, cb) mutation('missys_job_creator:server:saveNpc', data, cb) end)
RegisterNUICallback('saveShop', function(data, cb) mutation('missys_job_creator:server:saveShop', data, cb) end)
RegisterNUICallback('saveBusiness', function(data, cb) mutation('missys_job_creator:server:saveBusiness', data, cb) end)
RegisterNUICallback('deleteJob', function(data, cb) mutation('missys_job_creator:server:deleteJob', data.id, cb) end)
RegisterNUICallback('deleteNpc', function(data, cb) mutation('missys_job_creator:server:deleteNpc', data.id, cb) end)
RegisterNUICallback('deleteShop', function(data, cb) mutation('missys_job_creator:server:deleteShop', data.id, cb) end)
RegisterNUICallback('deleteBusiness', function(data, cb) mutation('missys_job_creator:server:deleteBusiness', data.id, cb) end)

RegisterNUICallback('exportJob', function(data, cb)
    cb(lib.callback.await('missys_job_creator:server:exportJob', false, data.id))
end)
RegisterNUICallback('previewImport', function(data, cb)
    cb(lib.callback.await('missys_job_creator:server:previewImport', false, data.raw))
end)
RegisterNUICallback('duplicateJob', function(data, cb)
    local response=lib.callback.await('missys_job_creator:server:duplicateJob',false,data)
    if response and response.ok then local bootstrap=lib.callback.await('missys_job_creator:server:bootstrap',false); if bootstrap and bootstrap.state then MJC.Client.setState(bootstrap.state) end; response.state=bootstrap and bootstrap.state; response.qbxJobs=bootstrap and bootstrap.qbxJobs end
    cb(response or {ok=false,error='Duplicate failed.'})
end)
RegisterNUICallback('importJob', function(data, cb)
    local response=lib.callback.await('missys_job_creator:server:importJob',false,data)
    if response and response.ok then local bootstrap=lib.callback.await('missys_job_creator:server:bootstrap',false); if bootstrap and bootstrap.state then MJC.Client.setState(bootstrap.state) end; response.state=bootstrap and bootstrap.state; response.qbxJobs=bootstrap and bootstrap.qbxJobs end
    cb(response or {ok=false,error='Import failed.'})
end)

RegisterNUICallback('placeNpc', function(data, cb)
    SendNUIMessage({ action = 'hideForPlacement' })
    SetNuiFocus(false, false)
    local result = MJC.Client.startPlacement(data.model or Config.DefaultPedModel, data.position)
    SendNUIMessage({ action = 'showAfterPlacement' })
    SetNuiFocus(true, true)
    if result then SendNUIMessage({ action = 'placementResult', payload = result }) end
    cb({ ok = result ~= nil, position = result })
end)

RegisterNUICallback('placePoint', function(data, cb)
    SendNUIMessage({ action = 'hideForPlacement' })
    SetNuiFocus(false, false)
    local result = MJC.Client.startPointPlacement(data.presentationType or data.presentation_type or 'target', data.model, data.position)
    SendNUIMessage({ action = 'showAfterPlacement' })
    SetNuiFocus(true, true)
    if result then SendNUIMessage({ action = 'pointPlacementResult', payload = result }) end
    cb({ ok = result ~= nil, position = result })
end)

RegisterNUICallback('currentPosition', function(_, cb)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local result = { x = coords.x, y = coords.y, z = coords.z, heading = GetEntityHeading(ped) }
    cb({ ok = true, position = result })
end)

RegisterNUICallback('purchaseBusiness', function(data, cb)
    local response = lib.callback.await('missys_job_creator:server:businessPurchase', false, data.shopId, data.itemName, data.count)
    if response and response.message then notify(response.message, response.ok and 'success' or 'error') end
    if response and response.ok then
        local view = lib.callback.await('missys_job_creator:server:businessShopView', false, data.shopId)
        cb({ ok = true, shop = view and view.data })
    else
        cb({ ok = false, error = response and response.message or 'Purchase failed.' })
    end
end)

RegisterNUICallback('purchasePointShop', function(data, cb)
    local response = lib.callback.await('missys_job_creator:server:usePoint', false, data.pointId, 'shop', { item=data.itemName, count=data.count })
    if not response or not response.ok then
        return cb({ ok = false, error = response and response.error or 'Purchase failed.' })
    end
    local purchaseData = response.data or {}
    if purchaseData.message then notify(purchaseData.message, 'success') end
    local view = lib.callback.await('missys_job_creator:server:usePoint', false, data.pointId, 'shop', { op='view' })
    cb({ ok = true, shop = view and view.ok and view.data or nil })
end)

CreateThread(function()
    Wait(750)
    if Config.AllowTxAdmin then TriggerServerEvent('txsv:checkIfAdmin') end
    Wait(750)
    local state = lib.callback.await('missys_job_creator:server:state', false)
    if state then MJC.Client.setState(state) end
end)
