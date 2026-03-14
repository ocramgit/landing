Config = {}

-- ═══════════════════════════════════════════════════════════
-- AVIÕES DISPONÍVEIS (cada ronda usa um diferente)
-- ═══════════════════════════════════════════════════════════
Config.Planes = {
    { model = 'luxor',      label = 'Luxor' },
    { model = 'luxor2',     label = 'Luxor Deluxe' },
    { model = 'shamal',     label = 'Shamal' },
    { model = 'vestra',     label = 'Vestra' },
    { model = 'mammatus',   label = 'Mammatus' },
    { model = 'duster',     label = 'Duster' },
    { model = 'stunt',      label = 'Stunt Plane' },
    { model = 'cuban800',   label = 'Cuban 800' },
    { model = 'velum',      label = 'Velum' },
    { model = 'velum2',     label = 'Velum 5-Seater' },
    { model = 'nimbus',     label = 'Nimbus' },
    { model = 'alphaz1',    label = 'Alpha-Z1' },
}

-- ═══════════════════════════════════════════════════════════
-- SPAWN SPOTS — Pista principal LSIA (12 posições lado a lado)
-- Espaçadas ~20m para evitar colisões no spawn
-- ═══════════════════════════════════════════════════════════
Config.SpawnSpots = {
    { x = -1249.0, y = -2892.0, z = 13.95, h = 330.0 },
    { x = -1269.0, y = -2892.0, z = 13.95, h = 330.0 },
    { x = -1289.0, y = -2892.0, z = 13.95, h = 330.0 },
    { x = -1309.0, y = -2892.0, z = 13.95, h = 330.0 },
    { x = -1329.0, y = -2892.0, z = 13.95, h = 330.0 },
    { x = -1349.0, y = -2892.0, z = 13.95, h = 330.0 },
    { x = -1369.0, y = -2892.0, z = 13.95, h = 330.0 },
    { x = -1389.0, y = -2892.0, z = 13.95, h = 330.0 },
    { x = -1409.0, y = -2892.0, z = 13.95, h = 330.0 },
    { x = -1429.0, y = -2892.0, z = 13.95, h = 330.0 },
    { x = -1449.0, y = -2892.0, z = 13.95, h = 330.0 },
    { x = -1469.0, y = -2892.0, z = 13.95, h = 330.0 },
}

-- ═══════════════════════════════════════════════════════════
-- TIMERS
-- ═══════════════════════════════════════════════════════════
Config.CountdownSeconds = 10    -- Countdown antes de descolar
Config.FlightTime = 300         -- 5 minutos de voo

-- ═══════════════════════════════════════════════════════════
-- SCORING
-- ═══════════════════════════════════════════════════════════
Config.Scoring = {
    baseScore = 10000,          -- Pontuação base
    penaltyPerMeter = 10,       -- Pontos perdidos por metro de distância
    explosionPenalty = 3000,    -- Penalização se o avião explodiu
}
