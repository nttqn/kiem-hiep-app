// Google Ads (App campaign) image assets for the zh_Hant launch: 1.91:1
// (1200x628), 1:1 (1200x1200) and 4:5 (1200x1500), cut from the captured
// clips and the zh_Hant store shots, with a short headline and the icon.
// Run in the work folder after capture: FF=... node ads.js → ads/*.png
// Also prints the text assets' Google Ads lengths (CJK characters count 2).
const fs = require('fs');
const { execFileSync } = require('child_process');

const FF = process.env.FF;
const FONT = 'fonts/msjhbd.ttc';
const K = 'C:/Users/Hi/.gemini/antigravity/scratch/kiem-hiep-app';
const ICON = `${K}/store/icon-512.png`;

// src: clip:<name>@<time> or shot:<store shot>; crop on the 1920x1080 frame.
const images = [
  { id: 'L1-tuyet-ky', w: 1200, h: 628, src: 'clip:a_fire@1.9', crop: '1700:890:200:0', big: '一招絕技橫掃全場', sub: '五大門派武俠動作 RPG' },
  { id: 'L2-thu-cuoi', w: 1200, h: 628, src: 'shot:08-thu-cuoi', crop: '1920:1005:0:40', big: '坐騎靈獸任你收集', sub: '俠客夥伴 · 打造你的江湖' },
  { id: 'S1-the-gioi', w: 1200, h: 1200, src: 'clip:f_wboss@3.0', crop: '1080:1080:640:0', big: '世界首領每日開戰', sub: '全服高手一較高下' },
  { id: 'S2-mon-phai', w: 1200, h: 1200, src: 'shot:05-chon-phai', crop: '1080:1080:0:0', big: '五大門派任你選', sub: '金木水火土 · 五行相剋' },
  { id: 'P1-hoa-son', w: 1200, h: 1500, src: 'clip:a_fire@1.9', crop: '864:1080:790:0', big: '熱血武俠 現在開戰', sub: '離線也能玩 · 雲端存檔' },
  { id: 'P2-nhu-lai', w: 1200, h: 1500, src: 'clip:c_kim@7.0', crop: '864:1080:612:0', big: '如來神掌', sub: '一鍵自動戰鬥 · 輕鬆練功' },
];

const headlines = ['劍俠五行：武俠動作RPG', '五大門派任你選', '一招絕技橫掃全場', '離線也能玩的武俠手遊', '每日世界首領等你挑戰'];
const descriptions = [
  '金木水火土五大門派，五行相剋，以巧破力，成就武林至尊！',
  '華麗技能特效，邊跑邊打或一鍵自動戰鬥，輕鬆練功升級。',
  '世界首領、擂台、武林大會，與全服高手一較高下。',
  '支援離線遊玩與雲端存檔，坐騎、靈獸、俠客夥伴等你收集。',
  '繁體中文版上線，專屬中文世界頻道，免費下載立即開戰！',
];
// Google Ads counts double-width (CJK, full-width punctuation) as 2.
const gLen = (s) => [...s].reduce((n, ch) => n + (/[\u1100-\u115F\u2E80-\uA4CF\uAC00-\uD7A3\uF900-\uFAFF\uFE30-\uFE4F\uFF00-\uFF60\uFFE0-\uFFE6]/.test(ch) ? 2 : 1), 0);
for (const h of headlines) console.log('headline', gLen(h), '/30', h);
for (const d of descriptions) console.log('description', gLen(d), '/90', d);

fs.mkdirSync('ads', { recursive: true });
for (const im of images) {
  const [kind, rest] = im.src.split(':');
  const input = kind === 'clip'
    ? ['-ss', rest.split('@')[1], '-i', `clips/${rest.split('@')[0]}.mp4`]
    : ['-i', `${K}/store/zh_Hant/phone/${rest}.png`];
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
    `geq=r='r(X,Y)*${f}':g='g(X,Y)*${f}':b='b(X,Y)*${f}'[bg];[1]scale=${icon}:${icon}[ic];` + (kind === 'clip' ? `[bg][ic]overlay=28:24,drawtext=fontfile=${FONT}:text='劍俠五行':fontsize=${Math.round(icon * 0.46)}:fontcolor=0xF3D27A:borderw=4:bordercolor=0x2A1810:x=${28 + icon + 18}:y=${24 + icon / 2}-text_h/2,` : '[ic]nullsink;[bg]null,') +
    `drawtext=fontfile=${FONT}:textfile=ads/${im.id}_big.txt:fontsize=${big}:fontcolor=0xFFD84A:borderw=${Math.round(big / 14)}:bordercolor=0x2A1008:shadowcolor=black@0.6:shadowx=5:shadowy=6:x=(w-text_w)/2:y=h-${Math.round(big * 1.1 + sub * 1.9)}-text_h*0,` +
    `drawtext=fontfile=${FONT}:textfile=ads/${im.id}_sub.txt:fontsize=${sub}:fontcolor=white:borderw=${Math.round(sub / 10)}:bordercolor=0x2A1008:x=(w-text_w)/2:y=h-${Math.round(sub * 1.9)}`,
    '-frames:v', '1', `ads/zh-ads-${im.id}.png`]);
  console.log('image', im.id, `${im.w}x${im.h}`);
}
