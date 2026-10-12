-- Shared helpers (client + server)
VJ = VJ or {}

-- Must match the version in fxmanifest.lua. If they differ, the server is running a stale manifest.
VJ.VERSION = '1.2.3'

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
