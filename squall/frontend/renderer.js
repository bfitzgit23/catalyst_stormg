/* Squall renderer — vanilla ES2020, no build step.
   Settings are persisted by squalld (~/.config/squall/settings.json) and cached in
   localStorage so the shell paints correctly before the daemon answers. */
'use strict';

const API = 'http://127.0.0.1:9876/api';
const STORAGE_KEY = 'squall.settings';
const $ = (sel, root = document) => root.querySelector(sel);
const $$ = (sel, root = document) => Array.from(root.querySelectorAll(sel));

const DEFAULTS = {
  theme: 'dark', accent: 'cyan', density: 'comfortable',
  motion: true, fontScale: 100, wallpaper: true
};

const state = {
  apps: [], filter: 'all', query: '',
  settings: { ...DEFAULTS }, audio: null, net: null, bt: null, power: null, profile: null,
  volumeTimer: null, brightTimer: null, ccReturnFocus: null
};

const ICON = {
  files: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linejoin="round"><path d="M3 7.5A2 2 0 0 1 5 5.5h4l2 2h8a2 2 0 0 1 2 2v8a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2z"/></svg>',
  terminal: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round"><rect x="3" y="4" width="18" height="16" rx="2"/><path d="M7 9l3 3-3 3M13 15h4"/></svg>',
  browser: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7"><circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3c2.6 3.2 2.6 14.8 0 18M12 3c-2.6 3.2-2.6 14.8 0 18"/></svg>',
  settings: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round"><path d="M4 8h8M16 8h4M4 16h4M12 16h8"/><circle cx="14" cy="8" r="2.2"/><circle cx="10" cy="16" r="2.2"/></svg>',
  software: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linejoin="round"><path d="M12 3l8 4.5v9L12 21l-8-4.5v-9z"/><path d="M4 7.5l8 4.5 8-4.5M12 12v9"/></svg>',
  app: '<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7"><rect x="4" y="4" width="16" height="16" rx="3"/><path d="M9 9h6v6H9z"/></svg>'
};

const SQUALL_APPS = [
  { name: 'Files', sub: 'squall', icon: 'files', cmd: 'squall --app files' },
  { name: 'Terminal', sub: 'xfce4', icon: 'terminal', cmd: 'xfce4-terminal' }
];

/* ── plumbing ─────────────────────────────────────────────────────────── */
async function api(path, options) {
  const res = await fetch(API + path, options);
  const body = await res.json().catch(() => ({}));
  if (!res.ok) throw new Error(body.error || `HTTP ${res.status}`);
  return body;
}
const post = (path, body) => api(path, {
  method: 'POST',
  headers: { 'Content-Type': 'application/json' },
  body: JSON.stringify(body || {})
});

function toast(message, kind = 'info') {
  const el = document.createElement('div');
  el.className = 'toast' + (kind === 'info' ? '' : ' ' + kind);
  el.innerHTML = '<span class="bar"></span><span></span>';
  el.lastElementChild.textContent = message;
  $('#toasts').appendChild(el);
  setTimeout(() => el.remove(), 3600);
}

function setSwitch(el, on, { disabled = false, label = null } = {}) {
  el.setAttribute('aria-checked', String(!!on));
  el.disabled = disabled;
  if (label) el.setAttribute('aria-label', label);
}

/* ── settings / theme engine ──────────────────────────────────────────── */
function applySettings(next) {
  const s = { ...DEFAULTS, ...next };
  state.settings = s;
  const root = document.documentElement;
  root.dataset.theme = s.theme;
  root.dataset.accent = s.accent;
  root.dataset.density = s.density;
  root.dataset.motion = s.motion ? 'on' : 'off';
  root.style.setProperty('--scale', (s.fontScale / 100).toFixed(2));
  document.body.classList.toggle('wallpaper-off', s.wallpaper === false);

  $('#themeName').textContent = s.theme;
  $$('[data-theme-choice]').forEach((b) => {
    const on = b.dataset.themeChoice === s.theme;
    b.classList.toggle('on', on);
    b.setAttribute('aria-checked', String(on));
  });
  $$('[data-accent-choice]').forEach((b) => {
    const on = b.dataset.accentChoice === s.accent;
    b.classList.toggle('on', on);
    b.setAttribute('aria-checked', String(on));
  });
  $$('[data-density-choice]').forEach((b) => b.classList.toggle('on', b.dataset.densityChoice === s.density));
  $$('[data-scale]').forEach((b) => b.classList.toggle('on', Number(b.dataset.scale) === s.fontScale));
  setSwitch($('#motionSwitch'), s.motion);
  setSwitch($('#wallpaperSwitch'), s.wallpaper);
}

