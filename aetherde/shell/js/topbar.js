import { ipc } from './ipc.js';

const $ = (id) => document.getElementById(id);
const cpuSamples = [];
const ramSamples = [];

function drawSpark(canvas, samples, value, color) {
  samples.push(Math.max(0, Math.min(100, value)));
  if (samples.length > 36) samples.shift();
  const ctx = canvas.getContext('2d');
  const { width, height } = canvas;
  ctx.clearRect(0, 0, width, height);
  if (samples.length < 2) return;
  ctx.beginPath();
  samples.forEach((sample, index) => {
    const x = (index / (samples.length - 1)) * width;
    const y = height - (sample / 100) * (height - 2) - 1;
    if (index === 0) ctx.moveTo(x, y);
    else ctx.lineTo(x, y);
  });
  ctx.strokeStyle = color;
  ctx.lineWidth = 1.5;
  ctx.stroke();
  ctx.lineTo(width, height);
  ctx.lineTo(0, height);
  ctx.closePath();
  ctx.globalAlpha = 0.14;
  ctx.fillStyle = color;
  ctx.fill();
  ctx.globalAlpha = 1;
}

function renderWorkspaces(info, windows) {
  const container = $('workspaces');
  container.replaceChildren();
  const occupied = new Set(windows.map((window) => window.desktop));
  for (let index = 0; index < info.count; index += 1) {
    const button = document.createElement('button');
    button.className = 'workspace-button';
    if (index === info.current) button.classList.add('current');
    if (occupied.has(index)) button.classList.add('occupied');
    button.dataset.workspace = String(index);
    button.textContent = String(index + 1);
    button.title = info.names[index] || `Workspace ${index + 1}`;
    button.setAttribute('role', 'tab');
    button.setAttribute('aria-selected', String(index === info.current));
    container.append(button);
  }
}

export async function initTopbar() {
  const snapshot = await ipc.api('/api/windows');
  renderWorkspaces(snapshot.workspaces, snapshot.windows);

  ipc.on('windows', (data) => renderWorkspaces(data.workspaces, data.windows));

  $('workspaces').addEventListener('click', (event) => {
    const button = event.target.closest('[data-workspace]');
    if (button) ipc.post(`/api/workspace/${button.dataset.workspace}`).catch(console.error);
  });

  const clock = $('clock');
  const tick = () => {
    clock.textContent = new Date().toLocaleTimeString([], {
      hour: '2-digit',
      minute: '2-digit',
    });
  };
  tick();
  setInterval(tick, 1000);

  const updateMetrics = (metrics) => {
    $('cpu-label').textContent = `${Math.round(metrics.cpu)}%`;
    $('ram-label').textContent = `${Math.round(metrics.ram)}%`;
    drawSpark($('spark-cpu'), cpuSamples, metrics.cpu, '#6ea8fe');
    drawSpark($('spark-ram'), ramSamples, metrics.ram, '#b197fc');
  };

  ipc.on('metrics', updateMetrics);
  const status = await ipc.api('/api/status');
  for (const sample of status.history) {
    cpuSamples.push(sample.cpu);
    ramSamples.push(sample.ram);
  }
  updateMetrics({ cpu: status.cpu, ram: status.ram });
}
