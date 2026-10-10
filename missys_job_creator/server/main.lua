MJC = MJC or {}
MJC.Server = MJC.Server or {}

local function refreshRuntime()
    MJC.Persistence.refreshAndBroadcast()
    MJC.Businesses.restore()
    MJC.Shops.restore()
end

local function adminMutation(source, fn, payload)
    if not MJC.Permissions.requireAdmin(source) then return { ok = false, error = 'No permission.' } end
    local ok, result, extra = pcall(fn, payload)
    if not ok then
        print(('[missys_job_creator] mutation error: %s'):format(result))
        return { ok = false, error = 'Server error. Check console.' }
    end
    if result ~= true then return { ok = false, error = extra or 'Action failed.' } end
    refreshRuntime()
    return { ok = true, id = extra }
end

lib.callback.register('missys_job_creator:server:state', function()
    return MJC.Persistence.publicState()
end)

local function qbxJobOptions()
    local result = {}
    for jobName, job in pairs(exports.qbx_core:GetJobs() or {}) do
        result[#result + 1] = { job_name = jobName, label = job.label or jobName }
    end
    table.sort(result, function(a, b) return a.label:lower() < b.label:lower() end)
    return result
end

lib.callback.register('missys_job_creator:server:bootstrap', function(source)
    if not MJC.Permissions.isAdmin(source) then return { admin = false } end
    return { admin = true, state = MJC.Persistence.publicState(), qbxJobs = qbxJobOptions(), integrations = MJC.Integrations.status(), presentationDefaults = { npc = Config.DefaultPedModel, prop = Config.Points.defaultProp } }
end)

lib.callback.register('missys_job_creator:server:saveJob', function(source, payload)
    return adminMutation(source, MJC.Jobs.save, payload)
end)
lib.callback.register('missys_job_creator:server:deleteJob', function(source, id)
    return adminMutation(source, MJC.Jobs.delete, id)
end)
lib.callback.register('missys_job_creator:server:savePoint', function(source, payload)
    return adminMutation(source, MJC.Points.save, payload)
end)
lib.callback.register('missys_job_creator:server:deletePoint', function(source, id)
    return adminMutation(source, MJC.Points.delete, id)
end)
lib.callback.register('missys_job_creator:server:saveBlip', function(source, payload)
    return adminMutation(source, MJC.Blips.save, payload)
end)
lib.callback.register('missys_job_creator:server:deleteBlip', function(source, id)
    return adminMutation(source, MJC.Blips.delete, id)
end)
lib.callback.register('missys_job_creator:server:saveFleet', function(source, payload)
    return adminMutation(source, MJC.Fleet.save, payload)
end)
lib.callback.register('missys_job_creator:server:deleteFleet', function(source, id)
    return adminMutation(source, MJC.Fleet.delete, id)
end)
lib.callback.register('missys_job_creator:server:requestFleet', function(source, pointId, fleetId)
    local ok, data = MJC.Fleet.requestLease(source, pointId, fleetId)
    return { ok=ok, data=ok and data or nil, error=ok and nil or data }
end)
lib.callback.register('missys_job_creator:server:registerFleetVehicle', function(source, netId)
    local ok, data = MJC.Fleet.registerVehicle(source, netId)
    return { ok=ok, error=ok and nil or data }
end)
lib.callback.register('missys_job_creator:server:returnFleet', function(source, pointId)
    local ok, data = MJC.Fleet.releaseLease(source, pointId)
    return { ok=ok, data=ok and data or nil, error=ok and nil or data }
end)
lib.callback.register('missys_job_creator:server:exportJob', function(source, id)
    if not MJC.Permissions.requireAdmin(source) then return {ok=false,error='No permission.'} end
    local ok, data = MJC.JobPackages.export(id)
    return {ok=ok, data=ok and data or nil, error=ok and nil or data}
end)
lib.callback.register('missys_job_creator:server:previewImport', function(source, raw)
    if not MJC.Permissions.requireAdmin(source) then return {ok=false,error='No permission.'} end
    local ok, data = MJC.JobPackages.preview(raw)
    return {ok=ok, data=ok and data or nil, error=ok and nil or data}
end)
lib.callback.register('missys_job_creator:server:duplicateJob', function(source, payload)
    if not MJC.Permissions.requireAdmin(source) then return {ok=false,error='No permission.'} end
    local ok, data = MJC.JobPackages.duplicate(payload.id, payload.job_name, payload.label)
    if ok then refreshRuntime() end
    return {ok=ok,id=ok and data or nil,error=ok and nil or data}
end)
lib.callback.register('missys_job_creator:server:importJob', function(source, payload)
    if not MJC.Permissions.requireAdmin(source) then return {ok=false,error='No permission.'} end
    local ok, data = MJC.JobPackages.import(payload.raw, payload.job_name, payload.label)
    if ok then refreshRuntime() end
    return {ok=ok,id=ok and data or nil,error=ok and nil or data}
end)
lib.callback.register('missys_job_creator:server:saveNpc', function(source, payload)
    return adminMutation(source, MJC.Npcs.save, payload)
end)
lib.callback.register('missys_job_creator:server:deleteNpc', function(source, id)
    return adminMutation(source, MJC.Npcs.delete, id)
end)
lib.callback.register('missys_job_creator:server:saveBusiness', function(source, payload)
    return adminMutation(source, MJC.Businesses.save, payload)
end)
lib.callback.register('missys_job_creator:server:deleteBusiness', function(source, id)
    return adminMutation(source, MJC.Businesses.delete, id)
end)
lib.callback.register('missys_job_creator:server:saveShop', function(source, payload)
    return adminMutation(source, MJC.Shops.save, payload)
end)
lib.callback.register('missys_job_creator:server:deleteShop', function(source, id)
    return adminMutation(source, MJC.Shops.delete, id)
end)

lib.callback.register('missys_job_creator:server:usePoint', function(source, pointId, action, payload)
    local ok, data = MJC.PointActions.use(source, pointId, action, payload)
    return { ok = ok, data = ok and data or nil, error = ok and nil or data }
end)

lib.callback.register('missys_job_creator:server:hire', function(source, npcId)
    local ok, message = MJC.Npcs.hire(source, npcId)
    return { ok = ok, message = message }
end)

lib.callback.register('missys_job_creator:server:businessShopView', function(source, shopId)
    local ok, data = MJC.Shops.businessView(source, shopId)
    return { ok = ok, data = ok and data or nil, error = ok and nil or data }
end)

lib.callback.register('missys_job_creator:server:businessPurchase', function(source, shopId, itemName, count)
    local ok, message = MJC.Shops.purchaseBusiness(source, shopId, itemName, count)
    return { ok = ok, message = message }
end)

lib.callback.register('missys_job_creator:server:prepareBusinessStock', function(source, businessJob)
    local ok, data = MJC.Businesses.prepareStock(source, businessJob)
    return { ok = ok, stashId = ok and data or nil, error = ok and nil or data }
end)

RegisterNetEvent('missys_job_creator:server:startActivity', function(npcId)
    local source = source
    local npc = MJC.State.npcs[tonumber(npcId)]
    if not npc or npc.role_type ~= 'activity' or not MJC.Npcs.isNearby(source, npc, Config.PurchaseDistance) or not MJC.Npcs.canUse(source, npc) then return end
    local key = npc.role_ref
    TriggerEvent('missys_job_creator:server:activity', source, key, npc.id)
    TriggerClientEvent('missys_job_creator:client:activity', source, key, npc.id)
end)

RegisterCommand(Config.Command or 'jobcreator', function(source)
    if source == 0 then return print('[missys_job_creator] /jobcreator is an in-game command.') end

    -- Do not block here on the cached txAdmin state. After this resource is
    -- restarted, that cache is empty until the client asks txAdmin to
    -- authenticate again. openAdmin() performs that retry, while the bootstrap
    -- callback below remains the server-authoritative permission gate.
    TriggerClientEvent('missys_job_creator:client:openCreator', source)
end, false)

MySQL.ready(function()
    local schemaStatements = MJC.Schema.ensure()
    local migratedBossPoints = MJC.Migrations.legacyBossPoints()
    MJC.Persistence.loadAll()
    MJC.PointActions.registerStashSecurityHook()
    local jobs = MJC.Jobs.restore()
    local businesses = MJC.Businesses.restore()
    local shops = MJC.Shops.restore()
    TriggerClientEvent('missys_job_creator:client:state', -1, MJC.Persistence.publicState())
    print(('[missys_job_creator] Ready: schema %s statements, %s legacy boss points migrated, %s jobs, %s businesses, %s infinite shops restored.'):format(schemaStatements, migratedBossPoints, jobs, businesses, shops))
end)

AddEventHandler('onResourceStart', function(resource)
    if resource ~= 'ox_inventory' and resource ~= 'qbx_core' and resource ~= 'qbx_management' then return end
    if GetResourceState(GetCurrentResourceName()) ~= 'started' then return end
    SetTimeout(1000, function()
        if not MJC.State then return end
        if resource == 'qbx_core' then MJC.Jobs.restore() end
        if resource == 'ox_inventory' then MJC.PointActions.registerStashSecurityHook(); MJC.Businesses.restore(); MJC.Shops.restore() end
        if resource == 'qbx_management' then MJC.Jobs.restore() end
    end)
end)
