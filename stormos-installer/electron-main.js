'use strict';
// Electron host for the StormOS installer. The GUI is served by the local
// backend over http://127.0.0.1, so the renderer stays same-origin and needs
// no node integration and no CORS relaxation.

const { app, BrowserWindow } = require('electron');

const URL = process.env.STORMOS_INSTALLER_URL || 'http://127.0.0.1:9877/';
let win = null;

app.whenReady().then(() => {
  win = new BrowserWindow({
    fullscreen: true,
    frame: false,
    autoHideMenuBar: true,
    backgroundColor: '#060a12',
    show: false,
    webPreferences: {
      nodeIntegration: false,
      contextIsolation: true,
      sandbox: true,
      webSecurity: true,
      devTools: false,
    },
  });

  win.once('ready-to-show', () => win.show());
  win.loadURL(URL);
  win.on('closed', () => { win = null; });
});

app.on('window-all-closed', () => app.quit());
