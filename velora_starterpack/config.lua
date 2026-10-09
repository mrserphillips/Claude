--[[
    ██╗   ██╗███████╗██╗      ██████╗ ██████╗  █████╗
    ██║   ██║██╔════╝██║     ██╔═══██╗██╔══██╗██╔══██╗
    ██║   ██║█████╗  ██║     ██║   ██║██████╔╝███████║
    ╚██╗ ██╔╝██╔══╝  ██║     ██║   ██║██╔══██╗██╔══██║
     ╚████╔╝ ███████╗███████╗╚██████╔╝██║  ██║██║  ██║
      ╚═══╝  ╚══════╝╚══════╝ ╚═════╝ ╚═╝  ╚═╝╚═╝  ╚═╝
                 VELORA CITY — STARTER PACK

    This file is loaded on the SERVER ONLY. Clients never receive it directly;
    the server sends the client only the UI/display data it needs. Reward
    names, amounts and money values therefore cannot be read or tampered with
    from the client.
]]

Config = {}

-- Master switch. When false, nobody can open or claim a starter pack.
Config.Enabled = true

-- Prints extra information to the server and client consoles.
Config.Debug = false

---------------------------------------------------------------------------
-- AUTOMATIC OPENING
---------------------------------------------------------------------------
---------------------------------------------------------------------------
-- STARTER PACK PED (Legion Square car park)
-- Players walk up to this ped and interact with it to open the menu.
---------------------------------------------------------------------------
Config.Ped = {
    enabled = true,

    model = 'a_f_y_bevhills_02',
    -- Standing position (x, y, z = player standing height as /coords shows it,
    -- w = heading). Default: beside
    -- the Legion Square car park entrance (qbx_garages "Pillbox Garage Parking"
    -- access point is at 218.66, -804.08). Adjust with /coords if needed.
    coords = vec4(215.76, -810.12, 30.73, 335.0),
    scenario = 'WORLD_HUMAN_CLIPBOARD', -- set to false for a plain idle stance

    -- The ped only exists on a client while they are within this range.
    spawnDistance = 60.0,

    -- 'ox_target' (third-eye) or 'textui' ([E] prompt). 'auto' uses ox_target
    -- when it is running, otherwise the [E] prompt.
    interaction = 'auto',
    targetLabel = 'Velora Welcome Pack',
    targetIcon = 'fa-solid fa-gift',
    interactDistance = 2.5,
    textUI = '[E] Velora Welcome Pack',
    textUIKey = 38, -- E

    -- SERVER-SIDE: menus opened at the ped can only be opened / claimed while
    -- the player is physically within this many metres of the ped.
    requireNearby = true,
    maxServerDistance = 8.0,

    blip = {
        enabled = true,
        sprite = 280,
        color = 8, -- pink
        scale = 0.8,
        label = 'Velora Welcome Pack',
    },
}

Config.AutoOpen = {
    -- What happens when an unclaimed character finishes creation and spawns:
    --   'notify' = tell them to visit the starter pack ped (and set a GPS waypoint)
    --   'menu'   = open the menu automatically wherever they are
    enabled = true,
    mode = 'notify',
    setWaypoint = true,
    notifyDuration = 12000,

    -- Delay (ms) after the player has loaded before we start checking whether
    -- it is safe to open. Gives multicharacter / spawn / appearance resources
    -- time to take over the screen first.
    delay = 6000,

    -- The UI only opens once ALL of these have been true continuously for
    -- this many ms: screen faded in, no other NUI has focus (multicharacter,
    -- clothing/appearance menus), pause menu closed, no player switch / loading
    -- screen, and the ped is alive and visible.
    stableFor = 4000,

    -- Give up waiting after this many ms (the player can still use /starterpack).
    maxWait = 300000,

    -- How often (ms) the readiness check runs while waiting. This loop only
    -- exists between player load and menu open; it is never a permanent loop.
    checkInterval = 500,

    -- Extra time (ms) to wait after an appearance/clothing menu reports that
    -- it closed, before the stability window starts.
    afterAppearanceDelay = 2500,

    -- Client events that indicate a first-time appearance/clothing menu is
    -- opening. While "pending", the menu will not open until NUI focus has
    -- been released. qbx_core fires 'qb-clothes:client:CreateFirstCharacter'
    -- for brand new characters.
    appearanceStartEvents = {
        'qb-clothes:client:CreateFirstCharacter',
    },

    -- Events that indicate the appearance menu has finished (optional, the
    -- NUI-focus check already covers this; these just make it faster).
    -- You can also trigger 'velora_starterpack:client:appearanceFinished'
    -- from your own appearance resource.
    appearanceFinishEvents = {
        'qb-clothing:client:onMenuClose',
        'illenium-appearance:client:reloadSkin',
    },

    -- Re-run the auto-open check when this resource is restarted while
    -- players are already in-game (useful while testing).
    onResourceRestart = false,
}

