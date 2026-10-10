--[[
    PC-MECHANIC MAIN CONFIGURATION
    Main settings for the mechanic system
]]

Config = Config or {}

-- ═══════════════════════════════════════════════════════════════════════════════
-- REGIONAL & LOCALE SETTINGS
-- ═══════════════════════════════════════════════════════════════════════════════
Config.Locale = "en"                            -- Language (en, ar, cn, de, es, fr, hu, it, ja, pt, sv, zh-tw)
Config.Currency = "USD"                         -- Currency display
Config.UseServerTime = false                    -- Use server time instead of local
Config.Use24HourFormat = true                  -- 24-hour time format

-- ═══════════════════════════════════════════════════════════════════════════════
-- BUSINESS & JOB MANAGEMENT
-- ═══════════════════════════════════════════════════════════════════════════════
Config.NearbySelfFlag = true                    -- Show nearby mechanic flag
Config.EnableBusyCheck = true                    -- Check if player is busy before sending invoices/hiring
Config.allowOwnOrders = true                    -- Allow mechanics to place orders for themselves
Config.NotifyAllEmployees = true                -- Notify all employees (true) or only on-duty (false)
Config.InternalFrameworkJobsystem = true        -- Use framework jobs (true) or database (false)
Config.LetAdminsUseTablets = false              -- Allow admins to use tablets
Config.UseExternalBanking = true               -- Use external banking for society funds
Config.SocietyMoneyAccess = true                -- Allow society money access
Config.PlayerBalance = "both"                   -- Default balance type for players

-- ═══════════════════════════════════════════════════════════════════════════════
-- INTERACTION CONTROLS
-- ═══════════════════════════════════════════════════════════════════════════════
Config.CustomiseVehicleKey = 38                 -- Key to open customization (38 = E)
Config.CustomiseVehiclePrompt = "[E] Customise vehicle"
Config.FreecamKey = "Tab"                        -- Key to toggle freecam in mod menu (e.g. "Tab", "F5", "CapsLock")
Config.AllowedConnectionDistance = 4.0          -- Max distance for tablet connection
Config.Target = "ox_target"                          -- Target system: "auto", "ox_target", "qb-target"
Config.AutoPositionPlayer = false               -- Auto-position player during minigames
Config.MinigameInteractionDistance = 4.0        -- Distance for minigame interactions
Config.PlayGameSounds = true                    -- Play in-game sounds (set false to disable all sounds)
Config.EnableDynoPlatform = true                -- Enable dyno platform props, DUI screen, alignment overlay, and animations
Config.ShowTabletDuringDyno = false             -- Show tablet UI while dyno test is running
Config.EnableDynoAlignment = true               -- Show alignment overlay when driving near dyno platform
Config.DynoAlignLeft = { offset = vector3(-0.85, -1.53, 0.0), size = vector3(0.14, 0.18, 0.0) }
Config.DynoAlignRight = { offset = vector3(0.83, -1.52, 0.0), size = vector3(0.16, 0.17, 0.0) }
Config.DynoAlignHeadingTolerance = 10.0
Config.DynoScreenCamOffset = vector3(0.95, 2.90, 1.85)
Config.DynoScreenLookAtOffset = vector3(0.90, 6.25, 0.85)
Config.DynoScreenCamFov = 68.5
Config.DynoScreenInteractDist = 2.0

-- Per-plate dyno test history (requires oxmysql)
Config.DynoHistory = {
    enabled = true,
    limit   = 5,                                -- max entries returned/shown per plate
}

-- ═══════════════════════════════════════════════════════════════════════════════
-- COMMANDS
-- ═══════════════════════════════════════════════════════════════════════════════
Config.RepairCommand = "fixpc"                    -- Admin repair command
Config.SetOwnerCommand = "setowner"             -- Set shop owner command
Config.UseTabletCommand = "tablet"              -- Tablet access command (false to disable)
Config.ViewRepairZonesCommand = "viewzones"     -- Admin command to visualize repair zones at nearest shop

