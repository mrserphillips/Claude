Config = {}
Config.KitItem = 'antilag_kit'
Config.InstallTime = 10000
Config.RemoveTime = 10000
Config.MechanicJobs = { mechanic=true, mechanic2=true }

Config.MinSpeedKmh = 5.0
Config.Range = 220.0

-- Native GTA audio. These are emitted FROM the vehicle, so GTA handles 3D positioning.
Config.NativeSounds = {
    pop  = { name = 'BOOT_POP', set = 'DLC_VW_BODY_DISPOSAL_SOUNDS' },
    bang = { name = 'Explosion_01', set = 'FBI_HEIST_ELEVATOR_SHAFT_DEBRIS_SOUNDS' },
    mega = { name = 'Explosion_04', set = 'FBI_HEIST_ELEVATOR_SHAFT_DEBRIS_SOUNDS' }
}

-- V4 uses driver input instead of addon-dependent RPM values.
Config.LimiterThrottle = 0.82
Config.LimiterHoldMs = 300
Config.LimiterCooldownMs = 720
Config.LiftThrottleBefore = 0.55
Config.LiftThrottleAfter = 0.08
Config.LiftCooldownMs = 520

Config.FlameScale = 1.55
Config.BigFlameScale = 2.15
