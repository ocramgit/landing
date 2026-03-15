-- ═══════════════════════════════════════════════════════════
-- LANDING COMPETITION — CLIENT
-- ═══════════════════════════════════════════════════════════

local QBCore = exports['qb-core']:GetCoreObject()

-- ── Local State ─────────────────────────────────────────────
local myVehicle = nil
local mySpot = nil
local gameActive = false
local hasLanded = false
local zoneData = nil
local flightTimeLeft = 0
local stableTimer = 0           -- frames at stable landing condition
local STABLE_THRESHOLD = 4      -- 4 × 500ms = 2 seconds
local stationaryTimer = 0       -- frames where vehicle is barely moving
local STATIONARY_THRESHOLD = 40 -- 40 × 500ms = 20 seconds

-- ── Blip/Marker ─────────────────────────────────────────────
local zoneBlip = nil
local zoneMarkerCoords = nil    -- {x, y, z} for drawing the ground marker

-- ── Save/Restore original position ─────────────────────────
local savedPos = nil

local function SavePlayerState()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    savedPos = { x = coords.x, y = coords.y, z = coords.z, h = GetEntityHeading(ped) }
end

local function RestorePlayerState()
    if savedPos then
        local ped = PlayerPedId()
        SetEntityCoords(ped, savedPos.x, savedPos.y, savedPos.z, false, false, false, true)
        SetEntityHeading(ped, savedPos.h)
        savedPos = nil
    end
end

-- ═══════════════════════════════════════════════════════════
-- EVENT: Server asks for my coords (/setlanding)
-- ═══════════════════════════════════════════════════════════
RegisterNetEvent('landing:getMyCoords', function()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    TriggerServerEvent('landing:sendMyCoords', {
        x = coords.x,
        y = coords.y,
        z = coords.z,
    })
end)

-- ═══════════════════════════════════════════════════════════
-- EVENT: Set the zone blip on the map (all players)
-- ═══════════════════════════════════════════════════════════
RegisterNetEvent('landing:setZoneBlip', function(zone)
    -- Remove old blip if exists
    if zoneBlip then
        RemoveBlip(zoneBlip)
        zoneBlip = nil
    end

    zoneMarkerCoords = zone

    -- Create blip
    zoneBlip = AddBlipForCoord(zone.x, zone.y, zone.z)
    SetBlipSprite(zoneBlip, 358)            -- Parachute/target icon
    SetBlipDisplay(zoneBlip, 4)
    SetBlipScale(zoneBlip, 1.2)
    SetBlipColour(zoneBlip, 1)              -- Red
    SetBlipAsShortRange(zoneBlip, false)     -- Always visible
    SetBlipFlashes(zoneBlip, true)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("🎯 Landing Zone")
    EndTextCommandSetBlipName(zoneBlip)

    -- Stop flashing after 10 seconds
    CreateThread(function()
        Wait(10000)
        if zoneBlip and DoesBlipExist(zoneBlip) then
            SetBlipFlashes(zoneBlip, false)
        end
    end)
end)

-- ═══════════════════════════════════════════════════════════
-- EVENT: Remove zone blip (/cancelarlanding)
-- ═══════════════════════════════════════════════════════════
RegisterNetEvent('landing:removeZoneBlip', function()
    if zoneBlip then
        RemoveBlip(zoneBlip)
        zoneBlip = nil
    end
    zoneMarkerCoords = nil
end)

-- ═══════════════════════════════════════════════════════════
-- THREAD: Draw 3D marker at zone location (pulsing column)
-- ═══════════════════════════════════════════════════════════
CreateThread(function()
    while true do
        Wait(0)
        if zoneMarkerCoords then
            -- Draw pulsing cylinder marker at the landing zone
            local z = zoneMarkerCoords.z - 1.0
            DrawMarker(
                1,                                      -- Type: cylinder
                zoneMarkerCoords.x, zoneMarkerCoords.y, z,
                0.0, 0.0, 0.0,                         -- Direction
                0.0, 0.0, 0.0,                         -- Rotation
                5.0, 5.0, 30.0,                        -- Scale (5m radius, 30m tall column)
                255, 0, 0, 100,                        -- RGBA (Red, semi-transparent)
                false,                                  -- Bob up and down
                false,                                  -- Face camera
                2,                                      -- P19
                false,                                  -- Rotate
                nil, nil,                               -- Texture dict/name
                false                                   -- Draw on entities
            )
        else
            Wait(500) -- Save CPU when no marker
        end
    end
end)

