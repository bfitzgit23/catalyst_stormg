/* StormOS Installer — vanilla ES5+/DOM, no framework, no build step. */
'use strict';

const $ = (id) => document.getElementById(id);
const STEP_NAMES = ['Environment', 'Destination', 'Account', 'Review', 'Install', 'Done'];

const state = {
  view: null,
  plan: {},
  valid: false,
  step: 0,
  installing: false,
  source: null,
};

async function api(path, options = {}) {
  const response = await fetch(path, {
    ...options,
    headers: { 'content-type': 'application/json', ...(options.headers || {}) },
  });
  const payload = await response.json();
  if (!response.ok && !payload.errors) {
    throw new Error(payload.error || `${response.status} ${response.statusText}`);
  }
  return payload;
}

function size(bytes) {
  if (!bytes) return '0 B';
  const units = ['B', 'KiB', 'MiB', 'GiB', 'TiB'];
  let value = bytes;
  let unit = 0;
  while (value >= 1024 && unit < units.length - 1) { value /= 1024; unit += 1; }
  return `${value >= 10 || unit === 0 ? Math.round(value) : value.toFixed(1)} ${units[unit]}`;
}

function notice(el, kind, text) {
  el.className = `notice ${kind}`;
  el.textContent = text;
  el.hidden = !text;
}

function fillSelect(el, values, selected) {
  el.replaceChildren();
  for (const value of values) {
    const option = document.createElement('option');
    option.value = value;
    option.textContent = value;
    if (value === selected) option.selected = true;
    el.append(option);
  }
}

function renderChrome() {
  const steps = $('steps');
  steps.replaceChildren();
  STEP_NAMES.forEach((name, index) => {
    const pip = document.createElement('div');
    pip.className = 'step-pip';
    if (index === state.step) pip.classList.add('on');
    else if (index < state.step) pip.classList.add('done');
    const number = document.createElement('b');
    number.textContent = String(index + 1);
    pip.append(number, document.createTextNode(name));
    steps.append(pip);
  });

  const rail = $('rail-items');
  rail.replaceChildren();
  const lines = [
    ['Session', state.view.efi ? 'UEFI' : 'Legacy BIOS'],
    ['Live media', state.view.source ? 'squashfs' : 'not found'],
    ['Disk', state.plan.disk || state.plan.root_part || '—'],
    ['Locale', state.plan.locale || '—'],
    ['User', state.plan.username || '—'],
  ];
  for (const [label, value] of lines) {
    const row = document.createElement('div');
    row.className = 'rail-item';
    const left = document.createElement('span');
    const title = document.createElement('b');
    title.textContent = label;
    const detail = document.createElement('i');
    detail.textContent = value;
    left.append(title, detail);
    row.append(left);
    rail.append(row);
  }
}

function showStep(index) {
  state.step = index;
  for (let i = 0; i < STEP_NAMES.length; i += 1) {
    $(`step-${STEP_NAMES[i].toLowerCase()}`).hidden = i !== index;
  }
  const back = $('btn-back');
  const next = $('btn-next');
  if (index === 5) {
    back.hidden = true;
    next.hidden = false;
    next.textContent = 'Reboot';
    next.classList.add('primary');
  } else if (state.installing) {
    back.hidden = false;
    back.textContent = 'Cancel install';
    next.hidden = true;
  } else {
    back.hidden = index === 0;
    back.textContent = 'Back';
    next.hidden = false;
    next.textContent = index === 3 ? 'Install StormOS' : 'Continue';
  }
  renderChrome();
}

function renderEnvironment() {
  const view = state.view;
  const tiles = $('env-tiles');
  tiles.replaceChildren();
  const data = [
    [view.efi ? 'UEFI' : 'BIOS', 'Firmware mode'],
    [size(view.memory_mb * 1048576), 'Available memory'],
    [String(view.disks.length), 'Detected disks'],
  ];
  for (const [value, label] of data) {
    const card = document.createElement('div');
    card.className = 'card';
    const title = document.createElement('div');
    title.className = 'title';
    title.textContent = value;
    const sub = document.createElement('div');
    sub.className = 'sub';
    sub.textContent = label;
    card.append(title, sub);
    tiles.append(card);
  }

  fillSelect($('f-locale'), view.locales, 'en_US.UTF-8');
  fillSelect($('f-keymap'), view.keymaps, view.keymaps.includes('us') ? 'us' : view.keymaps[0]);
  fillSelect($('f-timezone'), view.timezones, 'UTC');
  if (!view.source) {
    notice($('env-notice'), 'bad', 'The live squashfs was not found. Installation cannot continue from this environment.');
  } else {
    notice($('env-notice'), 'ok', `Environment ready — ${view.efi ? 'UEFI' : 'BIOS'} boot, ${view.disks.length} disk(s), live image ${view.source}.`);
  }
  $('bar-detail').textContent = view.efi ? 'UEFI firmware detected' : 'Legacy BIOS detected';
}

