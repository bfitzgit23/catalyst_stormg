import { ipc } from './ipc.js';

const $ = (id) => document.getElementById(id);
let windows = [];
let active = null;
let options = {};

function makeItem(label, glyph, attributes) {
  const button = document.createElement('button');
  button.className = 'dock-item';
  button.title = label;
  for (const [key, value] of Object.entries(attributes)) button.dataset[key] = value;
  if (glyph.image) {
    const image = document.createElement('img');
    image.src = glyph.image;
    image.alt = '';
    button.append(image);
  } else {
    const symbol = document.createElement('span');
    symbol.className = 'glyph';
    symbol.textContent = glyph.text;
    button.append(symbol);
  }
  return button;
}

function render() {
  const dock = $('dock');
  dock.replaceChildren();
  dock.append(makeItem('Applications', { text: '◆' }, { action: 'launcher' }));
  dock.append(makeItem('Terminal', { text: '▣' }, { action: 'terminal' }));

  const separator = document.createElement('span');
  separator.className = 'dock-separator';
  dock.append(separator);

  for (const window of windows) {
    const minimized = window.states.includes('_NET_WM_STATE_HIDDEN');
    const button = makeItem(
      window.name || window.wm_class || 'Window',
      window.icon ? { image: window.icon } : { text: (window.name || '?').slice(0, 1) },
      { id: String(window.id) }
    );
    if (window.id === active) button.classList.add('active');
    if (minimized) button.classList.add('minimized');
    dock.append(button);
  }
}

function handleClick(event) {
  const pinned = event.target.closest('[data-action]');
  if (pinned) {
    if (pinned.dataset.action === 'launcher') options.onLauncher?.();
    else if (pinned.dataset.action === 'terminal') options.onTerminal?.();
    return;
  }
  const item = event.target.closest('[data-id]');
  if (!item) return;
  const id = Number(item.dataset.id);
  const window = windows.find((entry) => entry.id === id);
  if (!window) return;
  const action = id === active ? 'minimize' : 'focus';
  ipc.post(`/api/window/${id}/${action}`).catch(console.error);
}

export async function initDock(callbacks = {}) {
  options = callbacks;
  const snapshot = await ipc.api('/api/windows');
  windows = snapshot.windows;
  active = snapshot.active;
  render();
  ipc.on('windows', (data) => {
    windows = data.windows;
    active = data.active;
    render();
  });
  $('dock').addEventListener('click', handleClick);
}
