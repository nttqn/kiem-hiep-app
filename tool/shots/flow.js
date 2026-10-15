// Walks the real build: title -> create -> town -> quest -> play -> pause -> town.
const { chromium } = require('playwright');
(async () => {
  const browser = await chromium.launch();
  const ctx = await browser.newContext({ viewport: { width: 844, height: 390 }, deviceScaleFactor: 2 });
  const page = await ctx.newPage();
  const errors = [];
  page.on('pageerror', (e) => errors.push(String(e)));
  page.on('console', (m) => { if (m.type() === 'error') errors.push(m.text()); });
  const shot = async (n) => { await page.screenshot({ path: `build/shots/flow_${n}.png` }); console.log('shot', n); };
  const steps = JSON.parse(process.argv[2]);
  await page.goto('http://localhost:8766/');
  await page.waitForTimeout(3500);
  for (const s of steps) {
    if (s.click) await page.mouse.click(s.click[0], s.click[1]);
    if (s.key) await page.keyboard.press(s.key);
    if (s.hold) { await page.keyboard.down(s.hold[0]); await page.waitForTimeout(s.hold[1]); await page.keyboard.up(s.hold[0]); }
    await page.waitForTimeout(s.wait || 1200);
    if (s.shot) await shot(s.shot);
  }
  console.log(errors.length ? 'ERRORS: ' + errors.slice(0, 5).join(' | ') : 'no errors');
  await browser.close();
})();
