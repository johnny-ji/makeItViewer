const fs = require('node:fs');
const path = require('node:path');
const iconv = require('iconv-lite');

function readMarkdownFile(filePath) {
  const buffer = fs.readFileSync(filePath);
  let content;
  if (buffer.subarray(0, 3).equals(Buffer.from([0xef, 0xbb, 0xbf]))) {
    content = buffer.subarray(3).toString('utf8');
  } else {
    content = buffer.toString('utf8');
    if (content.includes('\ufffd')) {
      content = iconv.decode(buffer, 'gb18030');
    }
  }
  return { path: filePath, filename: path.basename(filePath), content };
}

function createFileWatcher(onChange, debounceMs = 100) {
  let activeWatcher = null;
  let activePath = null;
  let timer = null;

  function close() {
    if (activeWatcher) activeWatcher.close();
    activeWatcher = null;
    activePath = null;
    if (timer) clearTimeout(timer);
    timer = null;
  }

  return {
    watch(filePath) {
      close();
      activePath = filePath;
      activeWatcher = fs.watch(filePath, () => {
        if (timer) clearTimeout(timer);
        timer = setTimeout(() => {
          timer = null;
          if (activePath === filePath && fs.existsSync(filePath)) onChange(filePath);
        }, debounceMs);
      });
    },
    close,
  };
}

module.exports = { readMarkdownFile, createFileWatcher };
