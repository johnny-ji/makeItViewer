const test = require('node:test');
const assert = require('node:assert/strict');
const Module = require('node:module');

test('preload exposes only the allowlisted viewer API', () => {
  const exposed = {};
  const calls = [];
  const listeners = [];
  const removals = [];
  const originalLoad = Module._load;
  Module._load = (request, parent, isMain) => request === 'electron'
    ? {
        contextBridge: { exposeInMainWorld: (name, api) => { exposed[name] = api; } },
        ipcRenderer: {
          invoke: (channel, payload) => { calls.push([channel, payload]); },
          on: (channel, listener) => { listeners.push([channel, listener]); },
          removeListener: (channel, listener) => { removals.push([channel, listener]); },
        },
      }
    : originalLoad(request, parent, isMain);

  try {
    delete require.cache[require.resolve('../preload.js')];
    require('../preload.js');
  } finally {
    Module._load = originalLoad;
  }

  assert.deepEqual(Object.keys(exposed.viewer).sort(), [
    'copyPng', 'findInPage', 'onFileChanged', 'onFindResult', 'openFile', 'print', 'reloadCurrentFile', 'savePng', 'saveSvg', 'stopFindInPage',
  ]);
  exposed.viewer.openFile();
  exposed.viewer.findInPage({ text: 'diagram', forward: true, findNext: true });
  exposed.viewer.stopFindInPage();
  let receivedResult = null;
  const unsubscribe = exposed.viewer.onFindResult((result) => { receivedResult = result; });
  const findListener = listeners.find(([channel]) => channel === 'viewer:find-result')[1];
  findListener({}, { requestId: 4, matches: 2, activeMatchOrdinal: 1, finalUpdate: true });
  unsubscribe();

  assert.deepEqual(calls, [
    ['viewer:open-file', undefined],
    ['viewer:find-in-page', { text: 'diagram', forward: true, findNext: true }],
    ['viewer:stop-find-in-page', undefined],
  ]);
  assert.deepEqual(receivedResult, { requestId: 4, matches: 2, activeMatchOrdinal: 1, finalUpdate: true });
  assert.deepEqual(removals, [['viewer:find-result', findListener]]);
});
