// YouTube thumbnails (1280x720) for the English promo, cut from the captured
// clips. Run in the work folder after capture: FF=... node thumbs.js
// Writes thumb/en-thumb-<id>.png.
const fs = require('fs');
const { execFileSync } = require('child_process');

const FF = process.env.FF;
const FONT = 'fonts/BeVietnamPro-Bold.ttf';
const ICON = 'C:/Users/Hi/.gemini/antigravity/scratch/kiem-hiep-app/store/icon-512.png';

// clip, the moment (a skill cue in frames/<clip>/sfx.json plus a delay, so
// a new capture keeps the shot), crop (w:h:x:y of the 1920x1080 frame), headline, sub, text side.
const thumbs = [
  { id: 'A-tuyet-ky', clip: 'a_fire', cue: 'fireLine', after: 0.4, crop: '1280:720:440:80', big: 'ONE STRIKE', sub: 'Clear the whole field!', side: 'left' },
  { id: 'B-bang-tam', clip: 'b_ice', cue: 'iceNova', after: 0.25, crop: '1600:900:0:150', big: 'ICE STORM', sub: 'Pick 1 of 5 sects', side: 'left' },
  { id: 'C-the-gioi', clip: 'f_wboss', cue: 'venomCloud', after: 0.3, crop: '1440:810:480:120', big: 'WORLD BOSS', sub: 'Beat the whole server', side: 'right' },
];

fs.mkdirSync('thumb', { recursive: true });
for (const t of thumbs) {
  const c = JSON.parse(fs.readFileSync(`frames/${t.clip}/sfx.json`, "utf8")).find((x) => x.cue === t.cue);
  t.at = (c ? c.t : 2) + t.after;
  const bf = `thumb/${t.id}_big.txt`, sf = `thumb/${t.id}_sub.txt`;
  fs.writeFileSync(bf, t.big);
  fs.writeFileSync(sf, t.sub);
  const left = t.side === 'left';
  const x = left ? '70' : 'w-text_w-70';
  // A dark gradient behind the words so they read on any frame.
  const grad = left
    ? "geq=r='r(X,Y)*(0.35+0.65*min(1,X/620))':g='g(X,Y)*(0.35+0.65*min(1,X/620))':b='b(X,Y)*(0.35+0.65*min(1,X/620))'"
    : "geq=r='r(X,Y)*(0.35+0.65*min(1,(W-X)/620))':g='g(X,Y)*(0.35+0.65*min(1,(W-X)/620))':b='b(X,Y)*(0.35+0.65*min(1,(W-X)/620))'";
  const iconX = left ? '40' : 'W-w-40';
  const nameX = left ? '150' : 'w-text_w-150';
  execFileSync(FF, ['-hide_banner', '-loglevel', 'error', '-y', '-ss', String(t.at), '-i', `clips/${t.clip}.mp4`, '-i', ICON.replace('C\\:', 'C:'),
    '-filter_complex',
    `[0]crop=${t.crop},scale=1280:720,eq=saturation=1.25:contrast=1.08,${grad}[bg];[1]scale=96:96[ic];[bg][ic]overlay=${iconX}:34,` +
    `drawtext=fontfile=${FONT}:text='KIEM HIEP':fontsize=44:fontcolor=0xF3D27A:borderw=4:bordercolor=0x2A1810:x=${nameX}:y=60,` +
    `drawtext=fontfile=${FONT}:textfile=${bf}:fontsize=150:fontcolor=0xFFD84A:borderw=10:bordercolor=0x2A1008:shadowcolor=black@0.6:shadowx=6:shadowy=7:x=${x}:y=380,` +
    `drawtext=fontfile=${FONT}:textfile=${sf}:fontsize=68:fontcolor=white:borderw=7:bordercolor=0x2A1008:x=${x}:y=560`,
    '-frames:v', '1', `thumb/en-thumb-${t.id}.png`]);
  console.log('thumb', t.id);
}