async function saveSettings(patch) {
  const previous = { ...state.settings };
  applySettings({ ...previous, ...patch });   // optimistic
  try {
    const res = await post('/settings', patch);
    if (res.settings) applySettings(res.settings);
    if (Array.isArray(res.rejected) && res.rejected.length) {
      toast(`Not supported: ${res.rejected.join(', ')}`, 'warn');
    }
    localStorage.setItem(STORAGE_KEY, JSON.stringify(state.settings));
  } catch (err) {
    applySettings(previous);
    toast(`Settings: ${err.message}`, 'err');
  }
}

async function loadSettings() {
  let stored = null;
  try { stored = JSON.parse(localStorage.getItem(STORAGE_KEY) || 'null'); } catch { stored = null; }
  applySettings(stored || DEFAULTS);
  try {
    const remote = await api('/settings');
    applySettings(remote);
    localStorage.setItem(STORAGE_KEY, JSON.stringify(state.settings));
  } catch { /* daemon down: cached values stand */ }
}

/* ── clock + workspaces ───────────────────────────────────────────────── */
function tick() {
  $('#clock').textContent = new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' });
}
tick();
setInterval(tick, 5000);

$$('.ws').forEach((ws) => ws.addEventListener('click', () => {
  $$('.ws').forEach((w) => w.setAttribute('aria-current', 'false'));
  ws.setAttribute('aria-current', 'true');
  toast(`Workspace ${ws.textContent}`);
}));

/* ── launcher ─────────────────────────────────────────────────────────── */
function appCategory(app) {
  const cats = (app.categories || []).join(';').toLowerCase();
  if (/game/.test(cats)) return 'games';
  if (/network|internet|webbrowser|email|chat|video|audio|graphics/.test(cats)) return 'internet';
  if (/settings|system|utility|filesystem|terminal|development|office/.test(cats)) return 'system';
  return 'apps';
}

function allApps() {
  return [
    ...SQUALL_APPS.map((a) => ({ ...a, category: 'system', categories: [], new: false })),
    ...state.apps.map((a) => ({
      id: a.id || a.name,
      name: a.name,
      sub: a.generic || a.comment || (a.exec || '').split(/\s+/)[0],
      icon: 'app',
      cmd: a.exec,
      category: appCategory(a),
      categories: a.categories || [],
      keywords: a.keywords || [],
      new: !!a.new
    }))
  ];
}

const escapeHtml = (s) => String(s).replace(/[&<>"']/g, (c) =>
  ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));
const escapeAttr = escapeHtml;

let appsFetchedAt = 0;
async function loadApps(force = false) {
  if (!force && Date.now() - appsFetchedAt < 30000) return;
  try {
    const result = await api('/apps');
    state.apps = Array.isArray(result) ? result : (result.apps || []);
    appsFetchedAt = Date.now();
    renderCats();
    renderGrid();
  } catch { /* keep the previous index rather than emptying the menu */ }
}

function renderGrid() {
  const q = state.query.trim().toLowerCase();
  const rows = allApps().filter((a) => {
    const byCat = state.filter === 'all'
      || (state.filter === 'new' ? a.new : a.category === state.filter);
    if (!byCat) return false;
    if (!q) return true;
    return [a.name, a.sub, a.cmd, ...(a.keywords || []), ...(a.categories || [])]
      .join(' ').toLowerCase().includes(q);
  });

  $('#grid').innerHTML = rows.map((a) => `
    <button class="app" role="option" data-cmd="${escapeAttr(a.cmd)}" tabindex="0" title="${escapeAttr(a.name)}">
      <span class="glyph">${ICON[a.icon] || ICON.app}</span>
      <span class="nm">${escapeHtml(a.name)}</span>
      <span class="sub">${escapeHtml(a.sub || 'application')}</span>
      ${a.new ? '<span class="new-chip">New</span>' : ''}
    </button>`).join('') || '<div class="unavailable">No matches</div>';

  $$('#grid .app').forEach((el) => el.addEventListener('click', () => {
    launch(el.dataset.cmd);
    toggleLauncher(false);
  }));
}