-- ═══════════════════════════════════════════════════════════
-- EVENT: Start game (all players)
-- ═══════════════════════════════════════════════════════════
RegisterNetEvent('landing:startGame', function(data)
    CreateThread(function()
        local mySource = tostring(GetPlayerServerId(PlayerId()))
        local assignment = data.spawnAssignments[mySource]

        if not assignment then
            print('[Landing] No spawn assignment for me (' .. mySource .. ')')
            return
        end

        -- Save current position
        SavePlayerState()

        -- Reset state
        gameActive = true
        hasLanded = false
        zoneData = data.zone
        flightTimeLeft = data.flightTime
        stableTimer = 0
        stationaryTimer = 0
        mySpot = assignment.spot

        local ped = PlayerPedId()

        -- ── Teleport to spawn spot ──────────────────────────────
        SetEntityCoords(ped, mySpot.x, mySpot.y, mySpot.z, false, false, false, true)
        SetEntityHeading(ped, mySpot.h)
        Wait(1500)

        -- ── Helper: load a model with timeout ──────────────────
        local function LoadModel(hash, maxMs)
            RequestModel(hash)
            local waited = 0
            while not HasModelLoaded(hash) do
                Wait(50)
                waited = waited + 50
                if waited > maxMs then return false end
            end
            return true
        end

        -- ── Helper: try to spawn vehicle ────────────────────────
        local function TrySpawnVehicle(hash, spot, maxRetries)
            for attempt = 1, maxRetries do
                -- Make sure ped is at the spawn spot
                ped = PlayerPedId()
                SetEntityCoords(ped, spot.x, spot.y, spot.z, false, false, false, true)
                SetEntityHeading(ped, spot.h)
                Wait(200)

                -- Clear area before spawning
                ClearAreaOfVehicles(spot.x, spot.y, spot.z, 15.0, false, false, false, false, false)
                Wait(200)

                local veh = CreateVehicle(hash, spot.x, spot.y, spot.z + 2.0, spot.h, true, false)
                if veh and veh ~= 0 and DoesEntityExist(veh) then
                    -- IMMEDIATELY protect from network cleanup
                    SetEntityAsMissionEntity(veh, true, true)
                    local netId = NetworkGetNetworkIdFromEntity(veh)
                    if netId and netId ~= 0 then
                        SetNetworkIdCanMigrate(netId, false)
                        SetNetworkIdExistsOnAllMachines(netId, true)
                    end
                    SetVehicleHasBeenOwnedByPlayer(veh, true)
                    print('[Landing] Vehicle spawned on attempt ' .. attempt .. ' (netId: ' .. tostring(netId) .. ')')
                    return veh
                end

                print('[Landing] Spawn attempt ' .. attempt .. ' failed, retrying...')
                if veh and veh ~= 0 then DeleteVehicle(veh) end
                Wait(1000)

                -- Re-request model just in case it got unloaded
                if not HasModelLoaded(hash) then
                    RequestModel(hash)
                    Wait(2000)
                end
            end
            return nil
        end

        -- ── Load vehicle model ──────────────────────────────────
        local myPlane = assignment.plane
        local modelHash = GetHashKey(myPlane.model)
        local FALLBACK_MODEL = 'mallard'
        local FALLBACK_LABEL = 'Mallard (Fallback)'

        if not LoadModel(modelHash, 20000) then
            print('[Landing] WARN: Failed to load "' .. myPlane.model .. '", switching to fallback "' .. FALLBACK_MODEL .. '"')
            modelHash = GetHashKey(FALLBACK_MODEL)
            if not LoadModel(modelHash, 15000) then
                print('[Landing] CRITICAL: Could not load any aircraft model!')
                return
            end
            myPlane = { model = FALLBACK_MODEL, label = FALLBACK_LABEL }
        end

        -- ── Delete any existing vehicle from previous rounds ────
        if myVehicle and DoesEntityExist(myVehicle) then
            DeleteVehicle(myVehicle)
            myVehicle = nil
            Wait(300)
        end

        -- ── Spawn vehicle (try original, then fallback) ─────────
        local MAX_RETRIES = 5
        myVehicle = TrySpawnVehicle(modelHash, mySpot, MAX_RETRIES)

        -- If original model failed to spawn, try fallback mallard
        if not myVehicle or not DoesEntityExist(myVehicle) then
            print('[Landing] Original model "' .. myPlane.model .. '" failed all spawns. Trying fallback "' .. FALLBACK_MODEL .. '"...')
            local fallbackHash = GetHashKey(FALLBACK_MODEL)
            if LoadModel(fallbackHash, 15000) then
                myVehicle = TrySpawnVehicle(fallbackHash, mySpot, MAX_RETRIES)
                if myVehicle and DoesEntityExist(myVehicle) then
                    myPlane = { model = FALLBACK_MODEL, label = FALLBACK_LABEL }
                    SetModelAsNoLongerNeeded(fallbackHash)
                end
            end
        end

        SetModelAsNoLongerNeeded(modelHash)

        -- Final validation
        if not myVehicle or not DoesEntityExist(myVehicle) then
            print('[Landing] CRITICAL: Could not create ANY vehicle after all attempts!')
            return
        end

        print('[Landing] SUCCESS: Player got aircraft "' .. myPlane.model .. '"')

        -- ── Configure vehicle ─────────────────────────────────
        -- Re-assert ownership protection (belt and suspenders)
        SetEntityAsMissionEntity(myVehicle, true, true)
        local netId = NetworkGetNetworkIdFromEntity(myVehicle)
        if netId and netId ~= 0 then
            SetNetworkIdCanMigrate(netId, false)
            SetNetworkIdExistsOnAllMachines(netId, true)
        end
        SetVehicleHasBeenOwnedByPlayer(myVehicle, true)
        SetVehicleEngineOn(myVehicle, true, true, false)
        SetEntityInvincible(myVehicle, true)
        FreezeEntityPosition(myVehicle, true)
        SetVehicleOnGroundProperly(myVehicle)

        -- ── Warp player into vehicle with retry ─────────────────
        ped = PlayerPedId()
        local warpAttempts = 0
        local MAX_WARP_RETRIES = 10
        repeat
            TaskWarpPedIntoVehicle(ped, myVehicle, -1)
            Wait(500)
            ped = PlayerPedId()
            warpAttempts = warpAttempts + 1
        until IsPedInVehicle(ped, myVehicle, false) or warpAttempts >= MAX_WARP_RETRIES

        if not IsPedInVehicle(ped, myVehicle, false) then
            print('[Landing] WARN: Could not warp player into vehicle after ' .. MAX_WARP_RETRIES .. ' attempts, forcing...')
            SetPedIntoVehicle(ped, myVehicle, -1)
            Wait(300)
        end

        -- ── Give vehicle keys (multiple methods) ────────────────
        local plate = GetVehicleNumberPlateText(myVehicle)
        if plate and plate ~= '' then
            -- Method 1: QB vehiclekeys event
            pcall(function()
                TriggerEvent('vehiclekeys:client:SetOwner', plate)
            end)
            -- Method 2: qb-vehiclekeys export
            pcall(function()
                exports['qb-vehiclekeys']:SetVehicleOwner(plate)
            end)
            -- Method 3: Direct server-side key assignment
            pcall(function()
                TriggerServerEvent('qb-vehiclekeys:server:AcquireVehicleKeys', plate)
            end)
        end

        -- ── Disable vehicle auto-lock ───────────────────────────
        SetVehicleDoorsLocked(myVehicle, 1) -- 1 = unlocked
        SetVehicleDoorsLockedForAllPlayers(myVehicle, false)

        -- ── Make sure the zone blip is visible ──────────────────
        if zoneBlip and DoesBlipExist(zoneBlip) then
            SetBlipRoute(zoneBlip, true)
            SetBlipRouteColour(zoneBlip, 1)
        end

        -- ── Send HUD info to NUI ────────────────────────────────
        SendNUIMessage({
            action = 'showHUD',
            zone = zoneData,
            planeName = myPlane.label,
            flightTime = data.flightTime,
            totalPlayers = data.totalPlayers,
        })

        -- ── Countdown ───────────────────────────────────────────
        SendNUIMessage({ action = 'countdown', seconds = data.countdown })

        -- Safety thread: keep player in vehicle during countdown
        local countdownActive = true
        CreateThread(function()
            while countdownActive and gameActive do
                Wait(300)
                local p = PlayerPedId()
                if myVehicle and DoesEntityExist(myVehicle) and not IsPedInVehicle(p, myVehicle, false) then
                    SetPedIntoVehicle(p, myVehicle, -1)
                    print('[Landing] Re-warped player into vehicle during countdown')
                end
            end
        end)

        -- Wait for countdown to finish
        for i = data.countdown, 1, -1 do
            Wait(1000)
        end
        Wait(500)
        countdownActive = false

        -- ── Final check before unfreeze ─────────────────────────
        ped = PlayerPedId()
        if myVehicle and DoesEntityExist(myVehicle) then
            if not IsPedInVehicle(ped, myVehicle, false) then
                SetPedIntoVehicle(ped, myVehicle, -1)
                Wait(300)
            end

            -- UNFREEZE — GO!
            FreezeEntityPosition(myVehicle, false)
            SetEntityInvincible(myVehicle, false)
            SetVehicleEngineOn(myVehicle, true, true, false)
        else
            print('[Landing] CRITICAL: Vehicle disappeared before unfreeze!')
            return
        end

        -- Start flight timer thread
        StartFlightTimer()

        -- Grace period: wait 5 seconds before landing detection
        Wait(5000)

        -- Start landing detection thread (only if still in game)
        if gameActive and not hasLanded then
            StartLandingDetection()
        end
    end)
end)

