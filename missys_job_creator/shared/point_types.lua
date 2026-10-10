MJC = MJC or {}

MJC.PointTypes = {
    ACTIONS = {
        stash = true,
        boss = true,
        duty = true,
        wardrobe = true,
        outfit = true,
        crafting = true,
        shop = true,
        sell = true,
        harvest = true,
        process = true,
        teleport = true,
        garage = true,
    },
    PRESENTATIONS = {
        target = true,
        marker = true,
        npc = true,
        prop = true,
    },
}

function MJC.PointTypes.isAction(value)
    return MJC.PointTypes.ACTIONS[tostring(value or '')] == true
end

function MJC.PointTypes.isPresentation(value)
    return MJC.PointTypes.PRESENTATIONS[tostring(value or '')] == true
end
