MJC=MJC or {}; MJC.Client=MJC.Client or {}; MJC.Client.jobBlips=MJC.Client.jobBlips or {}
local active=MJC.Client.jobBlips

local function clear()
    for id,handle in pairs(active) do if DoesBlipExist(handle) then RemoveBlip(handle) end; active[id]=nil end
end

local function visible(row)
    local access=row.access or {mode='public',minGrade=0}
    if access.mode=='public' then return true end
    local groups=exports.qbx_core:GetGroups() or {}
    local grade=tonumber(groups[row.job_name])
    if grade==nil then return false end
    if access.mode=='grade' then return grade >= (tonumber(access.minGrade) or 0) end
    return true
end

function MJC.Client.refreshBlips()
    clear()
    for _,row in pairs((MJC.Client.state or {}).blips or {}) do
        local access=row.access or {}
        if MJC.Validation.isEnabled(row.enabled) and visible(row) then
            local handle=AddBlipForCoord(tonumber(row.x),tonumber(row.y),tonumber(row.z))
            SetBlipSprite(handle,tonumber(row.sprite) or 280); SetBlipColour(handle,tonumber(row.colour) or 0); SetBlipScale(handle,tonumber(row.scale) or 0.8)
            SetBlipAsShortRange(handle,row.short_range==true or tonumber(row.short_range)==1)
            BeginTextCommandSetBlipName('STRING'); AddTextComponentString(row.label or row.job_name); EndTextCommandSetBlipName(handle)
            active[row.id]=handle
        end
    end
end

RegisterNetEvent('qbx_core:client:onGroupUpdate',function() SetTimeout(250,MJC.Client.refreshBlips) end)
RegisterNetEvent('QBCore:Client:OnJobUpdate',function() SetTimeout(250,MJC.Client.refreshBlips) end)
