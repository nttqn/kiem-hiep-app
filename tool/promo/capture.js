// Records game scenes from the dev web build through Chrome's screencast.
// node capture.js <outDir> [sceneName]
const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

const SLOW_DEFAULT = 4;
const scenes = [
  ['a_hoason', 'screen=play&level=90&sect=3&cs=3&map=hoason&ult=1&pet=dragon&pets=all', 7.5],
  ['b_palm', 'screen=play&level=80&sect=0&cs=1&map=vanvu&ult=1&pet=tiger', 6.5, 6],
  ['c_tower', 'screen=dungeon&level=92&sect=2&cs=2&tf=35&tower=34&ult=1&pet=fox&pets=all', 8],
  ['d_swords', 'screen=play&level=75&sect=4&map=hoadiem&ult=1&pet=kylin', 6.5],
  ['e_venom', 'screen=play&level=70&sect=1&map=bangnguyen&ult=1&pet=crane&female=1', 6],
];

(async () => {
  const out = process.argv[2];
  const only = process.argv[3];
  const browser = await chromium.launch();
  const ctx = await browser.newContext({ viewport: { width: 960, height: 540 }, deviceScaleFactor: 2 });
  for (const [name, q, secs, slow] of scenes) {
    const SLOW = slow || SLOW_DEFAULT;
    if (only && name !== only) continue;
    const dir = path.join(out, name);
    fs.rmSync(dir, { recursive: true, force: true });
    fs.mkdirSync(dir, { recursive: true });
    const page = await ctx.newPage();
    await page.goto(`http://localhost:8765/?${q}&slow=${SLOW}`);
    // Page load, then about 1.5 s of game time for the fight to start.
    await page.waitForTimeout(4200 + 1500 * SLOW);
    const cdp = await ctx.newCDPSession(page);
    const frames = [];
    cdp.on('Page.screencastFrame', async (f) => {
      frames.push({ t: f.metadata.timestamp, data: f.data });
      try { await cdp.send('Page.screencastFrameAck', { sessionId: f.sessionId }); } catch (_) {}
    });
    await cdp.send('Page.startScreencast', { format: 'jpeg', quality: 92, maxWidth: 1920, maxHeight: 1080, everyNthFrame: 1 });
    await page.waitForTimeout(secs * 1000 * SLOW);
    await cdp.send('Page.stopScreencast');
    // ffconcat list with real frame durations.
    let list = 'ffconcat version 1.0\n';
    frames.forEach((f, i) => {
      const file = `f${String(i).padStart(5, '0')}.jpg`;
      fs.writeFileSync(path.join(dir, file), Buffer.from(f.data, 'base64'));
      const next = frames[i + 1];
      const dur = (next ? next.t - f.t : 1 / 30) / SLOW;
      list += `file ${file}\nduration ${dur.toFixed(4)}\n`;
    });
    fs.writeFileSync(path.join(dir, 'list.txt'), list);
    const span = frames.length > 1 ? frames[frames.length - 1].t - frames[0].t : 0;
    console.log(name, frames.length, 'frames over', (span / SLOW).toFixed(2), 'game s =', (frames.length * SLOW / span).toFixed(1), 'fps');
    await page.close();
  }
  await browser.close();
})();
