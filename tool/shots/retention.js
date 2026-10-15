// Screenshots of the retention screens. NODE_PATH -> Playwright; dev build on :8765.
const { chromium } = require('playwright');
(async () => {
  const b = await chromium.launch();
  const ctx = await b.newContext({ viewport: { width: 844, height: 390 }, deviceScaleFactor: 2 });
  const shoot = async (name, q, wait, after) => {
    const p = await ctx.newPage();
    await p.goto(`http://localhost:8765/?${q}&nocache=${Date.now()}`);
    await p.waitForTimeout(wait);
    if (after) await after(p);
    await p.screenshot({ path: `build/shots/${name}.png` });
    await p.close();
    console.log(name);
  };
  await shoot('ret_offline', 'screen=town&level=30&sect=3&away=300', 3000);
  await shoot('ret_gift', 'screen=town&level=30&sect=3', 3000);
  await shoot('ret_ach', 'screen=ach&level=35&sect=2&female=1', 2500);
  await b.close();
})();
