// Cuts the ChatGPT icon sheets in art_in/ (five icons in a row on a
// transparent background) into assets/art/icons/<name>.webp, 128 square.
// Needs sharp: node tool/icons.js <project root> [preview dir]
const sharp = require('sharp');
const path = require('path');
const fs = require('fs');
const root = process.argv[2];
const preview = process.argv[3];
const inDir = path.join(root, 'art_in'), out = path.join(root, 'assets', 'art', 'icons');
fs.mkdirSync(out, { recursive: true });

const tiers = (p) => [1, 2, 3, 4, 5].map((i) => `${p}_${i}`);
const sheets = {
  w_con: tiers('w_con'), w_phitieu: tiers('w_phitieu'), w_kiem: tiers('w_kiem'), w_dao: tiers('w_dao'),
  w_truongkiem: tiers('w_truongkiem'), hat: tiers('hat'), armor: tiers('armor'), belt: tiers('belt'),
  boots: tiers('boots'), amulet: tiers('amulet'), ring: tiers('ring'),
  gems: ['gem_kim', 'gem_moc', 'gem_thuy', 'gem_hoa', 'gem_tho'],
  mats: ['mat_stone', 'mat_iron', 'mat_shard', 'mat_soul', 'mat_soulpill'],
  pills: ['pill_songboi', 'pill_tubao', 'pill_cuongluc', 'pill_kimcang', 'pill_taytuy'],
  // Single icons.
  pill_hoixuan: ['pill_hoixuan'],
};

