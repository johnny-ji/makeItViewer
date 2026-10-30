const test = require('node:test');
const assert = require('node:assert/strict');
const { findMarkdownPath } = require('../src/launch-file');

test('launch-file selects the Markdown file supplied by Windows', () => {
  const filePath = 'C:\\Users\\Alice\\Documents\\项目说明.md';

  assert.equal(
    findMarkdownPath(['MarkdownViewer.exe', '--inspect', filePath]),
    filePath,
  );
});

test('launch-file ignores non-Markdown arguments', () => {
  assert.equal(findMarkdownPath(['MarkdownViewer.exe', '--verbose', 'C:\\Temp\\notes.txt']), null);
});
