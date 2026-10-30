const path = require('node:path');

function findMarkdownPath(argumentsList) {
  return argumentsList.find((argument) => {
    const extension = path.extname(argument).toLowerCase();
    return extension === '.md' || extension === '.markdown';
  }) || null;
}

module.exports = { findMarkdownPath };
