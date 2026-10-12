-- Velora Jam Co. - shifts, company vans, supplier shop
local Shifts = {}   -- src -> { started, netId, plate, deposit, model, account }
VJS.Shifts = Shifts

function VJS.onShift(src)
    return Shifts[src] ~= nil
end

-- ─────────────────────────────────────────────────────────────────────────
-- Vehicle keys
-- ─────────────────────────────────────────────────────────────────────────
local function giveKeys(src, vehicle, plate)
    local system = Config.VehicleKeys
    if system == 'qbx_vehiclekeys' then
        local ok = pcall(function() exports.qbx_vehiclekeys:GiveKeys(src, vehicle) end)
        if not ok then TriggerClientEvent('vehiclekeys:client:SetOwner', src, plate) end
    elseif system == 'qs-vehiclekeys' or system == 'wasabi_carlock' or system == 'MrNewbVehicleKeys' then
        -- these scripts give keys client-side
        TriggerClientEvent('velora_jamco:client:giveKeys', src, NetworkGetNetworkIdFromEntity(vehicle), plate)
    elseif system == 'mk_vehiclekeys' then
        pcall(function() exports.mk_vehiclekeys:AddKey(vehicle, src) end)
    end
end

local function removeKeys(src, vehicle, plate)
    local system = Config.VehicleKeys
    if system == 'qbx_vehiclekeys' then
        pcall(function() exports.qbx_vehiclekeys:RemoveKeys(src, vehicle) end)
    elseif system == 'qs-vehiclekeys' or system == 'wasabi_carlock' or system == 'MrNewbVehicleKeys' then
        TriggerClientEvent('velora_jamco:client:removeKeys', src, plate)
    elseif system == 'mk_vehiclekeys' then
        pcall(function() exports.mk_vehiclekeys:RemoveKey(vehicle, src) end)
    end
end