async function cut(sheet, names) {
  const { data, info } = await sharp(path.join(inDir, sheet + '.png')).ensureAlpha().raw().toBuffer({ resolveWithObject: true });
  const { width: w, height: h } = info;
  // Some sheets come with a painted "transparent" checkerboard instead of
  // real transparency: clear the pale grey/white reaching in from the edges
  // (the items' own whites are closed in by their dark outline).
  const opaque = [0, w - 1, (h - 1) * w, h * w - 1].every((i) => data[i * 4 + 3] > 250);
  if (opaque) {
    const pale = (i) => {
      const r = data[i * 4], g = data[i * 4 + 1], b = data[i * 4 + 2];
      return Math.min(r, g, b) > 205 && Math.max(r, g, b) - Math.min(r, g, b) < 24;
    };
    const seen = new Uint8Array(w * h), st = [];
    for (let x = 0; x < w; x++) st.push(x, (h - 1) * w + x);
    for (let y = 0; y < h; y++) st.push(y * w, y * w + w - 1);
    while (st.length) {
      const i = st.pop();
      if (seen[i] || !pale(i)) continue;
      seen[i] = 1;
      data[i * 4 + 3] = 0;
      const x = i % w, y = (i / w) | 0;
      if (x > 0) st.push(i - 1);
      if (x < w - 1) st.push(i + 1);
      if (y > 0) st.push(i - w);
      if (y < h - 1) st.push(i + w);
    }
  }
  // The same fringe trim as the portraits.
  for (let i = 3; i < data.length; i += 4) {
    const a = data[i];
    data[i] = a <= 110 ? 0 : a >= 235 ? 255 : Math.round((a - 110) * 255 / 125);
  }
  // Blobs on a third-size mask; the biggest [names.length] are the icons,
  // every smaller blob goes to the nearest of them. First every solid
  // pixel (icons on real transparency never touch); if that leaves fewer
  // real icons (a solid glow joins two), only the dark outlines, which a
  // glow does not have.
  const k = 3, mw = Math.ceil(w / k), mh = Math.ceil(h / k);
  const solid = (o) => data[o + 3] > 200;
  const dark = (o) => data[o + 3] > 200 && data[o] + data[o + 1] + data[o + 2] < 330;
  function blobsOf(pred) {
    const mask = new Uint8Array(mw * mh);
    for (let y = 0; y < h; y++) {
      for (let x = 0; x < w; x++) {
        if (pred((y * w + x) * 4)) mask[((y / k) | 0) * mw + ((x / k) | 0)] = 1;
      }
    }
    const label = new Int32Array(mw * mh).fill(-1);
    const blobs = [];
    for (let i = 0; i < mw * mh; i++) {
      if (!mask[i] || label[i] >= 0) continue;
      const id = blobs.length, st = [i];
      const bl = { n: 0, x0: mw, y0: mh, x1: 0, y1: 0, sx: 0, sy: 0 };
      label[i] = id;
      while (st.length) {
        const j = st.pop(), x = j % mw, y = (j / mw) | 0;
        bl.n++; bl.sx += x; bl.sy += y;
        bl.x0 = Math.min(bl.x0, x); bl.x1 = Math.max(bl.x1, x); bl.y0 = Math.min(bl.y0, y); bl.y1 = Math.max(bl.y1, y);
        for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
          const xx = x + dx, yy = y + dy;
          if (xx < 0 || yy < 0 || xx >= mw || yy >= mh) continue;
          const q = yy * mw + xx;
          if (mask[q] && label[q] < 0) { label[q] = id; st.push(q); }
        }
      }
      blobs.push(bl);
    }
    const sizes = blobs.map((bl) => bl.n).sort((p, q) => q - p);
    const ok = sizes.length >= names.length && sizes[names.length - 1] >= sizes[0] * 0.2;
    return { label, blobs, ok };
  }
  let found = blobsOf(solid);
  if (!found.ok) found = blobsOf(dark);
  const { label, blobs } = found;
  if (!found.ok) throw new Error(`${sheet}: could not find ${names.length} icons`);
  const big = [...blobs].sort((p, q) => q.n - p.n).slice(0, names.length);
  for (const bl of blobs) {
    if (big.includes(bl)) { bl.owner = bl; continue; }
    const cx = bl.sx / bl.n, cy = bl.sy / bl.n;
    let best = big[0], bd = Infinity;
    for (const g of big) {
      const d = (g.sx / g.n - cx) ** 2 + (g.sy / g.n - cy) ** 2;
      if (d < bd) { bd = d; best = g; }
    }
    bl.owner = best;
    best.x0 = Math.min(best.x0, bl.x0); best.x1 = Math.max(best.x1, bl.x1);
    best.y0 = Math.min(best.y0, bl.y0); best.y1 = Math.max(best.y1, bl.y1);
  }
  big.sort((p, q) => p.sx / p.n - q.sx / q.n);
  // Every visible cell belongs to the icon whose outline it reaches first
  // (a breadth-first flood from all outlines at once): bright blades,
  // tassels and glows go with their own item, never a neighbour's.
  const any = new Uint8Array(mw * mh);
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w; x++) {
      if (data[(y * w + x) * 4 + 3] > 40) any[((y / k) | 0) * mw + ((x / k) | 0)] = 1;
    }
  }
  const own = new Int8Array(mw * mh).fill(-1);
  let queue = [];
  for (let c = 0; c < mw * mh; c++) {
    if (label[c] >= 0) {
      own[c] = big.indexOf(blobs[label[c]].owner);
      queue.push(c);
    }
  }
  while (queue.length) {
    const next = [];
    for (const c of queue) {
      const x = c % mw, y = (c / mw) | 0;
      for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
        const xx = x + dx, yy = y + dy;
        if (xx < 0 || yy < 0 || xx >= mw || yy >= mh) continue;
        const q = yy * mw + xx;
        if (any[q] && own[q] < 0) { own[q] = own[c]; next.push(q); }
      }
    }
    queue = next;
  }
  // Drop stray islands (a neighbour's blade tip): keep only an icon's
  // pieces at least a twentieth of its biggest.
  const seen = new Uint8Array(mw * mh);
  const parts = big.map(() => []);
  for (let c = 0; c < mw * mh; c++) {
    if (own[c] < 0 || seen[c]) continue;
    const i = own[c], cells = [c], st = [c];
    seen[c] = 1;
    while (st.length) {
      const j = st.pop(), x = j % mw, y = (j / mw) | 0;
      for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
        const xx = x + dx, yy = y + dy;
        if (xx < 0 || yy < 0 || xx >= mw || yy >= mh) continue;
        const q = yy * mw + xx;
        if (!seen[q] && own[q] === i) { seen[q] = 1; cells.push(q); st.push(q); }
      }
    }
    parts[i].push(cells);
  }
  for (const ps of parts) {
    const top = Math.max(...ps.map((p) => p.length));
    for (const p of ps) if (p.length < top / 20) for (const c of p) own[c] = -1;
  }
  const boxes = big.map(() => [w, h, 0, 0]);
  for (let c = 0; c < mw * mh; c++) {
    const i = own[c];
    if (i < 0) continue;
    const x = (c % mw) * k, y = ((c / mw) | 0) * k, b = boxes[i];
    b[0] = Math.min(b[0], x); b[1] = Math.min(b[1], y);
    b[2] = Math.min(w - 1, Math.max(b[2], x + k - 1)); b[3] = Math.min(h - 1, Math.max(b[3], y + k - 1));
  }
  const outs = [];
  for (let i = 0; i < boxes.length; i++) {
    const [x0, y0, x1, y1] = boxes[i];
    const bw = x1 - x0 + 1, bh = y1 - y0 + 1;
    const px = Buffer.alloc(bw * bh * 4);
    for (let y = y0; y <= y1; y++) {
      for (let x = x0; x <= x1; x++) {
        if (own[((y / k) | 0) * mw + ((x / k) | 0)] !== i) continue;
        const s = (y * w + x) * 4, t = ((y - y0) * bw + (x - x0)) * 4;
        data.copy(px, t, s, s + 4);
      }
    }
    const piece = await sharp(px, { raw: { width: bw, height: bh, channels: 4 } }).png().toBuffer();
    const icon = sharp(piece).resize(116, 116, { fit: 'contain', background: { r: 0, g: 0, b: 0, alpha: 0 } })
      .extend({ top: 6, bottom: 6, left: 6, right: 6, background: { r: 0, g: 0, b: 0, alpha: 0 } });
    const buf = await icon.png().toBuffer();
    await sharp(buf).webp({ quality: 88, alphaQuality: 95 }).toFile(path.join(out, names[i] + '.webp'));
    outs.push(buf);
  }
  return outs;
}

(async () => {
  const rows = [];
  for (const [sheet, names] of Object.entries(sheets)) {
    if (!fs.existsSync(path.join(inDir, sheet + '.png'))) { console.log('missing', sheet); continue; }
    rows.push(await cut(sheet, names));
    console.log(sheet, 'ok');
  }
  if (preview) {
    const comps = [];
    rows.forEach((r, y) => r.forEach((b, x) => comps.push({ input: b, left: x * 136 + 4, top: y * 136 + 4 })));
    await sharp({ create: { width: 5 * 136 + 4, height: rows.length * 136 + 4, channels: 4, background: '#2a1a14' } })
      .composite(comps).png().toFile(path.join(preview, 'icons_sheet.png'));
  }
})().catch((e) => { console.error(e.message); process.exit(1); });
