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
-- SPAWN SPOTS — Pista principal do LSIA (runway 03/21)
-- Coordenadas na pista longa, sem objetos, espaçados ~25m
-- Heading 60.0 aponta ao longo da pista para descolagem limpa
-- ═══════════════════════════════════════════════════════════
Config.SpawnSpots = {
    -- Fila 1 — lado esquerdo da pista (mais a oeste)
    { x = -1613.0, y = -3086.0, z = 13.94, h = 330.0 },
    { x = -1588.0, y = -3100.0, z = 13.94, h = 330.0 },
    { x = -1563.0, y = -3114.0, z = 13.94, h = 330.0 },
    { x = -1538.0, y = -3128.0, z = 13.94, h = 330.0 },
    { x = -1513.0, y = -3142.0, z = 13.94, h = 330.0 },
    { x = -1488.0, y = -3156.0, z = 13.94, h = 330.0 },

    -- Fila 2 — lado direito da pista (mais a este, +30m offset)
    { x = -1633.0, y = -3072.0, z = 13.94, h = 330.0 },
    { x = -1608.0, y = -3086.0, z = 13.94, h = 330.0 },
    { x = -1583.0, y = -3100.0, z = 13.94, h = 330.0 },
    { x = -1558.0, y = -3114.0, z = 13.94, h = 330.0 },
    { x = -1533.0, y = -3128.0, z = 13.94, h = 330.0 },
    { x = -1508.0, y = -3142.0, z = 13.94, h = 330.0 },
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
