const puppeteer = require('puppeteer');

(async () => {
  const browser = await puppeteer.launch({ headless: true, args: ['--no-sandbox','--disable-setuid-sandbox'] });
  const page = await browser.newPage();
  page.setDefaultTimeout(60000);

  page.on('console', msg => console.log('PAGE LOG:', msg.text()));
  page.on('pageerror', err => console.log('PAGE ERROR:', err.toString()));
  page.on('response', res => { if (res.status() >= 400) console.log('HTTP ERROR', res.status(), res.url()); });

  const url = 'https://uriel-academy-41fb0.web.app/leaderboard';
  console.log('Navigating to', url);
  // Unregister any service workers to avoid stale cached JS bundles
  await page.goto('about:blank');
  try {
    await page.evaluate(async () => {
      if ('serviceWorker' in navigator) {
        const regs = await navigator.serviceWorker.getRegistrations();
        for (const r of regs) {
          try { await r.unregister(); } catch (e) { /* ignore */ }
        }
      }
    });
    console.log('Unregistered existing service workers');
  } catch (e) {
    console.log('Failed to unregister service workers:', e && e.message);
  }

  await page.goto(url, { waitUntil: 'networkidle2' }).catch(e => console.log('goto error', e && e.message));
  console.log('After initial navigation, URL:', page.url());

  // Wait extra time for Flutter to boot and Firebase to initialize
  await new Promise((resolve) => setTimeout(resolve, 7000));

  // Capture some page state
  const html = await page.content();
  console.log('HTML length:', html.length);
  console.log('Contains "Leaderboard" text:', /Leaderboard/i.test(html));
  console.log('Contains "totalXP" token:', /totalXP/i.test(html));
  console.log('Contains XP-like text (XP, xp):', /\bXP\b|\bxp\b/.test(html));

  // Save a screenshot for manual inspection
  await page.screenshot({ path: 'leaderboard.png', fullPage: true }).catch(e => console.log('screenshot failed', e && e.message));
  console.log('Saved screenshot to leaderboard.png');

  await browser.close();
})();
