MJC = MJC or {}
MJC.Shops = {}

local S = MJC.Shops
local revenueHookId

local function shopType(id)
    return ('MJC_%s'):format(id)
end

local function itemExists(name)
    return exports.ox_inventory:Items(name) ~= nil
end

local function accessJob(shop, access)
    if access.mode == 'staff' then
        local businessJob = MJC.Validation.trim(shop.business_job)
        return businessJob ~= '' and businessJob or nil
    end
    local configuredJob = MJC.Validation.trim(access.job)
    return configuredJob ~= '' and configuredJob or nil
end

local function buildGroups(shop)
    local access = shop.access or MJC.Validation.decode(shop.access_json, { mode = 'public' })
    if not access.mode or access.mode == 'public' then return nil end
    local job = accessJob(shop, access)
    if not job then return nil end
    return { [job] = tonumber(access.minGrade) or 0 }
end

function S.hasAccess(source, shop)
    local access = shop.access or MJC.Validation.decode(shop.access_json, { mode = 'public' })
    if not access.mode or access.mode == 'public' then return true end
    local job = accessJob(shop, access)
    if not job then return false end
    return exports.qbx_core:HasGroup(source, { [job] = tonumber(access.minGrade) or 0 }) == true
end

function S.isNearby(source, shop)
    local npc = shop and MJC.State.npcs[tonumber(shop.npc_id)]
    if not npc then return false end
    return MJC.Npcs.isNearby(source, npc, Config.PurchaseDistance)
end

function S.registerInfinite(shop)
    if not MJC.Validation.isEnabled(shop.enabled) or shop.stock_mode ~= 'infinite' then return end
    local npc = MJC.State.npcs[tonumber(shop.npc_id)]
    if not npc or not MJC.Validation.isEnabled(npc.enabled) then return end

    local paymentType = MJC.Constants.PaymentTypes[shop.payment_type] and shop.payment_type or Config.DefaultPaymentType
    -- ox_inventory shops natively support item currencies (used for black_money), but not QBX bank balances.
    -- Bank-paid infinite shops use the creator's custom checkout instead.
    if paymentType == 'bank' then return end
    local currency = paymentType == 'black_money' and 'black_money' or nil

    local inventory = {}
    for i = 1, #shop.items do
        local item = shop.items[i]
        if MJC.Validation.isEnabled(item.enabled) and itemExists(item.item_name) then
            inventory[#inventory + 1] = {
                name = item.item_name,
                price = tonumber(item.buy_price) or 0,
                currency = currency,
            }
        end
    end

    exports.ox_inventory:RegisterShop(shopType(shop.id), {
        name = shop.label,
        inventory = inventory,
        locations = { vector3(tonumber(npc.x), tonumber(npc.y), tonumber(npc.z)) },
        groups = buildGroups(shop),
    })
end

function S.registerRevenueHook()
    if revenueHookId then return end
    revenueHookId = exports.ox_inventory:registerHook('buyItem', function(payload)
        if type(payload.shopType) == 'string' and payload.shopType:match('^MJC_%d+$') then
            local id = tonumber(payload.shopType:match('^MJC_(%d+)$'))
            local shop = id and MJC.State.shops[id]
            if shop and shop.stock_mode == 'infinite' and not S.hasAccess(payload.source, shop) then return false end
        end
    end)

    AddEventHandler(revenueHookId, function(success, payload)
        if not success or type(payload.shopType) ~= 'string' then return end
        local id = tonumber(payload.shopType:match('^MJC_(%d+)$'))
        local shop = id and MJC.State.shops[id]
        if not shop or shop.stock_mode ~= 'infinite' then return end
        local routed = MJC.Revenue.route(shop, tonumber(payload.totalPrice) or 0, 'npc-shop-sale')
        if not routed then
            print(('[missys_job_creator] Revenue route failed for shop %s after a successful ox purchase.'):format(id))
        end
    end)
