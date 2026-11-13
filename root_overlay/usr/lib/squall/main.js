const { app, BrowserWindow, screen } = require('electron');
const { spawn } = require('child_process');
const path = require('path');
const fs = require('fs');

const isDev = process.argv.includes('--dev');
// --app <name> opens a single Squall app in its own window instead of the shell
const appIdx = process.argv.indexOf('--app');
const appName = appIdx > -1 ? process.argv[appIdx + 1] : null;

const BACKEND = path.join(__dirname, 'backend', 'squalld.py');
let backend = null;

function startBackend() {
  if (!fs.existsSync(BACKEND)) {
    console.error('[squall] backend missing:', BACKEND);
    return;
  }
  backend = spawn('python3', [BACKEND, '--port', '9876'], { stdio: 'ignore' });
  backend.on('error', (e) => console.error('[squall] backend failed:', e.message));
  backend.unref();
}

function createShell() {
  const { width, height } = screen.getPrimaryDisplay().workAreaSize;
  const win = new BrowserWindow({
    x: 0, y: 0, width, height,
    transparent: true,
    frame: false,
    resizable: false,
    movable: false,
    skipTaskbar: true,
    alwaysOnTop: true,
    type: 'desktop',
    hasShadow: false,
    webPreferences: { nodeIntegration: false, contextIsolation: true }
  });
  win.setAlwaysOnTop(true, 'screen-saver');
  win.setVisibleOnAllWorkspaces(true, { visibleOnFullScreen: true });
  win.setFullScreen(true);
  win.loadFile(path.join(__dirname, 'frontend', 'index.html'));
  if (isDev) win.webContents.openDevTools({ mode: 'detach' });
}

function createApp(name) {
  const file = path.join(__dirname, 'apps', `${name}.html`);
  if (!fs.existsSync(file)) {
    console.error('[squall] unknown app:', name);
    return app.quit();
  }
  const win = new BrowserWindow({
    width: 1180, height: 760, minWidth: 720, minHeight: 480,
    backgroundColor: '#020c1b', autoHideMenuBar: true, title: `Squall ${name}`,
    webPreferences: { nodeIntegration: false, contextIsolation: true }
  });
  win.loadFile(file);
  if (isDev) win.webContents.openDevTools({ mode: 'detach' });
}

app.whenReady().then(() => {
  if (appName) {
    // app windows expect a running squalld (systemd user unit on StormG)
    createApp(appName);
    return;
  }
  startBackend();
  createShell();
});

app.on('window-all-closed', () => {
  if (backend) backend.kill();
  if (process.platform !== 'darwin') app.quit();
});
