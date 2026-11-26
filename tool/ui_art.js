// Battle ground textures and UI frames from the ChatGPT pictures in art_in/
// (tool/art_prompts.md §2 and §4).
//   ground_<theme>.png -> assets/art/ground/<theme>.webp, 768 square, with a
//     seam report: how much the wrap edge differs next to a normal step.
//   ui_panel.png, ui_title_bar.png -> assets/art/ui/panel.webp, title_bar.webp
//   ui_buttons.png (3 in a row) -> ui/btn_primary|secondary|disabled.webp
//   ui_slots.png (5 in a row)   -> ui/slot_0..4.webp
// Needs sharp: node tool/ui_art.js <project root>
const sharp = require('sharp');
const path = require('path');
const fs = require('fs');
const root = process.argv[2];
const inDir = path.join(root, 'art_in');
const out = path.join(root, 'assets', 'art');
fs.mkdirSync(path.join(out, 'ground'), { recursive: true });
fs.mkdirSync(path.join(out, 'ui'), { recursive: true });

// Mean colour step across the wrap edge vs across an ordinary column/row.
async function seam(file) {
  const { data, info } = await sharp(file).removeAlpha().raw().toBuffer({ resolveWithObject: true });
  const { width: w, height: h } = info;
  const px = (x, y, c) => data[(y * w + x) * 3 + c];
  const colStep = (a, b) => {
    let s = 0;
    for (let y = 0; y < h; y++) for (let c = 0; c < 3; c++) s += Math.abs(px(a, y, c) - px(b, y, c));
    return s / (h * 3);
  };
  const rowStep = (a, b) => {
    let s = 0;
    for (let x = 0; x < w; x++) for (let c = 0; c < 3; c++) s += Math.abs(px(x, a, c) - px(x, b, c));
    return s / (w * 3);
  };
  let inner = 0;
  for (let i = 1; i < 9; i++) inner += colStep(Math.floor(w * i / 9), Math.floor(w * i / 9) + 1) + rowStep(Math.floor(h * i / 9), Math.floor(h * i / 9) + 1);
  inner /= 16;
  return { x: colStep(w - 1, 0) / inner, y: rowStep(h - 1, 0) / inner };
}

// Opaque bounding boxes of the pieces in a row, left to right.
async function pieces(file, n) {
  const { data, info } = await sharp(file).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
  const { width: w, height: h } = info;
  const solid = new Uint8Array(w);
  for (let x = 0; x < w; x++) {
    let k = 0;
    for (let y = 0; y < h; y++) if (data[(y * w + x) * 4 + 3] > 128) k++;
    solid[x] = k > 2 ? 1 : 0;
  }
  let runs = [];
  for (let x = 0; x < w;) {
    if (!solid[x]) { x++; continue; }
    const s = x;
    while (x < w && solid[x]) x++;
    runs.push([s, x - 1]);
  }
  // Merge the closest runs until n remain (a glow can split one piece).
  while (runs.length > n) {
    let bi = 0, bg = Infinity;
    for (let i = 0; i + 1 < runs.length; i++) {
      const g = runs[i + 1][0] - runs[i][1];
      if (g < bg) { bg = g; bi = i; }
    }
    runs.splice(bi, 2, [runs[bi][0], runs[bi + 1][1]]);
  }
  if (runs.length !== n) throw new Error(`${file}: found ${runs.length} pieces, want ${n}`);
  return runs.map(([x0, x1]) => ({ left: x0, top: 0, width: x1 - x0 + 1, height: h }));
}

async function piece(file, box, outFile, size) {
  const buf = await sharp(file).extract(box).png().toBuffer();
  await sharp(buf).trim({ threshold: 1 }).resize(size).webp({ quality: 88, alphaQuality: 95 }).toFile(outFile);
  const m = await sharp(outFile).metadata();
  console.log(path.basename(outFile), m.width + 'x' + m.height);
}

(async () => {
  for (const f of fs.readdirSync(inDir).sort()) {
    const m = f.match(/^ground_(\w+)\.png$/);
    if (!m) continue;
    const src = path.join(inDir, f);
    const s = await seam(src);
    await sharp(src).removeAlpha().resize(768, 768).webp({ quality: 78 }).toFile(path.join(out, 'ground', m[1] + '.webp'));
    console.log(m[1].padEnd(9), 'seam x', s.x.toFixed(2), 'y', s.y.toFixed(2), s.x > 2.5 || s.y > 2.5 ? '<- visible seam?' : '');
  }
  const ui = (n) => path.join(inDir, n + '.png');
  if (fs.existsSync(ui('ui_panel'))) await piece(ui('ui_panel'), (await pieces(ui('ui_panel'), 1))[0], path.join(out, 'ui', 'panel.webp'), { width: 600 });
  if (fs.existsSync(ui('ui_title_bar'))) await piece(ui('ui_title_bar'), (await pieces(ui('ui_title_bar'), 1))[0], path.join(out, 'ui', 'title_bar.webp'), { width: 900 });
  if (fs.existsSync(ui('ui_buttons'))) {
    const names = ['btn_primary', 'btn_secondary', 'btn_disabled'];
    const boxes = await pieces(ui('ui_buttons'), 3);
    for (let i = 0; i < 3; i++) await piece(ui('ui_buttons'), boxes[i], path.join(out, 'ui', names[i] + '.webp'), { height: 96 });
  }
  if (fs.existsSync(ui('ui_slots'))) {
    const boxes = await pieces(ui('ui_slots'), 5);
    for (let i = 0; i < 5; i++) await piece(ui('ui_slots'), boxes[i], path.join(out, 'ui', `slot_${i}.webp`), { height: 160 });
  }
})().catch((e) => { console.error(e.message); process.exit(1); });
