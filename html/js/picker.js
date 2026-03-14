/* ═══════════════════════════════════════════════════════════
   LANDING COMPETITION — PICKER.JS (Map Zone Selector)
   ═══════════════════════════════════════════════════════════ */

let pickerMap = null;
let pickerMarker = null;
let selectedCoords = null;

// ── GTA V Map Tile Config ───────────────────────────────────
// Using gta5.dev tile server with L.CRS.Simple
// Tile bounds: 0-256 in both axes
const TILE_URL = 'https://maptilesv3.gta5.dev/tiles/satmap/{z}/{x}/{y}.jpg';
const MAP_BOUNDS = [[0, 0], [256, 256]];

// ── Coordinate conversion (Leaflet → GTA World) ────────────
// Based on gta5.dev tile mapping:
// Leaflet lat/lng 0-256 maps to GTA world approx -4096 to +4096
function leafletToWorld(latlng) {
    const worldX = (latlng.lng / 256.0 * 8192.0) - 4096.0;
    const worldY = (latlng.lat / 256.0 * 8192.0) - 4096.0;
    return { worldX: worldX, worldY: worldY };
}

// ── Init Picker ─────────────────────────────────────────────
function initPicker() {
    const container = document.getElementById('picker-map');

    // Destroy existing map
    if (pickerMap) {
        pickerMap.remove();
        pickerMap = null;
    }

    pickerMarker = null;
    selectedCoords = null;

    // Hide confirm bar
    document.getElementById('picker-confirm-bar').classList.add('hidden');

    // Create map
    pickerMap = L.map('picker-map', {
        crs: L.CRS.Simple,
        minZoom: 1,
        maxZoom: 5,
        zoomControl: true,
        attributionControl: false,
    });

    // Add tile layer
    L.tileLayer(TILE_URL, {
        minZoom: 1,
        maxZoom: 5,
        bounds: MAP_BOUNDS,
        noWrap: true,
    }).addTo(pickerMap);

    // Set initial view (center of map)
    pickerMap.setView([128, 128], 2);

    // Click handler
    pickerMap.on('click', function(e) {
        const latlng = e.latlng;

        // Clamp to bounds
        const lat = Math.max(0, Math.min(256, latlng.lat));
        const lng = Math.max(0, Math.min(256, latlng.lng));
        const clampedLatLng = L.latLng(lat, lng);

        // Calculate world coordinates
        selectedCoords = leafletToWorld(clampedLatLng);

        // Place or move marker
        if (pickerMarker) {
            pickerMarker.setLatLng(clampedLatLng);
        } else {
            pickerMarker = L.marker(clampedLatLng, {
                icon: L.divIcon({
                    className: 'marker-target',
                    iconSize: [24, 24],
                    iconAnchor: [12, 12],
                }),
                draggable: true,
            }).addTo(pickerMap);

            // Drag handler
            pickerMarker.on('dragend', function(e) {
                const pos = e.target.getLatLng();
                const clampedLat = Math.max(0, Math.min(256, pos.lat));
                const clampedLng = Math.max(0, Math.min(256, pos.lng));
                e.target.setLatLng(L.latLng(clampedLat, clampedLng));
                selectedCoords = leafletToWorld(L.latLng(clampedLat, clampedLng));
                updateConfirmBar();
            });
        }

        updateConfirmBar();
    });

    // Close button
    document.getElementById('picker-close').onclick = function() {
        fetch(`https://${resourceName}/closePicker`, {
            method: 'POST',
            body: JSON.stringify({}),
        });
        hideAllViews();
    };

    // Confirm button
    document.getElementById('btn-confirm').onclick = function() {
        if (!selectedCoords) return;

        fetch(`https://${resourceName}/zoneConfirmed`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(selectedCoords),
        });

        hideAllViews();
    };
}

// ── Update confirm bar with coordinates ─────────────────────
function updateConfirmBar() {
    if (!selectedCoords) return;

    const bar = document.getElementById('picker-confirm-bar');
    bar.classList.remove('hidden');

    const coordsText = document.getElementById('confirm-coords');
    coordsText.textContent = `X: ${selectedCoords.worldX.toFixed(1)} | Y: ${selectedCoords.worldY.toFixed(1)}`;
}
