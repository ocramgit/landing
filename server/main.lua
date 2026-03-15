-- ═══════════════════════════════════════════════════════════
-- LANDING COMPETITION — SERVER
-- ═══════════════════════════════════════════════════════════

local QBCore = exports['qb-core']:GetCoreObject()

-- ── Game State ──────────────────────────────────────────────
local GameState = {
    active = false,
    zone = nil,             -- { x, y, z } — set via /setlanding
    players = {},           -- { [source] = { spotIndex, plane, landed, coords, exploded, name } }
    results = {},           -- sorted results array
    usedPlanes = {},        -- models used in previous rounds (avoid repeats across rounds)
    initiator = nil,        -- source of who started the game
}

-- ── Utility: Get all online players ─────────────────────────
local function GetOnlinePlayers()
    local players = {}
    for _, playerId in ipairs(GetPlayers()) do
        players[#players + 1] = tonumber(playerId)
    end
    return players
end

-- ── Utility: Get player name ────────────────────────────────
local function GetPlayerDisplayName(source)
    local Player = QBCore.Functions.GetPlayer(source)
    if Player then
        local charinfo = Player.PlayerData.charinfo
        return charinfo.firstname .. ' ' .. charinfo.lastname
    end
    return GetPlayerName(source) or ('Player ' .. source)
end

-- ── Utility: Pick unique planes for all players ─────────────
-- Each player gets a DIFFERENT airplane. If more players than
-- planes, we shuffle and repeat but no two players in one round
-- share the same model.
local function AssignPlanesToPlayers(playerCount)
    -- Build shuffled list of planes
    local shuffled = {}
    for _, plane in ipairs(Config.Planes) do
        shuffled[#shuffled + 1] = { model = plane.model, label = plane.label }
    end

    -- Fisher-Yates shuffle
    for i = #shuffled, 2, -1 do
        local j = math.random(i)
        shuffled[i], shuffled[j] = shuffled[j], shuffled[i]
    end

    -- If we need more planes than available, duplicate the shuffled list
    local assignments = {}
    for i = 1, playerCount do
        local idx = ((i - 1) % #shuffled) + 1
        assignments[i] = shuffled[idx]
    end

    return assignments
end

-- ── Utility: Calculate 2D distance ──────────────────────────
local function CalcDistance2D(x1, y1, x2, y2)
    local dx = x1 - x2
    local dy = y1 - y2
    return math.sqrt(dx * dx + dy * dy)
end

-- ── Utility: Format distance ────────────────────────────────
local function FormatDistance(meters)
    if meters >= 1000 then
        return string.format("%.2f km", meters / 1000)
    else
        return string.format("%.1f m", meters)
    end
end

-- ── Broadcast results to all players ────────────────────────
local function BroadcastResults()
    if not GameState.active then return end

    -- Sort results by score descending
    table.sort(GameState.results, function(a, b)
        return a.score > b.score
    end)

    -- Add rank and formatted distance
    for i, result in ipairs(GameState.results) do
        result.rank = i
        result.distanceFormatted = FormatDistance(result.distance)
    end

    TriggerClientEvent('landing:showResults', -1, GameState.results, GameState.zone)

    -- Reset game after 35 seconds
    CreateThread(function()
        Wait(35000)
        ResetGame()
    end)
end

-- ── Reset game state ────────────────────────────────────────
local function ResetGame()
    GameState.active = false
    GameState.zone = nil
    GameState.players = {}
    GameState.results = {}
    GameState.initiator = nil
    TriggerClientEvent('landing:gameReset', -1)
end

-- ── Check if all players have landed ────────────────────────
local function CheckAllLanded()
    for _, data in pairs(GameState.players) do
        if not data.landed then
            return false
        end
    end
    return true
end

-- ═══════════════════════════════════════════════════════════
-- COMMAND: /setlanding
-- Admin goes to a location and runs this to mark the landing zone
-- ═══════════════════════════════════════════════════════════
RegisterCommand('setlanding', function(source, args, rawCommand)
    if GameState.active then
        TriggerClientEvent('QBCore:Notify', source, 'Não podes mudar o ponto durante uma competição!', 'error')
        return
    end

    -- Ask client to send their current coords
    TriggerClientEvent('landing:getMyCoords', source)
end, false)

-- Client sends back their position
RegisterNetEvent('landing:sendMyCoords', function(coords)
    local source = source

    GameState.zone = {
        x = coords.x,
        y = coords.y,
        z = coords.z,
    }

    -- Tell ALL clients to show the blip at this location
    TriggerClientEvent('landing:setZoneBlip', -1, GameState.zone)

    TriggerClientEvent('QBCore:Notify', source, '✅ Ponto de aterragem definido! Usa /comecarpiloto para iniciar.', 'success')

    print('[Landing Competition] Landing zone set at: ' .. coords.x .. ', ' .. coords.y .. ', ' .. coords.z)
end)

-- ═══════════════════════════════════════════════════════════
-- COMMAND: /comecarpiloto
-- Starts the competition using the pre-set landing zone
-- Each player gets a DIFFERENT airplane and a DIFFERENT spot
-- ═══════════════════════════════════════════════════════════
RegisterCommand('comecarpiloto', function(source, args, rawCommand)
    if GameState.active then
        TriggerClientEvent('QBCore:Notify', source, 'Já existe uma competição em andamento!', 'error')
        return
    end

    if not GameState.zone then
        TriggerClientEvent('QBCore:Notify', source, 'Define primeiro o ponto de aterragem com /setlanding!', 'error')
        return
    end

    -- Set game state
    GameState.active = true
    GameState.initiator = source
    GameState.players = {}
    GameState.results = {}

    -- Get all online players
    local onlinePlayers = GetOnlinePlayers()
    local totalSpots = #Config.SpawnSpots

    -- Assign a DIFFERENT airplane to each player
    local planeAssignments = AssignPlanesToPlayers(#onlinePlayers)

    -- Assign spawn spots (unique per player)
    local spawnAssignments = {}
    for i, playerId in ipairs(onlinePlayers) do
        local spotIndex = ((i - 1) % totalSpots) + 1
        local plane = planeAssignments[i]

        GameState.players[playerId] = {
            spotIndex = spotIndex,
            plane = plane,
            landed = false,
            coords = nil,
            exploded = false,
            name = GetPlayerDisplayName(playerId),
        }
        spawnAssignments[tostring(playerId)] = {
            spot = Config.SpawnSpots[spotIndex],
            spotIndex = spotIndex,
            plane = plane, -- Each player gets their own plane
        }
    end

    -- Notify all players to start game
    TriggerClientEvent('landing:startGame', -1, {
        zone = GameState.zone,
        spawnAssignments = spawnAssignments,
        countdown = Config.CountdownSeconds,
        flightTime = Config.FlightTime,
        totalPlayers = #onlinePlayers,
    })

    -- Start flight timer
    CreateThread(function()
        Wait(Config.FlightTime * 1000)
        if GameState.active then
            TriggerClientEvent('landing:forceLand', -1)
            -- Give 5 seconds for forced landings to register
            Wait(5000)
            if GameState.active then
                BroadcastResults()
            end
        end
    end)

    -- Build plane list for log
    local planeNames = {}
    for i, p in ipairs(planeAssignments) do
        planeNames[i] = p.label
    end

    print('[Landing Competition] Game started! ' ..
          'Zone: ' .. GameState.zone.x .. ', ' .. GameState.zone.y ..
          ' | Players: ' .. #onlinePlayers ..
          ' | Planes: ' .. table.concat(planeNames, ', '))
end, false)

-- ═══════════════════════════════════════════════════════════
-- COMMAND: /terminarpiloto — Force end the competition
-- ═══════════════════════════════════════════════════════════
RegisterCommand('terminarpiloto', function(source, args, rawCommand)
    -- Always force-reset everything, no matter the state
    TriggerClientEvent('QBCore:Notify', -1, '⚠️ Competição terminada pelo admin.', 'primary')

    -- Force immediate reset of ALL state
    GameState.active = false
    GameState.players = {}
    GameState.results = {}
    GameState.initiator = nil
    -- NOTE: Keep GameState.zone so admin doesn't have to /setlanding again

    -- Tell all clients to clean up
    TriggerClientEvent('landing:gameReset', -1)

    print('[Landing Competition] Game FORCE-ended by player ' .. source)
end, false)

-- ═══════════════════════════════════════════════════════════
-- COMMAND: /cancelarlanding — Cancel the set point
-- ═══════════════════════════════════════════════════════════
RegisterCommand('cancelarlanding', function(source, args, rawCommand)
    if GameState.active then
        TriggerClientEvent('QBCore:Notify', source, 'Não podes cancelar durante uma competição!', 'error')
        return
    end

    GameState.zone = nil
    TriggerClientEvent('landing:removeZoneBlip', -1)
    TriggerClientEvent('QBCore:Notify', source, 'Ponto de aterragem removido.', 'primary')
end, false)

-- ═══════════════════════════════════════════════════════════
-- EVENT: Player landed
-- ═══════════════════════════════════════════════════════════
RegisterNetEvent('landing:registerLanding', function(coords, exploded)
    local source = source
    if not GameState.active then return end
    if not GameState.players[source] then return end
    if GameState.players[source].landed then return end

    -- Mark as landed
    GameState.players[source].landed = true
    GameState.players[source].coords = coords
    GameState.players[source].exploded = exploded

    -- Calculate distance and score
    local distance = CalcDistance2D(
        coords.x, coords.y,
        GameState.zone.x, GameState.zone.y
    )

    local score = Config.Scoring.baseScore - (distance * Config.Scoring.penaltyPerMeter)
    if exploded then
        score = score - Config.Scoring.explosionPenalty
    end
    score = math.max(0, math.floor(score))

    -- Store result
    local result = {
        source = source,
        name = GameState.players[source].name,
        plane = GameState.players[source].plane.label,
        coords = coords,
        distance = distance,
        exploded = exploded,
        score = score,
    }
    GameState.results[#GameState.results + 1] = result

    -- Notify all players about this landing
    TriggerClientEvent('landing:playerLanded', -1, {
        name = result.name,
        plane = result.plane,
        distance = FormatDistance(distance),
        score = score,
        exploded = exploded,
    })

    print('[Landing Competition] ' .. result.name .. ' (' .. result.plane .. ') landed at ' ..
          FormatDistance(distance) .. ' | Score: ' .. score ..
          (exploded and ' (EXPLODED)' or ''))

    -- Check if all players have landed
    if CheckAllLanded() then
        CreateThread(function()
            Wait(3000) -- Small delay for dramatic effect
            BroadcastResults()
        end)
    end
end)
