const puppeteer = require('puppeteer');

(async () => {
  const browser = await puppeteer.launch({ headless: true, args: ['--no-sandbox','--disable-setuid-sandbox'] });
  const page = await browser.newPage();
  page.setDefaultTimeout(60000);
  await page.goto('https://uriel-academy-41fb0.web.app/sign-in', { waitUntil: 'networkidle2' });
  console.log('Opened sign-in page');

  // Try to find any email/password inputs by placeholder or type
  const emailSelectors = ["input[placeholder*='Email']", "input[type='email']", "input[aria-label*='email']", "input"];
  let emailSel = null;
  for (const sel of emailSelectors) {
    try { await page.waitForSelector(sel, { timeout: 3000 }); emailSel = sel; break; } catch(e){}
  }

  if (!emailSel) { console.error('No input found on sign-in page'); await browser.close(); return; }

  // Use the first input as email and the second as password
  const inputs = await page.$$('input');
  if (inputs.length < 2) {
    console.error('Not enough input fields on sign-in form'); await browser.close(); return;
  }

  const email = 'test-rme+1@uriel.test';
  const password = 'TestRme123!';

  await inputs[0].focus();
  await page.keyboard.type(email);
  await inputs[1].focus();
  await page.keyboard.type(password);

  // Try to click a button with text 'Sign in'/'Sign In'/'Continue' or input[type=submit]
  const buttonTexts = ['Sign in', 'Sign In', 'Continue', 'Log in', 'Log In'];
  let clicked = false;
  for (const text of buttonTexts) {
    try {
      const btn = await page.$x(`//button[contains(., '${text}')]`);
      if (btn && btn.length) { await btn[0].click(); clicked = true; break; }
    } catch (e) {}
  }
  if (!clicked) {
    // try input[type=submit]
    try { const submit = await page.$("input[type='submit']"); if (submit) { await submit.click(); clicked = true; }} catch(e){}
  }

  if (!clicked) { console.warn('Could not find sign-in button; proceeding after wait'); }

  await page.waitForNavigation({ waitUntil: 'networkidle2', timeout: 30000 }).catch(()=>{});
  console.log('After sign-in, URL:', page.url());

  // Navigate to past-questions
  await page.goto('https://uriel-academy-41fb0.web.app/past-questions', { waitUntil: 'networkidle2' });
  console.log('Loaded past-questions page');

  // Wait a bit for Flutter to render
  await page.waitForTimeout(4000);

  // Get page content and search for rme ids
  const html = await page.content();
  const hasRmeIds = /rme_1999_q\d+/.test(html);
  const hasRmeText = html.includes('RME') || html.toLowerCase().includes('religious');
  console.log('Page contains RME ids:', hasRmeIds);
  console.log('Page contains RME text:', hasRmeText);

  await browser.close();
})();
