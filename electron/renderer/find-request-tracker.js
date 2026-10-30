(function exposeFindRequestTracker(globalObject) {
  function createFindRequestTracker() {
    let generation = 0;
    let requestId = null;
    let pendingResults = new Map();

    function begin() {
      generation += 1;
      requestId = null;
      pendingResults = new Map();
      return generation;
    }

    return {
      begin,
      invalidate: begin,
      setRequestId(requestGeneration, nextRequestId) {
        if (requestGeneration !== generation) return null;
        requestId = nextRequestId;
        const result = pendingResults.get(nextRequestId) || null;
        pendingResults.delete(nextRequestId);
        return result;
      },
      receiveResult(result) {
        if (result.requestId === requestId) return result;
        if (requestId === null) pendingResults.set(result.requestId, result);
        return null;
      },
    };
  }

  if (typeof module !== 'undefined' && module.exports) module.exports = { createFindRequestTracker };
  globalObject.createFindRequestTracker = createFindRequestTracker;
}(typeof window === 'undefined' ? globalThis : window));
