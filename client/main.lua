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
        mySpot = assignment.spot

        local ped = PlayerPedId()

        -- Teleport to spawn spot
        SetEntityCoords(ped, mySpot.x, mySpot.y, mySpot.z, false, false, false, true)
        SetEntityHeading(ped, mySpot.h)
        Wait(1000)

        -- Load vehicle model (each player gets their own plane)
        local myPlane = assignment.plane
        local modelHash = GetHashKey(myPlane.model)
        RequestModel(modelHash)
        local timeout = 0
        while not HasModelLoaded(modelHash) do
            Wait(100)
            timeout = timeout + 100
            if timeout > 10000 then
                print('[Landing] Failed to load model: ' .. myPlane.model)
                return
            end
        end

        -- Spawn vehicle at exact spot
        myVehicle = CreateVehicle(modelHash, mySpot.x, mySpot.y, mySpot.z + 2.0, mySpot.h, true, false)
        SetModelAsNoLongerNeeded(modelHash)

        -- Configure vehicle
        SetVehicleEngineOn(myVehicle, true, true, false)
        SetEntityInvincible(myVehicle, true)
        FreezeEntityPosition(myVehicle, true)

        -- Put player inside
        TaskWarpPedIntoVehicle(ped, myVehicle, -1)
        Wait(500)

        -- Give vehicle keys (QB-Core vehiclekeys)
        local plate = GetVehicleNumberPlateText(myVehicle)
        TriggerEvent('vehiclekeys:client:SetOwner', plate)

        -- Also try qb-vehiclekeys export method
        pcall(function()
            exports['qb-vehiclekeys']:SetVehicleOwner(plate)
        end)

        -- Make sure the zone blip is visible and updated
        if zoneBlip and DoesBlipExist(zoneBlip) then
            SetBlipRoute(zoneBlip, true)    -- Show GPS route to landing zone
            SetBlipRouteColour(zoneBlip, 1) -- Red route
        end

        -- Send HUD info to NUI
        SendNUIMessage({
            action = 'showHUD',
            zone = zoneData,
            planeName = myPlane.label,
            flightTime = data.flightTime,
            totalPlayers = data.totalPlayers,
        })

        -- Countdown
        SendNUIMessage({ action = 'countdown', seconds = data.countdown })

        -- Wait for countdown to finish
        for i = data.countdown, 1, -1 do
            Wait(1000)
        end
        Wait(500)

        -- UNFREEZE — GO!
        FreezeEntityPosition(myVehicle, false)
        SetEntityInvincible(myVehicle, false)

        -- Start flight timer thread
        StartFlightTimer()

        -- Grace period: wait 5 seconds before landing detection
        -- (vehicle is still on the runway after unfreeze)
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
            DeleteVehicle(myVehicle)
        end
        myVehicle = nil

        -- Restore original position
        RestorePlayerState()

        -- Close NUI
        SetNuiFocus(false, false)
        SendNUIMessage({ action = 'hideAll' })
    end)
end)
