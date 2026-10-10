MJC = MJC or {}
MJC.Npcs = {}

local N = MJC.Npcs

function N.save(payload)
    local label, labelError = MJC.Validation.label(payload.label, 'NPC label')
    if not label then return false, labelError end
    local model, modelError = MJC.Validation.label(payload.model, 'Ped model', 64)
    if not model then return false, modelError end
    local interactionLabel, interactionError = MJC.Validation.label(payload.interaction_label or 'Talk', 'Interaction label', 64)
    if not interactionLabel then return false, interactionError end

    local position = payload.position or {}
    local x, y, z = tonumber(position.x), tonumber(position.y), tonumber(position.z)
    if not x or not y or not z then return false, 'Place the NPC before saving it.' end

    local roleType = MJC.Validation.trim(payload.role_type or 'none')
    if not MJC.Constants.NpcRoles[roleType] then return false, 'Invalid NPC role.' end
    local roleRef = MJC.Validation.trim(payload.role_ref)
    local roleGrade, roleGradeError = MJC.Validation.integer(payload.role_grade or 0, 0, 50, 'Hire grade')
    if not roleGrade then return false, roleGradeError end

    if roleType == 'hire' then
        local jobName, jobError = MJC.Validation.jobName(roleRef)
        if not jobName then return false, jobError end
        if not exports.qbx_core:GetJob(jobName) then return false, 'The hire NPC job does not exist in QBX.' end
        roleRef = jobName
    end

    local id = tonumber(payload.id)
    local enabled = payload.enabled == false and 0 or 1
    local scenario = MJC.Validation.trim(payload.scenario)
    local access = type(payload.access) == 'table' and payload.access or { mode = 'public' }
    local hours = type(payload.hours) == 'table' and payload.hours or { enabled = false }
    local blip = type(payload.blip) == 'table' and payload.blip or {}

    if id then
        MySQL.update.await([[
            UPDATE missys_job_creator_npcs
            SET label=?, model=?, x=?, y=?, z=?, heading=?, scenario=?, interaction_label=?, role_type=?, role_ref=?, role_grade=?, blip_json=?, access_json=?, hours_json=?, enabled=?
            WHERE id=?
        ]], {
            label, model, x, y, z, tonumber(position.heading) or 0.0, scenario, interactionLabel,
            roleType, roleRef ~= '' and roleRef or nil, roleGrade, json.encode(blip), json.encode(access), json.encode(hours), enabled, id
        })
    else
        id = MySQL.insert.await([[
            INSERT INTO missys_job_creator_npcs
            (label, model, x, y, z, heading, scenario, interaction_label, role_type, role_ref, role_grade, blip_json, access_json, hours_json, enabled)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ]], {
            label, model, x, y, z, tonumber(position.heading) or 0.0, scenario, interactionLabel,
            roleType, roleRef ~= '' and roleRef or nil, roleGrade, json.encode(blip), json.encode(access), json.encode(hours), enabled
        })
    end
    return true, id
end

function N.delete(id)
    id = tonumber(id)
    local npc = id and MJC.State.npcs[id]
    if not npc then return false, 'NPC not found.' end
    local shopCount = tonumber(MySQL.scalar.await('SELECT COUNT(*) FROM missys_job_creator_shops WHERE npc_id = ?', { id })) or 0
    if shopCount > 0 then return false, 'Delete or reassign the NPC shop first.' end
    MySQL.query.await('DELETE FROM missys_job_creator_npcs WHERE id = ?', { id })
    return true
end

function N.canUse(source, npc)
    if not npc or not MJC.Validation.isEnabled(npc.enabled) then return false end
    local access = npc.access or MJC.Validation.decode(npc.access_json, { mode = 'public' })
    if not access.mode or access.mode == 'public' then return true end
    local jobName = access.job
    if not jobName or jobName == '' then return false end
    return exports.qbx_core:HasGroup(source, { [jobName] = tonumber(access.minGrade) or 0 }) == true
end

function N.isNearby(source, npc, maxDistance)
    if not npc then return false end
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return false end
    local coords = GetEntityCoords(ped)
    local target = vector3(tonumber(npc.x), tonumber(npc.y), tonumber(npc.z))
    return #(coords - target) <= (maxDistance or Config.PurchaseDistance)
end

function N.hire(source, npcId)
    local npc = MJC.State.npcs[tonumber(npcId)]
    if not npc or npc.role_type ~= 'hire' or not MJC.Validation.isEnabled(npc.enabled) then return false, 'This NPC is not a hiring NPC.' end
    if not N.isNearby(source, npc, Config.PurchaseDistance) then return false, 'Move closer to the NPC.' end
    if not N.canUse(source, npc) then return false, 'You cannot use this NPC.' end

    local player = exports.qbx_core:GetPlayer(source)
    if not player then return false, 'Player not found.' end
    local jobName = npc.role_ref
    local grade = tonumber(npc.role_grade) or 0
    if not exports.qbx_core:GetJob(jobName) then return false, 'That job is currently unavailable.' end
    local success = exports.qbx_core:AddPlayerToJob(player.PlayerData.citizenid, jobName, grade)
    if success == false then return false, 'QBX could not add the job.' end
    exports.qbx_core:SetPlayerPrimaryJob(player.PlayerData.citizenid, jobName)
    return true, ('You are now employed by %s.'):format(exports.qbx_core:GetJob(jobName).label or jobName)
end