-- ═══════════════════════════════════════════════════════════
-- LANDING DETECTION THREAD
-- ═══════════════════════════════════════════════════════════
function StartLandingDetection()
    CreateThread(function()
        while gameActive and not hasLanded do
            Wait(500)

            if not myVehicle or not DoesEntityExist(myVehicle) then
                -- Vehicle destroyed/gone - register crash landing
                RegisterMyLanding(true)
                break
            end

            local ped = PlayerPedId()

            -- Check if vehicle is dead (exploded)
            if IsEntityDead(myVehicle) then
                RegisterMyLanding(true)
                break
            end

            -- Check if player left the vehicle
            if not IsPedInVehicle(ped, myVehicle, false) then
                -- Player bailed out - register at current position
                RegisterMyLanding(false)
                break
            end

            -- Check landing conditions: on ground + slow speed
            local speed = GetEntitySpeed(myVehicle) * 3.6 -- Convert m/s to km/h
            local onGround = IsVehicleOnAllWheels(myVehicle)

            if onGround and speed < 10.0 then
                stableTimer = stableTimer + 1
                if stableTimer >= STABLE_THRESHOLD then
                    RegisterMyLanding(false)
                    break
                end
            else
                stableTimer = 0
            end

            -- Stationary detection: if barely moving for 20s, consider landed/stuck
            if speed < 2.0 then
                stationaryTimer = stationaryTimer + 1
                if stationaryTimer >= STATIONARY_THRESHOLD then
                    print('[Landing] Vehicle stationary for 20s — registering as landed')
                    RegisterMyLanding(false)
                    break
                end
            else
                stationaryTimer = 0
            end
        end
    end)
