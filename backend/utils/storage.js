// Centralized JSON storage helpers
const fs = require('fs');

function safeLoad(path, fallback) {
  try { return JSON.parse(fs.readFileSync(path, 'utf8')); } catch { return fallback; }
}
function saveJson(path, data) {
  fs.writeFileSync(path, JSON.stringify(data, null, 2), 'utf8');
}

module.exports = { safeLoad, saveJson };
