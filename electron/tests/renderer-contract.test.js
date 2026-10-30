const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

test('renderer uses the Electron bridge and keeps SVG labels native', () => {
  const page = fs.readFileSync(path.join(__dirname, '../renderer/index.html'), 'utf8');
  assert.equal(page.includes('pywebview'), false);
  assert.equal(page.includes('startupOverlay'), false);
  assert.match(page, /window\.viewer\.openFile/);
  assert.match(page, /window\.viewer\.onFileChanged/);
  assert.match(page, /htmlLabels: false/);
});

test('renderer provides native find controls and restores an active query after rendering', () => {
  const page = fs.readFileSync(path.join(__dirname, '../renderer/index.html'), 'utf8');

  assert.match(page, /id="findInput"/);
  assert.match(page, /window\.viewer\.findInPage/);
  assert.match(page, /window\.viewer\.onFindResult/);
  assert.match(page, /case 'f': e\.preventDefault\(\); openFindBar\(\); break;/);
  assert.match(page, /bindPanZoomHandlers\(\);\s*restoreFindAfterRender\(\);/);
});

test('renderer starts a new native search only when Enter is pressed', () => {
  const page = fs.readFileSync(path.join(__dirname, '../renderer/index.html'), 'utf8');

  assert.doesNotMatch(page, /findInput\.addEventListener\('input', \(\) => requestFind\(true, true\)\);/);
  assert.match(page, /if \(e\.key === 'Enter'\) \{ e\.preventDefault\(\); requestFind\(!e\.shiftKey, true\); \}/);
});
