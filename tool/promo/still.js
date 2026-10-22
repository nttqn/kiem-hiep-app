const { chromium } = require('playwright');
(async () => {
  const browser = await chromium.launch();
  const ctx = await browser.newContext({ viewport: { width: 960, height: 540 }, deviceScaleFactor: 2 });
  const page = await ctx.newPage();
  await page.goto('http://localhost:8765/?screen=rank&level=92&sect=3&cs=2&lb=1&tower=71');
  await page.waitForTimeout(3500);
  await page.screenshot({ path: 'stills/4.png' });
  await browser.close();
})();