end

function S.restore()
    S.registerRevenueHook()
    local count = 0
    for _, shop in pairs(MJC.State.shops) do
        if MJC.Validation.isEnabled(shop.enabled) and shop.stock_mode == 'infinite' then
            S.registerInfinite(shop)
            count = count + 1
        end
    end
    return count
end

function S.save(payload)
    local label, labelError = MJC.Validation.label(payload.label, 'Shop label')
    if not label then return false, labelError end
    local npcId = tonumber(payload.npc_id)
    if not npcId or not MJC.State.npcs[npcId] then return false, 'Choose a valid NPC.' end
    local id = tonumber(payload.id)
    local existingShop = id and MJC.State.shops[id] or nil
    if id and not existingShop then return false, 'That shop no longer exists.' end
    local previousNpcId = existingShop and tonumber(existingShop.npc_id) or nil
    local conflictingShopId = MySQL.scalar.await('SELECT id FROM missys_job_creator_shops WHERE npc_id = ? AND id <> ? LIMIT 1', { npcId, id or 0 })
    if conflictingShopId then return false, 'That NPC is already assigned to another shop.' end

    local stockMode = MJC.Validation.trim(payload.stock_mode or 'infinite')
    if not MJC.Constants.StockModes[stockMode] then return false, 'Invalid stock mode.' end
    local revenueMode = MJC.Validation.trim(payload.revenue_mode or 'system')
    if not MJC.Constants.RevenueModes[revenueMode] then return false, 'Invalid revenue mode.' end
    local paymentType = MJC.Validation.trim(payload.payment_type or Config.DefaultPaymentType)
    if not MJC.Constants.PaymentTypes[paymentType] then return false, 'Invalid payment type.' end
    if paymentType == 'black_money' and not itemExists('black_money') then
        return false, 'ox_inventory item "black_money" does not exist.'
    end

    local businessJob = MJC.Validation.trim(payload.business_job)
    local linkedBusiness = businessJob ~= '' and MJC.Persistence.findBusinessByJob(businessJob) or nil
    local stashId = nil
    if stockMode == 'business' or revenueMode ~= 'system' then
        if businessJob == '' then return false, 'Choose a QBX business/job for business stock or revenue.' end
        if not linkedBusiness then
            local linked, businessOrError = MJC.Businesses.ensureLink(businessJob)
            if not linked then return false, businessOrError or 'Could not link that QBX business.' end
            linkedBusiness = businessOrError
        end
        stashId = linkedBusiness.stash_id
    end

    local items = type(payload.items) == 'table' and payload.items or {}
    if #items == 0 then return false, 'Add at least one shop item.' end
    local normalizedItems = {}
    local seen = {}
    for i = 1, #items do
        local name = MJC.Validation.trim(items[i].item_name):lower()
        if name == '' or not itemExists(name) then return false, ('ox_inventory item "%s" does not exist.'):format(name) end
        if seen[name] then return false, ('Item "%s" is duplicated.'):format(name) end
        seen[name] = true
        local price, priceError = MJC.Validation.price(items[i].buy_price)
        if not price then return false, priceError end
        normalizedItems[#normalizedItems + 1] = { item_name = name, buy_price = price, sell_price = tonumber(items[i].sell_price) }
    end

    local access = type(payload.access) == 'table' and payload.access or { mode = 'public' }
    if not MJC.Constants.AccessModes[access.mode or 'public'] then return false, 'Invalid access mode.' end
    local hours = type(payload.hours) == 'table' and payload.hours or { enabled = false }
    local revenue = type(payload.revenue) == 'table' and payload.revenue or {}
    if revenueMode ~= 'system' then
        local requestedAccount = MJC.Validation.trim(revenue.account)
        if requestedAccount == '' or requestedAccount == businessJob then
            local businessAccount = linkedBusiness and MJC.Validation.trim(linkedBusiness.revenue_account) or ''
            revenue.account = businessAccount ~= '' and businessAccount or businessJob
        else
            revenue.account = requestedAccount
        end
    end

    local enabled = payload.enabled == false and 0 or 1
    local uiMode = 'custom'
    if id then
        MySQL.update.await([[
            UPDATE missys_job_creator_shops
            SET npc_id=?, label=?, stock_mode=?, business_job=?, stash_id=?, revenue_mode=?, revenue_json=?, ui_mode=?, payment_type=?, access_json=?, hours_json=?, enabled=?
            WHERE id=?
        ]], { npcId, label, stockMode, businessJob ~= '' and businessJob or nil, stashId, revenueMode, json.encode(revenue), uiMode, paymentType, json.encode(access), json.encode(hours), enabled, id })
    else
        id = MySQL.insert.await([[
            INSERT INTO missys_job_creator_shops
            (npc_id, label, stock_mode, business_job, stash_id, revenue_mode, revenue_json, ui_mode, payment_type, access_json, hours_json, enabled)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ]], { npcId, label, stockMode, businessJob ~= '' and businessJob or nil, stashId, revenueMode, json.encode(revenue), uiMode, paymentType, json.encode(access), json.encode(hours), enabled })
    end

    MySQL.query.await('DELETE FROM missys_job_creator_shop_items WHERE shop_id = ?', { id })
    for i = 1, #normalizedItems do
        local item = normalizedItems[i]
        MySQL.insert.await([[
            INSERT INTO missys_job_creator_shop_items (shop_id, item_name, buy_price, sell_price, sort_order, enabled)
            VALUES (?, ?, ?, ?, ?, 1)
        ]], { id, item.item_name, item.buy_price, item.sell_price, i })
    end

    if previousNpcId and previousNpcId ~= npcId then
        MySQL.update.await("UPDATE missys_job_creator_npcs SET role_type='none', role_ref=NULL WHERE id=? AND role_type='shop' AND role_ref=?", { previousNpcId, tostring(id) })
    end
    MySQL.update.await("UPDATE missys_job_creator_npcs SET role_type='shop', role_ref=? WHERE id=?", { tostring(id), npcId })
    return true, id
end

function S.delete(id)
    id = tonumber(id)
    local shop = id and MJC.State.shops[id]
    if not shop then return false, 'Shop not found.' end
    MySQL.query.await('DELETE FROM missys_job_creator_shops WHERE id = ?', { id })
    MySQL.update.await("UPDATE missys_job_creator_npcs SET role_type='none', role_ref=NULL WHERE id=? AND role_type='shop' AND role_ref=?", { shop.npc_id, tostring(id) })
    return true
end

local function getLoadedBusinessInventory(business)
    if not business then return nil end
    MJC.Businesses.registerStash(business)
    local inventory = exports.ox_inventory:GetInventory(business.stash_id, false)
    return inventory
end

function S.businessView(source, id)
    local shop = MJC.State.shops[tonumber(id)]
    if not shop or not MJC.Validation.isEnabled(shop.enabled) then return false, 'Shop is unavailable.' end
    if shop.stock_mode ~= 'business' and shop.stock_mode ~= 'infinite' then return false, 'Shop is unavailable.' end
    if not S.hasAccess(source, shop) then return false, 'You cannot use this shop.' end
    if not S.isNearby(source, shop) then return false, 'Move closer to the shop.' end

    local inventory
    if shop.stock_mode == 'business' then
        local business = MJC.Persistence.findBusinessByJob(shop.business_job)
        inventory = getLoadedBusinessInventory(business)
        if not inventory then return false, 'Business stock inventory is unavailable. Check the linked business stash.' end
    end

    local result = {
        id = shop.id,
        label = shop.label,
        business_job = shop.business_job,
        payment_type = shop.payment_type,
        stock_mode = shop.stock_mode,
        max_purchase_count = Config.MaxPurchaseCount,
        items = {},
    }
    for i = 1, #shop.items do
        local configured = shop.items[i]
        if MJC.Validation.isEnabled(configured.enabled) then
            local itemData = exports.ox_inventory:Items(configured.item_name)
            local unlimited = shop.stock_mode == 'infinite'
            local count
            if not unlimited then
                count = exports.ox_inventory:GetItemCount(inventory.id, configured.item_name, nil, false) or 0
            end
            result.items[#result.items + 1] = {
                name = configured.item_name,
                label = itemData and itemData.label or configured.item_name,
                price = tonumber(configured.buy_price) or 0,
                count = count,
                unlimited = unlimited,
                image = configured.item_name .. '.png',
            }
        end
    end
    return true, result
end

function S.purchaseBusiness(source, id, itemName, requestedCount)
    local shop = MJC.State.shops[tonumber(id)]
    if not shop or not MJC.Validation.isEnabled(shop.enabled) then return false, 'Shop is unavailable.' end
    if shop.stock_mode ~= 'business' and shop.stock_mode ~= 'infinite' then return false, 'Shop is unavailable.' end
    if not S.hasAccess(source, shop) then return false, 'You cannot use this shop.' end
    if not S.isNearby(source, shop) then return false, 'Move closer to the shop.' end

    local count, countError = MJC.Validation.integer(requestedCount, 1, Config.MaxPurchaseCount, 'Quantity')
    if not count then return false, countError end
    itemName = MJC.Validation.trim(itemName):lower()
    local configured
    for i = 1, #shop.items do
        if MJC.Validation.isEnabled(shop.items[i].enabled) and shop.items[i].item_name == itemName then configured = shop.items[i] break end
    end
    if not configured then return false, 'That item is not sold here.' end

    local inventory
    if shop.stock_mode == 'business' then
        local business = MJC.Persistence.findBusinessByJob(shop.business_job)
        inventory = getLoadedBusinessInventory(business)
        if not inventory then return false, 'Business stock inventory is unavailable. Check the linked business stash.' end
        local stock = exports.ox_inventory:GetItemCount(inventory.id, itemName, nil, false) or 0
        if stock < count then return false, ('Only %s left in stock.'):format(stock) end
    end
    if not exports.ox_inventory:CanCarryItem(source, itemName, count) then return false, 'You cannot carry that many.' end

    local total = (tonumber(configured.buy_price) or 0) * count
    local paymentType = MJC.Constants.PaymentTypes[shop.payment_type] and shop.payment_type or Config.DefaultPaymentType
    if total > 0 and MJC.Payments.balance(source, paymentType) < total then
        return false, ('Not enough %s.'):format(MJC.Payments.label(paymentType))
    end
    if total > 0 and not MJC.Payments.take(source, paymentType, total, 'npc-shop') then return false, 'Payment failed.' end

    if inventory then
        local removed = exports.ox_inventory:RemoveItem(inventory.id, itemName, count)
        if not removed then
            if total > 0 then MJC.Payments.refund(source, paymentType, total, 'npc-shop-rollback') end
            return false, 'That stock was just sold. You have not been charged.'
        end
    end

    local added = exports.ox_inventory:AddItem(source, itemName, count)
    if not added then
        if inventory then exports.ox_inventory:AddItem(inventory.id, itemName, count) end
        if total > 0 then MJC.Payments.refund(source, paymentType, total, 'npc-shop-rollback') end
        return false, 'Purchase could not be delivered. The sale was rolled back.'
    end

    if total > 0 and not MJC.Revenue.route(shop, total, shop.stock_mode == 'business' and 'npc-business-shop' or 'npc-infinite-shop') then
        print(('[missys_job_creator] Revenue routing failed after shop %s sale; item sale remains valid.'):format(shop.id))
    end
    return true, ('Purchased %sx %s for $%s.'):format(count, (exports.ox_inventory:Items(itemName) or {}).label or itemName, total)
end
