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

const routes = [
  { path: '/', file: 'index.html', title: 'Uriel Academy – Home', desc: 'Master BECE & WASSCE exams with quizzes and past questions.' },
  { path: '/questions', file: 'questions.html', title: 'Past Questions', desc: 'Search and practice BECE & WASSCE past questions.' },
  { path: '/leaderboard', file: 'leaderboard.html', title: 'Leaderboard', desc: 'See top students and ranks on Uriel Academy.' },
  { path: '/profile', file: 'profile.html', title: 'Profile', desc: 'View your progress, ranks, and study recommendations.' }
];

routes.forEach(route => {
  let out = indexHtml;
  out = out.replace(/<title>.*?<\/title>/s, `<title>${route.title}<\/title>`);
  out = out.replace(/<meta name="description" content=".*?">/s, `<meta name="description" content="${route.desc}">`);
  // Basic OG replacement
  out = out.replace(/<meta property="og:title" content=".*?">/s, `<meta property="og:title" content="${route.title}">`);
  out = out.replace(/<meta property="og:description" content=".*?">/s, `<meta property="og:description" content="${route.desc}">`);

  const outPath = path.join(buildPath, route.file);
  fs.writeFileSync(outPath, out, 'utf8');
  console.log('Wrote', outPath);
});

console.log('Prerender complete.');