-- ═══════════════════════════════════════════════════════════════════════════════
-- VEHICLE MILEAGE SYSTEM
-- ═══════════════════════════════════════════════════════════════════════════════
Config.MileageEnabled = true                    -- Enable mileage tracking
Config.MileageDisplay = true                    -- Show mileage on HUD
Config.MileageDisplayPosition = "bottom-right"  -- HUD position: "bottom-right", "bottom-left", "top-right", "top-left", "bottom-center", "top-center"
Config.MileageDisplayScale = 1.0                -- HUD size multiplier (0.5 = half, 1.0 = default, 2.0 = double)
Config.MileageUnit = "kilometers"               -- "kilometers" or "miles"
Config.MileageUpdateKm = 3                      -- Update mileage every X km
Config.MileageMultiplier = 1                    -- Mileage accumulation multiplier (1 = realistic, 5 = 5x faster)
Config.AutoPurgeNonOwnedVehicles = true         -- Auto-purge non-owned vehicle data

-- ═══════════════════════════════════════════════════════════════════════════════
-- NITROUS SYSTEM
-- ═══════════════════════════════════════════════════════════════════════════════
Config.BoostKey = "RMENU"                       -- Nitrous activation key
Config.BoostMultiplier = 2.0                    -- Speed boost multiplier
Config.BoostTime = 10                           -- Boost duration (seconds)
Config.BoostCooldown = 5                        -- Cooldown between boosts (seconds)
Config.BoostMaxBottle = 3                       -- Max nitrous bottles
Config.BoostPurgingDrainRate = 0.1              -- Purging drain rate
Config.BoostAllowPartialRefill = true           -- Allow partial bottle refills

-- ═══════════════════════════════════════════════════════════════════════════════
-- VEHICLE MAINTENANCE
-- ═══════════════════════════════════════════════════════════════════════════════
Config.ServicingDegradation = true              -- Enable part degradation
Config.ServiceNotifyValue = 20                  -- Notify when part below this %

-- ═══════════════════════════════════════════════════════════════════════════════
-- USABLE ITEMS
-- ═══════════════════════════════════════════════════════════════════════════════
Config.RepairKitItem = "repairkit"               -- Item to repair vehicles
Config.RepairKitMechanicOnly = true             -- Only mechanics can use repair kits
Config.RepairKitRemoveOnUse = true              -- Consume repair kit after use

Config.OilLeakRepairItem = "blowtorch"          -- Item to repair oil leaks
Config.OilLeakRepairItemRemove = false          -- Consume item after use
Config.OilLeakRepairMechanicOnly = true         -- Only mechanics can use

Config.EngineReplacementItem = "engine_replacement"
Config.EngineReplacementMechanicOnly = true     -- Only mechanics can use
Config.EngineReplacementRemoveOnUse = true      -- Consume item after use

Config.TurbochargerItem = "turbocharger"        -- Item to install turbocharger
Config.TurbochargerMechanicOnly = true          -- Only mechanics can use
Config.TurbochargerRemoveOnUse = true           -- Consume item after use

-- ═══════════════════════════════════════════════════════════════════════════════
-- STANCE & CUSTOMIZATION
-- ═══════════════════════════════════════════════════════════════════════════════
Config.StanceMinSuspensionHeight = -0.3         -- Min suspension height
Config.StanceMaxSuspensionHeight = 0.3          -- Max suspension height
Config.StanceMinCamber = 0.0                    -- Min camber angle
Config.StanceMaxCamber = 0.5                    -- Max camber angle
Config.StanceMinTrackWidth = 0.5                -- Min track width
Config.StanceMaxTrackWidth = 1.25               -- Max track width
Config.StanceMinWheelSize = 0.5                 -- Min native wheel diameter
Config.StanceMaxWheelSize = 1.5                 -- Max native wheel diameter
Config.StanceMinWheelWidth = 0.1                -- Min native wheel width
Config.StanceMaxWheelWidth = 1.5                -- Max native wheel width
Config.StanceNearbyVehiclesFreqMs = 500         -- Nearby vehicle update frequency (ms)
Config.TuningGiveInstalledItemBackOnRemoval = false  -- Return item when removing upgrade

