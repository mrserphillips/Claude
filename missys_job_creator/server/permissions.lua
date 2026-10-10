MJC = MJC or {}
MJC.Permissions = {}
local DEFAULT_ACE = 'missys.jobcreator'
local txAdminAdmins = {}

local function rawAce(source, ace)
    if not ace or ace == '' then return false end
    return IsPlayerAceAllowed(tonumber(source) or source, ace)
end

local function hasAce(source, ace)
    local result = rawAce(source, ace)
    return result == true or result == 1
end

function MJC.Permissions.isTxAdmin(source)
    return txAdminAdmins[tonumber(source)] == true
end

-- txAdmin authenticates the player against its own Admin Manager and broadcasts
-- this server-only event. Tracking it gives us a secure fallback when a server's
-- ACE inheritance is missing or misconfigured.
AddEventHandler('txAdmin:events:adminAuth', function(data)
    if type(data) ~= 'table' then return end

    local netid = tonumber(data.netid)
    if netid == -1 and data.isAdmin == false then
        txAdminAdmins = {}
        return
    end

    if not netid or netid <= 0 then return end
    if data.isAdmin == true then
        txAdminAdmins[netid] = true
    else
        txAdminAdmins[netid] = nil
    end
end)

AddEventHandler('playerDropped', function()
    txAdminAdmins[tonumber(source)] = nil
end)

function MJC.Permissions.isAdmin(source)
    if source == 0 then return true end

    -- Custom resource ACE, e.g. add_ace group.owner missys.jobcreator allow
    if hasAce(source, Config.AdminAce or DEFAULT_ACE) then return true end

    -- Qbox/ox_lib permissions grant ACE objects such as `admin` to principals
    -- such as `group.admin`. IsPlayerAceAllowed checks the ACE object.
    if Config.AllowQboxGroupAdmin then
        if hasAce(source, 'admin') then return true end
        if hasAce(source, 'god') then return true end -- compatibility with older Qbox/QB setups
    end

    -- txAdmin has its own authenticated admin system. This event-backed check is
    -- server-side only; a client cannot mark itself as an authenticated admin.
    if Config.AllowTxAdmin and MJC.Permissions.isTxAdmin(source) then return true end

    return false
end

function MJC.Permissions.requireAdmin(source)
    if MJC.Permissions.isAdmin(source) then return true end
    exports.qbx_core:Notify(source, 'You do not have permission to use the job creator. Run /jobcreatorperm for a permission check.', 'error', 7000)
    return false
end

RegisterCommand('jobcreatorperm', function(source)
    if source == 0 then
        print('[missys_job_creator] /jobcreatorperm must be run in-game so it can inspect that player.')
        return
    end

    local customAce = Config.AdminAce or DEFAULT_ACE
    local rawCustom = rawAce(source, customAce)
    local rawAdmin = rawAce(source, 'admin')
    local rawGod = rawAce(source, 'god')
    local custom = rawCustom == true or rawCustom == 1
    local admin = rawAdmin == true or rawAdmin == 1
    local god = rawGod == true or rawGod == 1
    local txadmin = Config.AllowTxAdmin and MJC.Permissions.isTxAdmin(source) or false
    local allowed = custom or (Config.AllowQboxGroupAdmin and (admin or god)) or txadmin
    local identifiers = GetPlayerIdentifiers(source)

    print(('[missys_job_creator] Permission check for %s (%s): allowed=%s | %s=%s | admin=%s | god=%s | txadmin=%s | rawCustom=%s | rawAdmin=%s | rawGod=%s')
        :format(GetPlayerName(source) or 'unknown', source, tostring(allowed), customAce, tostring(custom), tostring(admin), tostring(god), tostring(txadmin), tostring(rawCustom), tostring(rawAdmin), tostring(rawGod)))
    print(('[missys_job_creator] Identifiers: %s'):format(table.concat(identifiers or {}, ', ')))

    local message = ('Job Creator permission: %s | custom=%s | admin=%s | god=%s | txadmin=%s')
        :format(allowed and 'ALLOWED' or 'DENIED', tostring(custom), tostring(admin), tostring(god), tostring(txadmin))
    exports.qbx_core:Notify(source, message, allowed and 'success' or 'error', 9000)
end, false)
