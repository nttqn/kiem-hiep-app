// Turns the ChatGPT pictures in art_in/ into game assets in assets/art/.
// Backgrounds (title, town): 1600 wide WebP. Everything else is a portrait
// on a transparent background: the soft coloured fringe on its edge is
// trimmed, then 720 tall (hiệp khách) or 600 tall (bosses) WebP.
// Needs sharp: node tool/art.js <project root> [preview dir]
const sharp = require('sharp');
const path = require('path');
const fs = require('fs');
const root = process.argv[2];
const preview = process.argv[3];
const inDir = path.join(root, 'art_in'), out = path.join(root, 'assets', 'art');
fs.mkdirSync(out, { recursive: true });

const backgrounds = ['title', 'town'];
const companions = ['tueminh', 'lamdiep', 'thanhvan', 'macliet', 'truongphong'];

async function bg(name) {
  await sharp(path.join(inDir, name + '.png')).resize({ width: 1600 }).webp({ quality: 80 }).toFile(path.join(out, name + '.webp'));
}

// Region vignettes for the map lists: 256 square, opaque.
async function mapTile(name) {
  await sharp(path.join(inDir, name + '.png')).resize(256, 256).webp({ quality: 82 }).toFile(path.join(out, name + '.webp'));
}

async function portrait(name, height) {
  const { data, info } = await sharp(path.join(inDir, name + '.png')).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
  const lo = 110, hi = 235;
  for (let i = 0; i < data.length; i += 4) {
    const a = data[i + 3];
    data[i + 3] = a <= lo ? 0 : a >= hi ? 255 : Math.round((a - lo) * 255 / (hi - lo));
  }
  const img = sharp(data, { raw: info }).trim({ threshold: 1 }).resize({ height });
  await img.clone().webp({ quality: 85, alphaQuality: 90 }).toFile(path.join(out, name + '.webp'));
  if (preview) {
    const buf = await img.clone().png().toBuffer();
    const m = await sharp(buf).metadata();
    await sharp({ create: { width: m.width + 40, height: m.height + 40, channels: 4, background: '#2a1a14' } })
      .composite([{ input: buf, left: 20, top: 20 }]).png().toFile(path.join(preview, 'pv_' + name + '.png'));
  }
}

(async () => {
  const only = process.argv[4];
  for (const f of fs.readdirSync(inDir)) {
    if (!f.endsWith('.png')) continue;
    const name = f.slice(0, -4);
    if (only && !only.split(',').includes(name)) continue;
    if (backgrounds.includes(name)) await bg(name);
    else if (name.startsWith('map_')) await mapTile(name);
    else await portrait(name, companions.includes(name) || name.startsWith('sect_') ? 720 : 600);
    console.log(name, fs.statSync(path.join(out, name + '.webp')).size);
  }
})();
