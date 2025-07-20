const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('electron', {
  onStream: (callback) => ipcRenderer.on('stream', (event, url) => callback(url)),
});
