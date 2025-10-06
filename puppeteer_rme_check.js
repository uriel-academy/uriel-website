const puppeteer = require('puppeteer');

(async () => {
  const browser = await puppeteer.launch({ headless: true, args: ['--no-sandbox'] });
  const page = await browser.newPage();
  await page.goto('https://uriel-academy-41fb0.web.app', { waitUntil: 'networkidle2', timeout: 60000 });
  console.log('Loaded home page');

  // navigate to past-questions route
  await page.goto('https://uriel-academy-41fb0.web.app/past-questions', { waitUntil: 'networkidle2', timeout: 60000 });
  console.log('Loaded past-questions page');

  // Wait for a search input or list container (guessing selectors)
  // Try several heuristics for search input or list
  const searchSelectors = ['input[type=text]', 'input[placeholder*="Search"]', '.search-input'];
  let found = null;
  for (const sel of searchSelectors) {
    try {
      await page.waitForSelector(sel, { timeout: 3000 });
      found = sel; break;
    } catch (e) {}
  }

  if (!found) {
    console.warn('No obvious search input found; trying to inspect page for RME strings.');
    const body = await page.content();
    if (body.includes('Take RME Quiz') || body.toLowerCase().includes('rme')) {
      console.log('Found RME text on page HTML.');
    } else {
      console.log('RME text not present in static HTML.');
    }
    await browser.close();
    return;
  }

  console.log('Using search selector:', found);
  await page.click(found);
  await page.type(found, 'RME');
  await page.keyboard.press('Enter');

  // Wait for possible results to load
  await page.waitForTimeout(3000);

  const html = await page.content();
  const hasRmeText = html.includes('RME') || html.toLowerCase().includes('religious');
  console.log('Page HTML contains RME or religious:', hasRmeText);

  // Look for question id patterns rme_1999_q
  const hasRmeIds = /rme_1999_q\d+/.test(html);
  console.log('Page HTML contains rme_1999_q ids:', hasRmeIds);

  await browser.close();
})();
