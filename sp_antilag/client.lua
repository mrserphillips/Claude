local installedCache = {}
local lastThrottle = 0.0
local lastRpm = 0.0
local lastBurst = 0
local confirmedPlate = nil
local rpmPeaks = {}

local function cleanPlate(p)
    return (p or ''):gsub('^%s*(.-)%s*$', '%1'):upper()
end

local function plateOf(vehicle)
    return cleanPlate(GetVehicleNumberPlateText(vehicle))
end

local function isMechanic()
    local data = exports.qbx_core:GetPlayerData()
    return data and data.job and Config.MechanicJobs[data.job.name] == true
end

local function currentInstallVehicle()
    local ped = PlayerPedId()
    if not IsPedInAnyVehicle(ped, false) then return 0, 'You must be inside the vehicle to install anti-lag.' end
    local vehicle = GetVehiclePedIsIn(ped, false)
    if vehicle == 0 or not DoesEntityExist(vehicle) then return 0, 'Could not detect the vehicle.' end
    if GetPedInVehicleSeat(vehicle, -1) ~= ped then return 0, 'You must be sitting in the driver seat to install anti-lag.' end
    return vehicle
end

-- installedCache[plate] = false, or { colour = ..., pops = true/false }
local function settingsOf(vehicle)
    local plate = plateOf(vehicle)
    if plate == '' then return false end
    if installedCache[plate] ~= nil then return installedCache[plate] end
    local result = lib.callback.await('sp_antilag:isInstalled', false, plate)
    installedCache[plate] = type(result) == 'table' and result or false
    return installedCache[plate]
end

local function installed(vehicle)
    return settingsOf(vehicle) ~= false
end

exports('useAntiLagKit', function()
    if not isMechanic() then return lib.notify({type='error', description='Only a mechanic can fit anti-lag.'}) end
    local vehicle, reason = currentInstallVehicle()
    if vehicle == 0 then return lib.notify({type='error', description=reason}) end
    local plate = plateOf(vehicle)
    if plate == '' then return lib.notify({type='error', description='Could not read this vehicle plate.'}) end
    if installed(vehicle) then return lib.notify({type='error', description='This vehicle already has anti-lag fitted.'}) end
    TriggerServerEvent('sp_antilag:requestInstall', plate)
end)

RegisterNetEvent('sp_antilag:beginInstall', function(expectedPlate)
    local vehicle, reason = currentInstallVehicle()
    if vehicle == 0 then return lib.notify({type='error', description=reason}) end
    if plateOf(vehicle) ~= expectedPlate then return lib.notify({type='error', description='Vehicle changed. Installation cancelled.'}) end

    local ok = lib.progressBar({
        duration=Config.InstallTime,
        label='Fitting anti-lag system...',
        canCancel=true,
        disable={car=true, move=true, combat=true}
    })
    if ok then TriggerServerEvent('sp_antilag:finishInstall', VehToNet(vehicle), expectedPlate) end
end)


RegisterCommand('removeantilag', function()
    if not isMechanic() then
        return lib.notify({type='error', description='Only a mechanic can remove anti-lag.'})
    end

    local vehicle, reason = currentInstallVehicle()
    if vehicle == 0 then
        return lib.notify({type='error', description=reason})
    end

    local plate = plateOf(vehicle)
    if plate == '' then
        return lib.notify({type='error', description='Could not read this vehicle plate.'})
    end

    if not installed(vehicle) then
        return lib.notify({type='error', description='This vehicle does not have anti-lag fitted.'})
    end

    local ok = lib.progressBar({
        duration=Config.RemoveTime,
        label='Removing anti-lag system...',
        canCancel=true,
        disable={car=true, move=true,combat=true}
    })

    if ok then
        TriggerServerEvent('sp_antilag:remove', VehToNet(vehicle), plate)
    end
end, false)

RegisterNetEvent('sp_antilag:setInstalled', function(plate, settings)
    installedCache[cleanPlate(plate)] = type(settings) == 'table' and settings or false
end)

local exhaustNames={'exhaust','exhaust_2','exhaust_3','exhaust_4','exhaust_5','exhaust_6','exhaust_7','exhaust_8','exhaust_9','exhaust_10','exhaust_11','exhaust_12','exhaust_13','exhaust_14','exhaust_15','exhaust_16'}

local presetByKey={}
for _,c in ipairs(Config.FlameColours) do presetByKey[c.key]=c end

