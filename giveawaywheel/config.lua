Config = {}

-- ============================
-- Giveaway table prop
-- ============================
Config.Prop = {
    model = `prop_table_02`,                     -- change to whatever table prop you want
    coords = vector3(-1379.507812, -596.624817, 30.120548),   -- CHANGE ME: where the prop spawns
    heading = 160.0,
}

-- ============================
-- ox_target option on the prop
-- ============================
Config.Target = {
    label = 'Sign Up for Giveaway',
    icon = 'fa-solid fa-ticket',
    distance = 2.0,
}

-- ============================
-- Admin ace groups allowed to run /spinwheel, /cleargiveaway, /giveawaylist.
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