function renderCats() {
  const apps = allApps();
  const counts = { all: apps.length, new: apps.filter((a) => a.new).length };
  apps.forEach((a) => { counts[a.category] = (counts[a.category] || 0) + 1; });
  const cats = [['all', 'All'], ['new', 'New'], ['apps', 'Apps'], ['system', 'System'], ['internet', 'Internet'], ['games', 'Games']]
    .filter(([id]) => id === 'all' || counts[id]);
  if (state.filter !== 'all' && !counts[state.filter]) state.filter = 'all';
  $('#cats').innerHTML = cats.map(([id, label]) =>
    `<button class="cat${state.filter === id ? ' on' : ''}" data-cat="${id}">${label}<span class="n">${counts[id] || 0}</span></button>`).join('');
  $$('#cats .cat').forEach((el) => el.addEventListener('click', () => {
    state.filter = el.dataset.cat;
    renderCats();
    renderGrid();
  }));
}

function toggleLauncher(open) {
  const el = $('#launcher');
  const next = open === undefined ? el.hidden : open;
  el.hidden = !next;
  $('#menuBtn').setAttribute('aria-expanded', String(next));
  if (next) {
    $('#appSearch').value = state.query;
    $('#appSearch').focus();
    loadApps();
  }
}

async function launch(cmd) {
  if (!cmd) return;
  try { await post('/launch', { cmd }); }
  catch (err) { toast(`Could not launch: ${err.message}`, 'err'); }
}

$('#menuBtn').addEventListener('click', () => toggleLauncher());
$('#appSearch').addEventListener('input', (e) => { state.query = e.target.value; renderGrid(); });
$('#appSearch').addEventListener('keydown', (e) => {
  if (e.key === 'Enter') { const first = $('#grid .app'); if (first) first.click(); }
  if (e.key === 'ArrowDown') { e.preventDefault(); $('#grid .app')?.focus(); }
});
$('#grid').addEventListener('keydown', (e) => {
  const items = $$('#grid .app');
  const i = items.indexOf(document.activeElement);
  if (e.key === 'ArrowDown' || e.key === 'ArrowRight') { e.preventDefault(); items[Math.min(items.length - 1, i + 1)]?.focus(); }
  if (e.key === 'ArrowUp' || e.key === 'ArrowLeft') { e.preventDefault(); items[Math.max(0, i - 1)]?.focus(); }
});

/* ── dock ─────────────────────────────────────────────────────────────── */
const DOCK = [
  { name: 'Files', icon: 'files', cmd: 'squall --app files' },
  { name: 'Terminal', icon: 'terminal', cmd: 'xfce4-terminal' },
  { name: 'Browser', icon: 'browser', cmd: 'firefox' },
  { name: 'Settings', icon: 'settings', cmd: 'squall --app settings' },
  { name: 'Software', icon: 'software', cmd: 'squall --app software' }
];

function renderDock() {
  $('#dock').innerHTML = '<span class="rail" aria-hidden="true"></span>' +
    DOCK.map((a, i) => `
      <button class="dock-app${i < 2 ? ' run' : ''}" data-cmd="${escapeAttr(a.cmd)}"
              title="${escapeAttr(a.name)}" aria-label="${escapeAttr(a.name)}">
        ${ICON[a.icon]}<span class="name">${a.name}</span>
      </button>`).join('') + '<span class="dock-sep" aria-hidden="true"></span>' +
    `<button class="dock-app" data-launcher="true" aria-label="All applications">${ICON.software}<span class="name">Apps</span></button>`;

  $$('#dock .dock-app').forEach((el) => el.addEventListener('click', () => {
    if (el.dataset.launcher) return toggleLauncher(true);
    launch(el.dataset.cmd);
  }));
}