local function hsvToRgb(h)
    -- Full saturation / value; h in 0..1. Returns 0..1 floats.
    local i=math.floor(h*6)
    local f=h*6-i
    local q,t=1-f,f
    i=i%6
    if i==0 then return 1,t,0
    elseif i==1 then return q,1,0
    elseif i==2 then return 0,1,t
    elseif i==3 then return 0,q,1
    elseif i==4 then return t,0,1
    end
    return 1,0,q
end

-- Returns r,g,b (0..1) for the tint, or nil for the untouched stock flame.
local function resolveColour(colour)
    if type(colour)~='string' then return nil end
    local preset=presetByKey[colour]
    if preset then
        if preset.rgb==nil then return nil end
        if preset.rgb=='rainbow' then return hsvToRgb((GetGameTimer()%2400)/2400) end
        return preset.rgb[1]/255,preset.rgb[2]/255,preset.rgb[3]/255
    end
    if colour:match('^#%x%x%x%x%x%x$') then
        return tonumber(colour:sub(2,3),16)/255,tonumber(colour:sub(4,5),16)/255,tonumber(colour:sub(6,7),16)/255
    end
    return nil
end

local function colourLabel(colour)
    local preset=presetByKey[colour]
    if preset then return preset.label end
    return colour or 'Stock'
end

local function loadPtfx()
    if HasNamedPtfxAssetLoaded('core') then return true end
    RequestNamedPtfxAsset('core')
    local untilTime=GetGameTimer()+2500
    while not HasNamedPtfxAssetLoaded('core') and GetGameTimer()<untilTime do Wait(0) end
    return HasNamedPtfxAssetLoaded('core')
end

local loadedBanks={}
local function nativeSound(vehicle,kind)
    local s=Config.NativeSounds[kind] or Config.NativeSounds.pop
    if s.bank and not loadedBanks[s.bank] then
        loadedBanks[s.bank]=RequestScriptAudioBank(s.bank,false)
    end
    -- Not networked: other clients already play it themselves from the synced
    -- sp_antilag:effect event, so a networked sound would double up.
    PlaySoundFromEntity(-1,s.name,vehicle,s.set,false,0)
end

-- V4.4.2: synthesised pops/bangs through NUI (html/index.html), volume and
-- muffling by distance from the camera.
local function synthSound(vehicle,kind)
    local dist=#(GetFinalRenderedCamCoord()-GetEntityCoords(vehicle))
    if dist>Config.SoundRange then return end
    local f=dist/Config.SoundRange
    SendNUIMessage({
        action='sp_antilag',
        kind=kind,
        volume=Config.SoundVolume*(1.0-f)^2,
        muffle=f
    })
end

local function playSound(vehicle,kind)
    if Config.SoundMode=='native' then nativeSound(vehicle,kind) else synthSound(vehicle,kind) end
end

local function spawnFlame(p,heading,scale,r,g,b)
    UseParticleFxAssetNextCall('core')
    -- Tint applies to the next non-looped particle only, so it is set per flame.
    if r then SetParticleFxNonLoopedColour(r,g,b) end
    StartParticleFxNonLoopedAtCoord(
        'veh_backfire',
        p.x,p.y,p.z,
        0.0,0.0,heading,
        scale,
        false,false,false
    )
end

local function fireFallback(vehicle,scale,r,g,b)
    local minDim,maxDim=GetModelDimensions(GetEntityModel(vehicle))
    local width=(maxDim.x-minDim.x)*0.26
    local rear=minDim.y-0.10
    local z=minDim.z+(maxDim.z-minDim.z)*0.34
    local heading=GetEntityHeading(vehicle)
    for _,x in ipairs({-width,width}) do
        spawnFlame(GetOffsetFromEntityInWorldCoords(vehicle,x,rear,z),heading,scale,r,g,b)
    end
end

local lastFlameByVehicle={}
local function flame(vehicle,big,colour)
    if not DoesEntityExist(vehicle) then return end

    -- Hard local safety gate: no vehicle can create visual PTFX faster than this.
    -- This is deliberately client-side and silent.
    local now=GetGameTimer()
    local key=VehToNet(vehicle)
    if key==0 then key=vehicle end
    if lastFlameByVehicle[key] and (now-lastFlameByVehicle[key]) < 70 then return end
    lastFlameByVehicle[key]=now

    if not loadPtfx() then return end
    local scale=big and Config.BigFlameScale or Config.FlameScale
    local r,g,b=resolveColour(colour)
    local heading=GetEntityHeading(vehicle)
    local found=0
    for _,name in ipairs(exhaustNames) do
        if found>=4 then break end
        local bone=GetEntityBoneIndexByName(vehicle,name)
        if bone~=-1 then
            spawnFlame(GetWorldPositionOfEntityBone(vehicle,bone),heading,scale,r,g,b)
            found=found+1
        end
    end
    if found==0 then fireFallback(vehicle,scale,r,g,b) end
