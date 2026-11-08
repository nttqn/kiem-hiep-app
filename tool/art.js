// Turns the ChatGPT pictures in art_in/ into game assets in assets/art/.
// Backgrounds: 1600 wide WebP. Portraits: 720 tall WebP with the soft
// coloured fringe on the transparent edge trimmed away.
const sharp = require('sharp');
const path = require('path');
const fs = require('fs');
const root = process.argv[2];
const inDir = path.join(root, 'art_in'), out = path.join(root, 'assets', 'art');
const preview = process.argv[3];
fs.mkdirSync(out, { recursive: true });

async function bg(name) {
  await sharp(path.join(inDir, name + '.png')).resize({ width: 1600 }).webp({ quality: 80 }).toFile(path.join(out, name + '.webp'));
}

async function portrait(name) {
  const { data, info } = await sharp(path.join(inDir, name + '.png')).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
  const lo = 110, hi = 235;
  for (let i = 0; i < data.length; i += 4) {
    const a = data[i + 3];
    data[i + 3] = a <= lo ? 0 : a >= hi ? 255 : Math.round((a - lo) * 255 / (hi - lo));
  }
  const img = sharp(data, { raw: info }).trim({ threshold: 1 }).resize({ height: 720 });
  await img.clone().webp({ quality: 85, alphaQuality: 90 }).toFile(path.join(out, name + '.webp'));
  if (preview) {
    const buf = await img.clone().png().toBuffer();
    const m = await sharp(buf).metadata();
    await sharp({ create: { width: m.width + 40, height: m.height + 40, channels: 4, background: '#2a1a14' } })
      .composite([{ input: buf, left: 20, top: 20 }]).png().toFile(path.join(preview, 'pv_' + name + '.png'));
  }
}

(async () => {
  for (const b of ['title', 'town']) await bg(b);
  for (const p of ['tueminh', 'lamdiep', 'thanhvan', 'macliet', 'truongphong']) await portrait(p);
  for (const f of fs.readdirSync(out)) console.log(f, fs.statSync(path.join(out, f)).size);
})();
