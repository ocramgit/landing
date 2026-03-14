-- ═══════════════════════════════════════════════════════════
-- LANDING COMPETITION — NUI BRIDGE
-- ═══════════════════════════════════════════════════════════

-- ── Close results screen ────────────────────────────────────
RegisterNUICallback('closeResults', function(data, cb)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'hideAll' })
    cb('ok')
end)
