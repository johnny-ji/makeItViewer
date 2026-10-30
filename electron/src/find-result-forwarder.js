function forwardFinalFindResult(webContents, sendResult) {
  webContents.on('found-in-page', (_event, result) => {
    if (result.finalUpdate) sendResult(result);
  });
}

module.exports = { forwardFinalFindResult };