-- ═══════════════════════════════════════════════════════════════════════════════
-- INSTALLATION MODE
-- ═══════════════════════════════════════════════════════════════════════════════
Config.InstallationMode = "sequential"          -- "individual" = per-category (current), "sequential" = all categories one-by-one with progress UI, "bulk" = one minigame installs all

-- ═══════════════════════════════════════════════════════════════════════════════
-- MINIGAMES & SKILLCHECKS
-- ═══════════════════════════════════════════════════════════════════════════════
Config.UseExternalMinigames = true              -- Use pc-mechanic-minigames for inspection tools (obd, pressure, multimeter, tread) — set false to use default internal minigames
Config.UseSkillbars = true                      -- Enable skillbar minigames
Config.ProgressBarDuration = 10000              -- Progress bar duration (ms)
Config.maxMiniGameAttempts = 3                  -- Max minigame attempts
Config.MiniGameDifficulty = { "easy", "easy", "easy", "easy", "easy" }
Config.MiniGameKeys = { "w", "a", "s", "d" }

-- ═══════════════════════════════════════════════════════════════════════════════
-- PRICING & ECONOMY
-- ═══════════════════════════════════════════════════════════════════════════════
Config.VehcilePricingInParts = true             -- Dynamic pricing based on vehicle value
Config.AlwaysProfit = true                      -- Ensure profit on all sales
Config.ProfitMargin = false                     -- Min profit % (false = use buffer)
Config.MinimumProfitBuffer = 1                  -- Buffer % above cost when margin disabled
Config.UseLowestShopPrice = false               -- Use lowest (true) or highest (false) price

-- ═══════════════════════════════════════════════════════════════════════════════
-- USER INTERFACE
-- ═══════════════════════════════════════════════════════════════════════════════
Config.DiffPlateWhileModding = "BiteMe"         -- Temp plate during modifications
Config.GitHubImageHost = "https://raw.githubusercontent.com/pixelcraftdevelopment/MechanicImages/main"

-- ═══════════════════════════════════════════════════════════════════════════════
-- FRAMEWORK & INTEGRATIONS (auto-detection recommended)
-- ═══════════════════════════════════════════════════════════════════════════════
Config.Framework = "Qbox"                       -- "auto", "QBCore", "Qbox", "ESX"
Config.Inventory = "auto"                       -- "auto", "ox_inventory", "qb-inventory", "qs-inventory", "codem-inventory", "tgiann-inventory", "ak47_inventory", "origen_inventory", "realrp_inventory", "jaksam_inventory", "esx_inventory", "l2s-inventory"
Config.Notifications = "lation_ui"                   -- "auto", "ox_lib", "okokNotify", "ps-ui", "nox_notify", "lation_ui"
Config.ProgressBar = "lation_ui"                   -- "ox-circle", "ox-bar", "lation_ui", "qb"
Config.SkillCheck = "lation_ui"                      -- "auto", "ox", "qb", "lation_ui"
Config.DrawText = "lation_ui"                        -- "auto", "ox_lib", "okokTextUI", "ps-ui", "ZSX_UIV2", "lation_ui", "qb-core"
Config.Menus = "lation_ui"                             -- "ox", "lation_ui"
Config.SocietyBanking = "qb-banking"                -- "auto", "pc-banking", "qb-banking", "qb-management", "Renewed-Banking", "esx_addonaccount", "okokBanking", "fd_banking", "wasabi_banking", "RxBanking", "justbanks", "tgg-banking", "crm-banking", "prism_banking", "p_banking"

