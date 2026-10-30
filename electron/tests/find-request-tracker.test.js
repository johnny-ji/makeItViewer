const test = require('node:test');
const assert = require('node:assert/strict');
const { createFindRequestTracker } = require('../renderer/find-request-tracker');

test('ignores a request ID that resolves after a newer query clears search', () => {
  const tracker = createFindRequestTracker();
  const oldGeneration = tracker.begin();
  tracker.invalidate();

  assert.equal(tracker.setRequestId(oldGeneration, 41), null);
  assert.equal(tracker.receiveResult({ requestId: 41, matches: 3, activeMatchOrdinal: 1 }), null);
});

test('delivers a final result that arrives before its find request resolves', () => {
  const tracker = createFindRequestTracker();
  const generation = tracker.begin();
  const earlyResult = { requestId: 42, matches: 2, activeMatchOrdinal: 1 };

  assert.equal(tracker.receiveResult(earlyResult), null);
  assert.deepEqual(tracker.setRequestId(generation, 42), earlyResult);
});
