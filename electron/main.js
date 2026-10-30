const { app, BrowserWindow, ipcMain, dialog, clipboard, nativeImage } = require('electron');
const path = require('node:path');
const { readMarkdownFile, createFileWatcher } = require('./src/file-service');
const { registerHandlers } = require('./src/main-handlers');
const { findMarkdownPath } = require('./src/launch-file');
const { forwardFinalFindResult } = require('./src/find-result-forwarder');

let mainWindow;
let watcher;
let rendererReady = false;
let requestedFilePath = findMarkdownPath(process.argv);

function openRequestedFile(filePath) {
  if (!filePath) return;
  requestedFilePath = filePath;
  if (!mainWindow || mainWindow.isDestroyed() || !rendererReady) return;

  try {
    watcher.watch(filePath);
    mainWindow.webContents.send('viewer:file-changed', readMarkdownFile(filePath));
    if (mainWindow.isMinimized()) mainWindow.restore();
    mainWindow.focus();
  } catch { }
}

function createWindow() {
  mainWindow = new BrowserWindow({
    width: 1400,
    height: 900,
    minWidth: 800,
    minHeight: 600,
    title: 'Markdown & Mermaid Viewer',
    webPreferences: {
      preload: path.join(__dirname, 'preload.js'),
      contextIsolation: true,
      nodeIntegration: false,
    },
  });
  watcher = createFileWatcher((filePath) => {
    try { mainWindow.webContents.send('viewer:file-changed', readMarkdownFile(filePath)); } catch { }
  });
  registerHandlers({ ipcMain, dialog, clipboard, nativeImage, readMarkdownFile, watcher, getWindow: () => mainWindow });
  forwardFinalFindResult(mainWindow.webContents, (result) => {
    if (!mainWindow || mainWindow.isDestroyed()) return;
    mainWindow.webContents.send('viewer:find-result', result);
  });
  mainWindow.webContents.once('did-finish-load', () => {
    rendererReady = true;
    openRequestedFile(requestedFilePath);
  });
  mainWindow.on('closed', () => {
    watcher.close();
    mainWindow = null;
    rendererReady = false;
  });
  mainWindow.loadFile(path.join(__dirname, 'renderer', 'index.html'));
}

const hasSingleInstanceLock = app.requestSingleInstanceLock();
if (!hasSingleInstanceLock) {
  app.quit();
} else {
  app.on('second-instance', (_event, commandLine) => openRequestedFile(findMarkdownPath(commandLine)));
  app.whenReady().then(createWindow);
}
app.on('window-all-closed', () => { if (process.platform !== 'darwin') app.quit(); });