-- ═══════════════════════════════════════════════════════════════════════════════
-- ROLE PERMISSIONS
-- ═══════════════════════════════════════════════════════════════════════════════
Config.Roles = {
    availableRoles = {
        {
            name = "owner",
            label = "Owner",
            level = 3,
            availableInTablet = false,
            frameworkGrades = {4},
            permissions = {
                canFrameworkHire = true, canFrameworkFire = true, canFrameworkPromote = true, canFrameworkDemote = true,
                canHire = {"manager", "mechanic", "novice"}, canFire = {"manager", "mechanic", "novice"},
                canPromote = {"manager", "mechanic", "novice"}, canDemote = {"manager", "mechanic", "novice"},
                canAccessManagement = true, canWithdrawFunds = true, canDepositFunds = true,
                canViewAllBills = true, canViewAllOrders = true, canViewAllShopOrders = true,
                canViewFunds = true, canViewAnalytics = true, canChangeBusinessSettings = true,
                canDeleteOrders = true, canAccessTablet = true, canManageOrders = true, canClaimOrders = true,
                canInstallParts = true, canManageInvoices = true, canServiceVehicles = true,
                canInspectVehicles = true, canApplyTuning = true, canPurchaseParts = true,
                canInstallNitrous = true, canToggleDuty = true, canAccessSettings = true,
                allowSocietyPay = true, allowFreeService = true
            }
        },
        {
            name = "manager",
            label = "Manager",
            level = 2,
            frameworkGrades = {3},
            permissions = {
                canFrameworkHire = true, canFrameworkFire = true, canFrameworkPromote = true, canFrameworkDemote = true,
                canHire = {"mechanic", "novice"}, canFire = {"mechanic", "novice"},
                canPromote = {"mechanic", "novice"}, canDemote = {"mechanic", "novice"},
                canAccessManagement = true, canWithdrawFunds = true, canDepositFunds = true,
                canViewAllBills = true, canViewAllOrders = false, canViewAllShopOrders = true,
                canViewFunds = true, canViewAnalytics = true, canChangeBusinessSettings = false,
                canDeleteOrders = true, canAccessTablet = true, canManageOrders = true, canClaimOrders = true,
                canInstallParts = true, canManageInvoices = true, canServiceVehicles = true,
                canInspectVehicles = true, canApplyTuning = true, canPurchaseParts = true,
                canInstallNitrous = true, canToggleDuty = true, canAccessSettings = true,
                allowSocietyPay = true, allowFreeService = true
            }
        },
        {
            name = "mechanic",
            label = "Mechanic",
            level = 1,
            frameworkGrades = {2},
            permissions = {
                canFrameworkHire = true, canFrameworkFire = true, canFrameworkPromote = true, canFrameworkDemote = true,
                canHire = {"novice"}, canFire = {"novice"}, canPromote = {"novice"}, canDemote = {"novice"},
                canAccessManagement = true, canWithdrawFunds = false, canDepositFunds = false,
                canViewFunds = true, canViewAllBills = false, canViewAllOrders = false, canViewAllShopOrders = false,
                canViewAnalytics = true, canChangeBusinessSettings = false, canDeleteOrders = false,
                canAccessTablet = true, canManageOrders = true, canClaimOrders = true, canInstallParts = true,
                canManageInvoices = true, canServiceVehicles = true, canInspectVehicles = true,
                canApplyTuning = true, canPurchaseParts = true, canInstallNitrous = true,
                canToggleDuty = true, canAccessSettings = true, allowSocietyPay = true, allowFreeService = false
            }
        },
        {
            name = "novice",
            label = "Novice",
            level = 0,
            frameworkGrades = {0, 1},
            permissions = {
                canFrameworkHire = true, canFrameworkFire = true, canFrameworkPromote = true, canFrameworkDemote = true,
                canHire = {}, canFire = {}, canPromote = {}, canDemote = {},
                canAccessManagement = true, canWithdrawFunds = false, canDepositFunds = false,
                canViewFunds = true, canViewAnalytics = true, canChangeBusinessSettings = false,
                canDeleteOrders = false, canAccessTablet = true, canManageOrders = true, canClaimOrders = true,
                canInstallParts = true, canManageInvoices = true, canServiceVehicles = true,
                canInspectVehicles = true, canApplyTuning = true, canPurchaseParts = true,
                canInstallNitrous = true, canToggleDuty = true, canAccessSettings = true,
                allowSocietyPay = true, allowFreeService = false
            }
        }
    },
    adminRole = {
        name = "server_admin",
        label = "Server Admin",
        level = 99,
        frameworkGrades = {4},
        permissions = {
            canFrameworkHire = true, canFrameworkFire = true, canFrameworkPromote = true, canFrameworkDemote = true,
            canHire = {"owner", "manager", "mechanic"}, canFire = {"owner", "manager", "mechanic"},
            canPromote = {"owner", "manager", "mechanic"}, canDemote = {"owner", "manager", "mechanic"},
            canAccessManagement = true, canViewAllBills = true, canViewAllOrders = true, canViewAllShopOrders = true,
            canWithdrawFunds = true, canDepositFunds = true, canViewFunds = true, canViewAnalytics = true,
            canChangeBusinessSettings = true, canDeleteOrders = true, canAccessTablet = true,
            canManageOrders = true, canClaimOrders = true, canInstallParts = true, canManageInvoices = true,
            canServiceVehicles = true, canInspectVehicles = true, canApplyTuning = true, canPurchaseParts = true,
            canInstallNitrous = true, canToggleDuty = true, canAccessSettings = true,
            allowSocietyPay = true, allowFreeService = true
        }
    }
}

