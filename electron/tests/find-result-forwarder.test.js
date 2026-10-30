const test = require('node:test');
const assert = require('node:assert/strict');
const { forwardFinalFindResult } = require('../src/find-result-forwarder');

test('forwards only final Chromium find results to the renderer sender', () => {
  let listener;
  const received = [];
  const webContents = { on: (event, callback) => { listener = { event, callback }; } };

  forwardFinalFindResult(webContents, (result) => received.push(result));
  listener.callback({}, { requestId: 2, matches: 1, activeMatchOrdinal: 1, finalUpdate: false });
  listener.callback({}, { requestId: 2, matches: 3, activeMatchOrdinal: 2, finalUpdate: true });

  assert.equal(listener.event, 'found-in-page');
  assert.deepEqual(received, [{ requestId: 2, matches: 3, activeMatchOrdinal: 2, finalUpdate: true }]);
});
