const { chromium } = require('playwright');
(async () => {
  const browser = await chromium.launch();
  const ctx = await browser.newContext({ viewport: { width: 960, height: 540 }, deviceScaleFactor: 2 });
  for (const [name, q] of [
    ['body', 'screen=body&level=95&sect=3&cs=6&body=22,24,20,21,23&iron=500&gold=50000000&pills=100'],
    ['skins', 'screen=skins&skinof=phikiem&level=90&sect=4&cs=3&mount=all&iron=500&tower=140'],
    ['skins2', 'screen=skins&skinof=bachho&level=80&sect=2&cs=2&mount=all&arena=30000'],
  ]) {
    const page = await ctx.newPage();
    await page.goto(`http://localhost:8765/?${q}&nocache=${Date.now()}`);
    await page.waitForTimeout(6000);
    await page.screenshot({ path: `stills/${name}.png` });
    await page.close();
  }
  await browser.close();
})();