end

-- ── Register landing ────────────────────────────────────────
function RegisterMyLanding(exploded)
    if hasLanded then return end
    hasLanded = true

    local coords
    if myVehicle and DoesEntityExist(myVehicle) then
        local vCoords = GetEntityCoords(myVehicle)
        coords = { x = vCoords.x, y = vCoords.y, z = vCoords.z }
    else
        local ped = PlayerPedId()
        local pCoords = GetEntityCoords(ped)
        coords = { x = pCoords.x, y = pCoords.y, z = pCoords.z }
    end

    TriggerServerEvent('landing:registerLanding', coords, exploded)

    -- Remove GPS route
    if zoneBlip and DoesBlipExist(zoneBlip) then
        SetBlipRoute(zoneBlip, false)
    end

    -- Notify NUI
    SendNUIMessage({
        action = 'landingRegistered',
        exploded = exploded,
    })
end

-- ═══════════════════════════════════════════════════════════
-- FLIGHT TIMER THREAD
-- ═══════════════════════════════════════════════════════════
function StartFlightTimer()
    CreateThread(function()
        while gameActive and flightTimeLeft > 0 do
            Wait(1000)
            flightTimeLeft = flightTimeLeft - 1
            SendNUIMessage({
                action = 'updateTimer',
                timeLeft = flightTimeLeft,
            })
        end
    end)