-- Allow unclaimed players to open the menu with a command.
-- With the ped enabled this is off by default, so the ped is the only way
-- to claim. If enabled while the ped exists, /starterpack only works near it.
Config.Command = {
    enabled = false,
    name = 'starterpack',
}

---------------------------------------------------------------------------
-- REWARDS
-- Item names MUST exist in ox_inventory (data/items.lua). Missing items are
-- reported clearly in the server console at start-up and claims are blocked
-- until fixed (so nobody gets a half-broken pack).
-- Optional per item: metadata = { ... } (will not stack with existing items).
---------------------------------------------------------------------------
Config.Rewards = {
    -- Every player receives this, regardless of the path they choose.
    standard = {
        items = {
            { name = 'phone',                  count = 1 },
            { name = 'cos_sprunk',             count = 10 },
            { name = 'bbs_double_cheese_goat', count = 10 },
            { name = 'lockpick',               count = 3 },
            { name = 'pumpkin_patch_card',     count = 1 },
        },
        -- Granted through qbx_core's money system (never as raw inventory items).
        money = {
            cash = 25000,
            bank = 15000,
        },
        -- Owned vehicles, created through qbx_vehicles and stored in a garage.
        -- model  = spawn name (must be in qbx_core/shared/vehicles.lua)
        -- garage = qbx_garages garage name ('pillboxgarage' = Legion Square car park)
        -- props  = optional ox_lib vehicle properties, e.g. { color1 = { 255, 79, 163 } }
        vehicles = {
            { model = 'issi8', label = 'Weeny Issi Rally', garage = 'pillboxgarage' },
        },
    },

    -- The two selectable paths. The keys ('civilian' / 'criminal') are what
    -- the UI sends back; the server only accepts keys defined here.
    paths = {
        civilian = {
            label    = 'Civilian',
            title    = 'THE CIVILIAN DREAM',
            subtitle = 'Build your future. Create your empire.',
            description = 'Every empire starts somewhere. Set up your business, sell your products, meet new people and make your fortune in Velora City.',
            theme    = 'civilian',
            tags     = { 'Business', 'Shopping', 'Luxury' },
            items = {
                { name = 'bodywavewigs',       count = 25 },
                { name = 'pink_messenger_bag', count = 25 },
            },
            money = { cash = 0, bank = 0 },
        },
        criminal = {
            label    = 'Criminal',
            title    = 'THE CRIMINAL UNDERWORLD',
            subtitle = 'Fortune favours the fearless.',
            description = 'Not every fortune is made legally. Start your underground hustle, build connections, take risks and make a name for yourself in Velora.',
            theme    = 'criminal',
            tags     = { 'Underground', 'Street', 'Hustle' },
            items = {
                { name = 'ls_og_kush_bag',  count = 25 },
                { name = 'ls_og_kush_seed', count = 25 },
            },
            money = { cash = 0, bank = 0 },
        },
    },

    -- Display order of the path cards in the UI.
    pathOrder = { 'civilian', 'criminal' },
}

-- Reason string passed to qbx_core AddMoney (shows in money logs).
Config.MoneyReason = 'velora-starter-pack'

---------------------------------------------------------------------------
-- VEHICLES
---------------------------------------------------------------------------
Config.Vehicles = {
    -- Used when a vehicle entry has no garage of its own.
    defaultGarage = 'pillboxgarage',
    -- Friendly garage names shown in the UI / notifications.
    garageLabels = {
        pillboxgarage = 'Legion Square car park',
    },
    -- Image shown in the UI. %s = model. Falls back to a car icon if missing.
    imagePath = 'https://docs.fivem.net/vehicles/%s.webp',
}

---------------------------------------------------------------------------
-- INVENTORY
---------------------------------------------------------------------------
Config.Inventory = {
    -- Name of the ox_inventory cash item. With qbx_core + ox_inventory, cash
    -- is mirrored as this item, so it needs a free slot if the player has none.
    cashItem = 'money',

    -- Image path for item icons in the UI. %s = item name.
    imagePath = 'nui://ox_inventory/web/images/%s.png',
}

---------------------------------------------------------------------------
-- SECURITY
---------------------------------------------------------------------------
Config.Security = {
    -- Minimum time (ms) between claim attempts from one player.
    claimCooldown = 3000,
    -- Minimum time (ms) between open requests (/starterpack, auto-open).
    openCooldown = 2000,
    -- A database processing lock older than this (seconds) is treated as
    -- stale (e.g. the server crashed mid-claim) and can be taken over.
    lockTimeout = 120,
    -- Number of rate-limit violations before it is logged as suspicious.
    spamLogThreshold = 5,
}

