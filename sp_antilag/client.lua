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
-- A "not fitted" answer is only trusted for a few seconds, then asked again.
local notFittedCheckedAt = {}
local NOT_FITTED_RECHECK_MS = 5000
local function settingsOf(vehicle)
    local plate = plateOf(vehicle)
    if plate == '' then return false end
    local cached = installedCache[plate]
    if cached then return cached end
    if cached == false and GetGameTimer() - (notFittedCheckedAt[plate] or 0) < NOT_FITTED_RECHECK_MS then return false end
    local result = lib.callback.await('sp_antilag:isInstalled', false, plate)
    installedCache[plate] = type(result) == 'table' and result or false
    notFittedCheckedAt[plate] = GetGameTimer()
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
    plate = cleanPlate(plate)
    installedCache[plate] = type(settings) == 'table' and settings or false
    notFittedCheckedAt[plate] = GetGameTimer()
end)

RegisterNetEvent('sp_antilag:resync', function()
    installedCache = {}
    notFittedCheckedAt = {}
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

local function loadPtfx(asset)
    asset=asset or 'core'
    if HasNamedPtfxAssetLoaded(asset) then return true end
    RequestNamedPtfxAsset(asset)
    local untilTime=GetGameTimer()+2500
    while not HasNamedPtfxAssetLoaded(asset) and GetGameTimer()<untilTime do Wait(0) end
    return HasNamedPtfxAssetLoaded(asset)
end

local loadedBanks={}

local soundByKey={}
for _,t in ipairs(Config.SoundTypes) do soundByKey[t.key]=t end

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
local function synthSound(vehicle,kind,soundKey)
    local dist=#(GetFinalRenderedCamCoord()-GetEntityCoords(vehicle))
    if dist>Config.SoundRange then return end
    local f=dist/Config.SoundRange
    local prof=soundByKey[soundKey] or Config.SoundTypes[1]
    SendNUIMessage({
        action='sp_antilag',
        kind=kind,
        volume=Config.SoundVolume*(1.0-f)^2,
        muffle=f,
        profile={pitch=prof.pitch,length=prof.length,crack=prof.crack}
    })
end

-- look = { colour, size, silent, hide, sound, compat } (see lookOf)
local function playSound(vehicle,kind,look)
    look=look or {}
    if look.silent then return end
    if Config.SoundMode=='native' then nativeSound(vehicle,kind) else synthSound(vehicle,kind,look.sound) end
    if kind=='big' and Config.BigBang.Shake>0 then
        local dist=#(GetEntityCoords(PlayerPedId())-GetEntityCoords(vehicle))
        if dist<Config.BigBang.ShakeRange then
            ShakeGameplayCam('SMALL_EXPLOSION_SHAKE',Config.BigBang.Shake*(1.0-dist/Config.BigBang.ShakeRange))
        end
    end
end

local STOCK_GLOW={1.0,0.47,0.08}

-- GTA's backfire flame texture is orange, and tint MULTIPLIES it, so it can never go blue.
-- Coloured flames therefore add a tintable effect (Config.ColourFxOptions[Config.ColourFx])
-- on top of, or instead of, the stock flame. Use /antilagfx to try each option in-game.
local function stockFlame(p,heading,scale)
    UseParticleFxAssetNextCall('core')
    StartParticleFxNonLoopedAtCoord('veh_backfire',p.x,p.y,p.z,0.0,0.0,heading,scale,false,false,false)
end

local function colourFx(fx,p,heading,scale,r,g,b)
    local rot=fx.rot or {0.0,0.0,0.0}
    local s=scale*(fx.scale or 1.0)
    UseParticleFxAssetNextCall(fx.asset)
    if fx.looped then
        local h=StartParticleFxLoopedAtCoord(fx.name,p.x,p.y,p.z,rot[1],rot[2],heading+rot[3],s,false,false,false,false)
        if not h or h==0 then return end
        SetParticleFxLoopedColour(h,r,g,b,false)
        SetTimeout(fx.durationMs or 150,function()
            StopParticleFxLooped(h,false)
            RemoveParticleFx(h,false)
        end)
    else
        SetParticleFxNonLoopedColour(r,g,b)
        StartParticleFxNonLoopedAtCoord(fx.name,p.x,p.y,p.z,rot[1],rot[2],heading+rot[3],s,false,false,false)
    end
end

local function spawnFlame(p,heading,scale,r,g,b,fx)
    if not r then return stockFlame(p,heading,scale) end
    fx=fx or Config.ColourFxOptions[Config.ColourFx]
    if not fx or not fx.hideStock then stockFlame(p,heading,scale) end
    if fx and loadPtfx(fx.asset) then colourFx(fx,p,heading,scale,r,g,b) end
end

local function glow(points,r,g,b,big)
    if not Config.FlameGlow then return end
    if not r then r,g,b=STOCK_GLOW[1],STOCK_GLOW[2],STOCK_GLOW[3] end
    local huge=big=='huge'
    local range=Config.FlameGlowRange*(huge and 2.2 or big and 1.4 or 1.0)
    local intensity=Config.FlameGlowIntensity*(huge and 2.5 or big and 1.5 or 1.0)
    local R,G,B=math.floor(r*255),math.floor(g*255),math.floor(b*255)
    CreateThread(function()
        local untilTime=GetGameTimer()+(huge and 280 or big and 160 or 100)
        while GetGameTimer()<untilTime do
            for _,p in ipairs(points) do DrawLightWithRange(p.x,p.y,p.z,R,G,B,range,intensity) end
            Wait(0)
        end
    end)
end

local function fallbackPoints(vehicle)
    local minDim,maxDim=GetModelDimensions(GetEntityModel(vehicle))
    local width=(maxDim.x-minDim.x)*0.26
    local rear=minDim.y-0.10
    local z=minDim.z+(maxDim.z-minDim.z)*0.34
    return {
        GetOffsetFromEntityInWorldCoords(vehicle,-width,rear,z),
        GetOffsetFromEntityInWorldCoords(vehicle,width,rear,z)
    }
end

local function flameLevel(kind)
    if kind=='big' then return 'huge' end
    return kind~='pop'
end

local lastFlameByVehicle={}
local function flame(vehicle,big,look,fx,sizeMul)
    if not DoesEntityExist(vehicle) then return end
    look=look or {}
    if look.hide then return end

    -- Hard local safety gate: no vehicle can create visual PTFX faster than this.
    -- This is deliberately client-side and silent.
    local now=GetGameTimer()
    local key=VehToNet(vehicle)
    if key==0 then key=vehicle end
    if lastFlameByVehicle[key] and (now-lastFlameByVehicle[key]) < 70 then return end
    lastFlameByVehicle[key]=now

    if not loadPtfx() then return end
    local scale=(big=='huge' and Config.HugeFlameScale) or (big and Config.BigFlameScale) or Config.FlameScale
    scale=scale*(look.size or 1.0)*(sizeMul or 1.0)
    if not fx and look.compat then fx=Config.ColourFxOptions[Config.CompatColourFx] end
    local r,g,b=resolveColour(look.colour)
    local heading=GetEntityHeading(vehicle)
    local points={}
    for _,name in ipairs(exhaustNames) do
        if #points>=4 then break end
        local bone=GetEntityBoneIndexByName(vehicle,name)
        if bone~=-1 then points[#points+1]=GetWorldPositionOfEntityBone(vehicle,bone) end
    end
    if #points==0 then points=fallbackPoints(vehicle) end
    for _,p in ipairs(points) do spawnFlame(p,heading,scale,r,g,b,fx) end
    glow(points,r,g,b,big)
end

-- What a shot looks and sounds like, from saved settings (or the unsaved test draft).
local function lookOf(s)
    return {
        colour=s.colour,
        size=s.size or 1.0,
        silent=s.silent==true,
        hide=s.hideFlames==true,
        sound=s.sound,
        compat=s.compat==true
    }
end

RegisterNetEvent('sp_antilag:effect',function(netId,kind,sourceServerId,look,withFlame)
    if sourceServerId==GetPlayerServerId(PlayerId()) then return end
    local vehicle=NetToVeh(netId)
    if vehicle==0 or not DoesEntityExist(vehicle) then return end
    if #(GetEntityCoords(PlayerPedId())-GetEntityCoords(vehicle))>Config.Range then return end
    if type(look)~='table' then look={colour=look} end
    playSound(vehicle,kind,look)
    if withFlame~=false then flame(vehicle,flameLevel(kind),look) end
end)

local testing=nil -- { vehicle, draft } while the panel's test mode runs

local function sendOne(vehicle,kind,withFlame,look,sizeMul)
    playSound(vehicle,kind,look)
    if withFlame then flame(vehicle,flameLevel(kind),look,nil,sizeMul) end
    TriggerServerEvent('sp_antilag:effect',VehToNet(vehicle),plateOf(vehicle),kind,withFlame,look)
end

-- A BIG bang is fired Config.BigBang.Count times back to back, like gunshots.
local function send(vehicle,kind,withFlame,look,sizeMul)
    if withFlame==nil then withFlame=true end
    look=look or lookOf(settingsOf(vehicle) or {})
    local count=kind=='big' and (Config.BigBang.Count or 1) or 1
    if count<=1 then return sendOne(vehicle,kind,withFlame,look,sizeMul) end
    CreateThread(function()
        local gap=Config.BigBang.GapMs or {110,170}
        for i=1,count do
            if not DoesEntityExist(vehicle) then return end
            sendOne(vehicle,kind,withFlame,look,sizeMul)
            if i<count then Wait(math.random(gap[1],gap[2])) end
        end
    end)
end

-- Bursts follow a sequence of { kind, gap-after-ms }.
local function burst(vehicle,sequence,look,sizeMul)
    for i,step in ipairs(sequence) do
        send(vehicle,step[1],true,look,sizeMul)
        if i<#sequence then Wait(step[2] or 90) end
    end
end

local function intensityOf(key)
    return Config.Intensity[key] or Config.Intensity.moderate
end

-- Weighted pick from an intensity's mix, e.g. { pop = 0.45, bang = 0.47, mega = 0.08 }.
local function pickKind(mix)
    local total=0
    for _,w in pairs(mix) do total=total+w end
    local r=math.random()*total
    for _,kind in ipairs({'pop','bang','mega','big'}) do
        r=r-(mix[kind] or 0)
        if r<=0 and (mix[kind] or 0)>0 then return kind end
    end
    return 'pop'
end

local function randomGap(it)
    return math.random(it.gap[1],it.gap[2])
end

local function liftBurst(vehicle) burst(vehicle,Config.LiftSequence) end

-- Popcorn: rapid string of pops.
local function popcorn(vehicle,look)
    local pc=Config.Popcorn
    for _=1,math.random(pc.Shots[1],pc.Shots[2]) do
        send(vehicle,'pop',true,look)
        Wait(math.random(pc.GapMs[1],pc.GapMs[2]))
    end
end

-- V4.4 pops & bangs: one irregular overrun shot.
local function crackleShot(vehicle)
    local pb=Config.PopsBangs
    local roll=math.random()
    if roll<Config.BigBang.CrackleChance then
        send(vehicle,'big',true)
    elseif roll<Config.BigBang.CrackleChance+pb.MegaChance then
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
local limiterGap=0
local lastLift=0
local lastPopcorn=0
local activePlate=nil
local overrunSince=nil
local finaleDone=false
local nextCrackle=0

local lastGear=nil
local lastGearShot=0

local function resetState()
    limiterSince=nil; lastThrottle=0.0; activePlate=nil; overrunSince=nil; lastGear=nil
end

-- One 2-step shot on the limiter. Returns how long to wait before the next one.
local function limiterShot(vehicle,settings,intensityKey,look)
    local it=intensityOf(intensityKey)
    local now=GetGameTimer()
    if settings.popcorn and now-lastPopcorn>=Config.Popcorn.CooldownMs and math.random()<Config.Popcorn.Chance then
        lastPopcorn=now
        CreateThread(function() popcorn(vehicle,look) end)
        return Config.Popcorn.Shots[2]*Config.Popcorn.GapMs[2]
    end
    if math.random()<=it.chance then send(vehicle,pickKind(it.mix),true,look,it.flame) end
    return randomGap(it)
end

CreateThread(function()
    while true do
        local sleep=350
        local ped=PlayerPedId()
        if testing then
            sleep=500
        elseif IsPedInAnyVehicle(ped,false) then
            local vehicle=GetVehiclePedIsIn(ped,false)
            local settings=vehicle~=0 and GetPedInVehicleSeat(vehicle,-1)==ped and settingsOf(vehicle)
            if settings and settings.enabled~=false then
                sleep=20
                local plate=plateOf(vehicle)
                if activePlate~=plate then
                    activePlate=plate
                    lib.notify({type='success',description=('Anti-lag v%s active on %s - /%s to tune'):format(GetResourceMetadata(GetCurrentResourceName(),'version',0) or '?',plate,Config.MenuCommand)})
                end

                local throttle=GetControlNormal(0,71)
                local speed=GetEntitySpeed(vehicle)*3.6
                local now=GetGameTimer()
                local lc=Config.LaunchControl
                local launching=settings.launch and speed<3.0 and throttle>=Config.LimiterThrottle
                    and IsControlPressed(0,lc.HoldControl)

                if launching then
                    -- Launch control: hold the revs at the panel's limiter every frame.
                    sleep=0
                    local cap=settings.launchRpm or lc.DefaultRpm
                    if GetVehicleCurrentRpm(vehicle)>cap then SetVehicleCurrentRpm(vehicle,cap) end
                    limiterSince=limiterSince or now
                    if now-limiterSince>=Config.LimiterHoldMs and now-lastLimiter>=limiterGap then
                        lastLimiter=now
                        limiterGap=limiterShot(vehicle,settings,settings.launchIntensity,lookOf(settings))
                    end
                else
                    local it=intensityOf(settings.intensity)
                    if speed<it.maxSpeed and throttle>=Config.LimiterThrottle then
                        limiterSince=limiterSince or now
                        if now-limiterSince>=Config.LimiterHoldMs and now-lastLimiter>=limiterGap then
                            lastLimiter=now
                            limiterGap=limiterShot(vehicle,settings,settings.intensity,lookOf(settings))
                        end
                    else
                        limiterSince=nil
                    end
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
                if pb.Enabled and settings.pops
                and speed>=pb.MinSpeedKmh and throttle<=pb.MaxThrottle then
                    -- Only starts from a real lift-off, not from rolling with no input.
                    if not overrunSince and lastThrottle>pb.MaxThrottle then
                        overrunSince=now
                        nextCrackle=now+pb.StartDelayMs
                        finaleDone=false
                    end
                    if overrunSince and now-overrunSince<=pb.MaxDurationMs and now>=nextCrackle then
                        nextCrackle=now+math.random(pb.MinGapMs,pb.MaxGapMs)
                        crackleShot(vehicle)
                    elseif overrunSince and not finaleDone and Config.BigBang.CrackleFinale
                    and now-overrunSince>pb.MaxDurationMs and now>=nextCrackle+Config.BigBang.FinaleDelayMs then
                        -- Crackle has run its course: finish it with one BIG bang.
                        finaleDone=true
                        send(vehicle,'big',true)
                    end
                else
                    overrunSince=nil
                end

                -- Gear change: fire Config.GearChange.Sequence on each shift.
                local gc=Config.GearChange
                local gear=GetVehicleCurrentGear(vehicle)
                if gc.Enabled and settings.gear~=false and lastGear and gear~=lastGear and gear>0 and lastGear>0
                and (gear>lastGear or gc.Downshifts)
                and speed>=gc.MinSpeedKmh and now-lastGearShot>=gc.CooldownMs then
                    lastGearShot=now
                    CreateThread(function() burst(vehicle,gc.Sequence) end)
                end
                lastGear=gear

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
-- V5.0 2-STEP PANEL (NUI)
---------------------------------------------------------------------
local panelOpen=false
local panelVehicle=0

local function settingsVehicle()
    local vehicle,reason=currentInstallVehicle()
    if vehicle==0 then return 0,(reason:gsub('to install anti%-lag','to tune the anti-lag')) end
    if not installed(vehicle) then return 0,'This vehicle does not have anti-lag fitted.' end
    if Config.SettingsPermission=='mechanic' and not isMechanic() then return 0,'Only a mechanic can tune the anti-lag.' end
    return vehicle
end

local function hexOf(c)
    if type(c.rgb)=='table' then return ('#%02X%02X%02X'):format(c.rgb[1],c.rgb[2],c.rgb[3]) end
    if c.rgb=='rainbow' then return 'rainbow' end
    return '#FF6A1A'
end

local function uiConfig()
    local colours={}
    for _,c in ipairs(Config.FlameColours) do colours[#colours+1]={key=c.key,label=c.label,hex=hexOf(c)} end
    local sounds={}
    for _,t in ipairs(Config.SoundTypes) do sounds[#sounds+1]={key=t.key,label=t.label,pitch=t.pitch,length=t.length,crack=t.crack} end
    local intensity={}
    for _,k in ipairs({'soft','moderate','max'}) do
        if Config.Intensity[k] then intensity[#intensity+1]={key=k,label=Config.Intensity[k].label} end
    end
    return {
        ui=Config.UI,
        colours=colours,
        sounds=sounds,
        intensity=intensity,
        launch={min=Config.LaunchControl.MinRpm,max=Config.LaunchControl.MaxRpm},
        size=Config.FlameSize,
        popsEnabled=Config.PopsBangs.Enabled,
        gearEnabled=Config.GearChange.Enabled,
        hotbarKey=Config.Hotbar.Enabled and Config.Hotbar.Key or nil,
        volume=Config.SoundVolume,
        synth=Config.SoundMode~='native',
    }
end

local function vehicleInfo(vehicle)
    local model=GetEntityModel(vehicle)
    local label=GetLabelText(GetDisplayNameFromVehicleModel(model))
    if label=='NULL' then label=GetDisplayNameFromVehicleModel(model) end
    local fuel=Entity(vehicle).state.fuel or GetVehicleFuelLevel(vehicle)
    return {
        name=label,
        plate=plateOf(vehicle),
        fuel=math.floor((fuel or 0)+0.5),
        engine=math.floor(math.max(0,math.min(1000,GetVehicleEngineHealth(vehicle)))/10+0.5),
        turbo=IsToggleModOn(vehicle,18)
    }
end

local function copySettings(s)
    local out={}
    for k,v in pairs(s) do if k~='hotbar' then out[k]=v end end
    return out
end

local endTest

local function closePanel()
    if testing then endTest() end
    panelOpen=false
    panelVehicle=0
    SetNuiFocus(false,false)
    SendNUIMessage({action='close'})
end

local function openMenu()
    if panelOpen then return end
    local vehicle,reason=settingsVehicle()
    if vehicle==0 then return lib.notify({type='error',description=reason}) end
    local settings=settingsOf(vehicle) or {}
    local hotbar={}
    for i=1,3 do hotbar[i]=settings.hotbar and settings.hotbar[i] or false end
    panelOpen=true
    panelVehicle=vehicle
    SetNuiFocus(true,true)
    SendNUIMessage({
        action='open',
        config=uiConfig(),
        settings=copySettings(settings),
        hotbar=hotbar,
        vehicle=vehicleInfo(vehicle)
    })
end

-- Closes the panel if the player leaves the driver seat.
CreateThread(function()
    while true do
        Wait(500)
        if panelOpen then
            local ped=PlayerPedId()
            if not DoesEntityExist(panelVehicle) or GetVehiclePedIsIn(ped,false)~=panelVehicle
            or GetPedInVehicleSeat(panelVehicle,-1)~=ped then
                closePanel()
            end
        end
    end
end)

RegisterNUICallback('close',function(_,cb) closePanel(); cb(1) end)

RegisterNUICallback('save',function(data,cb)
    cb(1)
    if not panelOpen or type(data)~='table' or type(data.settings)~='table' then return end
    local changes=copySettings(data.settings)
    if type(data.hotbar)=='table' then
        local hb={}
        for i=1,3 do if type(data.hotbar[i])=='table' then hb[i]=copySettings(data.hotbar[i]) end end
        changes.hotbar=hb
    end
    TriggerServerEvent('sp_antilag:saveSettings',VehToNet(panelVehicle),plateOf(panelVehicle),changes,data.message)
end)

-- Test mode: freeze the car, rev with handbrake + throttle, the unsaved draft is used.
local function testLoop()
    local lastShot=0
    local testGap=0
    local device=nil
    while testing do
        local vehicle=testing.vehicle
        if not DoesEntityExist(vehicle) then break end
        DisableControlAction(0,1,true); DisableControlAction(0,2,true)
        DisableControlAction(0,24,true); DisableControlAction(0,25,true)
        DisableControlAction(0,200,true); DisableControlAction(0,199,true)
        DisableControlAction(0,75,true) -- leave vehicle
        local kb=IsUsingKeyboard(2)
        if kb~=device then
            device=kb
            SendNUIMessage({action='testDevice',keyboard=kb})
        end
        if IsDisabledControlJustPressed(0,194) or IsControlJustPressed(0,194) then break end

        local throttle=GetControlNormal(0,71)
        local now=GetGameTimer()
        if throttle>=Config.LimiterThrottle and IsControlPressed(0,Config.LaunchControl.HoldControl)
        and now-lastShot>=testGap then
            lastShot=now
            local draft=testing.draft
            local it=intensityOf(draft.intensity)
            send(vehicle,pickKind(it.mix),true,lookOf(draft),it.flame)
            testGap=randomGap(it)
        end
        Wait(0)
    end
    if testing then endTest() end
end

endTest=function()
    if not testing then return end
    local vehicle=testing.vehicle
    testing=nil
    if DoesEntityExist(vehicle) then FreezeEntityPosition(vehicle,false) end
    SetNuiFocusKeepInput(false)
    SendNUIMessage({action='testEnded'})
end

RegisterNUICallback('startTest',function(data,cb)
    cb(1)
    if not panelOpen or testing or type(data)~='table' or type(data.draft)~='table' then return end
    testing={vehicle=panelVehicle,draft=data.draft}
    FreezeEntityPosition(panelVehicle,true)
    SetNuiFocusKeepInput(true)
    CreateThread(testLoop)
end)

RegisterNUICallback('updateTest',function(data,cb)
    cb(1)
    if testing and type(data)=='table' and type(data.draft)=='table' then testing.draft=data.draft end
end)

RegisterNUICallback('endTest',function(_,cb) cb(1); endTest() end)

AddEventHandler('onResourceStop',function(res)
    if res~=GetCurrentResourceName() then return end
    if testing and DoesEntityExist(testing.vehicle) then FreezeEntityPosition(testing.vehicle,false) end
    if panelOpen then SetNuiFocus(false,false); SetNuiFocusKeepInput(false) end
end)

RegisterCommand(Config.MenuCommand,function() openMenu() end,false)
exports('OpenMenu',openMenu)

---------------------------------------------------------------------
-- V5.0 HOTBAR: three presets per vehicle, swapped without the panel
---------------------------------------------------------------------
local hotbarOpen=false

local function applyPreset(vehicle,i)
    local settings=settingsOf(vehicle)
    local preset=settings and settings.hotbar and settings.hotbar[i]
    if not preset then return lib.notify({type='error',description=('Preset %d is empty. Save one from the Hotbar tab.'):format(i)}) end
    TriggerServerEvent('sp_antilag:saveSettings',VehToNet(vehicle),plateOf(vehicle),copySettings(preset),('Preset %d loaded.'):format(i))
end

local function hotbarSummary(s)
    if not s then return false end
    return {colour=s.colour,intensity=s.intensity,sound=s.sound,launch=s.launch}
end

local function openHotbar()
    if hotbarOpen or panelOpen then return end
    local vehicle,reason=settingsVehicle()
    if vehicle==0 then return lib.notify({type='error',description=reason}) end
    local settings=settingsOf(vehicle) or {}
    local presets={}
    for i=1,3 do presets[i]=hotbarSummary(settings.hotbar and settings.hotbar[i]) end
    hotbarOpen=true
    SendNUIMessage({action='hotbar',show=true,presets=presets,config=uiConfig()})
    CreateThread(function()
        local untilTime=GetGameTimer()+6000
        local keys={157,158,160} -- 1, 2, 3
        while hotbarOpen and GetGameTimer()<untilTime do
            for i,c in ipairs(keys) do
                DisableControlAction(0,c,true)
                if IsDisabledControlJustPressed(0,c) then
                    applyPreset(vehicle,i)
                    SendNUIMessage({action='hotbarPick',slot=i})
                    untilTime=GetGameTimer()+500
                end
            end
            Wait(0)
        end
        hotbarOpen=false
        SendNUIMessage({action='hotbar',show=false})
    end)
end

if Config.Hotbar.Enabled then
    RegisterCommand('sp_antilag_hotbar',function()
        if hotbarOpen then hotbarOpen=false else openHotbar() end
    end,false)
    RegisterKeyMapping('sp_antilag_hotbar','Anti-lag hotbar presets','keyboard',Config.Hotbar.Key)
end

-- /antilagtest: plays pop, pop, bang, pop, mega, BIG locally so you can check the sound works.
RegisterCommand('antilagtest',function()
    local ped=PlayerPedId()
    local vehicle=GetVehiclePedIsIn(ped,false)
    local target=vehicle~=0 and vehicle or ped
    CreateThread(function()
        for _,kind in ipairs({'pop','pop','bang','pop','mega','big'}) do
            local look=vehicle~=0 and lookOf(settingsOf(vehicle) or {}) or {}
            playSound(target,kind,look)
            if vehicle~=0 then flame(vehicle,flameLevel(kind),look) end
            Wait(kind=='pop' and 110 or kind=='big' and 1200 or 450)
        end
    end)
end,false)

print(('^2[sp_antilag] client v%s loaded (sound mode: %s)^7'):format(GetResourceMetadata(GetCurrentResourceName(),'version',0) or '?',Config.SoundMode))

-- /antilagfx       cycles through every Config.ColourFxOptions entry (3 shots each)
-- /antilagfx 3     fires only option 3
-- Uses the vehicle's flame colour, or blue if it is on Stock. Pick the best-looking number
-- and set Config.ColourFx to it.
RegisterCommand('antilagfx',function(_,args)
    local vehicle=GetVehiclePedIsIn(PlayerPedId(),false)
    if vehicle==0 then return lib.notify({type='error',description='Sit in a vehicle to test flame effects.'}) end
    -- Each option fires red, then green, then blue: if all three look the same (orange),
    -- that effect does not take colour on this game build.
    local testColours={'red','green','blue'}
    local only=tonumber(args[1])
    CreateThread(function()
        for i,fx in ipairs(Config.ColourFxOptions) do
            if not only or only==i then
                lib.notify({description=('Flame FX %d: %s (red, green, blue)'):format(i,fx.label or fx.name),duration=3500})
                for n=1,3 do
                    lastFlameByVehicle={}
                    flame(vehicle,true,{colour=testColours[n]},fx)
                    playSound(vehicle,'pop')
                    Wait(700)
                end
                Wait(900)
            end
        end
    end)
end,false)
