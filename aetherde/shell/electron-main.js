'use strict';
// Electron host for the AetherDE web shell.
// The window is borderless, non-focusable and forced into the EWMH desktop layer so
// xfwm4-managed native applications always paint above it and keep keyboard focus.

const { app, BrowserWindow, shell } = require('electron');
const { execFile } = require('child_process');
const path = require('path');

const urlArg = process.argv.find((a) => a.startsWith('http://') || a.startsWith('https://'));
const TARGET = urlArg || 'http://127.0.0.1:8787/index.html';

let win = null;

function pinToDesktopLayer(wid) {
  const operations = [
    ['-id', wid, '-f', '_NET_WM_WINDOW_TYPE', '32a', '-set',
      '_NET_WM_WINDOW_TYPE', '_NET_WM_WINDOW_TYPE_DESKTOP'],
    ['-id', wid, '-f', '_NET_WM_STATE', '32a', '-set',
      '_NET_WM_STATE', '_NET_WM_STATE_BELOW'],
    ['-id', wid, '-b', 'add,skip_taskbar,skip_pager'],
  ];
  for (const args of operations) {
    execFile('xprop', args, (err) => {
      if (err) console.error('[aether-shell] xprop:', err.message);
    });
  }
}

app.whenReady().then(() => {
  win = new BrowserWindow({
    fullscreen: true,
    frame: false,
    transparent: true,
    backgroundColor: '#00000000',
    resizable: false,
    movable: false,
    minimizable: false,
    maximizable: false,
    closable: false,
    focusable: false,
    skipTaskbar: true,
    show: false,
    type: 'desktop',
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true,
      sandbox: true,
      preload: path.join(__dirname, 'preload.js'),
    },
  });

  win.setFocusable(false);
  win.setAlwaysOnTop(false);
  if (win.setVisibleOnAllWorkspaces) {
    win.setVisibleOnAllWorkspaces(true, { visibleOnFullScreen: true });
  }

  win.once('ready-to-show', () => {
    const handle = win.getNativeWindowHandle();
    let wid = null;
    if (handle.length >= 8) wid = String(handle.readBigUInt64LE(0));
    else if (handle.length >= 4) wid = String(handle.readUInt32LE(0));
    if (wid) pinToDesktopLayer(wid);
    win.show();
  });

  win.webContents.setWindowOpenHandler(({ url }) => {
    if (/^https?:\/\//.test(url)) shell.openExternal(url);
    return { action: 'deny' };
  });

  win.loadURL(TARGET);
  win.on('closed', () => { win = null; });
});

app.on('window-all-closed', () => app.quit());
