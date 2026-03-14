/* ═══════════════════════════════════════════════════════════
   LANDING COMPETITION — APP.JS (Main Router + Dev Mode)
   ═══════════════════════════════════════════════════════════ */

// ── View Management ─────────────────────────────────────────
function showView(id) {
    document.querySelectorAll('.view').forEach(v => v.classList.add('hidden'));
    const el = document.getElementById(id);
    if (el) el.classList.remove('hidden');
}

function hideAllViews() {
    document.querySelectorAll('.view').forEach(v => v.classList.add('hidden'));
}

// ── Resource name (FiveM) ───────────────────────────────────
const resourceName = window.GetParentResourceName ? window.GetParentResourceName() : 'landing-competition';
const isDevMode = !window.GetParentResourceName;

// ── Message Router ──────────────────────────────────────────
window.addEventListener('message', function(event) {
    const data = event.data;
    if (!data || !data.action) return;

    switch (data.action) {
        case 'showPicker':
            showView('picker-view');
            if (typeof initPicker === 'function') initPicker();
            break;

        case 'showHUD':
            showView('hud-view');
            if (typeof initHUD === 'function') initHUD(data);
            break;

        case 'countdown':
            if (typeof startCountdown === 'function') startCountdown(data.seconds);
            break;

        case 'updateTimer':
            if (typeof updateTimer === 'function') updateTimer(data.timeLeft);
            break;

        case 'playerLandedFeed':
            if (typeof addLandingFeed === 'function') addLandingFeed(data);
            break;

        case 'landingRegistered':
            if (typeof showLandedNotice === 'function') showLandedNotice(data.exploded);
            break;

        case 'showResults':
            showView('results-view');
            if (typeof initResults === 'function') initResults(data.results, data.zone);
            break;

        case 'hideAll':
            hideAllViews();
            break;
    }
});

// ── ESC key to close results ────────────────────────────────
document.addEventListener('keydown', function(e) {
    if (e.key === 'Escape') {
        const resultsView = document.getElementById('results-view');
        if (resultsView && !resultsView.classList.contains('hidden')) {
            fetch(`https://${resourceName}/closeResults`, { method: 'POST', body: JSON.stringify({}) });
            hideAllViews();
        }
    }
});

// ═══════════════════════════════════════════════════════════
// DEV MODE — Simulate full game sequence in browser
// ═══════════════════════════════════════════════════════════
if (isDevMode) {
    console.log('%c✈️ Landing Competition — DEV MODE', 'color: #00e5ff; font-size: 16px; font-weight: bold;');
    console.log('Simulating game sequence...');

    // Simulate picker
    setTimeout(() => {
        window.postMessage({ action: 'showPicker' }, '*');
    }, 300);

    // After "confirming", simulate HUD + countdown
    setTimeout(() => {
        hideAllViews();
        window.postMessage({
            action: 'showHUD',
            zone: { worldX: 150.0, worldY: -1020.0 },
            planeName: 'Luxor Deluxe',
            flightTime: 300,
            totalPlayers: 4,
        }, '*');
    }, 5000);

    setTimeout(() => {
        window.postMessage({ action: 'countdown', seconds: 10 }, '*');
    }, 5500);

    // Simulate landing feed
    setTimeout(() => {
        window.postMessage({
            action: 'playerLandedFeed',
            name: 'Marco Silva',
            distance: '42.3 m',
            score: 9577,
            exploded: false,
        }, '*');
    }, 18000);

    setTimeout(() => {
        window.postMessage({
            action: 'playerLandedFeed',
            name: 'João Pedro',
            distance: '187.5 m',
            score: 8125,
            exploded: false,
        }, '*');
    }, 20000);

    setTimeout(() => {
        window.postMessage({
            action: 'playerLandedFeed',
            name: 'Ana Costa',
            distance: '1.23 km',
            score: 0,
            exploded: true,
        }, '*');
    }, 22000);

    // Simulate results
    setTimeout(() => {
        window.postMessage({
            action: 'showResults',
            results: [
                { rank: 1, name: 'Marco Silva', distance: 42.3, distanceFormatted: '42.3 m', score: 9577, exploded: false, coords: { x: 165.0, y: -985.0, z: 30.0 } },
                { rank: 2, name: 'João Pedro', distance: 187.5, distanceFormatted: '187.5 m', score: 8125, exploded: false, coords: { x: 250.0, y: -870.0, z: 30.0 } },
                { rank: 3, name: 'Ana Costa', distance: 1230.0, distanceFormatted: '1.23 km', score: 0, exploded: true, coords: { x: 900.0, y: -200.0, z: 30.0 } },
                { rank: 4, name: 'Carlos Lima', distance: 560.0, distanceFormatted: '560.0 m', score: 4400, exploded: false, coords: { x: 600.0, y: -700.0, z: 30.0 } },
            ],
            zone: { worldX: 150.0, worldY: -1020.0 },
        }, '*');
    }, 25000);
}
