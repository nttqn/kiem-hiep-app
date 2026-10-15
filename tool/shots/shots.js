// Screenshots of the dev entry. NODE_PATH must point at a Playwright install.
// node shots.js [onlyName]
const { chromium } = require('playwright');
const shots = [
  ['title', 'screen=title', 3000],
  ['create', 'screen=create', 3000],
  ['town', 'screen=town&level=12&sect=3', 3000],
  ['play1', 'screen=play&level=3&sect=0', 9000],
  ['play_moc', 'screen=play&level=12&sect=1&map=truclam', 12000],
  ['play_thuy', 'screen=play&level=22&sect=2&map=hacphong', 12000],
  ['play_hoa', 'screen=play&level=30&sect=3&map=hoangsa', 12000],
  ['play_tho', 'screen=play&level=40&sect=4&map=bangnguyen', 12000],
  ['play_volcano', 'screen=play&level=50&sect=3&map=hoadiem&female=1', 12000],
  ['play_fortress', 'screen=play&level=62&sect=0&map=magiao', 12000],
  ['dungeon', 'screen=dungeon&level=10&sect=4&d=a2', 14000],
  ['char', 'screen=char&level=20&sect=2&female=1', 2500],
  ['skills', 'screen=skills&level=30&sect=3', 2500],
  ['bag', 'screen=bag&level=25&sect=1', 2500],
  ['shop', 'screen=shop&level=25&sect=1', 2500],
  ['quests', 'screen=quests&level=9&sect=0&quest=6', 2500],
  ['maps', 'screen=maps&level=20&sect=0', 2500],
  ['dungeons', 'screen=dungeons&level=20&sect=0', 2500],
];
(async () => {
  const only = process.argv[2];
  const browser = await chromium.launch();
  const ctx = await browser.newContext({ viewport: { width: 844, height: 390 }, deviceScaleFactor: 2 });
  for (const [name, q, wait] of shots) {
    if (only && !name.startsWith(only)) continue;
    const page = await ctx.newPage();
    const errors = [];
    page.on('pageerror', (e) => errors.push(String(e)));
    page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
    await page.goto(`http://localhost:8765/?${q}`);
    await page.waitForTimeout(wait);
    await page.screenshot({ path: `build/shots/${name}.png` });
    console.log(name, errors.length ? 'ERRORS: ' + errors.slice(0, 3).join(' | ') : 'ok');
    await page.close();
  }
  await browser.close();
})();
