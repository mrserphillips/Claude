Config = {}

-- ============================
-- Giveaway lucky wheel prop
-- vw_prop_vw_luckywheel_01a is the casino wheel's base/stand - players target this.
-- vw_prop_vw_luckywheel_02a is the wheel disc that sits on it and physically spins
-- in sync with the on-screen wheel when an admin spins.
-- ============================
Config.Prop = {
    model = `vw_prop_vw_luckywheel_01a`,
    coords = vector3(-1379.507812, -596.624817, 30.120548),   -- CHANGE ME: where the wheel spawns
    heading = 160.0,
    placeOnGround = true,       -- snap the base to the ground; set false to use coords.z exactly
}

Config.Wheel = {
    enabled = true,                       -- set false to spawn the base only
    model = `vw_prop_vw_luckywheel_02a`,
    offset = vector3(0.0, 0.0, 0.38),     -- disc position relative to the base (casino layout)
    fullSpins = 6,                        -- full turns the physical disc makes per spin
}

-- ============================
-- ox_target options on the prop
-- Sign-up is shown to everyone; the admin options only show for players who pass
-- IsAdmin() on the server (and the server re-checks every time they're used).
-- ============================
Config.Target = {
    distance = 2.5,
    signup = { label = 'Sign Up for Giveaway', icon = 'fa-solid fa-ticket' },
    spin   = { label = 'Spin the Wheel',       icon = 'fa-solid fa-dharmachakra' },
    list   = { label = 'View Entrants',        icon = 'fa-solid fa-list' },
    clear  = { label = 'Clear Entrants',       icon = 'fa-solid fa-trash' },
}

-- ============================
-- Admin ace groups allowed to spin/list/clear (via the wheel's target or the commands).
-- Checked with IsPlayerAceAllowed(src, 'group.<name>') - these must match the groups
-- you grant in server.cfg, e.g.:
--   add_ace group.admin command allow
--   add_principal identifier.license:xxxx group.admin
-- ============================
Config.AdminGroups = {
    ['admin'] = true,
    ['god'] = true,
}

-- ============================
-- Chat commands (no leading slash)
-- ============================
Config.Commands = {
    spin = 'spinwheel',        -- /spinwheel        -> picks a winner and spins the wheel for everyone
    clear = 'cleargiveaway',   -- /cleargiveaway     -> wipes the current sign-up list
    list = 'giveawaylist',     -- /giveawaylist      -> lists current entrants to the admin
}

Config.MinEntrants = 2           -- minimum sign-ups required before the wheel can spin
Config.ClearAfterSpin = true     -- wipe the sign-up list once a winner is picked
Config.RemoveOnDisconnect = true -- drop a player from the list if they disconnect before the spin

-- Must match SPIN_DURATION_MS fallback in html/script.js (that value is only a fallback,
-- this is the one that actually drives the spin since it's sent to every client)
Config.SpinDurationMs = 8000

-- Swap this out if you don't use ox_lib notifications
Config.Notify = function(source, message, type)
    TriggerClientEvent('ox_lib:notify', source, {
        title = 'Giveaway',
        description = message,
        type = type or 'inform',
    })
end
