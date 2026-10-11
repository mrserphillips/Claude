-- Velora Jam Co. - orchard trees, bushes and the harvesting minigame
local Spawned = {}   -- tree id -> entity
local current = nil  -- { tree, token, finished }

local function dist2D(a, b)
    local dx, dy = a.x - b.x, a.y - b.y
    return math.sqrt(dx * dx + dy * dy)
end

local function stopHarvest()
    if current and not current.finished then
        local token = current.token
        lib.callback('velora_jamco:harvest:cancel', false, function() end, token)
    end
    current = nil
    VJC.stopAnim()
    VJC.busy = false
end

Nui.onClose('harvest', stopHarvest)

local function monitor(tree)
    CreateThread(function()
        while current and current.tree == tree do
            Wait(250)
            if not current then break end
            local ped = cache.ped
            local reason = nil
            if IsEntityDead(ped) or IsPedRagdoll(ped) then
                reason = 'You were interrupted.'
            elseif IsPedInAnyVehicle(ped, false) then
                reason = 'You got into a vehicle.'
            elseif dist2D(GetEntityCoords(ped), tree.coords) > Config.Harvest.MaxDistance then
                reason = 'You walked away from the tree.'
            end
            if reason then
                if Nui.app == 'harvest' then Nui.close() else stopHarvest() end
                VJC.notify(reason, 'error')
                break
            end
        end
    end)
end

local function startHarvest(tree)
    if not VJC.canStart() then return end
    VJC.busy = true
    local res = lib.callback.await('velora_jamco:harvest:start', false, tree.id)
    if not res or not res.ok then
        VJC.busy = false
        return VJC.notify(res and res.msg or 'Something went wrong.', 'error')
    end

    current = { tree = tree, token = res.token, finished = false }
    local ped = cache.ped
    local target = Spawned[tree.id] and GetEntityCoords(Spawned[tree.id]) or tree.coords
    TaskTurnPedToFaceCoord(ped, target.x, target.y, target.z, 700)
    Wait(700)
    if not current then return end
    local anim = Config.Harvest.Anims[tree.anim] or Config.Harvest.Anims.tree
    VJC.playAnim(anim.dict, anim.clip, 1)

    Nui.open('harvest', res)
    monitor(tree)
end

RegisterNUICallback('harvest:finish', function(data, cb)
    if not current or current.finished then return cb({ ok = false, msg = 'This harvest has expired.' }) end
    current.finished = true
    local res = lib.callback.await('velora_jamco:harvest:finish', false, current.token, data)
    VJC.stopAnim()
    if res and res.ok and res.amount > 0 then
        PlaySoundFrontend(-1, 'PICK_UP', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
    end
    cb(res or { ok = false, msg = 'No response from the orchard.' })
end)

-- ─────────────────────────────────────────────────────────────────────────
-- Trees: spawned props (anywhere) or real world trees (sphere zones)
-- ─────────────────────────────────────────────────────────────────────────
local function targetOptions(tree)
    local fruit = Config.Fruits[tree.fruit]
    return {
        {
            name = 'velora_jamco_tree_' .. tree.id,
            label = ('Pick %s'):format(fruit.plural),
            icon = tree.anim == 'bush' and 'fa-solid fa-seedling' or 'fa-solid fa-apple-whole',
            iconColor = fruit.color,
            distance = Config.Harvest.InteractDistance + (tree.anim == 'bush' and 0.0 or 0.8),
            canInteract = function() return not VJC.busy end,
            onSelect = function() startHarvest(tree) end,
        },
    }
end

local function spawnTree(tree)
    if Spawned[tree.id] and DoesEntityExist(Spawned[tree.id]) then return end
    local model = tree.prop
    if not IsModelInCdimage(GetHashKey(model)) then
        print(('^3[velora_jamco] prop %s not found for %s, using fallback^7'):format(model, tree.id))
        model = Config.Harvest.FallbackProp
    end
    local hash = GetHashKey(model)
    if not pcall(lib.requestModel, hash, 8000) then return end
    local obj = CreateObject(hash, tree.coords.x, tree.coords.y, tree.coords.z, false, false, false)
    SetModelAsNoLongerNeeded(hash)
    SetEntityHeading(obj, tree.heading or 0.0)
    PlaceObjectOnGroundProperly(obj)
    FreezeEntityPosition(obj, true)
    SetEntityLodDist(obj, 120)
    Spawned[tree.id] = obj
    exports.ox_target:addLocalEntity(obj, targetOptions(tree))
end

local function deleteTree(tree)
    local obj = Spawned[tree.id]
    if obj and DoesEntityExist(obj) then
        exports.ox_target:removeLocalEntity(obj)
        DeleteEntity(obj)
    end
    Spawned[tree.id] = nil
end

CreateThread(function()
    for _, orchard in ipairs(Config.Orchards) do
        VJC.blip(orchard.center, orchard.blip, orchard.label)
        for _, tree in ipairs(orchard.trees) do
            if Config.Fruits[tree.fruit] then
                if tree.prop then
                    lib.points.new({
                        coords = tree.coords,
                        distance = 80.0,
                        onEnter = function() spawnTree(tree) end,
                        onExit = function() deleteTree(tree) end,
                    })
                else
                    exports.ox_target:addSphereZone({
                        coords = tree.coords,
                        radius = tree.anim == 'bush' and 1.2 or 1.8,
                        debug = Config.Debug,
                        options = targetOptions(tree),
                    })
                end
            end
        end
    end
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    for id, obj in pairs(Spawned) do
        if DoesEntityExist(obj) then DeleteEntity(obj) end
        Spawned[id] = nil
    end
    if current then VJC.stopAnim() end
end)
