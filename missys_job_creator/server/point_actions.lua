MJC = MJC or {}
MJC.PointActions = MJC.PointActions or {}

local A = MJC.PointActions
local cooldowns = {}
A.cooldowns = cooldowns

local EMPLOYEE_ONLY = { stash=true, boss=true, duty=true, wardrobe=true, outfit=true, crafting=true, harvest=true, process=true, garage=true }

local function nowMs()
    return os.time() * 1000
end

local function gradeLevel(job)
    if type(job) ~= 'table' then return 0 end
    if type(job.grade) == 'table' then return tonumber(job.grade.level or job.grade.grade) or 0 end
    return tonumber(job.grade) or 0
end

local function pointConfig(point)
    return point.config or MJC.Validation.decode(point.config_json, {})
end

local function itemCount(inv, item)
    return tonumber(exports.ox_inventory:Search(inv, 'count', item)) or 0
end

local function addItem(inv, item, count, metadata)
    if not exports.ox_inventory:CanCarryItem(inv, item, count, metadata) then return false, 'You cannot carry that.' end
    local ok, err = exports.ox_inventory:AddItem(inv, item, count, metadata)
    return ok == true, err
end

local function removeItem(inv, item, count, metadata)
    local ok, err = exports.ox_inventory:RemoveItem(inv, item, count, metadata)
    return ok == true, err
end

local function validateIngredients(source, ingredients, multiplier)
    for _, ingredient in ipairs(ingredients or {}) do
        local name = MJC.Validation.trim(ingredient.item or ingredient.name or ingredient.item_name):lower()
        local count = math.max(1, math.floor(tonumber(ingredient.count or ingredient.amount) or 1)) * multiplier
        if name == '' or itemCount(source, name) < count then
            return false, ('You need %sx %s.'):format(count, name ~= '' and name or 'ingredient')
        end
    end
    return true
end

