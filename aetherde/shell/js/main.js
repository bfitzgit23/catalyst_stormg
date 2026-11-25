import { ipc } from './ipc.js';
import { initTopbar } from './topbar.js';
import { initLauncher, openLauncher } from './launcher.js';
import { initDock } from './dock.js';
import { terminal } from './terminal.js';
import { initQuickSettings } from './quicksettings.js';
import { initNotifications } from './notifications.js';

const $ = (id) => document.getElementById(id);

function toggleDrawer(id) {
  const target = $(id);
  const open = target.classList.contains('hidden');
  document.querySelectorAll('.drawer').forEach((drawer) => drawer.classList.add('hidden'));
  if (open) target.classList.remove('hidden');
}

function commandLine(execJson) {
  try {
    const parts = JSON.parse(execJson);
    return parts
      .map((part) => (/[\s"']/.test(part) ? JSON.stringify(part) : part))
      .join(' ');
  } catch (_error) {
    return '';
  }
}

async function launchApp(app) {
  if (!app.exec) return;
  if (app.terminal) {
    const command = commandLine(app.exec);
    if (command) terminal.runCommand(command);
    return;
  }
  try {
    await ipc.post('/api/launch', { command: app.exec });
  } catch (error) {
    console.error('[launch] failed', error);
  }
}

async function boot() {
  initNotifications();
  await Promise.all([
    initTopbar(),
    initDock({ onLauncher: openLauncher, onTerminal: () => terminal.open() }),
    initQuickSettings({ onTerminal: () => terminal.open() }),
  ]);
  await initLauncher({ onLaunch: launchApp });

  $('btn-notifications').addEventListener('click', () => toggleDrawer('notification-center'));
  $('btn-clock').addEventListener('click', () => toggleDrawer('quick-settings'));
  $('btn-volume').addEventListener('click', () => toggleDrawer('quick-settings'));
  $('btn-network').addEventListener('click', () => toggleDrawer('quick-settings'));

  document.addEventListener('keydown', (event) => {
    if (event.key !== 'Escape') return;
    $('launcher').classList.add('hidden');
    document.querySelectorAll('.drawer').forEach((drawer) => drawer.classList.add('hidden'));
  });
}

boot().catch((error) => console.error('[aether-shell] boot failed', error));
