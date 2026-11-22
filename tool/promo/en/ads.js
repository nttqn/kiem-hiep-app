// Google Ads (App campaign) image assets for the English launch: 1.91:1
// (1200x628), 1:1 (1200x1200) and 4:5 (1200x1500), cut from the captured
// clips and the English store shots, with a short headline and the icon.
// Run in the work folder after capture: FF=... node ads.js → ads/*.png
// Also prints the text assets' Google Ads lengths (CJK counts 2).
const fs = require('fs');
const { execFileSync } = require('child_process');

const FF = process.env.FF;
const FONT = 'fonts/BeVietnamPro-Bold.ttf';
const K = 'C:/Users/Hi/.gemini/antigravity/scratch/kiem-hiep-app';
const ICON = `${K}/store/icon-512.png`;

// src: clip:<name>@<skill cue>+<delay> (as in thumbs.js) or shot:<store shot>; crop on the 1920x1080 frame.
const images = [
  { id: 'L1-tuyet-ky', w: 1200, h: 628, src: 'clip:a_fire@fireLine+0.4', crop: '1700:890:200:0', big: 'One Strike, Whole Field', sub: 'Five-sect wuxia action RPG' },
  { id: 'L2-thu-cuoi', w: 1200, h: 628, src: 'shot:08-thu-cuoi', crop: '1920:1005:0:40', big: 'Mounts & Spirit Beasts', sub: 'Companions · your own jianghu' },
  { id: 'S1-the-gioi', w: 1200, h: 1200, src: 'clip:f_wboss@venomCloud+0.3', crop: '1080:1080:640:0', big: 'Daily World Boss', sub: 'Beat the whole server' },
  { id: 'S2-mon-phai', w: 1200, h: 1200, src: 'shot:05-chon-phai', crop: '1080:1080:0:0', big: 'Pick Your Sect', sub: 'Metal · Wood · Water · Fire · Earth' },
  { id: 'P1-hoa-son', w: 1200, h: 1500, src: 'clip:a_fire@fireLine+0.4', crop: '864:1080:790:0', big: 'Wuxia Awaits', sub: 'Play offline · Cloud save' },
  { id: 'P2-bang-tam', w: 1200, h: 1500, src: 'clip:b_ice@iceNova+0.25', crop: '864:1080:528:0', big: 'Freeze Them All', sub: 'Auto battle, fast growth' },
];

const headlines = ['Kiem Hiep: Wuxia Action RPG', 'Five Sects, Five Elements', 'One Strike Clears the Field', 'Offline Wuxia RPG', 'Fight the World Boss Daily'];
const descriptions = [
  'Join one of five martial sects and master the five elements to become Supreme Master.',
  'Flashy skills and ultimates. Fight by hand or switch on auto battle and level up fast.',
  'World Boss, Arena and the weekly Martial Conclave: prove yourself against the server.',
  'Play offline with cloud save. Collect mounts, spirit beasts and wuxia companions.',
  'Now in English, with its own world chat. Download free and start your legend!',
];
// Google Ads counts double-width (CJK, full-width punctuation) as 2.
const gLen = (s) => [...s].reduce((n, ch) => n + (/[\u1100-\u115F\u2E80-\uA4CF\uAC00-\uD7A3\uF900-\uFAFF\uFE30-\uFE4F\uFF00-\uFF60\uFFE0-\uFFE6]/.test(ch) ? 2 : 1), 0);
for (const h of headlines) console.log('headline', gLen(h), '/30', h);
for (const d of descriptions) console.log('description', gLen(d), '/90', d);

// <clip>@<cue>+<delay>: the delay after that skill cue in the capture.
const at = (rest) => {
  const [clip, when] = rest.split('@');
  const [cue, d] = when.split('+');
  const c = JSON.parse(fs.readFileSync(`frames/${clip}/sfx.json`, 'utf8')).find((x) => x.cue === cue);
  return ((c ? c.t : 2) + Number(d)).toFixed(2);
};

fs.mkdirSync('ads', { recursive: true });
for (const im of images) {
  const [kind, rest] = im.src.split(':');
  const input = kind === 'clip'
    ? ['-ss', at(rest), '-i', `clips/${rest.split('@')[0]}.mp4`]
    : ['-i', `${K}/store/en/phone/${rest}.png`];
  fs.writeFileSync(`ads/${im.id}_big.txt`, im.big);
  fs.writeFileSync(`ads/${im.id}_sub.txt`, im.sub);
  const s = im.w / 1200; // text scale
  const big = Math.round((im.h < 700 ? 74 : 92) * s);
  const sub = Math.round(big * 0.52);
  const icon = Math.round((im.h < 700 ? 84 : 110) * s);
  // Darken the top (brand) and bottom (words) so text reads on any frame.
  const f = `(0.3+0.7*min(1,min(Y/(0.2*H),(H-Y)/(0.42*H))))`;
  execFileSync(FF, ['-hide_banner', '-loglevel', 'error', '-y', ...input, '-i', ICON, '-filter_complex',
    `[0]crop=${im.crop},scale=${im.w}:${im.h},eq=saturation=1.2:contrast=1.06,` +
    `geq=r='r(X,Y)*${f}':g='g(X,Y)*${f}':b='b(X,Y)*${f}'[bg];[1]scale=${icon}:${icon}[ic];` + (kind === 'clip' ? `[bg][ic]overlay=28:24,drawtext=fontfile=${FONT}:text='KIEM HIEP':fontsize=${Math.round(icon * 0.46)}:fontcolor=0xF3D27A:borderw=4:bordercolor=0x2A1810:x=${28 + icon + 18}:y=${24 + icon / 2}-text_h/2,` : '[ic]nullsink;[bg]null,') +
    `drawtext=fontfile=${FONT}:textfile=ads/${im.id}_big.txt:fontsize=${big}:fontcolor=0xFFD84A:borderw=${Math.round(big / 14)}:bordercolor=0x2A1008:shadowcolor=black@0.6:shadowx=5:shadowy=6:x=(w-text_w)/2:y=h-${Math.round(big * 1.1 + sub * 1.9)}-text_h*0,` +
    `drawtext=fontfile=${FONT}:textfile=ads/${im.id}_sub.txt:fontsize=${sub}:fontcolor=white:borderw=${Math.round(sub / 10)}:bordercolor=0x2A1008:x=(w-text_w)/2:y=h-${Math.round(sub * 1.9)}`,
    '-frames:v', '1', `ads/en-ads-${im.id}.png`]);
  console.log('image', im.id, `${im.w}x${im.h}`);
}