local function removeIngredients(source, ingredients, multiplier)
    local removed = {}
    for _, ingredient in ipairs(ingredients or {}) do
        local name = MJC.Validation.trim(ingredient.item or ingredient.name or ingredient.item_name):lower()
        local count = math.max(1, math.floor(tonumber(ingredient.count or ingredient.amount) or 1)) * multiplier
        local ok = removeItem(source, name, count, ingredient.metadata)
        if not ok then
            for _, row in ipairs(removed) do exports.ox_inventory:AddItem(source, row.name, row.count, row.metadata) end
            return false, 'Ingredients changed before the action completed.'
        end
        removed[#removed + 1] = { name=name, count=count, metadata=ingredient.metadata }
    end
    return true, removed
end

local function rollbackIngredients(source, removed)
    for _, row in ipairs(removed or {}) do exports.ox_inventory:AddItem(source, row.name, row.count, row.metadata) end
end

local function findConfigItem(items, requested)
    requested = MJC.Validation.trim(requested):lower()
    for index, row in ipairs(items or {}) do
        local name = MJC.Validation.trim(row.item or row.name or row.item_name):lower()
        local key = tostring(row.id or index)
        if name == requested or key == tostring(requested) then return row, name, index end
    end
end

local function findRecipe(recipes, requested)
    for index, recipe in ipairs(recipes or {}) do
        local key = tostring(recipe.id or recipe.key or index)
        if key == tostring(requested) then return recipe, index end
    end
end

local function cooldownKey(source, pointId, suffix)
    return ('%s:%s:%s'):format(source, pointId, suffix or 'use')
end

local function checkCooldown(source, point, seconds, suffix)
    seconds = math.max(0, tonumber(seconds) or 0)
    if seconds <= 0 then return true end
    local key = cooldownKey(source, point.id, suffix)
    local now = nowMs()
    local expiry = cooldowns[key] or 0
    if expiry > now then return false, math.ceil((expiry - now) / 1000) end
    cooldowns[key] = now + math.floor(seconds * 1000)
    return true
end

local function validatePoint(source, pointId, requestedAction)
    local point = MJC.Persistence.findPoint(pointId)
    if not point then return nil, nil, 'World point not found.' end
    if requestedAction and requestedAction ~= '' and requestedAction ~= point.point_type then return nil, nil, 'Point action mismatch.' end
    local access = point.access or {}
    if EMPLOYEE_ONLY[point.point_type] and access.mode == 'public' then return nil, nil, 'This point type must be employee-only.' end
    local ok, playerOrError = MJC.Points.canUse(source, point, Config.Points and Config.Points.serverDistance or nil)
    if not ok then return nil, nil, playerOrError end
    return point, playerOrError
end

local function ensureBoss(player, point)
    local config = pointConfig(point)
    if config.bossOnly == false then return true end
    local job = player.PlayerData.job or {}
    if job.isboss == true or job.isBoss == true then return true end
    local qbxJob = exports.qbx_core:GetJob(point.job_name)
    local grade = qbxJob and qbxJob.grades and qbxJob.grades[gradeLevel(job)]
    if grade and (grade.isboss == true or grade.isBoss == true) then return true end
    return false
end

local function pointStashId(point)
    local config = pointConfig(point)
    local stashId = MJC.Validation.trim(config.stashId or config.stash_id)
    if stashId == '' then stashId = ('mjc_point_%s'):format(point.id) end
    return stashId
end

local function protectedPlayerStashOwner(inventoryId)
    inventoryId = tostring(inventoryId or '')
    for _, point in pairs((MJC.State and MJC.State.points) or {}) do
        local access = point.access or MJC.Validation.decode(point.access_json, {})
        if point.point_type == 'stash' and MJC.Validation.isEnabled(point.enabled) and access.mode == 'player' then
            local ownerCitizenId = MJC.Validation.trim(access.ownerCitizenId or access.owner_citizenid)
            if ownerCitizenId ~= '' then
                local protectedId = ('%s:%s'):format(pointStashId(point), ownerCitizenId)
                if inventoryId == protectedId then return ownerCitizenId end
            end
        end
    end
end

function A.registerStashSecurityHook()
    return exports.ox_inventory:registerHook('openInventory', function(payload)
        if not payload or payload.inventoryType ~= 'stash' then return end
        local ownerCitizenId = protectedPlayerStashOwner(payload.inventoryId)
        if not ownerCitizenId then return end
        local player = exports.qbx_core:GetPlayer(payload.source)
        if not player or not player.PlayerData or tostring(player.PlayerData.citizenid or '') ~= ownerCitizenId then
            return false
        end
    end)
end

local function registerPointStash(point)
    local config = pointConfig(point)
    local stashId = pointStashId(point)
    local slots = math.max(1, math.min(200, math.floor(tonumber(config.slots) or 50)))
    local weight = math.max(1000, math.min(2000000, math.floor(tonumber(config.weight or config.maxWeight) or 150000)))
    local access = point.access or {}
    local ownerCitizenId = access.mode == 'player' and MJC.Validation.trim(access.ownerCitizenId or access.owner_citizenid) or nil
    local groups = access.mode == 'job' and { [point.job_name] = tonumber(access.minGrade) or 0 } or nil
    exports.ox_inventory:RegisterStash(stashId, point.label, slots, weight, ownerCitizenId, groups, vector3(point.x, point.y, point.z))
    return stashId, ownerCitizenId
end

local function actionStash(source, point)
    local stashId, stashOwner = registerPointStash(point)
    return true, { clientAction='stash', stashId=stashId, stashOwner=stashOwner, label=point.label }
end

local function actionBoss(source, point, player)
    if not ensureBoss(player, point) then return false, 'Only management can use this point.' end
    return true, { clientAction='boss' }
end

local function actionDuty(source, point, player)
    local job = player.PlayerData.job or {}
    local onDuty = not (job.onduty == true or job.onDuty == true)
    exports.qbx_core:SetJobDuty(source, onDuty)
    return true, { message = onDuty and 'You are now on duty.' or 'You are now off duty.' }
end

local function actionWardrobe()
    return true, { clientAction='wardrobe' }
end

local function actionOutfit(source, point)
    return true, { clientAction='outfit', outfit=pointConfig(point).outfit or {} }
end

local function actionCrafting(source, point, player, payload)
    local config = pointConfig(point)
    local recipe = findRecipe(config.recipes, payload.recipe or payload.recipeId or payload.index)
    if not recipe or recipe.enabled == false then return false, 'Recipe unavailable.' end
    local batch = math.max(1, math.floor(tonumber(payload.count) or 1))
    local maxBatch = math.max(1, math.floor(tonumber(recipe.maxBatch or recipe.max_batch) or 1))
    if batch > maxBatch then return false, ('Maximum batch is %s.'):format(maxBatch) end
    local player = exports.qbx_core:GetPlayer(source)
    local minGrade = tonumber(recipe.minGrade or recipe.min_grade) or 0
    if gradeLevel(player and player.PlayerData and player.PlayerData.job) < minGrade then return false, 'Your grade cannot craft this.' end
    local output = MJC.Validation.trim(recipe.output or recipe.output_item):lower()
    local outputCount = math.max(1, math.floor(tonumber(recipe.outputCount or recipe.output_quantity) or 1)) * batch
    if output == '' or not exports.ox_inventory:Items(output) then return false, 'Recipe output item is invalid.' end
    local ok, err = validateIngredients(source, recipe.ingredients, batch); if not ok then return false, err end
    if not exports.ox_inventory:CanCarryItem(source, output, outputCount, recipe.metadata) then return false, 'You cannot carry the crafted items.' end
    local removedOk, removed = removeIngredients(source, recipe.ingredients, batch); if not removedOk then return false, removed end
    local added = exports.ox_inventory:AddItem(source, output, outputCount, recipe.metadata)
    if not added then rollbackIngredients(source, removed); return false, 'Crafting failed and ingredients were returned.' end
    return true, { message=('Crafted %sx %s.'):format(outputCount, output) }
end

local function actionHarvest(source, point)
    local config = pointConfig(point)
    local ok, left = checkCooldown(source, point, tonumber(config.cooldown) or 3, 'harvest')
    if not ok then return false, ('Wait %ss before harvesting again.'):format(left) end
    local tool = MJC.Validation.trim(config.tool):lower()
    if tool ~= '' and itemCount(source, tool) < 1 then return false, ('You need %s.'):format(tool) end
    local output = MJC.Validation.trim(config.output or config.item):lower()
    if output == '' or not exports.ox_inventory:Items(output) then return false, 'Harvest output item is invalid.' end
    local minimum = math.max(1, math.floor(tonumber(config.min or config.minQuantity) or 1))
    local maximum = math.max(minimum, math.floor(tonumber(config.max or config.maxQuantity) or minimum))
    local count = math.random(minimum, maximum)
    local added, err = addItem(source, output, count, config.metadata)
    if not added then return false, err == 'inventory_full' and 'You cannot carry any more.' or 'Harvest failed.' end
    local consumeChance = tonumber(config.toolConsumeChance) or 0
    if tool ~= '' and consumeChance > 0 and math.random(1,100) <= consumeChance then removeItem(source, tool, 1) end
    return true, { message=('Collected %sx %s.'):format(count, output) }
end

local function actionProcess(source, point, player, payload)
    local config = pointConfig(point)
    local recipe = (#(config.recipes or {}) > 0) and findRecipe(config.recipes, payload.recipe or payload.recipeId or payload.index) or config
    if not recipe or recipe.enabled == false then return false, 'Process recipe unavailable.' end
    local batch = math.max(1, math.floor(tonumber(payload.count) or 1))
    local maxBatch = math.max(1, math.floor(tonumber(recipe.maxBatch or recipe.max_batch) or 10))
    if batch > maxBatch then return false, ('Maximum batch is %s.'):format(maxBatch) end
    local inputs = recipe.inputs or recipe.ingredients or {}
    local outputs = recipe.outputs or {{ item=recipe.output or recipe.output_item, count=recipe.outputCount or recipe.output_quantity or 1 }}
    local ok, err = validateIngredients(source, inputs, batch); if not ok then return false, err end
    for _, row in ipairs(outputs) do
        local name = MJC.Validation.trim(row.item or row.name or row.item_name):lower()
        local count = math.max(1, math.floor(tonumber(row.count or row.amount) or 1)) * batch
        if name == '' or not exports.ox_inventory:Items(name) then return false, 'Process output item is invalid.' end
        if not exports.ox_inventory:CanCarryItem(source, name, count, row.metadata) then return false, 'You cannot carry the processed items.' end
    end
    local removedOk, removed = removeIngredients(source, inputs, batch); if not removedOk then return false, removed end
    local addedRows = {}
    for _, row in ipairs(outputs) do
        local name = MJC.Validation.trim(row.item or row.name or row.item_name):lower()
        local count = math.max(1, math.floor(tonumber(row.count or row.amount) or 1)) * batch
        local added = exports.ox_inventory:AddItem(source, name, count, row.metadata)
        if not added then
            for _, addedRow in ipairs(addedRows) do exports.ox_inventory:RemoveItem(source, addedRow.name, addedRow.count, addedRow.metadata) end
            rollbackIngredients(source, removed)
            return false, 'Processing failed and ingredients were returned.'
        end
        addedRows[#addedRows + 1] = {name=name,count=count,metadata=row.metadata}
    end
    return true, { message='Processing complete.' }
end

local function businessInventory(jobName)
    local business = MJC.Persistence.findBusinessByJob(jobName)
    if not business then return nil end
    local stashId = business.stash_id
    if not stashId or stashId == '' then return nil end
    return stashId, business
end

local function actionShop(source, point, player, payload)
    local config = pointConfig(point)
    if payload.op == 'view' or not payload.item then
        local stockMode = config.stockMode == 'business' and 'business' or 'infinite'
        local businessJob = config.businessJob or point.job_name or ''
        local paymentType = MJC.Constants.PaymentTypes[config.paymentType] and config.paymentType or Config.DefaultPaymentType
        local result = {
            clientAction='shop', source_type='point', point_id=point.id, id=point.id,
            label=point.label, business_job=businessJob, stock_mode=stockMode,
            payment_type=paymentType, max_purchase_count=Config.MaxPurchaseCount, items={}
        }
        local businessStash = stockMode == 'business' and businessInventory(businessJob) or nil
        for _, row in ipairs(config.items or {}) do
            if row.enabled ~= false then
                local name = MJC.Validation.trim(row.item or row.name or row.item_name):lower()
                local itemData = exports.ox_inventory:Items(name)
                local stock = businessStash and itemCount(businessStash, name) or nil
                result.items[#result.items+1] = {
                    name=name, label=itemData and itemData.label or name,
                    price=math.max(0,math.floor(tonumber(row.price or row.buy_price) or 0)),
                    count=stock, unlimited=stockMode ~= 'business'
                }
            end
        end
        return true, result
    end
    local row, name = findConfigItem(config.items, payload.item)
    if not row or row.enabled == false then return false, 'That item is not sold here.' end
    local count = math.max(1, math.floor(tonumber(payload.count) or 1))
    if count > Config.MaxPurchaseCount then return false, 'That quantity is too large.' end
    local price = math.max(0, math.floor(tonumber(row.price or row.buy_price) or 0))
    local total = price * count
    local paymentType = MJC.Constants.PaymentTypes[config.paymentType] and config.paymentType or Config.DefaultPaymentType
    if not exports.ox_inventory:CanCarryItem(source, name, count) then return false, 'You cannot carry that many.' end
    local stashId
    if config.stockMode == 'business' then
        stashId = businessInventory(config.businessJob or point.job_name)
        if not stashId then return false, 'Business stock is unavailable.' end
        if itemCount(stashId, name) < count then return false, 'Not enough business stock.' end
    end
    if total > 0 and MJC.Payments.balance(source, paymentType) < total then
        return false, ('Not enough %s.'):format(MJC.Payments.label(paymentType))
    end
    if not MJC.Payments.take(source, paymentType, total, 'job-creator-point-shop') then return false, 'Payment failed.' end
    if stashId and not removeItem(stashId, name, count) then
        if total > 0 then MJC.Payments.refund(source, paymentType, total, 'job-creator-point-shop-rollback') end
        return false, 'Stock changed; payment returned.'
    end
    local added = exports.ox_inventory:AddItem(source, name, count, row.metadata)
    if not added then
        if stashId then exports.ox_inventory:AddItem(stashId, name, count, row.metadata) end
        if total > 0 then MJC.Payments.refund(source, paymentType, total, 'job-creator-point-shop-rollback') end
        return false, 'Purchase could not be delivered; payment returned.'
    end
    if total > 0 and config.revenueMode == 'business' then
        local businessJob = config.businessJob or point.job_name
        MJC.Revenue.route({ revenue_mode='business', business_job=businessJob, revenue={account=businessJob} }, total, 'job-creator-point-shop')
    end
    return true, { message=('Purchased %sx %s for $%s.'):format(count, name, total), refresh=true }
end

local function actionSell(source, point, player, payload)
    local config = pointConfig(point)
    local row, name = findConfigItem(config.items, payload.item)
    if not row or row.enabled == false then return false, 'This market does not buy that item.' end
    local count = math.max(1, math.floor(tonumber(payload.count) or 1))
    if count > (Config.Points and Config.Points.maxActionCount or 100) then return false, 'That quantity is too large.' end
    if itemCount(source, name) < count then return false, 'You do not have enough of that item.' end
    local price = math.max(0, math.floor(tonumber(row.price or row.sell_price) or 0))
    local total = price * count
    if not removeItem(source, name, count) then return false, 'Items changed before the sale completed.' end
    local paymentType = MJC.Constants.PaymentTypes[config.paymentType] and config.paymentType or Config.DefaultPaymentType
    if total > 0 and not MJC.Payments.give(source, paymentType, total, 'job-creator-point-sell') then
        exports.ox_inventory:AddItem(source, name, count)
        return false, 'Payment failed; items returned.'
    end
    return true, { message=('Sold %sx %s for $%s.'):format(count, name, total) }
end

local function actionTeleport(source, point)
    local dest = pointConfig(point).destination or {}
    local x,y,z = tonumber(dest.x),tonumber(dest.y),tonumber(dest.z)
    if not x or not y or not z then return false, 'Teleport destination is not configured.' end
    return true, { clientAction='teleport', destination={x=x,y=y,z=z,heading=tonumber(dest.heading) or 0.0}, withVehicle=dest.withVehicle==true }
end

local handlers = {
    stash=actionStash, boss=actionBoss, duty=actionDuty, wardrobe=actionWardrobe, outfit=actionOutfit,
    crafting=actionCrafting, shop=actionShop, sell=actionSell, harvest=actionHarvest, process=actionProcess,
    teleport=actionTeleport,
    garage=function() return true, { clientAction='garage' } end,
}

function A.use(source, pointId, requestedAction, payload)
    payload = type(payload) == 'table' and payload or {}
    local point, player, err = validatePoint(source, tonumber(pointId), requestedAction)
    if not point then return false, err end
    local handler = handlers[point.point_type]
    if not handler then return false, 'Unsupported point action.' end
    return handler(source, point, player, payload)
end
