Config = {}

Config.Command = 'jobcreator'
Config.SelfTestCommand = 'jobcreatortest'
Config.AdminAce = 'missys.jobcreator'
Config.AllowQboxGroupAdmin = true
Config.AllowTxAdmin = true -- Allow authenticated txAdmin admins as a fallback
Config.NotifyPosition = 'top-right'

Config.DefaultPedModel = 's_m_m_linecook'
Config.DefaultScenario = 'WORLD_HUMAN_STAND_IMPATIENT'
Config.InteractionDistance = 2.2
Config.PurchaseDistance = 4.0
Config.MaxPurchaseCount = 200
Config.DefaultPaymentType = 'cash' -- cash | bank | black_money

Config.BusinessStash = {
    slots = 80,
    maxWeight = 250000,
}

Config.Placement = {
    moveSpeed = 0.025,
    fastMultiplier = 5.0,
    verticalSpeed = 0.02,
    rotationSpeed = 1.5,
}

-- Society money. Missy's House now uses Lation Banking society accounts.
-- Lation addresses society accounts by the exact QBX job name (for example 'whitewidow').
Config.Revenue = {
    provider = 'lation', -- auto | lation | internal
    accountPrefix = '',
    taxAccount = 'city_tax',
}

-- Override this if your server uses a custom banking/boss-finance resource.
-- Return true when the deposit was accepted, false to use the fallback ledger.
Config.CustomBusinessDeposit = function(account, amount, reason)
    return false
end

Config.Debug = false

Config.Points = {
    streamDistance = 90.0,
    serverDistance = 4.5,
    markerDrawDistance = 25.0,
    maxActionCount = 100,
    defaultProp = 'prop_tool_box_04',
}

Config.Packages = {
    maxBytes = 512000,
}