/* ── control center + deep links ──────────────────────────────────────── */
function openCC(section) {
  const cc = $('#cc');
  if (cc.hidden) state.ccReturnFocus = document.activeElement;
  cc.hidden = false;
  $('#ccBtn').setAttribute('aria-pressed', 'true');
  if (section) {
    const target = $('#sec-' + section);
    if (target) {
      target.scrollIntoView({ block: 'start', behavior: 'smooth' });
      target.classList.remove('flash');
      void target.offsetWidth;
      target.classList.add('flash');
    }
  }
}
function closeCC() {
  $('#cc').hidden = true;
  $('#ccBtn').setAttribute('aria-pressed', 'false');
  if (state.ccReturnFocus && state.ccReturnFocus.focus) state.ccReturnFocus.focus();
}
function toggleCC(open) { (open === undefined ? $('#cc').hidden : open) ? openCC() : closeCC(); }

$('#ccBtn').addEventListener('click', () => toggleCC());
$('#ccClose').addEventListener('click', () => closeCC());
$$('[data-open-cc]').forEach((el) =>
  el.addEventListener('click', () => openCC(el.dataset.ccSection)));

document.addEventListener('keydown', (e) => {
  if (e.key === 'Escape') { toggleLauncher(false); closeCC(); }
  if (e.key === ' ' && (e.ctrlKey || e.metaKey)) { e.preventDefault(); toggleLauncher(); }
});

/* ── audio ────────────────────────────────────────────────────────────── */
function renderAudio(a) {
  const supported = !!(a && a.supported);
  const vol = a?.volume ?? null;
  $('#volValue').textContent = supported && vol !== null ? `${vol}%` : '—';
  $('#volSub').textContent = supported ? 'pactl · default sink' : 'pactl unavailable';
  $('#volRange').disabled = !supported;
  $('#volRange').style.opacity = supported ? '1' : '.35';
  if (supported && vol !== null) {
    $('#volRange').value = vol;
    $('#volRange').style.setProperty('--fill', `${Math.min(100, (vol / 150) * 100)}%`);
    $('#volLabel').textContent = `${vol}%`;
  } else {
    $('#volLabel').textContent = '—';
  }
  setSwitch($('#muteSwitch'), supported ? a.muted : false, { disabled: !supported, label: 'Mute' });
}

$('#volRange').addEventListener('input', (e) => {
  const v = Number(e.target.value);
  $('#volValue').textContent = `${v}%`;
  $('#volLabel').textContent = `${v}%`;
  e.target.style.setProperty('--fill', `${Math.min(100, (v / 150) * 100)}%`);
  clearTimeout(state.volumeTimer);
  state.volumeTimer = setTimeout(async () => {
    try { renderAudio(await post('/audio', { volume: v })); }
    catch (err) { toast(`Volume: ${err.message}`, 'err'); }
  }, 120);
});

$('#muteSwitch').addEventListener('click', async (e) => {
  const next = e.currentTarget.getAttribute('aria-checked') !== 'true';
  setSwitch(e.currentTarget, next);
  try { renderAudio(await post('/audio', { muted: next })); }
  catch (err) { setSwitch(e.currentTarget, !next); toast(`Mute: ${err.message}`, 'err'); }
});

/* ── network ──────────────────────────────────────────────────────────── */
function renderNetwork(n) {
  const supported = !!(n && n.supported);
  $('#netUnavailable').hidden = supported;
  setSwitch($('#wifiSwitch'), supported ? n.wifi : false, { disabled: !supported, label: 'Wi-Fi' });
  $('#netLabel').textContent = supported ? (n.ssid || (n.wifi ? 'On' : 'Off')) : 'Off';
  $('#netBadge').textContent = supported ? (n.ssid ? 'Linked' : 'Idle') : 'N/A';
  $('#ssidLabel').textContent = supported
    ? (n.ssid || (n.wifi ? 'No active link' : 'Radio disabled'))
    : 'nmcli unavailable';
}

