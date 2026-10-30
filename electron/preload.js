const { contextBridge, ipcRenderer } = require('electron');

contextBridge.exposeInMainWorld('viewer', {
  openFile: () => ipcRenderer.invoke('viewer:open-file'),
  saveSvg: (payload) => ipcRenderer.invoke('viewer:save-svg', payload),
  savePng: (payload) => ipcRenderer.invoke('viewer:save-png', payload),
  copyPng: (payload) => ipcRenderer.invoke('viewer:copy-png', payload),
  reloadCurrentFile: () => ipcRenderer.invoke('viewer:reload-file'),
  findInPage: (payload) => ipcRenderer.invoke('viewer:find-in-page', payload),
  stopFindInPage: () => ipcRenderer.invoke('viewer:stop-find-in-page'),
  print: () => ipcRenderer.invoke('viewer:print'),
  onFileChanged: (callback) => {
    const listener = (_event, document) => callback(document);
    ipcRenderer.on('viewer:file-changed', listener);
    return () => ipcRenderer.removeListener('viewer:file-changed', listener);
  },
  onFindResult: (callback) => {
    const listener = (_event, result) => callback(result);
    ipcRenderer.on('viewer:find-result', listener);
    return () => ipcRenderer.removeListener('viewer:find-result', listener);
  },
});