-- ─────────────────────────────────────────────────────────────────────────
-- Vans
-- ─────────────────────────────────────────────────────────────────────────
local function randomPlate()
    local chars = 'ABCDEFGHJKLMNPRSTUVWXYZ23456789'
    local prefix = Config.Van.PlatePrefix or ''
    local plate = prefix
    while #plate < 8 do
        local i = math.random(1, #chars)
        plate = plate .. chars:sub(i, i)
    end
    return plate
end

local function freeSpawn()
    local vehicles = GetAllVehicles()
    for _, spawn in ipairs(Config.Van.Spawns) do
        local point = vec3(spawn.x, spawn.y, spawn.z)
        local blocked = false
        for i = 1, #vehicles do
            if #(GetEntityCoords(vehicles[i]) - point) < Config.Van.SpawnClearRadius then
                blocked = true
                break
            end
        end
        if not blocked then
            for _, playerId in ipairs(GetPlayers()) do
                local ped = GetPlayerPed(playerId)
                if ped ~= 0 and #(GetEntityCoords(ped) - point) < 1.5 then
                    blocked = true
                    break
                end
            end
        end
        if not blocked then return spawn end
    end
    return nil
end

local function vanEntity(shift)
    if not shift or not shift.netId then return 0 end
    local veh = NetworkGetEntityFromNetworkId(shift.netId)
    if veh ~= 0 and DoesEntityExist(veh) and GetEntityType(veh) == 2 then return veh end
    return 0
end

local function deleteVan(shift)
    local veh = vanEntity(shift)
    if veh ~= 0 then DeleteEntity(veh) end
end

local function nearBusiness(src)
    return VJS.distance(src, Config.Business.npc.coords) <= Config.Business.interactDistance + 3.0
end

-- ─────────────────────────────────────────────────────────────────────────
-- Callbacks
-- ─────────────────────────────────────────────────────────────────────────
lib.callback.register('velora_jamco:business:getData', function(src)
    local cid = VJS.getCid(src)
    if not cid then return nil end
    local shift = Shifts[src]
    local stats = VJS.getStats(cid)

    local orchards = {}
    for _, o in ipairs(VJS.orchardSummary()) do
        orchards[#orchards + 1] = {
            id = o.orchard.id, label = o.orchard.label, description = o.orchard.description,
            x = o.x, y = o.y, trees = o.trees, fruits = o.fruits,
            distance = math.floor(VJS.distance(src, vec3(o.x, o.y, VJS.coords(src) and VJS.coords(src).z or 0.0))),
        }
    end

    local counts = VJS.counts(src, VJ.allItemNames())
    local van = nil
    if shift then
        local veh = vanEntity(shift)
        van = {
            plate = shift.plate, model = shift.label, exists = veh ~= 0,
            nearby = veh ~= 0 and #(GetEntityCoords(veh) - Config.Business.returnPoint) <= Config.Business.returnRadius,
            body = veh ~= 0 and math.floor(GetVehicleBodyHealth(veh) / 10) or 0,
            engine = veh ~= 0 and math.floor(GetVehicleEngineHealth(veh) / 10) or 0,
        }
    end

    return {
        npcName = Config.Business.npc.name,
        shift = shift and { started = shift.started, elapsed = os.time() - shift.started, deposit = shift.deposit, van = van } or nil,
        deposit = Config.Van.Deposit,
        depositAccount = Config.Payment.deposit,
        vanRequired = Config.Van.Required,
        orchards = orchards,
        counts = counts,
        stats = stats,
        achievements = VJS.achievementList(cid),
        book = VJS.recipeBook(cid),
        shop = Config.Shop.enabled,
    }
end)

lib.callback.register('velora_jamco:business:startShift', function(src, data)
    if type(data) ~= 'table' then return { ok = false, msg = 'Invalid request.' } end
    if Shifts[src] then return { ok = false, msg = 'You are already on shift.' } end
    if not nearBusiness(src) then return { ok = false, msg = 'You need to be at Velora Jam Co.' } end
    local can, why = VJS.canAct(src)
    if not can then return { ok = false, msg = why } end
    if not VJS.lock(src, 'shift') then return { ok = false, msg = 'Please wait...' } end

    local result = (function()
        local wantsVan = data.van == true
        if Config.Van.Required then wantsVan = true end
        local shift = { started = os.time(), deposit = 0, cid = VJS.getCid(src) }

        if wantsVan then
            local modelCfg = Config.Van.Models[tonumber(data.model) or 0]
            local colour = Config.Van.Colours[tonumber(data.colour) or 0]
            if not modelCfg or not colour then return { ok = false, msg = 'Choose a van and a colour.' } end

            local spawn = freeSpawn()
            if not spawn then return { ok = false, msg = 'All van bays are occupied. Clear the parking area and try again.' } end

            local deposit = Config.Van.Deposit or 0
            local account = Config.Payment.deposit
            if deposit > 0 and not VJS.removeMoney(src, account, deposit, 'velora-jamco-van-deposit', 'deposit') then
                return { ok = false, msg = ('You need $%d in your %s account for the van deposit.'):format(deposit, account) }
            end

            local veh = CreateVehicleServerSetter(GetHashKey(modelCfg.model), 'automobile', spawn.x, spawn.y, spawn.z, spawn.w)
            local timeout = GetGameTimer() + 5000
            while (veh == 0 or not DoesEntityExist(veh)) and GetGameTimer() < timeout do Wait(50) end
            if veh == 0 or not DoesEntityExist(veh) then
                if deposit > 0 then VJS.addMoney(src, account, deposit, 'velora-jamco-van-deposit-refund', 'refund') end
                return { ok = false, msg = 'The van could not be delivered. Your deposit has been returned.' }
            end

            local plate = randomPlate()
            SetVehicleNumberPlateText(veh, plate)
            SetVehicleColours(veh, colour.primary, colour.secondary)
            SetVehicleDoorsLocked(veh, 1)
            Entity(veh).state:set('fuel', Config.VanFuel, true)
            Entity(veh).state:set('veloraJamVan', src, true)

            shift.netId = NetworkGetNetworkIdFromEntity(veh)
            shift.plate = plate
            shift.label = modelCfg.label
            shift.deposit = deposit
            shift.account = account
            giveKeys(src, veh, plate)
        end

        Shifts[src] = shift
        VJS.log(src, 'shift_start', { plate = shift.plate, deposit = shift.deposit })
        return { ok = true, netId = shift.netId, plate = shift.plate, deposit = shift.deposit }
    end)()

    VJS.unlock(src, 'shift')
    return result
end)

lib.callback.register('velora_jamco:business:endShift', function(src, forfeit)
    local shift = Shifts[src]
    if not shift then return { ok = false, msg = 'You are not on shift.' } end
    if not nearBusiness(src) then return { ok = false, msg = 'Return to Velora Jam Co. to end your shift.' } end
    if not VJS.lock(src, 'shift') then return { ok = false, msg = 'Please wait...' } end

    local refund, msg = 0, 'Shift ended. Thank you, darling!'
    if shift.netId then
        local veh = vanEntity(shift)
        local returned = veh ~= 0 and #(GetEntityCoords(veh) - Config.Business.returnPoint) <= Config.Business.returnRadius
        if not returned and not forfeit then
            VJS.unlock(src, 'shift')
            return { ok = false, needForfeit = true, msg = 'Your van is not parked at the depot. End the shift anyway and lose the deposit?' }
        end
        if returned then
            if GetVehicleBodyHealth(veh) >= Config.Van.RefundHealth.body and GetVehicleEngineHealth(veh) >= Config.Van.RefundHealth.engine then
                refund = shift.deposit
            else
                msg = 'The van came back damaged, so the deposit has been kept for repairs.'
            end
        else
            msg = 'Shift ended without returning the van. The deposit has been kept.'
        end
        removeKeys(src, veh, shift.plate)
        deleteVan(shift)
        if refund > 0 then
            VJS.addMoney(src, shift.account, refund, 'velora-jamco-van-deposit-refund', 'refund')
            msg = ('Van returned in lovely condition. $%d deposit refunded.'):format(refund)
        end
    end

    Shifts[src] = nil
    VJS.log(src, 'shift_end', { plate = shift.plate, refund = refund, duration = os.time() - shift.started })
    VJS.unlock(src, 'shift')
    return { ok = true, msg = msg, refund = refund }
end)

lib.callback.register('velora_jamco:business:openShop', function(src)
    if not Config.Shop.enabled then return false end
    return nearBusiness(src)
end)

-- ─────────────────────────────────────────────────────────────────────────
-- Cleanup (disconnect / resource stop) - deposits are never lost to a crash
-- ─────────────────────────────────────────────────────────────────────────
AddEventHandler('playerDropped', function()
    local src = source
    local shift = Shifts[src]
    if not shift then return end
    Shifts[src] = nil
    deleteVan(shift)
    -- citizen id may already be gone at this point, so we stored it on the shift
    if shift.deposit > 0 and shift.cid then
        VJS.addPending(shift.cid, 'money', { account = shift.account, amount = shift.deposit, reason = 'velora-jamco-van-deposit-refund' })
    end
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    for src, shift in pairs(Shifts) do
        deleteVan(shift)
        if shift.deposit > 0 then
            VJS.addMoney(src, shift.account, shift.deposit, 'velora-jamco-van-deposit-refund', 'refund')
        end
    end
end)

-- ─────────────────────────────────────────────────────────────────────────
-- Supplier shop
-- ─────────────────────────────────────────────────────────────────────────
CreateThread(function()
    if not Config.Shop.enabled then return end
    while GetResourceState('ox_inventory') ~= 'started' do Wait(500) end
    local inventory = {}
    for _, entry in ipairs(Config.Shop.items) do
        inventory[#inventory + 1] = { name = entry.name, price = entry.price, currency = Config.Shop.currency ~= 'money' and Config.Shop.currency or nil }
    end
    local npc = Config.Business.npc.coords
    exports.ox_inventory:RegisterShop('velora_jamco_supplies', {
        name = Config.Shop.name,
        inventory = inventory,
        locations = { vec3(npc.x, npc.y, npc.z) },
    })
end)
