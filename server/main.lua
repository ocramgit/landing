-- ═══════════════════════════════════════════════════════════
-- LANDING COMPETITION — SERVER
-- ═══════════════════════════════════════════════════════════

local QBCore = exports['qb-core']:GetCoreObject()

-- ── Game State ──────────────────────────────────────────────
local GameState = {
    active = false,
    zone = nil,             -- { worldX, worldY, worldZ }
    plane = nil,            -- { model, label }
    players = {},           -- { [source] = { spotIndex, landed, coords, exploded, name } }
    results = {},           -- sorted results array
    usedPlanes = {},        -- models used in previous rounds (avoid repeats)
    initiator = nil,        -- source of who started the game
    timerHandle = nil,      -- SetTimeout handle
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

-- ── Utility: Pick random plane (avoid repeats) ──────────────
local function PickRandomPlane()
    local available = {}
    for _, plane in ipairs(Config.Planes) do
        local used = false
        for _, usedModel in ipairs(GameState.usedPlanes) do
            if usedModel == plane.model then
                used = true
                break
            end
        end
        if not used then
            available[#available + 1] = plane
        end
    end

    -- Reset if all planes used
    if #available == 0 then
        GameState.usedPlanes = {}
        available = Config.Planes
    end

    local picked = available[math.random(#available)]
    GameState.usedPlanes[#GameState.usedPlanes + 1] = picked.model
    return picked
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
        GameState.active = false
        GameState.zone = nil
        GameState.plane = nil
        GameState.players = {}
        GameState.results = {}
        GameState.initiator = nil
        GameState.timerHandle = nil
        TriggerClientEvent('landing:gameReset', -1)
    end)
end

-- ── Check if all players have landed ────────────────────────
local function CheckAllLanded()
    for source, data in pairs(GameState.players) do
        if not data.landed then
            return false
        end
    end
    return true
end

-- ═══════════════════════════════════════════════════════════
-- COMMAND: /comecarpiloto
-- ═══════════════════════════════════════════════════════════
RegisterCommand('comecarpiloto', function(source, args, rawCommand)
    if GameState.active then
        TriggerClientEvent('QBCore:Notify', source, 'Já existe uma competição em andamento!', 'error')
        return
    end

    GameState.initiator = source
    TriggerClientEvent('landing:openPicker', source)
end, false) -- false = all players can use it (change to true for admin only)

-- ═══════════════════════════════════════════════════════════
-- EVENT: Zone selected from picker
-- ═══════════════════════════════════════════════════════════
RegisterNetEvent('landing:zoneSelected', function(data)
    local source = source
    if GameState.active then return end
    if source ~= GameState.initiator then return end

    -- Set game state
    GameState.active = true
    GameState.zone = {
        worldX = data.worldX,
        worldY = data.worldY,
        worldZ = data.worldZ or 0.0,
    }
    GameState.plane = PickRandomPlane()
    GameState.players = {}
    GameState.results = {}

    -- Get all online players and assign spawn spots
    local onlinePlayers = GetOnlinePlayers()
    local spawnAssignments = {}
    local totalSpots = #Config.SpawnSpots

    for i, playerId in ipairs(onlinePlayers) do
        local spotIndex = ((i - 1) % totalSpots) + 1
        GameState.players[playerId] = {
            spotIndex = spotIndex,
            landed = false,
            coords = nil,
            exploded = false,
            name = GetPlayerDisplayName(playerId),
        }
        spawnAssignments[tostring(playerId)] = {
            spot = Config.SpawnSpots[spotIndex],
            spotIndex = spotIndex,
        }
    end

    -- Notify all players to start game
    TriggerClientEvent('landing:startGame', -1, {
        zone = GameState.zone,
        plane = GameState.plane,
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

    print('[Landing Competition] Game started! Plane: ' .. GameState.plane.label ..
          ' | Zone: ' .. GameState.zone.worldX .. ', ' .. GameState.zone.worldY ..
          ' | Players: ' .. #onlinePlayers)
end)

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
        GameState.zone.worldX, GameState.zone.worldY
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
        coords = coords,
        distance = distance,
        exploded = exploded,
        score = score,
    }
    GameState.results[#GameState.results + 1] = result

    -- Notify all players about this landing
    TriggerClientEvent('landing:playerLanded', -1, {
        name = result.name,
        distance = FormatDistance(distance),
        score = score,
        exploded = exploded,
    })

    print('[Landing Competition] ' .. result.name .. ' landed at ' ..
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