-- ═══════════════════════════════════════════════════════════════════════════════
-- REPAIR ZONES
-- ═══════════════════════════════════════════════════════════════════════════════
Config.RepairZones = {
    enabled = true,                             -- Enable repair zone restrictions
    autoAdjust = true,                          -- Auto-snap zone points to ground and detect ceiling via raycasts (works in MLOs)
    fallbackThickness = 6.0,                    -- Thickness used when ceiling detection fails (outdoor areas)
    showZoneInfo = true,                        -- Show zone name & allowed mods (top-right) when employee enters/exits
    flashZoneOnRestriction = true,              -- Briefly flash zone outline when mechanic tries to work outside it
    flashDuration = 3000,                       -- Duration of zone flash in ms
    flashColor = { r = 255, g = 50, b = 50, a = 120 }, -- Color of the zone flash
}

-- ═══════════════════════════════════════════════════════════════════════════════
-- MECHANIC JOBS WHITELIST
-- ═══════════════════════════════════════════════════════════════════════════════
Config.MechanicJobs = {"mechanic"}              -- Jobs counted as mechanics for duty system

-- ═══════════════════════════════════════════════════════════════════════════════
-- SHOP LOCATIONS
-- ═══════════════════════════════════════════════════════════════════════════════
Config.ShopLocations = {
    bennys = {
        allowFreeService = true,
        allowSocietyPay = true,
        blip = { color = 47, id = 446, scale = 0.7000000000000455 },
        label = "Benny's Original Motor Works",
        locations = {
            {
                coords = { x = -211.60000610351562, y = -1324.72998046875, z = 30.229999542236328 },
                employeeOnly = false,
                showBlip = true,
                size = 8.0
            }
        },
        logo = "bennys.png",
        mods = {
            repair = { enabled = true, price = 750, vehiclevaluePortion = 0.010000000000001563 },
            respray = { enabled = true, price = 3000, vehiclevaluePortion = 0.010000000000001563 },
            wheels = { enabled = false, multiplier = 0.18000000000000682, price = 5000, vehiclevaluePortion = 0.010000000000001563 }
        },
        type = "self-service"
    },
    flowcustoms = {
        allowFreeService = false,
        allowSelfServiceWhenOffDuty = false,
        allowSocietyPay = false,
        blip = { color = 61, id = 446, scale = 0.599999999999909, visibleToAll = true },
        commission = 0,
        dynoStation = {},
        job = "mechanic",
        label = "Flow Customs",
        locations = {
            {
                allowSelfService = false,
                coords = { x = 66.44700622558594, y = -1752.4112548828125, z = 29.623821258544922 },
                employeeOnly = false,
                showBlip = true,
                size = 6.5
            },
            {
                allowSelfService = false,
                coords = { x = 43.39815902709961, y = -1783.9263916015625, z = 29.623796463012695 },
                employeeOnly = true,
                showBlip = false,
                size = 3.0
            }
        },
        logo = "flow_customs.png",
        mods = {
            bulletproofTyres = { enabled = true, price = 2525, vehiclevaluePortion = 0.010000000000001563 },
            cosmetics = { enabled = true, multiplier = 0.12000000000000455, price = 3535, vehiclevaluePortion = 0.010000000000001563 },
            extras = { enabled = true, price = 1010, vehiclevaluePortion = 0.010000000000001563 },
            headlights = { enabled = true, price = 2525, vehiclevaluePortion = 0.010000000000001563 },
            neonLights = { enabled = true, price = 2525, vehiclevaluePortion = 0.010000000000001563 },
            performance = { enabled = true, multiplier = 0.14999999999997726, price = 5000, vehiclevaluePortion = 0.010000000000001563 },
            repair = { enabled = true, price = 1000, vehiclevaluePortion = 0.010000000000001563 },
            respray = { enabled = true, price = 2500, vehiclevaluePortion = 0.010000000000001563 },
            stance = { enabled = true, price = 350, vehiclevaluePortion = 0.010000000000001563 },
            tyreSmoke = { enabled = true, price = 808, vehiclevaluePortion = 0.010000000000001563 },
            wheels = { enabled = true, multiplier = 0.18000000000000682, price = 2525, vehiclevaluePortion = 0.010000000000001563 }
        },
        repairZones = {
            main_garage = {
                allowedMods = {},
                label = "Main Garage",
                points = {
                    { x = 44.6622428894043, y = -1790.80859375, z = 29.623823165893555 },
                    { x = 31.33082389831543, y = -1777.7794189453125, z = 29.623796463012695 },
                    { x = 56.380516052246094, y = -1747.91455078125, z = 29.62381362915039 },
                    { x = 78.95476531982422, y = -1767.6748046875, z = 29.623796463012695 }
                },
                thickness = 8.0
            }
        },
        selfServiceJobs = { "police", "ambulance" },
        shops = {
            {
                coords = { x = 60.718666076660156, y = -1770.3448486328125, z = 29.623823165893555 },
                items = {
                    { label = "Suspension Parts", name = "suspension_parts", price = 1500 },
                    { label = "Body Parts", name = "cosmetic_part", price = 3000 },
                    { label = "Engine Oil", name = "engine_oil", price = 35 },
                    { label = "Spark Plug", name = "spark_plug", price = 55 },
                    { label = "Brakepad Replacement", name = "brakepad_replacement", price = 900 },
                    { label = "Air Filter", name = "air_filter", price = 180 },
                    { label = "Clutch Replacement", name = "clutch_replacement", price = 1800 },
                    { label = "Tyre Replacement", name = "tyre_replacement", price = 1200 },
                    { label = "Cleaning Kit", name = "cleaning_kit", price = 80 },
                    { label = "Vehicle Repair Kit", name = "repairkit", price = 525 },
                    { label = "EV Coolant", name = "ev_coolant", price = 180 }
                },
                marker = {
                    bobUpAndDown = 0,
                    color = { a = 80, b = 255, g = 255, r = 255 },
                    drawOnEnts = 0,
                    faceCamera = 0,
                    id = 23,
                    rotate = 1,
                    size = { x = 1.0000000000000, y = 1.0000000000000, z = -0.09999999999999432 }
                },
                name = "Servicing Supplies",
                pedModel = "s_m_m_gaffer_01",
                size = 1.0,
                usePed = false
            },
            {
                coords = { x = 53.45302963256836, y = -1778.9970703125, z = 29.623823165893555 },
                items = {
                    { label = "I4 Engine", name = "i4_engine", price = 18000 },
                    { label = "V6 Engine", name = "v6_engine", price = 28000 },
                    { label = "V8 Engine", name = "v8_engine", price = 42000 },
                    { label = "V12 Engine", name = "v12_engine", price = 58000 },
                    { label = "Turbo Charger", name = "turbocharger", price = 22000 },
                    { label = "Slick Tyres", name = "slick_tyres", price = 12000 },
                    { label = "Semi Slick Tyres", name = "semi_slick_tyres", price = 10000 },
                    { label = "Offroad Tyres", name = "offroad_tyres", price = 9500 },
                    { label = "Ceramic Brakes", name = "ceramic_brakes", price = 14000 },
                    { label = "AWD Drivetrain", name = "awd_drivetrain", price = 32000 },
                    { label = "RWD Drivetrain", name = "rwd_drivetrain", price = 28000 },
                    { label = "FWD Drivetrain", name = "fwd_drivetrain", price = 25000 },
                    { label = "Drift Tuning Kit", name = "drift_tuning_kit", price = 15000 },
                    { label = "Nitrous Bottle", name = "nitrous_bottle", price = 350 },
                    { label = "Nitrous Install Kit", name = "nitrous_install_kit", price = 3500 },
                    { label = "Performance Part", name = "performance_part", price = 4000 },
                    { label = "Body Kit", name = "cosmetic_part", price = 3500 },
                    { label = "Vehicle Wheels Set", name = "vehicle_wheels", price = 2500 },
                    { label = "Respray Kit", name = "respray_kit", price = 1000 },
                    { label = "Tyre Smoke Kit", name = "tyre_smoke_kit", price = 800 },
                    { label = "Bulletproof Tyres", name = "bulletproof_tyres", price = 2500 },
                    { label = "Extras Kit", name = "extras_kit", price = 1000 },
                    { label = "EV Motor", name = "ev_motor", price = 65000 },
                    { label = "EV Battery", name = "ev_battery", price = 35000 },
                    { label = "Lighting Kit", name = "lighting_kit", price = 2500 }
                },
                marker = {
                    bobUpAndDown = 0,
                    color = { a = 80, b = 255, g = 160, r = 0 },
                    drawOnEnts = 0,
                    faceCamera = 0,
                    id = 23,
                    rotate = 1,
                    size = { x = 1.0000000000000, y = 1.0000000000000, z = -0.09999999999999432 }
                },
                name = "Advanced Upgrades",
                pedModel = "s_m_m_gaffer_01",
                size = 1.0,
                usePed = true
            }
        },
        stashes = {
            {
                coords = { x = 86.63224792480469, y = -1766.545166015625, z = 29.623821258544922 },
                marker = {
                    bobUpAndDown = 0,
                    color = { a = 80, b = 255, g = 255, r = 255 },
                    drawOnEnts = 0,
                    faceCamera = 0,
                    id = 23,
                    rotate = 1,
                    size = { x = 1.0000000000000, y = 1.0000000000000, z = -0.09999999999999432 }
                },
                name = "Parts Bin",
                pedModel = "s_m_m_gaffer_01",
                size = 1.0,
                slots = 100,
                usePed = false,
                weight = 5000000
            }
        },
        tuning = {
            antiRollBars = { enabled = true, needsItem = true, requiresPayment = false },
            brakes = { enabled = true, needsItem = true, requiresPayment = false },
            driftTuning = { enabled = true, needsItem = true, requiresPayment = false },
            drivetrains = { enabled = true, needsItem = true, requiresPayment = false },
            engines = { enabled = true, needsItem = true, requiresPayment = false },
            launchControl = { enabled = true, needsItem = false, requiresPayment = false },
            tyres = { enabled = true, needsItem = true, requiresPayment = false }
        },
        type = "owned"
    },
    police = {
        allowFreeService = true,
        allowSocietyPay = true,
        blip = { color = 47, id = 446, scale = 0.7000000000000455, visibleToAll = false },
        job = "police",
        label = "LSPD",
        locations = {
            {
                coords = { x = 452.5400085449219, y = -997.3099975585938, z = 25.760000228881836 },
                employeeOnly = true,
                showBlip = true,
                size = 8.0
            }
        },
        logo = "bennys.png",
        mods = {
            repair = { enabled = true, price = 750, vehiclevaluePortion = 0.010000000000001563 },
            respray = { enabled = true, price = 3000, vehiclevaluePortion = 0.010000000000001563 }
        },
        type = "self-service"
    }
}

-- ═══════════════════════════════════════════════════════════════════════════════
-- DISCORD WEBHOOKS
-- ═══════════════════════════════════════════════════════════════════════════════
Config.DiscordWebhooks = {
    ImageUrl = "https://forum.cfx.re/user_avatar/forum.cfx.re/pixelcraft_dev/48/5087487_2.png",
    WorkOrdersLog = "",                         -- Webhook for work orders
    ServiceLog = "",                            -- Webhook for servicing activities
    BillingLog = "",                            -- Webhook for invoices/payments
    StaffManagementLog = ""                     -- Webhook for staff management
}
