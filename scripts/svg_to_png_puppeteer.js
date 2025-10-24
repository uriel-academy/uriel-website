#!/usr/bin/env node
const puppeteer = require('puppeteer');
const path = require('path');
const fs = require('fs');

async function svgToPng() {
  const svgPath = path.resolve(process.cwd(), 'assets', 'bece_ict', 'bece_ict_2024_q_38.svg');
  const outPath = path.resolve(process.cwd(), 'assets', 'bece_ict', 'bece_ict_2024_q_38.png');

  if (!fs.existsSync(svgPath)) {
    console.error('SVG not found at', svgPath);
    process.exit(1);
  }

  console.log('Rendering SVG to PNG:', svgPath);

  const browser = await puppeteer.launch({ args: ['--no-sandbox', '--disable-setuid-sandbox'] });
  try {
    const page = await browser.newPage();
    // Large viewport for higher-resolution rasterization
    await page.setViewport({ width: 1400, height: 1000, deviceScaleFactor: 2 });

    const fileUrl = 'file://' + svgPath;
    await page.goto(fileUrl, { waitUntil: 'networkidle0' });

    // Wait for <svg> element
    await page.waitForSelector('svg', { timeout: 2000 }).catch(() => {});

    const svgHandle = await page.$('svg');
    if (svgHandle) {
      // Screenshot the element to a PNG file
      await svgHandle.screenshot({ path: outPath });
      console.log('Saved PNG to', outPath);
    } else {
      // Fallback: screenshot full page
      await page.screenshot({ path: outPath, fullPage: true });
      console.log('Saved full-page PNG to', outPath);
    }
  } finally {
    await browser.close();
  }
}

svgToPng().catch(e => { console.error(e); process.exit(1); });
