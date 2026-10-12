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
    local obj = Spawned[tree.id]
    local target = (type(obj) == 'number' and DoesEntityExist(obj)) and GetEntityCoords(obj) or tree.coords
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

-- Ground height under a point, waiting for map collision to stream in first
local function groundZ(x, y, zHint)
    RequestCollisionAtCoord(x, y, zHint)
    for _ = 1, 30 do
        local found, z = GetGroundZFor_3dCoord(x, y, zHint + 25.0, false)
        if found then return z end
        RequestCollisionAtCoord(x, y, zHint)
        Wait(100)
    end
    return nil
end

local function spawnTree(tree)
    if Spawned[tree.id] then return end
    Spawned[tree.id] = 'loading'
    CreateThread(function()
        local model = tree.prop
        if not IsModelInCdimage(GetHashKey(model)) then
            print(('^3[velora_jamco] prop %s not found for %s, using fallback^7'):format(model, tree.id))
            model = Config.Harvest.FallbackProp
        end
        local hash = GetHashKey(model)
        if not pcall(lib.requestModel, hash, 8000) then Spawned[tree.id] = nil return end
        -- wait for the ground to exist, otherwise the prop floats at the configured height
        local z = groundZ(tree.coords.x, tree.coords.y, tree.coords.z) or tree.coords.z
        if Spawned[tree.id] ~= 'loading' then SetModelAsNoLongerNeeded(hash) return end -- left the area meanwhile
        local obj = CreateObject(hash, tree.coords.x, tree.coords.y, z, false, false, false)
        SetModelAsNoLongerNeeded(hash)
        SetEntityHeading(obj, tree.heading or 0.0)
        local deadline = GetGameTimer() + 3000
        while not HasCollisionLoadedAroundEntity(obj) and GetGameTimer() < deadline do Wait(50) end
        PlaceObjectOnGroundProperly(obj)
        FreezeEntityPosition(obj, true)
        SetEntityLodDist(obj, 120)
        if Spawned[tree.id] ~= 'loading' then DeleteEntity(obj) return end
        Spawned[tree.id] = obj
        exports.ox_target:addLocalEntity(obj, targetOptions(tree))
    end)
end

local function deleteTree(tree)
    local obj = Spawned[tree.id]
    Spawned[tree.id] = nil
    if obj and obj ~= 'loading' and DoesEntityExist(obj) then
        exports.ox_target:removeLocalEntity(obj)
        DeleteEntity(obj)
    end
end

-- ─────────────────────────────────────────────────────────────────────────
-- Tree registry (comes from the server: config trees + trees placed in-game)
-- ─────────────────────────────────────────────────────────────────────────
local Registered = {}   -- id -> { tree, point | zone }
local OrchardBlips = {}

local function clearTrees()
    for id, entry in pairs(Registered) do
        if entry.point then entry.point:remove() end
        if entry.zone then exports.ox_target:removeZone(entry.zone) end
        deleteTree(entry.tree)
        Registered[id] = nil
    end
    for _, blip in ipairs(OrchardBlips) do RemoveBlip(blip) end
    OrchardBlips = {}
end

