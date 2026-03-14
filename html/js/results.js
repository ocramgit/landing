/* ═══════════════════════════════════════════════════════════
   LANDING COMPETITION — RESULTS.JS (GeoGuessr-style Results)
   ═══════════════════════════════════════════════════════════ */

let resultsMap = null;
let autoCloseTimer = null;

// ── Player colors for map markers ───────────────────────────
const PLAYER_COLORS = [
    '#ffd700', // Gold (1st)
    '#c0c0c0', // Silver (2nd)
    '#cd7f32', // Bronze (3rd)
    '#00e5ff', // Cyan
    '#ff2d7b', // Magenta
    '#00e676', // Green
    '#ff9100', // Orange
    '#7c4dff', // Purple
    '#18ffff', // Light Cyan
    '#ff6e40', // Deep Orange
    '#eeff41', // Lime
    '#e040fb', // Pink
];

// ── Coordinate conversion (GTA World → Leaflet) ────────────
function worldToLeaflet(worldX, worldY) {
    const lng = (worldX + 4096.0) / 8192.0 * 256.0;
    const lat = (worldY + 4096.0) / 8192.0 * 256.0;
    return L.latLng(lat, lng);
}

// ── Init Results ────────────────────────────────────────────
function initResults(results, zone) {
    const mapContainer = document.getElementById('results-map');
    const listContainer = document.getElementById('results-list');

    // Destroy existing map
    if (resultsMap) {
        resultsMap.remove();
        resultsMap = null;
    }

    // Clear list
    listContainer.innerHTML = '';

    // Create map
    resultsMap = L.map('results-map', {
        crs: L.CRS.Simple,
        minZoom: 1,
        maxZoom: 5,
        zoomControl: true,
        attributionControl: false,
    });

    // Add tile layer
    L.tileLayer('https://maptilesv3.gta5.dev/tiles/satmap/{z}/{x}/{y}.jpg', {
        minZoom: 1,
        maxZoom: 5,
        bounds: [[0, 0], [256, 256]],
        noWrap: true,
    }).addTo(resultsMap);

    // ── Target marker (🎯) ──────────────────────────────────
    const targetLatLng = worldToLeaflet(zone.worldX, zone.worldY);

    L.marker(targetLatLng, {
        icon: L.divIcon({
            className: 'marker-target',
            iconSize: [24, 24],
            iconAnchor: [12, 12],
        }),
    }).addTo(resultsMap);

    // Collect all points for auto-zoom
    const allPoints = [targetLatLng];

    // ── Player markers + lines ──────────────────────────────
    results.forEach((result, index) => {
        const color = PLAYER_COLORS[index % PLAYER_COLORS.length];
        const playerLatLng = worldToLeaflet(result.coords.x, result.coords.y);
        allPoints.push(playerLatLng);

        // Player marker
        L.marker(playerLatLng, {
            icon: L.divIcon({
                className: '',
                html: `<div class="marker-player" style="background: ${color};">${index + 1}</div>`,
                iconSize: [32, 32],
                iconAnchor: [16, 16],
            }),
        }).addTo(resultsMap)
            .bindPopup(`<b>${escapeHtmlResult(result.name)}</b><br>${result.distanceFormatted} | ${result.score} pts`);

        // Dashed line to target
        L.polyline([playerLatLng, targetLatLng], {
            color: color,
            weight: 2,
            opacity: 0.5,
            dashArray: '8, 6',
            className: 'result-line',
        }).addTo(resultsMap);
    });

    // Auto-zoom to fit all markers
    if (allPoints.length > 1) {
        const bounds = L.latLngBounds(allPoints);
        resultsMap.fitBounds(bounds.pad(0.15));
    } else {
        resultsMap.setView(targetLatLng, 3);
    }

    // ── Sidebar ranking ─────────────────────────────────────
    results.forEach((result, index) => {
        const card = document.createElement('div');
        const rankClass = index < 3 ? `rank-${index + 1}` : '';
        card.className = `result-card ${rankClass}`;
        card.style.animationDelay = `${index * 0.1}s`;

        const rankEmoji = index === 0 ? '🥇' : index === 1 ? '🥈' : index === 2 ? '🥉' : '';
        const rankDisplay = rankEmoji || `#${index + 1}`;

        const color = PLAYER_COLORS[index % PLAYER_COLORS.length];

        card.innerHTML = `
            <div class="result-rank ${rankClass || 'rank-other'}">${rankDisplay}</div>
            <div class="result-info">
                <div class="result-name" style="color: ${color};">${escapeHtmlResult(result.name)}</div>
                <div class="result-distance">
                    📍 ${result.distanceFormatted}
                    ${result.exploded ? '<span class="exploded-tag">💥 EXPLODIU</span>' : ''}
                </div>
            </div>
            <div class="result-score">
                ${result.score.toLocaleString()}
                <span>pontos</span>
            </div>
        `;

        // Hover → highlight on map
        card.addEventListener('mouseenter', () => {
            const playerLatLng = worldToLeaflet(result.coords.x, result.coords.y);
            resultsMap.panTo(playerLatLng, { duration: 0.5 });
        });

        listContainer.appendChild(card);
    });

    // ── Auto-close timer ────────────────────────────────────
    startAutoClose(30);

    // ── Close button ────────────────────────────────────────
    document.getElementById('btn-close-results').onclick = function() {
        closeResults();
    };
}

// ── Auto-close progress bar ─────────────────────────────────
function startAutoClose(seconds) {
    if (autoCloseTimer) clearInterval(autoCloseTimer);

    const progressBar = document.getElementById('auto-close-progress');
    const timeDisplay = document.getElementById('auto-close-time');
    let remaining = seconds;

    progressBar.style.width = '100%';
    timeDisplay.textContent = remaining;

    autoCloseTimer = setInterval(() => {
        remaining--;
        timeDisplay.textContent = remaining;
        progressBar.style.width = `${(remaining / seconds) * 100}%`;

        if (remaining <= 0) {
            clearInterval(autoCloseTimer);
            autoCloseTimer = null;
            closeResults();
        }
    }, 1000);
}

// ── Close results ───────────────────────────────────────────
function closeResults() {
    if (autoCloseTimer) {
        clearInterval(autoCloseTimer);
        autoCloseTimer = null;
    }

    fetch(`https://${resourceName}/closeResults`, {
        method: 'POST',
        body: JSON.stringify({}),
    });

    hideAllViews();
}

// ── HTML escape utility ─────────────────────────────────────
function escapeHtmlResult(str) {
    const div = document.createElement('div');
    div.textContent = str;
    return div.innerHTML;
}