$('#wifiSwitch').addEventListener('click', async (e) => {
  const next = e.currentTarget.getAttribute('aria-checked') !== 'true';
  setSwitch(e.currentTarget, next);
  try { renderNetwork(await post('/network', { wifi: next })); }
  catch (err) { setSwitch(e.currentTarget, !next); toast(`Wi-Fi: ${err.message}`, 'err'); }
});

/* ── bluetooth ────────────────────────────────────────────────────────── */
function renderBluetooth(b) {
  const supported = !!(b && b.supported);
  setSwitch($('#btSwitch'), supported ? b.powered : false, { disabled: !supported, label: 'Bluetooth' });
  $('#btLabel').textContent = supported ? (b.name || (b.powered ? 'Powered' : 'Off')) : 'bluetoothctl unavailable';
  $('#btBadge').textContent = supported ? (b.powered ? 'On' : 'Off') : 'N/A';
}

$('#btSwitch').addEventListener('click', async (e) => {
  const next = e.currentTarget.getAttribute('aria-checked') !== 'true';
  setSwitch(e.currentTarget, next);
  try { renderBluetooth(await post('/bluetooth', { powered: next })); }
  catch (err) { setSwitch(e.currentTarget, !next); toast(`Bluetooth: ${err.message}`, 'err'); }
});

/* ── power ────────────────────────────────────────────────────────────── */
function renderPower(p) {
  const battery = p?.battery;
  $('#batteryValue').textContent = battery == null ? '—' : `${battery}%`;
  $('#powerBadge').textContent = p?.charging ? 'Charging' : (battery != null ? 'Battery' : 'N/A');
  const bits = [];
  if (p?.battery_health != null) bits.push(`health ${p.battery_health}%`);
  if (p?.time_left_min != null && !p.charging) bits.push(`${Math.floor(p.time_left_min / 60)}h ${p.time_left_min % 60}m left`);
  if (p?.power_draw_w != null) bits.push(`${p.power_draw_w} W`);
  $('#batterySub').textContent = bits.join(' · ') || 'Battery';
  const bright = p?.brightness;
  $('#brightValue').textContent = bright == null ? '—' : `${bright}%`;
  $('#brightRange').disabled = bright == null;
  if (bright != null) {
    $('#brightRange').value = bright;
    $('#brightRange').style.setProperty('--fill', `${bright}%`);
  }
}

$('#brightRange').addEventListener('input', (e) => {
  const v = Number(e.target.value);
  $('#brightValue').textContent = `${v}%`;
  e.target.style.setProperty('--fill', `${v}%`);
  clearTimeout(state.brightTimer);
  state.brightTimer = setTimeout(async () => {
    try { renderPower(await post('/brightness', { value: v })); }
    catch (err) { toast(`Brightness: ${err.message}`, 'err'); }
  }, 140);
});

function renderPowerProfile(p) {
  const supported = !!(p && p.supported);
  state.profile = p;
  $('#profileSub').textContent = supported ? `powerprofilesctl · ${p.profile}` : 'powerprofilesctl unavailable';
  $$('#profileSeg button').forEach((b) => {
    b.disabled = !supported;
    b.classList.toggle('on', supported && b.dataset.profile === p.profile);
  });
}

$$('#profileSeg button').forEach((b) => b.addEventListener('click', async () => {
  const profile = b.dataset.profile;
  $$('#profileSeg button').forEach((x) => x.classList.toggle('on', x === b));
  try { renderPowerProfile(await post('/powerprofile', { profile })); }
  catch (err) { toast(`Power profile: ${err.message}`, 'err'); }
}));

/* ── graphics / cpu / keyboard backlight ─────────────────────────────── */
function renderGpu(g) {
  const supported = !!(g && g.supported);
  $$('#gpuSeg button').forEach((b) => {
    b.disabled = !supported;
    b.classList.toggle('on', supported && b.dataset.gpu === g.mode);
  });
  $('#gpuBadge').textContent = supported ? (g.mode || 'unknown') : 'N/A';
  $('#gpuSub').textContent = supported
    ? (g.gpus && g.gpus.length ? g.gpus.join(' · ') : 'no GPU reported by lspci')
    : 'envycontrol unavailable';
  $('#gpuHint').hidden = !supported;
  $('#gpuHint').textContent = g && g.needs_root
    ? 'Switching logs you out and asks for administrator approval.'
    : 'Switching logs you out; run envycontrol with root to change it.';
}

