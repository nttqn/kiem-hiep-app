// Records gameplay scenes at 1920x1080 (game slowed SLOW x, frame times
// divided back) and logs sound cues. node capture.js <outDir> <scene|all>
const fs = require('fs');
const path = require('path');
const { chromium } = require('playwright');

const SLOW = 6;
const scenes = {
  a_fire: 'screen=play&level=90&sect=3&cs=3&map=hoason&ult=1&pet=dragon&pets=all',
  b_ice: 'screen=play&level=85&sect=2&cs=3&map=vanvu&pet=fox&pets=all&female=1',
  c_kim: 'screen=play&level=80&sect=0&cs=2&map=hoadiem&pet=tiger',
  d_mount: 'screen=play&level=88&sect=4&cs=3&map=vanvu&skin=phikiem_hoa&pet=kylin',
  e_mount2: 'screen=play&level=70&sect=1&cs=2&map=hoason&skin=kylan_lam&female=1',
  f_wboss: 'screen=wboss&level=88&sect=1&cs=2&ult=1&pet=dragon&pets=all&female=1',
};
const SECS = 10;

(async () => {
  const [out, which] = process.argv.slice(2);
  const browser = await chromium.launch({ args: ['--force-device-scale-factor=2'] });
  const ctx = await browser.newContext({ viewport: { width: 960, height: 540 }, deviceScaleFactor: 2 });
  for (const [name, q] of Object.entries(scenes)) {
    if (which !== 'all' && which !== name) continue;
    const dir = path.join(out, name);
    fs.rmSync(dir, { recursive: true, force: true });
    fs.mkdirSync(dir, { recursive: true });
    const page = await ctx.newPage();
    let recording = false;
    let t0 = 0;
    const sfx = [];
    page.on('console', (m) => {
      const t = m.text();
      if (recording && t.startsWith('SFX ')) sfx.push({ t: (Date.now() - t0) / 1000 / SLOW, cue: t.slice(4).trim() });
    });
    await page.goto(`http://localhost:8765/?${q}&slow=${SLOW}&hud=0&sfx=1&nocache=${Date.now()}`);
    await page.waitForTimeout(4200 + 200 * SLOW);
    const cdp = await ctx.newCDPSession(page);
    await cdp.send('Emulation.setDeviceMetricsOverride', { width: 960, height: 540, deviceScaleFactor: 2, mobile: false });
    const frames = [];
    cdp.on('Page.screencastFrame', async (f) => {
      const now = Date.now();
      if (!recording) { recording = true; t0 = now; }
      frames.push({ t: now, data: f.data });
      try { await cdp.send('Page.screencastFrameAck', { sessionId: f.sessionId }); } catch (_) {}
    });
    await cdp.send('Page.startScreencast', { format: 'jpeg', quality: 92, maxWidth: 1920, maxHeight: 1080 });
    await page.waitForTimeout(SECS * 1000 * SLOW);
    await cdp.send('Page.stopScreencast');
    recording = false;
    let list = 'ffconcat version 1.0\n';
    frames.forEach((f, i) => {
      const file = `f${String(i).padStart(5, '0')}.jpg`;
      fs.writeFileSync(path.join(dir, file), Buffer.from(f.data, 'base64'));
      const next = frames[i + 1];
      list += `file ${file}\nduration ${(((next ? next.t - f.t : 33) / 1000) / SLOW).toFixed(4)}\n`;
    });
    fs.writeFileSync(path.join(dir, 'list.txt'), list);
    fs.writeFileSync(path.join(dir, 'sfx.json'), JSON.stringify(sfx));
    const span = (frames[frames.length - 1].t - frames[0].t) / 1000 / SLOW;
    console.log(name, frames.length, 'frames,', (frames.length / span).toFixed(1), 'fps,', sfx.length, 'sound cues');
    await page.close();
  }
  await browser.close();
})();