---------------------------------------------------------------------------
-- DATABASE
---------------------------------------------------------------------------
Config.Database = {
    -- Create the tables automatically on resource start if they don't exist.
    -- sql/install.sql contains the same schema if you prefer to run it manually.
    autoCreate = true,
}

---------------------------------------------------------------------------
-- ADMIN
---------------------------------------------------------------------------
Config.Admin = {
    ace = 'velora.starterpack.admin',
    commands = {
        check = 'startercheck',
        reset = 'starterreset',
        give  = 'startergive',
    },
    -- /starterreset must be repeated with "confirm" within this many seconds.
    resetConfirmWindow = 30,
}

---------------------------------------------------------------------------
-- LOGGING
---------------------------------------------------------------------------
Config.Logging = {
    -- Optional Discord webhook for claim / admin logs. Leave '' to disable.
    -- (Server-only: this file is never sent to clients.)
    webhook = '',
    webhookName = 'Velora Starter Pack',
}

---------------------------------------------------------------------------
-- UI (colours & text). Sent to the NUI when it opens.
---------------------------------------------------------------------------
Config.UI = {
    colors = {
        primary     = '#ff4fa3', -- Velora pink
        primaryGlow = 'rgba(255, 79, 163, 0.55)',
        accent      = '#ffc2dc',
        roseGold    = '#e8b4a0',
        background  = '#07050a',
        surface     = 'rgba(20, 12, 22, 0.55)',
        text        = '#fff5fa',
        textMuted   = 'rgba(255, 235, 245, 0.68)',
        criminal    = '#8b2cff',
        criminalRed = '#b3122e',
    },
    text = {
        brand          = 'VELORA CITY',
        welcomeTitle   = 'WELCOME TO VELORA CITY',
        welcomeSubtitle = 'Every story has a beginning. What will yours be?',
        selectButton   = 'SELECT PATH',
        bonusHeading   = 'Path Bonus',
        standardHeading = 'Included With Every Path',
        standardSubtitle = 'Whichever path you choose, you also receive all of these.',
        confirmTitle   = 'Begin Your Journey?',
        confirmText    = 'Are you sure you want to begin your Velora journey as a %s? This choice cannot be changed.',
        confirmButton  = 'Confirm My Journey',
        backButton     = 'Go Back',
        processing     = 'Preparing your rewards…',
        rewardTitle    = 'YOUR VELORA JOURNEY BEGINS!',
        rewardSubtitle = 'Your rewards have been delivered.',
        finishButton   = 'WELCOME TO VELORA',
        resumeNotice   = 'Your path has been chosen. Make space in your inventory and continue to collect your remaining rewards.',
        resumeButton   = 'COLLECT MY REWARDS',
        closeHint      = 'Press ESC to decide later — come back to the welcome host any time.',
        vehicleHeading = 'Your First Ride',
        vehicleGarage  = 'Waiting in: %s',
        cashLabel      = 'Cash',
        bankLabel      = 'Bank',
    },
    -- Allow ESC / close button before a path is confirmed.
    allowClose = true,
}

---------------------------------------------------------------------------
-- NOTIFICATIONS (ox_lib)
---------------------------------------------------------------------------
Config.Notify = {
    position = 'top',
    duration = 6000,
    title = 'Velora City',
    messages = {
        disabled        = 'Starter packs are currently disabled.',
        alreadyClaimed  = 'You have already claimed your starter pack.',
        notLoaded       = 'Your character is not fully loaded yet.',
        busy            = 'Your starter pack is already being processed.',
        cooldown        = 'Please wait a moment before trying again.',
        invalidPath     = 'That path does not exist.',
        pathLocked      = 'You have already chosen the %s path.',
        configError     = 'The starter pack is temporarily unavailable. Please contact staff.',
        inventoryFull   = 'Not enough inventory space. You need %s free slot(s) and %.1fkg of free weight. Make space and speak to the welcome host again.',
        grantFailed     = 'Some rewards could not be delivered. Nothing was duplicated — make space and speak to the welcome host to collect the rest.',
        success         = 'Welcome to Velora City! Your %s starter pack has been delivered.',
        needsReview     = 'Your starter pack is complete, but one reward needs staff review. Please open a ticket.',
        dbError         = 'A database error occurred. Please try again shortly.',
        noPermission    = 'You do not have permission to do that.',
        vehicleReady    = 'Your %s is waiting for you in the %s garage.',
        tooFar          = 'You need to be with the Velora welcome host at the Legion Square car park.',
        visitPed        = 'Welcome to Velora City! Collect your free starter pack from the welcome host at the Legion Square car park — it is marked on your GPS.',
    },
}
