// Store screenshots for every Play Store and App Store size, landscape,
// from the dev entry. NODE_PATH must point at a Playwright install; the dev
// build must be served on :8765.
//   node store_shots.js [deviceName] [shotPrefix]
// LANG_SHOT=zh_Hant shoots that language into store/<LANG>/<device>/; PORT overrides 8765.
const fs = require('fs');
const { chromium } = require('playwright');

// Logical viewport x device scale = the pixel size each store asks for.
const devices = [
  ['phone', 960, 540, 2], // Play phone 1920x1080
  ['tablet-7in', 960, 600, 2], // Play 7" tablet 1920x1200
  ['tablet-10in', 1280, 800, 2], // Play 10" tablet 2560x1600
  ['iphone-6.9in', 956, 440, 3], // App Store 6.9" iPhone 2868x1320
  ['iphone-6.3in', 874, 402, 3], // App Store 6.1"/6.3" iPhone (Dynamic Island) 2622x1206
  // 13" iPad 2752x2064, drawn larger than the device's 1376x1032 points:
  // at true size the panels sat mostly empty with tiny text.
  ['ipad-13in', 1032, 774, 8 / 3],
];

const shots = [
  ['01-hoa-son', 'screen=play&level=92&sect=3&cs=3&map=hoason&pet=dragon&pets=all', 11000],
  ['02-van-vu-son', 'screen=play&level=78&sect=2&female=1&map=vanvu&pet=fox&pets=all', 8000],
  ['03-vuot-ai', 'screen=dungeon&level=76&sect=4&cs=1&d=a15&pet=kylin&pets=all', 13000],
  ['04-kiem-trung', 'screen=dungeon&level=92&sect=1&cs=5&d=a17&pet=dragon&pets=all', 13000],
  ['05-chon-phai', 'screen=create', 3000],
  ['06-hiep-khach', 'screen=comp&level=80&sect=1&comp=all', 3500],
  ['07-boss-the-gioi', 'screen=boss&level=90&sect=1&cs=3', 9000],
  ['08-thu-cuoi', 'screen=mounts&level=90&sect=3&mount=all', 3500],
  ['09-tui-do', 'screen=items&level=60&sect=1&herbs=12&tbdmaps=3&dao=5', 3500],
  ['10-loi-dai', 'screen=arena&level=99&sect=4&cs=6', 5000],
];

const lang = process.env.LANG_SHOT || "";
const port = process.env.PORT || 8765;
const outRoot = lang ? `store/${lang}` : "store";

(async () => {
  const onlyDevice = process.argv[2];
  const onlyShot = process.argv[3];
  // CHROME=<chrome.exe> when the installed Playwright has no matching browser.
  const browser = await chromium.launch(process.env.CHROME ? { executablePath: process.env.CHROME } : {});
  for (const [dev, w, h, dpr] of devices) {
    if (onlyDevice && dev !== onlyDevice) continue;
    fs.mkdirSync(`${outRoot}/${dev}`, { recursive: true });
    const ctx = await browser.newContext({ viewport: { width: w, height: h }, deviceScaleFactor: dpr });
    for (const [name, q, wait] of shots) {
      if (onlyShot && !name.startsWith(onlyShot)) continue;
      const page = await ctx.newPage();
      await page.goto(`http://localhost:${port}/?${q}${lang ? `&lang=${lang}` : ""}&nocache=${Date.now()}`);
      await page.waitForTimeout(wait);
      await page.screenshot({ path: `${outRoot}/${dev}/${name}.png` });
      await page.close();
    }
    await ctx.close();
    console.log(dev, `${w * dpr}x${h * dpr}`);
  }
  await browser.close();
})();
