MJC = MJC or {}
MJC.Client = MJC.Client or {}

local function notifyResponse(response)
    if response and response.message then MJC.Client.notify(response.message, response.ok == false and 'error' or 'success') end
end

local function openWardrobe()
    if GetResourceState('illenium-appearance') == 'started' then
        TriggerEvent('illenium-appearance:client:openClothingShopMenu', true)
        return true
    end
    if GetResourceState('fivem-appearance') == 'started' then
        TriggerEvent('fivem-appearance:client:openClothingShop')
        return true
    end
    MJC.Client.notify('No supported wardrobe integration is running.', 'error')
    return false
end

local function applyOutfit(outfit)
    if type(outfit) ~= 'table' or next(outfit) == nil then return MJC.Client.notify('No outfit is configured for this point.', 'error') end
    if GetResourceState('illenium-appearance') == 'started' then
        TriggerEvent('illenium-appearance:client:changeOutfit', outfit)
        return
    end
    MJC.Client.notify('No supported outfit integration is running.', 'error')
end

local function openPointShop(point, data)
    data = data or {}
    data.source_type = 'point'
    data.point_id = data.point_id or point.id
    data.id = data.id or point.id
    MJC.Client.creatorOpen = true
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'openCustomerShop', payload = data })
end

local function openSellMenu(point)
    local options = {}
    for _, row in ipairs((point.config or {}).items or {}) do
        if row.enabled ~= false then
            local name = row.item or row.name or row.item_name
            local price = row.price or row.sell_price or 0
            options[#options+1] = { title=('%s · $%s each'):format(name,price), icon='dollar-sign', onSelect=function()
                local input=lib.inputDialog(point.label or 'Sell',{{type='number',label='Quantity',default=1,min=1,max=(Config.Points and Config.Points.maxActionCount) or 100}})
                if input then MJC.Client.usePoint(point,{item=name,count=input[1]}) end
            end }
        end
    end
    lib.registerContext({id=('mjc_point_sell_%s'):format(point.id),title=point.label,options=options})
    lib.showContext(('mjc_point_sell_%s'):format(point.id))
end

local function openCraftMenu(point, actionType)
    local recipes = (point.config or {}).recipes or {}
    local options={}
    for index, recipe in ipairs(recipes) do
        if recipe.enabled ~= false then
            options[#options+1]={ title=recipe.label or recipe.output or ('Recipe '..index), icon='hammer', onSelect=function()
                local max=tonumber(recipe.maxBatch or recipe.max_batch) or 1
                local input=lib.inputDialog(point.label,{{type='number',label='Quantity',default=1,min=1,max=max}})
                if not input then return end
                local duration=(tonumber(recipe.duration or recipe.craftTime or recipe.craft_time) or 1000)*input[1]
                if lib.progressCircle({duration=duration,label=recipe.label or 'Working...',canCancel=true,disable={move=true,car=true,combat=true}}) then
                    MJC.Client.usePoint(point,{recipe=recipe.id or recipe.key or index,count=input[1]},true)
                end
            end }
        end
    end
    lib.registerContext({id=('mjc_point_recipe_%s'):format(point.id),title=point.label,options=options})
    lib.showContext(('mjc_point_recipe_%s'):format(point.id))
end

function MJC.Client.usePoint(point, payload, skipProgress)
    if not point then return end
    payload = payload or {}
    if point.point_type == 'sell' and not payload.item then return openSellMenu(point) end
    if (point.point_type == 'crafting' or point.point_type == 'process') and not payload.recipe and ((point.config or {}).recipes or {})[1] then return openCraftMenu(point, point.point_type) end
    if point.point_type == 'harvest' and not skipProgress then
        local duration = tonumber((point.config or {}).duration) or 1500
        if not lib.progressCircle({duration=duration,label=point.label,canCancel=true,disable={move=true,car=true,combat=true}}) then return end
    end
    local response = lib.callback.await('missys_job_creator:server:usePoint', false, point.id, point.point_type, payload)
    if not response or not response.ok then return MJC.Client.notify(response and response.error or 'Action failed.', 'error') end
    local data = response.data or {}
    if data.clientAction == 'stash' then
        local stashData = data.stashOwner and { id = data.stashId, owner = data.stashOwner } or data.stashId
        exports.ox_inventory:openInventory('stash', stashData)
    elseif data.clientAction == 'boss' then exports.qbx_management:OpenBossMenu('job')
    elseif data.clientAction == 'wardrobe' then openWardrobe()
    elseif data.clientAction == 'outfit' then applyOutfit(data.outfit)
    elseif data.clientAction == 'teleport' then
        local ped=PlayerPedId(); local entity=(data.withVehicle and IsPedInAnyVehicle(ped,false)) and GetVehiclePedIsIn(ped,false) or ped
        SetEntityCoords(entity,data.destination.x,data.destination.y,data.destination.z,false,false,false,false); SetEntityHeading(entity,data.destination.heading or 0.0)
    elseif data.clientAction == 'shop' then openPointShop(point,data)
    elseif data.clientAction == 'garage' and MJC.Client.openFleet then MJC.Client.openFleet(point) end
    notifyResponse(data)
end
