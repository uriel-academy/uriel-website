const fs = require('fs');
const path = require('path');

const srcFavicon = path.resolve(__dirname, '..', 'assets', 'favicon.ico');
const destFavicon = path.resolve(__dirname, '..', 'web', 'favicon.ico');

try {
  fs.copyFileSync(srcFavicon, destFavicon);
  console.log(`Copied ${srcFavicon} -> ${destFavicon}`);
} catch (err) {
  console.error('Failed to copy favicon:', err.message);
  process.exit(1);
}

// Delete unwanted PNG/icon files from web/icons to ensure only favicon.ico is used
try {
  const unwanted = [
    path.resolve(__dirname, '..', 'web', 'icons', 'Icon-192.png'),
    path.resolve(__dirname, '..', 'web', 'icons', 'Icon-512.png'),
    path.resolve(__dirname, '..', 'web', 'icons', 'Icon-maskable-192.png'),
    path.resolve(__dirname, '..', 'web', 'icons', 'Icon-maskable-512.png'),
    path.resolve(__dirname, '..', 'web', 'icons', 'icon.ico')
  ];

  unwanted.forEach((p) => {
    if (fs.existsSync(p)) {
      fs.unlinkSync(p);
      console.log(`Deleted unwanted icon: ${p}`);
    }
  });
} catch (err) {
  console.error('Failed to delete unwanted icons:', err.message);
}