end

RegisterNetEvent('sp_antilag:effect',function(netId,kind,sourceServerId,colour,withFlame)
    if sourceServerId==GetPlayerServerId(PlayerId()) then return end
    local vehicle=NetToVeh(netId)
    if vehicle==0 or not DoesEntityExist(vehicle) then return end
    if #(GetEntityCoords(PlayerPedId())-GetEntityCoords(vehicle))>Config.Range then return end
    playSound(vehicle,kind)
    if withFlame~=false then flame(vehicle,kind~='pop',colour) end
end)

local function send(vehicle,kind,withFlame)
    if withFlame==nil then withFlame=true end
    local settings=settingsOf(vehicle)
    playSound(vehicle,kind)
    if withFlame then flame(vehicle,kind~='pop',settings and settings.colour) end
    TriggerServerEvent('sp_antilag:effect',VehToNet(vehicle),plateOf(vehicle),kind,withFlame)
end

local function limiterBurst(vehicle)
    -- Crackle builds into ONE proper bang instead of every hit sounding the same.
    send(vehicle,'pop'); Wait(82)
    send(vehicle,'pop'); Wait(88)
    send(vehicle,'pop'); Wait(96)
    send(vehicle,'bang')
end

local function liftBurst(vehicle)
    -- Short overrun crackle, then a single hard bang.
    send(vehicle,'pop'); Wait(95)
    send(vehicle,'pop'); Wait(120)
    send(vehicle,'mega')
end

-- V4.4 pops & bangs: one irregular overrun shot.
local function crackleShot(vehicle)
    local pb=Config.PopsBangs
    local roll=math.random()
    if roll<pb.MegaChance then
        send(vehicle,'mega',true)
    elseif roll<pb.MegaChance+pb.BangChance then
        send(vehicle,'bang',true)
    else
        send(vehicle,'pop',math.random()<pb.FlameChance)
    end
end

local lastThrottle=0.0
local limiterSince=nil
local lastLimiter=0
local lastLift=0
local activePlate=nil
local overrunSince=nil
local nextCrackle=0

local function resetState()
    limiterSince=nil; lastThrottle=0.0; activePlate=nil; overrunSince=nil
end

CreateThread(function()
    while true do
        local sleep=350
        local ped=PlayerPedId()
        if IsPedInAnyVehicle(ped,false) then
            local vehicle=GetVehiclePedIsIn(ped,false)
            if vehicle~=0 and GetPedInVehicleSeat(vehicle,-1)==ped and installed(vehicle) then
                sleep=20
                local plate=plateOf(vehicle)
                if activePlate~=plate then
                    activePlate=plate
                    lib.notify({type='success',description=('Anti-lag v%s active on %s - /%s to tune'):format(GetResourceMetadata(GetCurrentResourceName(),'version',0) or '?',plate,Config.MenuCommand)})
                end

                local throttle=GetControlNormal(0,71)
                local speed=GetEntitySpeed(vehicle)*3.6
                local now=GetGameTimer()

                if speed<12.0 and throttle>=Config.LimiterThrottle then
                    limiterSince=limiterSince or now
                    if now-limiterSince>=Config.LimiterHoldMs and now-lastLimiter>=Config.LimiterCooldownMs then
                        lastLimiter=now
                        CreateThread(function() limiterBurst(vehicle) end)
                    end
                else
                    limiterSince=nil
                end

                if speed>=Config.MinSpeedKmh
                and lastThrottle>=Config.LiftThrottleBefore
                and throttle<=Config.LiftThrottleAfter
                and now-lastLift>=Config.LiftCooldownMs then
                    lastLift=now
                    CreateThread(function() liftBurst(vehicle) end)
                end

                -- Pops & bangs: keeps crackling on the overrun after the lift burst.
                local pb=Config.PopsBangs
                local settings=settingsOf(vehicle)
                if pb.Enabled and settings and settings.pops
                and speed>=pb.MinSpeedKmh and throttle<=pb.MaxThrottle then
                    -- Only starts from a real lift-off, not from rolling with no input.
                    if not overrunSince and lastThrottle>pb.MaxThrottle then
                        overrunSince=now
                        nextCrackle=now+pb.StartDelayMs
                    end
                    if overrunSince and now-overrunSince<=pb.MaxDurationMs and now>=nextCrackle then
                        nextCrackle=now+math.random(pb.MinGapMs,pb.MaxGapMs)
                        crackleShot(vehicle)
                    end
                else
                    overrunSince=nil
                end

                lastThrottle=throttle
            else
                resetState()
            end
        else
            resetState()
        end
        Wait(sleep)
    end
end)

