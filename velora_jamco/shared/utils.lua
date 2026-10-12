-- Shared helpers (client + server)
VJ = VJ or {}

-- Fill in any setting missing from config.lua with the shipped default (see shared/defaults.lua),
-- so keeping an older config.lua after an update never breaks the resource.
VJ.MissingConfig = {}
do
    local function isList(t) return type(t) == 'table' and rawget(t, 1) ~= nil end
    local function merge(target, defaults, path)
        for key, value in pairs(defaults) do
            local name = path and (path .. '.' .. tostring(key)) or tostring(key)
            if target[key] == nil then
                target[key] = value
                VJ.MissingConfig[#VJ.MissingConfig + 1] = name
            elseif type(value) == 'table' and type(target[key]) == 'table' and not isList(value) and not isList(target[key]) then
                merge(target[key], value, name)
            end
        end
    end
    if type(Config) ~= 'table' then Config = {} end
    if VJ_CONFIG_DEFAULTS then merge(Config, VJ_CONFIG_DEFAULTS, nil) end
    -- configs from before v1.2.5 used FruitPerJar and a 4/12-jar cap; move them to the new yield system
    local crafting, defaults = Config.Crafting, VJ_CONFIG_DEFAULTS and VJ_CONFIG_DEFAULTS.Crafting
    if crafting and defaults and crafting.FruitPerJar ~= nil and (crafting.MaxJarsPerBatch or 0) < defaults.MaxJarsPerBatch then
        crafting.MaxJarsPerBatch = defaults.MaxJarsPerBatch
        VJ.MissingConfig[#VJ.MissingConfig + 1] = 'Crafting.MaxJarsPerBatch (raised for the new jar yield)'
    end
    -- an older config pointed jar icons at a hard-coded folder name; let the server build it instead
    if type(Config.JamImageUrl) == 'string' and Config.JamImageUrl:find('//velora_jamco/', 1, true)
        and GetCurrentResourceName() ~= 'velora_jamco' then
        Config.JamImageUrl = nil
    end
end

-- Must match the version in fxmanifest.lua. If they differ, the server is running a stale manifest.
VJ.VERSION = '1.2.6'

function VJ.clamp(v, lo, hi)
    if v < lo then return lo end
    if v > hi then return hi end
    return v
end

function VJ.round(n)
    return math.floor(n + 0.5)
end

function VJ.qualityTier(quality)
    for i = 1, #Config.QualityTiers do
        local tier = Config.QualityTiers[i]
        if quality >= tier.min then return tier end
    end
    return Config.QualityTiers[#Config.QualityTiers]
end

function VJ.rarity(id)
    return Config.Rarities[id] or Config.Rarities.common
end

-- Item name -> fruit id / special id lookups
VJ.FruitByItem = {}
for id, fruit in pairs(Config.Fruits) do VJ.FruitByItem[fruit.item] = id end
VJ.SpecialByItem = {}
for id, special in pairs(Config.Specials) do VJ.SpecialByItem[special.item] = id end

-- Every item this resource reads from inventories
function VJ.allItemNames()
    local list = {}
    for _, id in ipairs(Config.FruitOrder) do list[#list + 1] = Config.Fruits[id].item end
    for _, id in ipairs(Config.SpecialOrder) do list[#list + 1] = Config.Specials[id].item end
    for _, supply in pairs(Config.Supplies) do list[#list + 1] = supply.item end
    return list
end

function VJ.debug(...)
    if Config.Debug then print('^5[velora_jamco]^7', ...) end
end