$('#gpuSeg').addEventListener('click', async (e) => {
  const btn = e.target.closest('button[data-gpu]');
  if (!btn || btn.disabled) return;
  const mode = btn.dataset.gpu;
  if (!window.confirm(`Switch GPU to ${mode}? The session must log out to apply.`)) return;
  try {
    renderGpu(await post('/gpu', { mode }));
    toast(`GPU mode: ${mode} — log out to apply`);
  } catch (err) { toast(`GPU: ${err.message}`, 'err'); }
});

const pretty = (s) => String(s).replace(/[_-]/g, ' ').replace(/\b\w/g, (c) => c.toUpperCase());

function renderCpu(c) {
  const supported = !!(c && c.supported);
  const governors = c?.governors || [];
  const seg = $('#cpuSeg');
  seg.hidden = !supported || !governors.length;
  if (seg.dataset.key !== governors.join(',')) {
    seg.dataset.key = governors.join(',');
    seg.innerHTML = governors.map((g) =>
      `<button data-governor="${escapeAttr(g)}">${pretty(g)}</button>`).join('');
  }
  $$('#cpuSeg button').forEach((b) => {
    b.disabled = !supported;
    b.classList.toggle('on', supported && b.dataset.governor === c.governor);
  });
  $('#cpuBadge').textContent = supported ? `${c.cores ?? '—'} cores` : 'N/A';
  $('#cpuSub').textContent = supported
    ? (c.max_mhz ? `max ${c.max_mhz} MHz` : 'scaling governor')
    : 'cpufreq unavailable';
  $('#cpuFreq').textContent = c?.freq_mhz ? `${c.freq_mhz} MHz` : '—';
  setSwitch($('#turboSwitch'), supported ? !!c.turbo : false,
    { disabled: !supported || c.turbo_supported === false, label: 'Turbo boost' });
}

$('#cpuSeg').addEventListener('click', async (e) => {
  const btn = e.target.closest('button[data-governor]');
  if (!btn || btn.disabled) return;
  try { renderCpu(await post('/cpu', { governor: btn.dataset.governor })); }
  catch (err) { toast(`Governor: ${err.message}`, 'err'); }
});

$('#turboSwitch').addEventListener('click', async (e) => {
  const next = e.currentTarget.getAttribute('aria-checked') !== 'true';
  setSwitch(e.currentTarget, next);
  try {
    const res = await post('/cpu', { turbo: next });
    renderCpu(res);
    if (res.error) toast(res.error, 'warn');
  } catch (err) { setSwitch(e.currentTarget, !next); toast(`Turbo: ${err.message}`, 'err'); }
});

function renderKbd(k) {
  const supported = !!(k && k.supported);
  $('#kbdValue').textContent = supported ? `${k.value}%` : '—';
  $('#kbdSub').textContent = supported ? k.device : 'no backlight device';
  const range = $('#kbdRange');
  range.disabled = !supported;
  range.style.opacity = supported ? '1' : '.35';
  if (supported) {
    range.value = k.value;
    range.style.setProperty('--fill', `${k.value}%`);
  }
}

let kbdTimer = null;
$('#kbdRange').addEventListener('input', (e) => {
  const v = Number(e.target.value);
  $('#kbdValue').textContent = `${v}%`;
  e.target.style.setProperty('--fill', `${v}%`);
  clearTimeout(kbdTimer);
  kbdTimer = setTimeout(async () => {
    try { renderKbd(await post('/kbdlight', { value: v })); }
    catch (err) { toast(`Keyboard light: ${err.message}`, 'err'); }
  }, 140);
});

