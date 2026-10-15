// Play Store screenshots, 1920x1080, from the dev entry.
// NODE_PATH must point at a Playwright install; the dev build must be
// served on :8765. node store_shots.js [onlyPrefix]
const { chromium } = require('playwright');
const shots = [
  ['01-chien-dau', 'screen=play&level=30&sect=3&map=hoangsa', 11000],
  ['02-hang-dong', 'screen=play&level=22&sect=2&female=1&map=hacphong', 11000],
  ['03-vuot-ai', 'screen=dungeon&level=12&sect=4&d=a3', 13000],
  ['04-nui-lua', 'screen=play&level=50&sect=0&map=hoadiem', 11000],
  ['05-chon-phai', 'screen=create', 3000],
  ['06-thanh', 'screen=town&level=25&sect=3&female=1&quest=8', 3000],
  ['07-ky-nang', 'screen=skills&level=40&sect=2&female=1', 2500],
  ['08-hanh-trang', 'screen=bag&level=35&sect=1', 2500],
];
(async () => {
  const only = process.argv[2];
  const browser = await chromium.launch();
  const ctx = await browser.newContext({ viewport: { width: 960, height: 540 }, deviceScaleFactor: 2 });
  for (const [name, q, wait] of shots) {
    if (only && !name.startsWith(only)) continue;
    const page = await ctx.newPage();
    await page.goto(`http://localhost:8765/?${q}&nocache=${Date.now()}`);
    await page.waitForTimeout(wait);
    await page.screenshot({ path: `store/phone/${name}.png` });
    console.log(name);
    await page.close();
  }
  await browser.close();
})();
