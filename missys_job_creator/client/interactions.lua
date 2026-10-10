MJC = MJC or {}
MJC.Client = MJC.Client or {}
MJC.Client.targetZones = MJC.Client.targetZones or {}

local function hourAllowed(hours)
    if not hours or not hours.enabled then return true end
    local current = GetClockHours()
    local startHour = tonumber(hours.start) or 0
    local endHour = tonumber(hours.finish) or 24
    if startHour == endHour then return true end
    if startHour < endHour then return current >= startHour and current < endHour end
    return current >= startHour or current < endHour
end
MJC.Client.hourAllowed = hourAllowed

function MJC.Client.openBusinessStock(businessJob, fallbackStashId)
    local response = lib.callback.await('missys_job_creator:server:prepareBusinessStock', false, businessJob)
    if not response or not response.ok then
        return MJC.Client.notify(response and response.error or 'Business stock is unavailable.', 'error')
    end

    local stashId = response.stashId or fallbackStashId
    if not stashId or stashId == '' then
        return MJC.Client.notify('Business stock stash is unavailable.', 'error')
    end

    local opened = exports.ox_inventory:openInventory('stash', stashId)
    if opened == false then
        MJC.Client.notify('Cannot open business stock here.', 'error')
    end
end

function MJC.Client.addNpcTarget(ped, npc)
    local options = {{
        name = ('mjc_npc_%s'):format(npc.id),
        label = npc.interaction_label or npc.label,
        icon = npc.role_type == 'shop' and 'fa-solid fa-basket-shopping' or npc.role_type == 'hire' and 'fa-solid fa-user-tie' or 'fa-solid fa-comments',
        distance = Config.InteractionDistance,
        onSelect = function() MJC.Client.interactNpc(npc) end,
    }}

    if npc.role_type == 'shop' then
        local shop = MJC.Client.state.shops[tonumber(npc.role_ref)]
        if not shop then
            for _, candidate in pairs(MJC.Client.state.shops or {}) do
                if tonumber(candidate.npc_id) == tonumber(npc.id) then shop = candidate break end
            end
        end
        if shop and shop.stock_mode == 'business' and shop.business_job and shop.business_job ~= '' and shop.stash_id and shop.stash_id ~= '' then
            options[#options + 1] = {
                name = ('mjc_restock_%s'):format(shop.id),
                label = ('Open %s Stock'):format(shop.label or 'Business'),
                icon = 'fa-solid fa-box-open',
                distance = Config.InteractionDistance,
                groups = { [shop.business_job] = 0 },
                onSelect = function()
                    MJC.Client.openBusinessStock(shop.business_job, shop.stash_id)
                end,
            }
        end
    end

    exports.ox_target:addLocalEntity(ped, options)
end

function MJC.Client.interactNpc(npc)
    if not hourAllowed(npc.hours) then return MJC.Client.notify('This business is currently closed.', 'error') end
    if npc.role_type == 'shop' then
        local shop = MJC.Client.state.shops[tonumber(npc.role_ref)]
        if not shop then
            for _, candidate in pairs(MJC.Client.state.shops) do if tonumber(candidate.npc_id) == tonumber(npc.id) then shop = candidate break end end
        end
        if not shop or not MJC.Validation.isEnabled(shop.enabled) then return MJC.Client.notify('This shop is unavailable.', 'error') end
        if not hourAllowed(shop.hours) then return MJC.Client.notify('This shop is currently closed.', 'error') end
        return MJC.Client.openCustomerShop(shop.id)
    end

    if npc.role_type == 'hire' then
        local response = lib.callback.await('missys_job_creator:server:hire', false, npc.id)
        if response and response.message then MJC.Client.notify(response.message, response.ok and 'success' or 'error') end
        return
    end

    if npc.role_type == 'activity' then
        TriggerServerEvent('missys_job_creator:server:startActivity', npc.id)
        return
    end

    MJC.Client.notify(npc.label, 'inform')
end

function MJC.Client.clearBusinessZones()
    for i = 1, #MJC.Client.targetZones do exports.ox_target:removeZone(MJC.Client.targetZones[i]) end
    MJC.Client.targetZones = {}
end

function MJC.Client.createBusinessZones()
    MJC.Client.clearBusinessZones()
    for _, business in pairs(MJC.Client.state.businesses or {}) do
        if MJC.Validation.isEnabled(business.enabled) and business.stock_x and business.stock_y and business.stock_z then
            local zone = exports.ox_target:addSphereZone({
                coords = vector3(tonumber(business.stock_x), tonumber(business.stock_y), tonumber(business.stock_z)),
                radius = 0.8,
                debug = Config.Debug,
                options = {{
                    name = ('mjc_stock_%s'):format(business.id),
                    label = ('Open %s Stock'):format(business.label),
                    icon = 'fa-solid fa-box-open',
                    groups = { [business.job_name] = 0 },
                    onSelect = function() MJC.Client.openBusinessStock(business.job_name, business.stash_id) end,
                }},
            })
            MJC.Client.targetZones[#MJC.Client.targetZones + 1] = zone
        end
    end
end