function renderDisks() {
  const container = $('disk-cards');
  container.replaceChildren();
  const candidates = state.view.disks.filter((disk) => !disk.live);
  const recommended = candidates.reduce((best, disk) => (!best || disk.size > best.size ? disk : best), null);
  state.plan.boot = state.view.efi ? 'uefi' : 'bios';
  state.plan.mode = state.plan.mode || 'erase';
  state.plan.disk = state.plan.disk || (recommended ? recommended.name : '');

  for (const disk of state.view.disks) {
    const card = document.createElement('div');
    card.className = 'card selectable';
    card.dataset.disk = disk.name;
    if (disk.name === state.plan.disk) card.classList.add('on');
    if (disk.live) card.classList.add('warn');

    const title = document.createElement('div');
    title.className = 'title';
    title.textContent = disk.name;
    if (disk.name === recommended && !disk.live) {
      const badge = document.createElement('span');
      badge.className = 'badge';
      badge.textContent = 'recommended';
      title.append(badge);
    }
    const sub = document.createElement('div');
    sub.className = 'sub';
    sub.textContent = `${disk.model || 'Disk'} · ${size(disk.size)} · ${disk.partitions.length} partition(s)`;
    if (disk.live) sub.textContent += ' — running this live ISO, cannot be used';
    card.append(title, sub);
    card.addEventListener('click', () => {
      if (disk.live) return;
      state.plan.disk = disk.name;
      state.plan.disk_size = disk.size;
      fillPartitions(disk);
      renderDisks();
      validate();
    });
    container.append(card);
  }
  fillPartitions(state.view.disks.find((d) => d.name === state.plan.disk));
}

function fillPartitions(disk) {
  const values = (disk ? disk.partitions : []).map((part) => part.name);
  fillSelect($('f-root'), values.length ? values : ['—'], values[0]);
  fillSelect($('f-esp'), ['—', ...values], '—');
  state.plan.root_part = values[0] || '';
  state.plan.esp_part = '';
}

function bindMode() {
  $('mode-seg').addEventListener('click', (event) => {
    const button = event.target.closest('[data-mode]');
    if (!button) return;
    state.plan.mode = button.dataset.mode;
    for (const other of $('mode-seg').children) {
      other.classList.toggle('on', other === button);
    }
    $('manual-fields').hidden = state.plan.mode !== 'manual';
    notice($('disk-notice'), state.plan.mode === 'erase' ? 'warn' : 'info',
      state.plan.mode === 'erase'
        ? 'Destructive: all data on the selected disk will be erased.'
        : 'Manual mode: existing partitions are mounted as-is and are not formatted.');
    validate();
  });
}

function buildPlan() {
  const plan = { ...state.plan };
  if (state.step >= 0) {
    plan.locale = $('f-locale').value;
    plan.keymap = $('f-keymap').value;
    plan.timezone = $('f-timezone').value;
  }
  if (state.step >= 2) {
    plan.hostname = $('f-hostname').value.trim();
    plan.username = $('f-username').value.trim();
    plan.password = $('f-password').value;
    if (plan.password !== $('f-password2').value) {
      notice($('account-notice'), 'bad', 'Passwords do not match.');
    } else {
      $('account-notice').hidden = true;
    }
  }
  if (state.plan.mode === 'manual') {
    plan.root_part = $('f-root').value === '—' ? '' : $('f-root').value;
    plan.esp_part = $('f-esp').value === '—' ? '' : $('f-esp').value;
  }
  if (state.step >= 3) plan.confirm = $('f-confirm').value.trim();
  state.plan = plan;
  return plan;
}

async function validate() {
  if (state.installing) return;
  const plan = buildPlan();
  try {
    const verdict = await api('/api/validate', {
      method: 'POST',
      body: JSON.stringify({ plan, check_confirm: state.step >= 3 }),
    });
    state.valid = verdict.ok;
    const text = [...verdict.errors, ...verdict.warnings].join('  ·  ');
    notice($('validate-notice'), verdict.errors.length ? 'bad' : 'warn', text);
    $('foot-hint').textContent = verdict.ok ? 'Plan is valid — ready to install' : (verdict.errors[0] || 'Check the highlighted fields');
    if (state.step === 3) {
      $('review-notice').hidden = verdict.ok === false;
    }
    renderChrome();
  } catch (error) {
    state.valid = false;
    $('foot-hint').textContent = error.message;
  }
}

function renderReview() {
  const plan = buildPlan();
  const list = $('review-list');
  list.replaceChildren();
  const rows = [
    ['Destination', plan.mode === 'erase' ? `${plan.disk} (${size(plan.disk_size || 0)})` : `${plan.root_part}${plan.esp_part ? ` + ${plan.esp_part}` : ''}`],
    ['Mode', plan.mode === 'erase' ? 'Erase and install' : 'Manual partitions'],
    ['Boot', plan.boot === 'uefi' ? 'UEFI' : 'Legacy BIOS'],
    ['Filesystem', plan.fs || 'ext4'],
    ['Locale', plan.locale],
    ['Keyboard', plan.keymap],
    ['Timezone', plan.timezone],
    ['Hostname', plan.hostname || '—'],
    ['User', plan.username || '—'],
    ['Session', 'AetherDE (XFCE selectable)'],
    ['Token', state.view.token],
  ];
  for (const [key, value] of rows) {
    const dt = document.createElement('dt');
    dt.textContent = key;
    const dd = document.createElement('dd');
    dd.textContent = String(value);
    list.append(dt, dd);
  }
  validate();
}

