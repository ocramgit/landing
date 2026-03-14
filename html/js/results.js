/* ═══════════════════════════════════════════════════════════
   LANDING COMPETITION — RESULTS.JS (Leaderboard)
   ═══════════════════════════════════════════════════════════ */

let autoCloseTimer = null;

// ── Init Results (Leaderboard only, no map) ─────────────────
function initResults(results, zone) {
    const listContainer = document.getElementById('results-list');
    listContainer.innerHTML = '';

    // Sort is already done server-side by score descending
    results.forEach((result, index) => {
        const card = document.createElement('div');
        const rankClass = index < 3 ? `rank-${index + 1}` : '';
        card.className = `result-card ${rankClass}`;
        card.style.animationDelay = `${index * 0.12}s`;

        const rankEmoji = index === 0 ? '🥇' : index === 1 ? '🥈' : index === 2 ? '🥉' : '';
        const rankDisplay = rankEmoji || `#${index + 1}`;

        const planeInfo = result.plane ? escapeHtmlResult(result.plane) : '';

        card.innerHTML = `
            <div class="result-rank ${rankClass || 'rank-other'}">${rankDisplay}</div>
            <div class="result-info">
                <div class="result-name">${escapeHtmlResult(result.name)}</div>
                <div class="result-details">
                    <span class="result-plane">✈️ ${planeInfo}</span>
                    <span class="result-dist">📍 ${result.distanceFormatted}</span>
                    ${result.exploded ? '<span class="exploded-tag">💥 Explodiu</span>' : ''}
                </div>
            </div>
            <div class="result-score">
                ${result.score.toLocaleString()}
                <span>pts</span>
            </div>
        `;

        listContainer.appendChild(card);
    });

    // Auto-close in 20 seconds
    startAutoClose(20);
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
