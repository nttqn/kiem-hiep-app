const { chromium } = require('playwright');
(async () => {
  const browser = await chromium.launch();
  const ctx = await browser.newContext({ viewport: { width: 960, height: 540 }, deviceScaleFactor: 2 });
  for (const [name, q] of [['refine', 'screen=refine&level=85&sect=3&seed=7'], ['rank', 'screen=rank&level=92&sect=3&cs=2&lb=1&tower=71']]) {
    const page = await ctx.newPage();
    await page.goto(`http://localhost:8765/?${q}`);
    await page.waitForTimeout(5000);
    await page.screenshot({ path: `stills/${name}.png` });
    await page.close();
  }
  await browser.close();
})();
