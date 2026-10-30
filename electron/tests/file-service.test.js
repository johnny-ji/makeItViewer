const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { readMarkdownFile, createFileWatcher } = require('../src/file-service');

test('file service reads UTF-8 Markdown and reports its filename', () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'viewer-'));
  const file = path.join(dir, '说明.md');
  fs.writeFileSync(file, '\ufeff# 中文标题');
  const document = readMarkdownFile(file);
  assert.equal(document.filename, '说明.md');
  assert.equal(document.content, '# 中文标题');
  fs.rmSync(dir, { recursive: true, force: true });
});

test('file watcher replaces its active watch target', async () => {
  const dir = fs.mkdtempSync(path.join(os.tmpdir(), 'viewer-'));
  const first = path.join(dir, 'first.md');
  const second = path.join(dir, 'second.md');
  fs.writeFileSync(first, 'one');
  fs.writeFileSync(second, 'two');
  const changes = [];
  const watcher = createFileWatcher((filePath) => changes.push(filePath), 20);
  watcher.watch(first);
  watcher.watch(second);
  fs.writeFileSync(first, 'one changed');
  fs.writeFileSync(second, 'two changed');
  await new Promise((resolve) => setTimeout(resolve, 120));
  watcher.close();
  assert.deepEqual(changes, [second]);
  fs.rmSync(dir, { recursive: true, force: true });
});