/* ── system ───────────────────────────────────────────────────────────── */
function renderSystem(s) {
  $('#barState').textContent = s.load ? s.load.split(' ')[0] : 'Ready';
  $('#barPath').textContent = `StormG · load ${s.load || '—'}`;
  $('#memValue').textContent = s.mem_avail ? `${Math.round(parseInt(s.mem_avail, 10) / 1048576)} GB` : '—';
  $('#diskValue').textContent = `${s.disk_free_gb ?? '—'} GB`;
  $('#loadValue').textContent = s.load ? s.load.split(' ')[0] : '—';
  if (s.uptime_s) $('#uptime').textContent = `Up ${Math.floor(Number(s.uptime_s) / 3600)}h`;
}

/* ── appearance wiring ────────────────────────────────────────────────── */
$$('[data-theme-choice]').forEach((b) => b.addEventListener('click', () => {
  saveSettings({ theme: b.dataset.themeChoice });
  toast(`Theme: ${b.dataset.themeChoice}`);
}));
$$('[data-accent-choice]').forEach((b) => b.addEventListener('click', () => {
  saveSettings({ accent: b.dataset.accentChoice });
}));
$$('[data-density-choice]').forEach((b) => b.addEventListener('click', () => {
  saveSettings({ density: b.dataset.densityChoice });
}));
$$('[data-scale]').forEach((b) => b.addEventListener('click', () => {
  saveSettings({ fontScale: Number(b.dataset.scale) });
}));
$('#motionSwitch').addEventListener('click', (e) => {
  saveSettings({ motion: e.currentTarget.getAttribute('aria-checked') !== 'true' });
});
$('#wallpaperSwitch').addEventListener('click', (e) => {
  saveSettings({ wallpaper: e.currentTarget.getAttribute('aria-checked') !== 'true' });
});

/* ── session ──────────────────────────────────────────────────────────── */
$$('[data-command]').forEach((el) => el.addEventListener('click', async () => {
  const action = el.dataset.command;
  if ((action === 'reboot' || action === 'poweroff') &&
      !window.confirm(`${action === 'reboot' ? 'Reboot' : 'Shut down'} now?`)) return;
  try { await post('/command', { action }); toast(`${action} requested`); }
  catch (err) { toast(`${action}: ${err.message}`, 'err'); }
}));

/* ── refresh loop ─────────────────────────────────────────────────────── */
let lastFailure = 0;
async function refreshAll() {
  if (document.hidden) return;
  const [audio, net, bt, power, system, profile, gpu, cpu, kbd] = await Promise.allSettled([
    api('/audio'), api('/network'), api('/bluetooth'), api('/power'),
    api('/system'), api('/powerprofile'), api('/gpu'), api('/cpu'), api('/kbdlight')
  ]);

  if (audio.status === 'fulfilled') { state.audio = audio.value; renderAudio(audio.value); }
  else renderAudio({ supported: false });

  if (net.status === 'fulfilled') { state.net = net.value; renderNetwork(net.value); }
  else renderNetwork({ supported: false });

  if (bt.status === 'fulfilled') { state.bt = bt.value; renderBluetooth(bt.value); }
  else renderBluetooth({ supported: false });

  if (power.status === 'fulfilled') renderPower(power.value); else renderPower({});
  if (system.status === 'fulfilled') renderSystem(system.value);
  if (profile.status === 'fulfilled') renderPowerProfile(profile.value);
  if (gpu.status === 'fulfilled') renderGpu(gpu.value); else renderGpu({ supported: false });
  if (cpu.status === 'fulfilled') renderCpu(cpu.value); else renderCpu({ supported: false });
  if (kbd.status === 'fulfilled') renderKbd(kbd.value); else renderKbd({ supported: false });

  const offline = system.status !== 'fulfilled';
  $('#stateDot').classList.toggle('warn', offline);
  if (offline && Date.now() - lastFailure > 30000) {
    lastFailure = Date.now();
    toast('squalld is not responding — retrying', 'warn');
  }
}

document.addEventListener('visibilitychange', () => { if (!document.hidden) refreshAll(); });

/* ── boot ─────────────────────────────────────────────────────────────── */
(async function boot() {
  renderDock();
  renderCats();
  renderGrid();
  await loadSettings();
  await refreshAll();
  setInterval(refreshAll, 15000);
  await loadApps(true);
})();
