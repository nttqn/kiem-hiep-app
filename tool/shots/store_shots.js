// Store screenshots for every Play Store and App Store size, landscape,
// from the dev entry. NODE_PATH must point at a Playwright install; the dev
// build must be served on :8765.
//   node store_shots.js [deviceName] [shotPrefix]
const fs = require('fs');
const { chromium } = require('playwright');

// Logical viewport x device scale = the pixel size each store asks for.
const devices = [
  ['phone', 960, 540, 2], // Play phone 1920x1080
  ['tablet-7in', 960, 600, 2], // Play 7" tablet 1920x1200
  ['tablet-10in', 1280, 800, 2], // Play 10" tablet 2560x1600
  ['iphone-6.9in', 956, 440, 3], // App Store 6.9" iPhone 2868x1320
  ['ipad-13in', 1376, 1032, 2], // App Store 13" iPad 2752x2064
];

const shots = [
  ['01-chien-dau', 'screen=play&level=30&sect=3&map=hoangsa', 11000],
  ['02-hang-dong', 'screen=play&level=22&sect=2&female=1&map=hacphong', 11000],
  ['03-vuot-ai', 'screen=dungeon&level=12&sect=4&d=a3', 13000],
  ['04-nui-lua', 'screen=play&level=50&sect=0&map=hoadiem', 11000],
  ['05-chon-phai', 'screen=create', 3000],
  ['06-qua-dang-nhap', 'screen=town&level=25&sect=3&female=1', 3500],
  ['07-thanh-tuu', 'screen=ach&level=35&sect=2&female=1', 2500],
  ['08-ky-nang', 'screen=skills&level=40&sect=2&female=1', 2500],
];

(async () => {
  const onlyDevice = process.argv[2];
  const onlyShot = process.argv[3];
  const browser = await chromium.launch();
  for (const [dev, w, h, dpr] of devices) {
    if (onlyDevice && dev !== onlyDevice) continue;
    fs.mkdirSync(`store/${dev}`, { recursive: true });
    const ctx = await browser.newContext({ viewport: { width: w, height: h }, deviceScaleFactor: dpr });
    for (const [name, q, wait] of shots) {
      if (onlyShot && !name.startsWith(onlyShot)) continue;
      const page = await ctx.newPage();
      await page.goto(`http://localhost:8765/?${q}&nocache=${Date.now()}`);
      await page.waitForTimeout(wait);
      await page.screenshot({ path: `store/${dev}/${name}.png` });
      await page.close();
    }
    await ctx.close();
    console.log(dev, `${w * dpr}x${h * dpr}`);
  }
  await browser.close();
})();
