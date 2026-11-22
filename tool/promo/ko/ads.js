// Google Ads (App campaign) image assets for the Korean launch: 1.91:1
// (1200x628), 1:1 (1200x1200) and 4:5 (1200x1500), cut from the captured
// clips and the Korean store shots, with a short headline and the icon.
// Run in the work folder after capture: FF=... node ads.js → ads/*.png
// Also prints the text assets' Google Ads lengths (Hangul counts 2).
const fs = require('fs');
const { execFileSync } = require('child_process');

const FF = process.env.FF;
const FONT = 'fonts/malgunbd.ttf';
const K = 'C:/Users/Hi/.gemini/antigravity/scratch/kiem-hiep-app';
const ICON = `${K}/store/icon-512.png`;

// src: clip:<name>@<skill cue>+<delay> (as in thumbs.js) or shot:<store shot>; crop on the 1920x1080 frame.
const images = [
  { id: 'L1-tuyet-ky', w: 1200, h: 628, src: 'clip:a_fire@fireLine+0.4', crop: '1700:890:200:0', big: '절기 한 방으로 전장 정리', sub: '5대 문파 무협 액션 RPG' },
  { id: 'L2-thu-cuoi', w: 1200, h: 628, src: 'shot:08-thu-cuoi', crop: '1920:1005:0:40', big: '탈것과 영수를 모아라', sub: '협객 동료 · 나만의 강호' },
  { id: 'S1-the-gioi', w: 1200, h: 1200, src: 'clip:f_wboss@venomCloud+0.3', crop: '1080:1080:640:0', big: '매일 월드 보스', sub: '전 서버 고수와 대결' },
  { id: 'S2-mon-phai', w: 1200, h: 1200, src: 'shot:05-chon-phai', crop: '1080:1080:0:0', big: '5대 문파 중 선택', sub: '금목수화토 · 오행상극' },
  { id: 'P1-hoa-son', w: 1200, h: 1500, src: 'clip:a_fire@fireLine+0.4', crop: '864:1080:790:0', big: '정통 무협 지금 시작', sub: '오프라인 플레이 · 클라우드 저장' },
  { id: 'P2-nhu-lai', w: 1200, h: 1500, src: 'clip:c_kim@buddhaPalm+0.5', crop: '864:1080:543:0', big: '여래신장', sub: '자동 전투로 쉽게 성장' },
];

const headlines = ['검협 오행: 무협 액션 RPG', '5대 문파 중 하나를 골라라', '절기 한 방으로 전장 정리', '오프라인 무협 RPG', '매일 월드 보스에 도전'];
const descriptions = [
  '금목수화토 5대 문파, 오행상극으로 적을 제압하고 무림지존이 되어라!',
  '화려한 스킬 이펙트, 직접 싸우거나 자동 전투로 쉽게 성장.',
  '월드 보스, 뇌대, 무림대회에서 전 서버 고수와 겨뤄라.',
  '오프라인 플레이와 클라우드 저장, 탈것·영수·협객 동료 수집.',
  '한국어 출시! 한국어 전용 채팅 채널, 지금 무료로 시작하세요.',
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
    : ['-i', `${K}/store/ko/phone/${rest}.png`];
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
    `geq=r='r(X,Y)*${f}':g='g(X,Y)*${f}':b='b(X,Y)*${f}'[bg];[1]scale=${icon}:${icon}[ic];` + (kind === 'clip' ? `[bg][ic]overlay=28:24,drawtext=fontfile=${FONT}:text='검협 오행':fontsize=${Math.round(icon * 0.46)}:fontcolor=0xF3D27A:borderw=4:bordercolor=0x2A1810:x=${28 + icon + 18}:y=${24 + icon / 2}-text_h/2,` : '[ic]nullsink;[bg]null,') +
    `drawtext=fontfile=${FONT}:textfile=ads/${im.id}_big.txt:fontsize=${big}:fontcolor=0xFFD84A:borderw=${Math.round(big / 14)}:bordercolor=0x2A1008:shadowcolor=black@0.6:shadowx=5:shadowy=6:x=(w-text_w)/2:y=h-${Math.round(big * 1.1 + sub * 1.9)}-text_h*0,` +
    `drawtext=fontfile=${FONT}:textfile=ads/${im.id}_sub.txt:fontsize=${sub}:fontcolor=white:borderw=${Math.round(sub / 10)}:bordercolor=0x2A1008:x=(w-text_w)/2:y=h-${Math.round(sub * 1.9)}`,
    '-frames:v', '1', `ads/ko-ads-${im.id}.png`]);
  console.log('image', im.id, `${im.w}x${im.h}`);
}