---------------------------------------------------------------------
-- V4.4 settings menu: flame colour + pops & bangs toggle
---------------------------------------------------------------------
local function settingsVehicle()
    local vehicle,reason=currentInstallVehicle()
    if vehicle==0 then return 0,(reason:gsub('to install anti%-lag','to tune the anti-lag')) end
    if not installed(vehicle) then return 0,'This vehicle does not have anti-lag fitted.' end
    if Config.SettingsPermission=='mechanic' and not isMechanic() then return 0,'Only a mechanic can tune the anti-lag.' end
    return vehicle
end

local function pushSettings(vehicle,colour,pops)
    TriggerServerEvent('sp_antilag:updateSettings',VehToNet(vehicle),plateOf(vehicle),colour,pops)
end

local openMenu

local function openColourMenu(vehicle)
    local settings=settingsOf(vehicle) or {}
    local options={}
    for _,c in ipairs(Config.FlameColours) do
        local swatch
        if type(c.rgb)=='table' then swatch=('#%02X%02X%02X'):format(c.rgb[1],c.rgb[2],c.rgb[3]) end
        options[#options+1]={
            title=c.label,
            icon=c.key=='rainbow' and 'rainbow' or 'fire',
            iconColor=swatch or (c.key=='stock' and '#FF8C1A' or nil),
            description=settings.colour==c.key and 'Current' or nil,
            onSelect=function() pushSettings(vehicle,c.key,nil) end
        }
    end
    if Config.AllowCustomColour then
        options[#options+1]={
            title='Custom colour...',
            icon='palette',
            description=(settings.colour and settings.colour:sub(1,1)=='#') and ('Current: '..settings.colour) or 'Pick any colour',
            onSelect=function()
                local input=lib.inputDialog('Custom flame colour',{
                    { type='color', label='Flame colour', format='hex', required=true,
                      default=(settings.colour and settings.colour:sub(1,1)=='#') and settings.colour or '#2878FF' }
                })
                if input and input[1] then pushSettings(vehicle,input[1],nil) end
            end
        }
    end
    lib.registerContext({ id='sp_antilag_colours', title='Flame colour', menu='sp_antilag_menu', options=options })
    lib.showContext('sp_antilag_colours')
end

openMenu=function()
    local vehicle,reason=settingsVehicle()
    if vehicle==0 then return lib.notify({type='error',description=reason}) end
    local settings=settingsOf(vehicle) or {}
    local options={
        {
            title='Flame colour',
            description='Current: '..colourLabel(settings.colour),
            icon='fire',
            arrow=true,
            onSelect=function() openColourMenu(vehicle) end
        }
    }
    if Config.PopsBangs.Enabled then
        options[#options+1]={
            title='Pops & bangs: '..(settings.pops and 'ON' or 'OFF'),
            description='Overrun crackle while coasting off throttle',
            icon=settings.pops and 'toggle-on' or 'toggle-off',
            onSelect=function() pushSettings(vehicle,nil,not settings.pops) end
        }
    end
    lib.registerContext({ id='sp_antilag_menu', title='Anti-lag ('..plateOf(vehicle)..')', options=options })
    lib.showContext('sp_antilag_menu')
end

RegisterCommand(Config.MenuCommand,function() openMenu() end,false)

-- /antilagtest: plays pop, pop, bang, pop, mega locally so you can check the sound works.
RegisterCommand('antilagtest',function()
    local ped=PlayerPedId()
    local vehicle=GetVehiclePedIsIn(ped,false)
    local target=vehicle~=0 and vehicle or ped
    CreateThread(function()
        for _,kind in ipairs({'pop','pop','bang','pop','mega'}) do
            playSound(target,kind)
            if vehicle~=0 then flame(vehicle,kind~='pop',(settingsOf(vehicle) or {}).colour) end
            Wait(kind=='pop' and 110 or 450)
        end
    end)
end,false)

print(('^2[sp_antilag] client v%s loaded (sound mode: %s)^7'):format(GetResourceMetadata(GetCurrentResourceName(),'version',0) or '?',Config.SoundMode))
