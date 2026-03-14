-- ═══════════════════════════════════════════════════════════
-- LANDING COMPETITION — NUI BRIDGE
-- ═══════════════════════════════════════════════════════════

-- ── Zone confirmed from picker ──────────────────────────────
RegisterNUICallback('zoneConfirmed', function(data, cb)
    SetNuiFocus(false, false)
    TriggerServerEvent('landing:zoneSelected', {
        worldX = data.worldX,
        worldY = data.worldY,
        worldZ = 0.0,
    })
    cb('ok')
end)

-- ── Close results screen ────────────────────────────────────
RegisterNUICallback('closeResults', function(data, cb)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'hideAll' })
    cb('ok')
end)

-- ── Close picker (cancelled) ────────────────────────────────
RegisterNUICallback('closePicker', function(data, cb)
    SetNuiFocus(false, false)
    SendNUIMessage({ action = 'hideAll' })
    cb('ok')
end)
