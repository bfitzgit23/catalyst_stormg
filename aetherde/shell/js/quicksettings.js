import { ipc } from './ipc.js';

const $ = (id) => document.getElementById(id);
let options = {};
const STATE_LABELS = ['Unknown', 'Asleep', 'Disconnected', 'Connecting', 'Connected', 'Disconnecting'];

function applyVolume(volume) {
  $('qs-volume').value = String(volume.level);
  $('qs-volume-value').textContent = `${volume.level}%${volume.muted ? ' (muted)' : ''}`;
}

function applyNetwork(status) {
  const changed = status.changed || {};
  const state = status.state ?? changed.State;
  const label = status.state_label || STATE_LABELS[state] || 'Unknown';
  const connections = status.active_connections || [];
  $('qs-network').textContent = `${label}${connections.length ? ` · ${connections.length} active` : ''}`;
}

function applyMetrics(metrics) {
  const cpu = Math.round(metrics.cpu);
  const ram = Math.round(metrics.ram);
  $('qs-cpu-bar').style.width = `${cpu}%`;
  $('qs-ram-bar').style.width = `${ram}%`;
  $('qs-cpu-text').textContent = `${cpu}%`;
  $('qs-ram-text').textContent = `${ram}%`;
  if (typeof metrics.load === 'number') {
    $('qs-load').textContent = `Load ${metrics.load.toFixed(2)}`;
  }
}

export async function initQuickSettings(callbacks = {}) {
  options = callbacks;
  try { applyVolume(await ipc.api('/api/volume')); } catch (error) { console.error(error); }
  try { applyNetwork(await ipc.api('/api/network')); } catch (error) { console.error(error); }
  try { applyMetrics(await ipc.api('/api/status')); } catch (error) { console.error(error); }

  ipc.on('volume', applyVolume);
  ipc.on('network', applyNetwork);
  ipc.on('metrics', applyMetrics);

  $('qs-volume').addEventListener('input', (event) => {
    const level = Number(event.target.value);
    $('qs-volume-value').textContent = `${level}%`;
    ipc.post('/api/volume', { level }).catch(console.error);
  });
  $('qs-mute').addEventListener('click', () => ipc.post('/api/mute').catch(console.error));
  $('qs-terminal').addEventListener('click', () => {
    $('quick-settings').classList.add('hidden');
    options.onTerminal?.();
  });
}
