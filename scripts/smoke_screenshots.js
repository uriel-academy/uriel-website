const puppeteer = require('puppeteer');
const fs = require('fs');
const path = require('path');

(async () => {
  const url = 'https://uriel-academy-41fb0.web.app';
  const outDir = path.resolve(__dirname, '..', 'build', 'screenshots');
  if (!fs.existsSync(outDir)) fs.mkdirSync(outDir, { recursive: true });

  const browser = await puppeteer.launch({ headless: true, args: ['--no-sandbox', '--disable-setuid-sandbox'] });
  try {
    const page = await browser.newPage();
    await page.setViewport({ width: 1200, height: 900 });
    console.log('Navigating to', url);
    await page.goto(url, { waitUntil: 'networkidle2', timeout: 60000 });

    // Wait for Flutter first frame
    try {
      await page.waitForFunction(() => document.body.classList.contains('flutter-loaded'), { timeout: 30000 });
      console.log('Flutter first frame loaded');
    } catch (e) {
      console.log('Timeout waiting for flutter-first-frame; continuing anyway');
    }

    // Helper to find a visible input or textarea
    async function findVisibleInput() {
      return await page.evaluateHandle(() => {
        const els = Array.from(document.querySelectorAll('input, textarea, [contenteditable="true"]'));
        function isVisible(el) {
          const rect = el.getBoundingClientRect();
          return rect.width > 10 && rect.height > 10 && window.getComputedStyle(el).visibility !== 'hidden' && window.getComputedStyle(el).display !== 'none';
        }
        for (const el of els) {
          if (isVisible(el)) return el;
        }
        return null;
      });
    }

    const prompts = [
      'Explain factorization',
      'Simplify the expression $x^2 - 5x + 6$',
      'Show the integral $$\int_0^1 x^2 \, dx$$'
    ];

    for (let i = 0; i < prompts.length; i++) {
      const p = prompts[i];
      console.log('Sending prompt:', p);
      // Try to focus input by clicking center (works for initial prompt)
      try {
        const handle = await findVisibleInput();
        if (handle) {
          const asElement = handle.asElement();
          if (asElement) {
            await asElement.focus();
            await page.evaluate((text) => {
              const el = document.activeElement;
              if (el) {
                if (el.tagName === 'INPUT' || el.tagName === 'TEXTAREA') {
                  el.value = text;
                  el.dispatchEvent(new Event('input', { bubbles: true }));
                } else if (el.isContentEditable) {
                  el.innerText = text;
                }
              }
            }, p);
            // Press Enter
            await page.keyboard.press('Enter');
          } else {
            // fallback: click center and type
            await page.mouse.click(600, 300);
            await page.keyboard.type(p);
            await page.keyboard.press('Enter');
          }
        } else {
          // fallback: click center and type
          await page.mouse.click(600, 300);
          await page.keyboard.type(p);
          await page.keyboard.press('Enter');
        }
      } catch (err) {
        console.log('Error interacting with input:', err);
      }

      // wait for some time to allow assistant to respond (streaming)
      const waitMs = 8000 + i * 2000; // progressively longer for later prompts
  console.log(`Waiting ${waitMs}ms for response to render...`);
  await new Promise((res) => setTimeout(res, waitMs));

      const filename = path.join(outDir, `prompt_${i + 1}.png`);
      await page.screenshot({ path: filename, fullPage: true });
      console.log('Saved screenshot to', filename);
    }

    console.log('Screenshots complete');
  } finally {
    await browser.close();
  }
})();
