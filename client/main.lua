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

-- ── Save/Restore original position ─────────────────────────
local savedPos = nil
local savedWeapons = nil

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
-- EVENT: Open picker (only for initiator)
-- ═══════════════════════════════════════════════════════════
RegisterNetEvent('landing:openPicker', function()
    SetNuiFocus(true, true)
    SendNUIMessage({ action = 'showPicker' })
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
        Wait(500)

        -- Load vehicle model
        local modelHash = GetHashKey(data.plane.model)
        RequestModel(modelHash)
        local timeout = 0
        while not HasModelLoaded(modelHash) do
            Wait(100)
            timeout = timeout + 100
            if timeout > 10000 then
                print('[Landing] Failed to load model: ' .. data.plane.model)
                return
            end
        end

        -- Spawn vehicle
        myVehicle = CreateVehicle(modelHash, mySpot.x, mySpot.y, mySpot.z + 1.0, mySpot.h, true, false)
        SetModelAsNoLongerNeeded(modelHash)

        -- Configure vehicle
        SetVehicleEngineOn(myVehicle, true, true, false)
        SetVehicleOnGroundProperly(myVehicle)
        SetEntityInvincible(myVehicle, true)
        FreezeEntityPosition(myVehicle, true)

        -- Put player inside
        TaskWarpPedIntoVehicle(ped, myVehicle, -1)
        Wait(500)

        -- Give vehicle keys (QB-Core vehiclekeys)
        local plate = GetVehicleNumberPlateText(myVehicle)
        TriggerEvent('vehiclekeys:client:SetOwner', plate)

        -- Also try qb-vehiclekeys export method
        local success, _ = pcall(function()
            exports['qb-vehiclekeys']:SetVehicleOwner(plate)
        end)

        -- Send HUD info to NUI
        SendNUIMessage({
            action = 'showHUD',
            zone = zoneData,
            planeName = data.plane.label,
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