local function buildTrees(list)
    if current then return end -- never pull a tree out from under someone mid-harvest; next update applies
    clearTrees()
    local centres = {}
    for _, t in ipairs(list or {}) do
        if Config.Fruits[t.fruit] then
            local tree = {
                id = t.id, fruit = t.fruit, coords = vec3(t.x, t.y, t.z), heading = t.heading,
                prop = t.prop, anim = t.anim,
            }
            local entry = { tree = tree }
            if tree.prop then
                entry.point = lib.points.new({
                    coords = tree.coords,
                    distance = 80.0,
                    onEnter = function() spawnTree(tree) end,
                    onExit = function() deleteTree(tree) end,
                })
            else
                entry.zone = exports.ox_target:addSphereZone({
                    coords = tree.coords + vec3(0.0, 0.0, 1.0),
                    radius = tree.anim == 'bush' and 1.2 or 1.8,
                    debug = Config.Debug,
                    options = targetOptions(tree),
                })
            end
            Registered[t.id] = entry
            local c = centres[t.orchard] or { x = 0, y = 0, z = 0, n = 0 }
            c.x, c.y, c.z, c.n = c.x + t.x, c.y + t.y, c.z + t.z, c.n + 1
            centres[t.orchard] = c
        end
    end
    for _, orchard in ipairs(Config.Orchards) do
        local c = centres[orchard.id]
        if c then
            local blip = VJC.blip(vec3(c.x / c.n, c.y / c.n, c.z / c.n), orchard.blip, orchard.label)
            if blip then OrchardBlips[#OrchardBlips + 1] = blip end
        end
    end
end

local pendingList = nil
RegisterNetEvent('velora_jamco:client:trees', function(list)
    if current then pendingList = list return end
    buildTrees(list)
end)

-- apply an update that arrived while harvesting
CreateThread(function()
    while true do
        Wait(2000)
        if pendingList and not current then
            local list = pendingList
            pendingList = nil
            buildTrees(list)
        end
    end
end)

CreateThread(function()
    local list = lib.callback.await('velora_jamco:trees:list', false)
    buildTrees(list)
end)

-- ─────────────────────────────────────────────────────────────────────────
-- Admin placement mode: /jamplace [fruit]
-- ─────────────────────────────────────────────────────────────────────────
local placing = false

local function propFor(fruit)
    return Config.Harvest.BushFruits[fruit] and Config.Harvest.DefaultProps.bush or Config.Harvest.DefaultProps.tree
end

RegisterNetEvent('velora_jamco:client:placeTrees', function(fruit)
    if placing then return end
    placing = true
    local order = Config.FruitOrder
    local fi = 1
    for i, id in ipairs(order) do if id == fruit then fi = i end end
    local heading, worldMode, ghost, ghostModel = 0.0, false, nil, nil

    local function setGhost()
        local model = propFor(order[fi])
        if ghost and ghostModel == model then return end
        if ghost and DoesEntityExist(ghost) then DeleteEntity(ghost) end
        local hash = GetHashKey(model)
        if not IsModelInCdimage(hash) then hash = GetHashKey(Config.Harvest.FallbackProp) end
        lib.requestModel(hash, 8000)
        ghost = CreateObject(hash, GetEntityCoords(cache.ped), false, false, false)
        SetModelAsNoLongerNeeded(hash)
        SetEntityAlpha(ghost, 170, false)
        SetEntityCollision(ghost, false, false)
        FreezeEntityPosition(ghost, true)
        ghostModel = model
    end

    local function prompt()
        local label = Config.Fruits[order[fi]].label
        lib.showTextUI(('Placing: %s %s  \n[E] Place  ·  [Scroll] Rotate  ·  [←/→] Fruit  ·  [G] %s  ·  [Backspace] Finish'):format(
            label, worldMode and '(real GTA tree here)' or '(spawned prop)', worldMode and 'Use prop' or 'Use real tree'),
            { position = 'left-center', icon = 'seedling', iconColor = '#f06aa6' })
    end

    setGhost()
    prompt()
    VJC.notify('Look at the ground where the tree should stand and press E. Placed trees are saved instantly.', 'inform', 'Tree placement')

    CreateThread(function()
        while placing do
            Wait(0)
            DisableControlAction(0, 24, true); DisableControlAction(0, 25, true)
            DisableControlAction(0, 14, true); DisableControlAction(0, 15, true)
            DisableControlAction(0, 16, true); DisableControlAction(0, 17, true)
            DisableControlAction(0, 37, true); DisableControlAction(0, 47, true)
            local hit, _, coords = lib.raycast.cam(1, cache.ped, 30.0)
            if hit and coords then
                if worldMode then
                    if ghost then SetEntityVisible(ghost, false, false) end
                    DrawMarker(1, coords.x, coords.y, coords.z - 0.05, 0, 0, 0, 0, 0, 0, 1.4, 1.4, 1.6, 240, 106, 166, 120, false, false, 2, false, nil, nil, false)
                else
                    SetEntityVisible(ghost, true, false)
                    SetEntityCoords(ghost, coords.x, coords.y, coords.z, false, false, false, false)
                    SetEntityHeading(ghost, heading)
                    PlaceObjectOnGroundProperly(ghost)
                end
            end
            if IsDisabledControlJustPressed(0, 14) then heading = (heading + 10.0) % 360 end
            if IsDisabledControlJustPressed(0, 15) then heading = (heading - 10.0) % 360 end
            if IsControlJustPressed(0, 174) then fi = fi > 1 and fi - 1 or #order; setGhost(); prompt() end
            if IsControlJustPressed(0, 175) then fi = fi < #order and fi + 1 or 1; setGhost(); prompt() end
            if IsDisabledControlJustPressed(0, 47) then worldMode = not worldMode; prompt() end
            if IsControlJustPressed(0, 38) and hit and coords then
                local pos = worldMode and coords or GetEntityCoords(ghost)
                local res = lib.callback.await('velora_jamco:trees:add', false, {
                    fruit = order[fi], x = pos.x, y = pos.y, z = pos.z, heading = heading, world = worldMode,
                })
                if res and res.ok then
                    PlaySoundFrontend(-1, 'SELECT', 'HUD_FRONTEND_DEFAULT_SOUNDSET', true)
                    VJC.notify(('%s placed (#%d).'):format(Config.Fruits[order[fi]].label, res.id), 'success', 'Tree placement')
                else
                    VJC.notify(res and res.msg or 'Could not place tree.', 'error', 'Tree placement')
                end
            end
            if IsControlJustPressed(0, 177) or IsControlJustPressed(0, 194) then placing = false end
        end
        lib.hideTextUI()
        if ghost and DoesEntityExist(ghost) then DeleteEntity(ghost) end
        VJC.notify('Tree placement finished.', 'inform', 'Tree placement')
    end)
end)

RegisterNetEvent('velora_jamco:client:removeTree', function()
    local res = lib.callback.await('velora_jamco:trees:remove', false)
    VJC.notify(res and res.ok and 'Tree removed.' or (res and res.msg or 'Could not remove tree.'), res and res.ok and 'success' or 'error', 'Tree placement')
end)

AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    for id, obj in pairs(Spawned) do
        if obj ~= 'loading' and DoesEntityExist(obj) then DeleteEntity(obj) end
        Spawned[id] = nil
    end
    if placing then placing = false; lib.hideTextUI() end
    if current then VJC.stopAnim() end
end)
