'use strict';
const { contextBridge, shell } = require('electron');

contextBridge.exposeInMainWorld('aetherHost', Object.freeze({
  platform: 'linux',
  openExternal(url) {
    if (typeof url === 'string' && /^https?:\/\//.test(url)) {
      shell.openExternal(url);
    }
  },
}));
