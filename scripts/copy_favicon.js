const fs = require('fs');
const path = require('path');

const src = path.resolve(__dirname, '..', 'assets', 'favicon.ico');
const dest = path.resolve(__dirname, '..', 'web', 'favicon.ico');

try {
  fs.copyFileSync(src, dest);
  console.log(`Copied ${src} -> ${dest}`);
} catch (err) {
  console.error('Failed to copy favicon:', err.message);
  process.exit(1);
}
