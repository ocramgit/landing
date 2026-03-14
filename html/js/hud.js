/* ═══════════════════════════════════════════════════════════
   LANDING COMPETITION — HUD.JS (Flight HUD + Countdown)
   ═══════════════════════════════════════════════════════════ */

let countdownInterval = null;

// ── Init HUD ────────────────────────────────────────────────
function initHUD(data) {
    // Set plane name
    document.getElementById('hud-plane').textContent = data.planeName || '---';

    // Set timer
    const minutes = Math.floor(data.flightTime / 60);
    const seconds = data.flightTime % 60;
    const timerEl = document.getElementById('hud-timer');
    timerEl.textContent = `${minutes}:${String(seconds).padStart(2, '0')}`;
    timerEl.className = 'hud-value';

    // Set players count
    document.getElementById('hud-players').textContent = data.totalPlayers || '0';

    // Clear previous feed
    document.getElementById('landing-feed').innerHTML = '';
}

// ── Countdown Overlay ───────────────────────────────────────
function startCountdown(seconds) {
    const overlay = document.getElementById('countdown-overlay');
    const numberEl = document.getElementById('countdown-number');

    overlay.classList.remove('hidden');
    numberEl.className = '';

    let current = seconds;
    numberEl.textContent = current;

    if (countdownInterval) clearInterval(countdownInterval);

    countdownInterval = setInterval(() => {
        current--;

        if (current > 0) {
            numberEl.textContent = current;
            numberEl.className = '';

            // Pulse animation reset
            numberEl.style.animation = 'none';
            numberEl.offsetHeight; // Trigger reflow
            numberEl.style.animation = '';
        } else if (current === 0) {
            numberEl.textContent = 'GO!';
            numberEl.className = 'go';
        } else {
            clearInterval(countdownInterval);
            countdownInterval = null;
            overlay.classList.add('hidden');
        }
    }, 1000);
}

// ── Update Timer ────────────────────────────────────────────
function updateTimer(timeLeft) {
    const timerEl = document.getElementById('hud-timer');
    if (!timerEl) return;

    const minutes = Math.floor(timeLeft / 60);
    const seconds = timeLeft % 60;
    timerEl.textContent = `${minutes}:${String(seconds).padStart(2, '0')}`;

    // Color changes based on time remaining
    if (timeLeft <= 30) {
        timerEl.className = 'hud-value danger';
    } else if (timeLeft <= 60) {
        timerEl.className = 'hud-value warning';
    } else {
        timerEl.className = 'hud-value';
    }
}

// ── Landing Feed ────────────────────────────────────────────
function addLandingFeed(data) {
    const feed = document.getElementById('landing-feed');
    if (!feed) return;

    const item = document.createElement('div');
    item.className = 'feed-item' + (data.exploded ? ' exploded' : '');

    item.innerHTML = `
        <span class="feed-icon">${data.exploded ? '💥' : '✈️'}</span>
        <div class="feed-text">
            <div class="feed-name">${escapeHtml(data.name)}</div>
            <div class="feed-detail">${data.distance}${data.exploded ? ' • EXPLODIU' : ''}</div>
        </div>
        <div class="feed-score">${data.score.toLocaleString()}</div>
    `;

    feed.insertBefore(item, feed.firstChild);

    // Auto-remove after 8 seconds
    setTimeout(() => {
        item.style.transition = 'opacity 0.5s, transform 0.5s';
        item.style.opacity = '0';
        item.style.transform = 'translateX(100%)';
        setTimeout(() => item.remove(), 500);
    }, 8000);

    // Cap max items
    while (feed.children.length > 6) {
        feed.removeChild(feed.lastChild);
    }
}

// ── Landed Notice (for the player who just landed) ──────────
function showLandedNotice(exploded) {
    const existing = document.querySelector('.landed-notice');
    if (existing) existing.remove();

    const notice = document.createElement('div');
    notice.className = 'landed-notice' + (exploded ? ' exploded' : '');
    notice.textContent = exploded
        ? '💥 CRASH LANDING! (-3000 pts)'
        : '✈️ ATERRAGEM REGISTADA!';

    document.body.appendChild(notice);

    setTimeout(() => {
        if (notice.parentNode) notice.remove();
    }, 3500);
}

// ── HTML escape utility ─────────────────────────────────────
function escapeHtml(str) {
    const div = document.createElement('div');
    div.textContent = str;
    return div.innerHTML;
}