end

-- ═══════════════════════════════════════════════════════════
-- EVENT: Force land (time's up)
-- ═══════════════════════════════════════════════════════════
RegisterNetEvent('landing:forceLand', function()
    if gameActive and not hasLanded then
        RegisterMyLanding(false)
    end
end)

-- ═══════════════════════════════════════════════════════════
-- EVENT: Another player landed (feed notification)
-- ═══════════════════════════════════════════════════════════
RegisterNetEvent('landing:playerLanded', function(data)
    SendNUIMessage({
        action = 'playerLandedFeed',
        name = data.name,
        distance = data.distance,
        score = data.score,
        exploded = data.exploded,
    })
end)

-- ═══════════════════════════════════════════════════════════
-- EVENT: Show results (GeoGuessr style)
-- ═══════════════════════════════════════════════════════════
RegisterNetEvent('landing:showResults', function(results, zone)
    CreateThread(function()
        SendNUIMessage({
            action = 'showResults',
            results = results,
            zone = zone,
        })
        SetNuiFocus(true, false) -- Show cursor for results, but allow camera movement
    end)
end)

-- ═══════════════════════════════════════════════════════════
-- EVENT: Game reset
-- ═══════════════════════════════════════════════════════════
RegisterNetEvent('landing:gameReset', function()
    CreateThread(function()
        gameActive = false
        hasLanded = false
        zoneData = nil
        stableTimer = 0

        -- Remove GPS route
        if zoneBlip and DoesBlipExist(zoneBlip) then
            SetBlipRoute(zoneBlip, false)
        end

        -- Remove the zone blip entirely after game
        if zoneBlip then
            RemoveBlip(zoneBlip)
            zoneBlip = nil
        end
        zoneMarkerCoords = nil

        -- Delete the spawned vehicle if it still exists
        if myVehicle and DoesEntityExist(myVehicle) then
            SetEntityAsMissionEntity(myVehicle, true, true)
            DeleteVehicle(myVehicle)
        end
        myVehicle = nil

        -- Clean up ALL planes/vehicles around every spawn spot
        for _, spot in ipairs(Config.SpawnSpots) do
            ClearAreaOfVehicles(spot.x, spot.y, spot.z, 50.0, false, false, false, false, false)
        end

        -- Restore original position
        RestorePlayerState()

        -- Close NUI
        SetNuiFocus(false, false)
        SendNUIMessage({ action = 'hideAll' })
    end)
end)