function renderSteps() {
  const wrap = $('install-steps');
  wrap.replaceChildren();
  const names = ['preflight', 'partition', 'format', 'mount', 'unpack', 'fstab', 'configure', 'bootloader', 'finish'];
  for (const name of names) {
    const chip = document.createElement('div');
    chip.className = 'step-chip';
    chip.dataset.name = name;
    chip.textContent = name;
    wrap.append(chip);
  }
}

function logLine(event) {
  const log = $('log');
  const line = document.createElement('div');
  let kind = 'info';
  if (event.kind === 'error') kind = 'err';
  if (event.kind === 'done') kind = 'ok';
  line.className = kind;
  line.textContent = event.kind === 'step'
    ? `${event.status === 'done' ? '✓' : '›'} ${event.name}`
    : event.message || JSON.stringify(event);
  log.append(line);
  log.scrollTop = log.scrollHeight;
}

function startInstall() {
  state.installing = true;
  renderSteps();
  $('log').replaceChildren();
  showStep(4);
  api('/api/install', { method: 'POST', body: JSON.stringify({ plan: buildPlan() }) })
    .then(() => {
      if (state.source) state.source.close();
      state.source = new EventSource('/api/events');
      state.source.addEventListener('message', (message) => {
        let event;
        try { event = JSON.parse(message.data); } catch (_error) { return; }
        logLine(event);
        if (event.kind === 'step') {
          const chip = document.querySelector(`.step-chip[data-name="${event.name}"]`);
          if (chip) chip.className = `step-chip ${event.status}`;
          if (event.status === 'running') $('progress-step').textContent = event.name;
        }
        if (typeof event.progress === 'number') {
          $('progress-bar').style.width = `${event.progress}%`;
          $('progress-pct').textContent = `${event.progress}%`;
        }
        if (event.kind === 'done') {
          state.installing = false;
          state.source.close();
          $('bar-status').firstElementChild.textContent = 'Complete';
          showStep(5);
        }
        if (event.kind === 'error') {
          state.installing = false;
          state.source.close();
          $('bar-status').firstElementChild.textContent = 'Failed';
          logLine({ kind: 'error', message: 'Installation stopped. Review the log above.' });
          showStep(4);
        }
      });
    })
    .catch((error) => {
      state.installing = false;
      logLine({ kind: 'error', message: error.message });
      showStep(3);
    });
}

function next() {
  if (state.step === 5) {
    api('/api/command', { method: 'POST', body: JSON.stringify({ action: 'reboot' }) }).catch(() => {});
    return;
  }
  if (state.step === 0 || state.step === 1 || state.step === 2) {
    buildPlan();
    validate();
    if (!state.valid) return;
  }
  if (state.step === 3) {
    if (!state.valid) return;
    startInstall();
    return;
  }
  if (state.step === 4 && state.installing) return;
  showStep(Math.min(state.step + 1, 5));
  if (state.step === 3) renderReview();
}

function back() {
  if (state.installing) {
    api('/api/cancel', { method: 'POST' }).catch(() => {});
    return;
  }
  if (state.step > 0) showStep(state.step - 1);
}

async function init() {
  $('f-confirm').addEventListener('input', validate);
  $('f-hostname').addEventListener('input', validate);
  $('f-username').addEventListener('input', validate);
  $('f-password').addEventListener('input', validate);
  $('f-password2').addEventListener('input', validate);
  $('f-locale').addEventListener('change', validate);
  $('f-keymap').addEventListener('change', validate);
  $('f-timezone').addEventListener('change', validate);
  $('f-root').addEventListener('change', validate);
  $('f-esp').addEventListener('change', validate);
  $('btn-next').addEventListener('click', next);
  $('btn-back').addEventListener('click', back);
  bindMode();

  document.addEventListener('keydown', (event) => {
    if (event.key === 'Enter' && !state.installing && event.target.tagName !== 'SELECT') next();
    if (event.key === 'Escape' && !state.installing) back();
  });

  try {
    state.view = await api('/api/overview');
  } catch (error) {
    notice($('env-notice'), 'bad', `Cannot reach the installer backend: ${error.message}`);
    return;
  }
  state.plan = { mode: 'erase', boot: state.view.efi ? 'uefi' : 'bios', fs: 'ext4', token: state.view.token };
  renderEnvironment();
  renderDisks();
  renderChrome();
  showStep(0);
  validate();
}

init().catch((error) => notice($('env-notice'), 'bad', error.message));
