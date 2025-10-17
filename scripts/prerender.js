const fs = require('fs');
const path = require('path');

// Simple prerender: read build/web/index.html and write variant files
const buildPath = path.resolve(__dirname, '..', 'build', 'web');
const indexPath = path.join(buildPath, 'index.html');

if (!fs.existsSync(indexPath)) {
  console.error('Build not found. Run `flutter build web` first.');
  process.exit(1);
}

const indexHtml = fs.readFileSync(indexPath, 'utf8');

// Load route metadata
const metaPath = path.join(__dirname, 'route-meta.json');
let routeMeta = {};
if (fs.existsSync(metaPath)) {
  routeMeta = JSON.parse(fs.readFileSync(metaPath, 'utf8'));
} else {
  console.error('route-meta.json not found; using default routes');
}

const routes = Object.keys(routeMeta).map(routePath => {
  const filename = routePath === '/' ? 'index.html' : routePath.replace(/^\//, '') + '.html';
  return {
    path: routePath,
    file: filename,
    meta: routeMeta[routePath]
  };
});

routes.forEach(route => {
  let out = indexHtml;
  const title = route.meta.title || 'Uriel Academy';
  const desc = route.meta.description || 'Uriel Academy';
  const image = route.meta.image || 'https://uriel-academy-41fb0.web.app/assets/uriel_logo.png';

  out = out.replace(/<title>.*?<\/title>/s, `<title>${title}<\/title>`);
  out = out.replace(/<meta name="description" content=".*?">/s, `<meta name="description" content="${desc}">`);
  out = out.replace(/<meta property="og:title" content=".*?">/s, `<meta property="og:title" content="${title}">`);
  out = out.replace(/<meta property="og:description" content=".*?">/s, `<meta property="og:description" content="${desc}">`);
  out = out.replace(/<meta property="og:image" content=".*?">/s, `<meta property="og:image" content="${image}">`);
  out = out.replace(/<meta property="twitter:title" content=".*?">/s, `<meta property="twitter:title" content="${title}">`);
  out = out.replace(/<meta property="twitter:description" content=".*?">/s, `<meta property="twitter:description" content="${desc}">`);
  out = out.replace(/<meta property="twitter:image" content=".*?">/s, `<meta property="twitter:image" content="${image}">`);
  out = out.replace(/<link rel="canonical" href=".*?">/s, `<link rel="canonical" href="https://uriel-academy-41fb0.web.app${route.path}">`);

  const outPath = path.join(buildPath, route.file);
  fs.writeFileSync(outPath, out, 'utf8');
  console.log('Wrote', outPath);
});

console.log('Prerender complete.');
