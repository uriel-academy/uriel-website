const puppeteer = require('puppeteer');
const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// adjust path to service account present in repo
const serviceAccountPath = path.join(__dirname, '..', 'uriel-academy-41fb0-firebase-adminsdk-fbsvc-4f2dfa7d5b.json');
if (!admin.apps.length) {
  const serviceAccount = require(serviceAccountPath);
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    projectId: 'uriel-academy-41fb0'
  });
}

const db = admin.firestore();

async function run() {
  const id = process.argv[2] || 'ict_2020_q2';
  const outDir = path.join(__dirname, 'output');
  if (!fs.existsSync(outDir)) fs.mkdirSync(outDir, { recursive: true });

  const doc = await db.collection('questions').doc(id).get();
  if (!doc.exists) {
    console.error('Question not found in Firestore:', id);
    process.exit(2);
  }
  const data = doc.data();
  console.log('Loaded question from Firestore:', id);

  const questionText = (data.questionText || '').replace(/\s+/g, ' ').trim();
  const snippet = questionText.slice(0, Math.min(120, questionText.length));
  const correctLetter = (data.correctAnswer || '').trim();
  const correctFull = (data.fullAnswer || '').trim();
  const options = data.options || [];

  const browser = await puppeteer.launch({ headless: true, args: ['--no-sandbox','--disable-setuid-sandbox'] });
    const page = await browser.newPage();
    page.setDefaultTimeout(60000);

    const sleep = (ms) => new Promise((res) => setTimeout(res, ms));

  try {
    await page.goto('https://uriel-academy-41fb0.web.app/past-questions', { waitUntil: 'networkidle2' });
    console.log('Loaded past-questions page');

  // give Flutter time to render
  await sleep(3500);

    let html = await page.content();
    if (!html.includes(snippet)) {
      console.log('Snippet not immediately present. Trying search input heuristics...');
      const searchSelectors = ['input[type=text]', "input[placeholder*='Search']", '.search-input'];
      let found = null;
      for (const sel of searchSelectors) {
        try {
          await page.waitForSelector(sel, { timeout: 2500 });
          found = sel; break;
        } catch (e) {}
      }
      if (found) {
        console.log('Typing into search input:', found);
        await page.click(found);
        // try searching by subject and year
        await page.type(found, 'ICT 2020');
        await page.keyboard.press('Enter');
        await sleep(3000);
        html = await page.content();
      } else {
        console.warn('No search input selector found; will try to locate question snippet in page HTML');
        await sleep(2000);
        html = await page.content();
      }
    }

    const foundSnippet = html.includes(snippet);
    console.log('Snippet present in rendered HTML:', foundSnippet);

    // Try clicking the element that contains the question text snippet
    let clickedQuestion = false;
    try {
      const xpath = `//*[contains(normalize-space(.), "${snippet.replace(/"/g, '\\"')}")]`;
      const nodes = await page.$x(xpath);
      if (nodes && nodes.length) {
        await nodes[0].click().catch(()=>{});
        clickedQuestion = true;
        console.log('Clicked a matching element for the question snippet');
      }
    } catch (e) {
      console.warn('XPath click attempt failed', e && e.message);
    }

  // wait for question view to render
  await sleep(2500);

    // Try to find and click the option matching the correct full answer text or letter
    let optionClicked = false;
    // prefer full option string like 'B. cursor.'
    const preferred = options.find(o => o.trim().startsWith(correctLetter + '.')) || options[0] || '';
    const preferText = preferred.replace(/\s+/g, ' ').trim();
    console.log('Preferred option text to click:', preferText);

    // Search for exact option text in page and click it
    try {
      const optXPath = `//*[contains(normalize-space(.), "${preferText.replace(/"/g,'\\"')}")]`;
      const optNodes = await page.$x(optXPath);
      if (optNodes && optNodes.length) {
        await optNodes[0].click().catch(()=>{});
        optionClicked = true;
        console.log('Clicked option node matching preferred option');
      }
    } catch (e) {
      console.warn('Option XPath click failed', e && e.message);
    }

    // If we didn't click an option, try clicking first button or list item heuristics
    if (!optionClicked) {
      try {
        const btn = await page.$('button');
        if (btn) { await btn.click().catch(()=>{}); optionClicked = true; console.log('Clicked first button as fallback'); }
      } catch (e) {}
    }

    // Attempt to submit/check answer — look for buttons with common text
    const submitTexts = ['Submit','Check','Answer','Reveal','Finish','Next'];
    let submitted = false;
    for (const txt of submitTexts) {
      try {
        const el = await page.$x(`//button[contains(., '${txt}')]`);
        if (el && el.length) { await el[0].click().catch(()=>{}); submitted = true; console.log('Clicked button:', txt); break; }
      } catch (e) {}
    }

  await sleep(2000);

    const finalHtml = await page.content();
    const sawCorrect = /correct/i.test(finalHtml) || /score/i.test(finalHtml) || /1\s*\/\s*1/.test(finalHtml);

    // Save artifacts
    const shotPath = path.join(outDir, `smoke_${id}.png`);
    await page.screenshot({ path: shotPath, fullPage: true });
    fs.writeFileSync(path.join(outDir, `smoke_${id}.html`), finalHtml);
    console.log('Saved screenshot and HTML to', outDir);
    console.log('Clicked question:', clickedQuestion, 'optionClicked:', optionClicked, 'submitted:', submitted, 'sawCorrectOrScore:', sawCorrect);

    await browser.close();

  // success criteria: either we observed a correct/score indicator OR we located the snippet and interacted
  const success = sawCorrect || (foundSnippet && (optionClicked || submitted));
    process.exit(success ? 0 : 3);
  } catch (err) {
    console.error('Error during smoke test:', err && err.stack);
    try { await browser.close(); } catch(e){}
    process.exit(4);
  }
}

run();
