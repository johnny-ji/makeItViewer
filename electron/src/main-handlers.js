const fs = require('node:fs');
const path = require('node:path');

function registerHandlers({ ipcMain, dialog, clipboard, nativeImage, readMarkdownFile, watcher, getWindow }) {
  let currentPath = null;
  let dialogOpen = false;
  const sendCurrent = (document) => getWindow()?.webContents.send('viewer:file-changed', document);

  ipcMain.handle('viewer:open-file', async () => {
    if (dialogOpen) return null;
    dialogOpen = true;
    try {
      const result = await dialog.showOpenDialog(getWindow(), {
        title: '打开 Markdown 文件',
        filters: [{ name: 'Markdown', extensions: ['md', 'markdown', 'mdx', 'txt'] }],
        properties: ['openFile'],
      });
      if (result.canceled || !result.filePaths[0]) return null;
      currentPath = result.filePaths[0];
      const document = readMarkdownFile(currentPath);
      watcher.watch(currentPath);
      return document;
    } finally { dialogOpen = false; }
  });

  ipcMain.handle('viewer:reload-file', () => currentPath ? readMarkdownFile(currentPath) : null);
  ipcMain.handle('viewer:find-in-page', (_event, payload) => {
    const text = String(payload?.text || '').trim();
    const webContents = getWindow()?.webContents;
    if (!text) {
      webContents?.stopFindInPage('clearSelection');
      return null;
    }
    return webContents?.findInPage(text, {
      forward: payload?.forward !== false,
      findNext: payload?.findNext === true,
      matchCase: false,
    }) ?? null;
  });
  ipcMain.handle('viewer:stop-find-in-page', () => {
    getWindow()?.webContents?.stopFindInPage('clearSelection');
    return true;
  });
  ipcMain.handle('viewer:save-svg', async (_event, payload) => savePayload(dialog, payload, 'svg', 'image/svg+xml;charset=utf-8'));
  ipcMain.handle('viewer:save-png', async (_event, payload) => savePayload(dialog, payload, 'png'));
  ipcMain.handle('viewer:copy-png', (_event, payload) => {
    const base64 = String(payload?.base64 || '').replace(/^data:image\/png;base64,/, '');
    clipboard.writeImage(nativeImage.createFromBuffer(Buffer.from(base64, 'base64')));
    return true;
  });
  ipcMain.handle('viewer:print', () => getWindow()?.webContents.print({ printBackground: true }));

  watcher.onChange = (filePath) => { if (filePath === currentPath) sendCurrent(readMarkdownFile(filePath)); };
}

async function savePayload(dialog, payload, extension, encoding) {
  const fallback = `flowchart.${extension}`;
  const result = await dialog.showSaveDialog({ defaultPath: path.basename(String(payload?.filename || fallback)).replace(/[^\w.\-() ]/g, '_') });
  if (result.canceled || !result.filePath) return false;
  const value = extension === 'png'
    ? Buffer.from(String(payload?.base64 || '').replace(/^data:image\/png;base64,/, ''), 'base64')
    : String(payload?.content || '');
  fs.writeFileSync(result.filePath, value, encoding ? { encoding } : undefined);
  return true;
}

module.exports = { registerHandlers };
