const test = require('node:test');
const assert = require('node:assert/strict');
const { registerHandlers } = require('../src/main-handlers');

function createSearchHarness(windowRef) {
  const handlers = new Map();
  registerHandlers({
    ipcMain: { handle: (channel, handler) => handlers.set(channel, handler) },
    dialog: {},
    clipboard: {},
    nativeImage: {},
    readMarkdownFile: () => null,
    watcher: { onChange: null },
    getWindow: () => windowRef.current,
  });
  return handlers;
}

test('find IPC starts a case-insensitive Chromium search with supplied direction', async () => {
  const calls = [];
  const windowRef = { current: { webContents: { findInPage: (...args) => calls.push(args) } } };
  const handlers = createSearchHarness(windowRef);

  await handlers.get('viewer:find-in-page')({}, { text: 'Mermaid', forward: false, findNext: true });

  assert.deepEqual(calls, [['Mermaid', { forward: false, findNext: true, matchCase: false }]]);
});

test('find IPC clears selection for an empty query and supports explicit stop', async () => {
  const stops = [];
  const windowRef = { current: { webContents: { stopFindInPage: (action) => stops.push(action) } } };
  const handlers = createSearchHarness(windowRef);

  await handlers.get('viewer:find-in-page')({}, { text: '   ' });
  await handlers.get('viewer:stop-find-in-page')({});

  assert.deepEqual(stops, ['clearSelection', 'clearSelection']);
});

test('find IPC defaults forward and safely handles a closed window', async () => {
  const calls = [];
  const windowRef = { current: { webContents: { findInPage: (...args) => calls.push(args) } } };
  const handlers = createSearchHarness(windowRef);

  await handlers.get('viewer:find-in-page')({}, { text: 'label' });
  windowRef.current = null;
  await handlers.get('viewer:find-in-page')({}, { text: 'ignored' });
  await handlers.get('viewer:stop-find-in-page')({});

  assert.deepEqual(calls, [['label', { forward: true, findNext: false, matchCase: false }]]);
});
