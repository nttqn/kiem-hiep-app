// Assembles the narrated promo: scenes timed to the voice lines, the game's
// own sound effects at their recorded times, the battle theme ducked under
// the voice, and Vietnamese subtitles. Writes out/16x9.mp4 and out/9x16.mp4.
// node build.js
const fs = require('fs');
const { execFileSync } = require('child_process');

const FF = '../ffmpeg/ffmpeg-n8.1-latest-win64-gpl-8.1/bin/ffmpeg.exe';
const FP = '../ffmpeg/ffmpeg-n8.1-latest-win64-gpl-8.1/bin/ffprobe.exe';
const K = 'C:/Users/Hi/.gemini/antigravity/scratch/kiem-hiep-app';
const MUSIC = `${K}/assets/audio/music/battle.ogg`;
const ICON = `${K}/store/icon-512.png`;
const SFX_DIR = `${K}/assets/audio`;
const FONT_B = 'fonts/BeVietnamPro-ExtraBold.ttf';
const FONT_T = 'fonts/PlayfairDisplay.ttf';

const ff = (args) => execFileSync(FF, ['-hide_banner', '-loglevel', 'error', '-y', ...args], { stdio: 'inherit' });
const dur = (f) => parseFloat(execFileSync(FP, ['-v', 'error', '-show_entries', 'format=duration', '-of', 'csv=p=0', f]).toString());
const ENC = ['-r', '30', '-c:v', 'libx264', '-crf', '17', '-preset', 'medium', '-pix_fmt', 'yuv420p', '-an'];

// Sound cue → file, as in lib/services/sound.dart.
const CUES = {
  hit: 'hit', swing: 'swing', shoot: 'shoot', arcGold: 'slash', arcFire: 'slash', bell: 'magic',
  healWater: 'magic', earthShield: 'magic', swordOrbit: 'magic', quake: 'boom', buddha: 'boom',
  meteor: 'boom', spikes: 'boom', knife: 'shoot', needle: 'shoot', taiji: 'shoot', poisonPalm: 'poison',
  poisonCloud: 'poison', iceBlade: 'ice', iceField: 'ice', snowStorm: 'ice', fireDash: 'dash',
  fireRing: 'fire', buddhaPalm: 'boom', venomCloud: 'poison', iceNova: 'ice', fireLine: 'fire',
  swordStorm: 'magic', die: 'die', bossDie: 'bossdie', coin: 'coin', loot: 'loot',
};
const ULTS = ['fireLine', 'buddhaPalm', 'swordStorm', 'iceNova', 'venomCloud'];
// Per-cue loudness: big moves loud, the constant hits and coins soft.
const VOL = { hit: 0.35, coin: 0.25, loot: 0.3, die: 0.4, swing: 0.4, shoot: 0.45 };

const script = JSON.parse(fs.readFileSync('script.json', 'utf8'));
fs.mkdirSync('seg', { recursive: true });
fs.mkdirSync('out', { recursive: true });
fs.mkdirSync('txt', { recursive: true });
fs.writeFileSync('txt/title.txt', 'KIẾM HIỆP NGŨ HÀNH');
fs.writeFileSync('txt/tagline.txt', 'Nhập vai kiếm hiệp offline');
fs.writeFileSync('txt/cta.txt', 'TẢI MIỄN PHÍ TRÊN GOOGLE PLAY');

const GAP = 0.45; // silence after each line
let t = 0;
const segs = [];
const sfx = []; // {at, file, vol}
const subs = []; // {from, to, file}
const voices = []; // {at, file}

script.forEach((line, n) => {
  const vfile = `voice/${line.id}.wav`;
  const len = dur(vfile) + GAP + (n === 0 ? 0.3 : 0);
  const voiceAt = t + (n === 0 ? 0.3 : 0);
  voices.push({ at: voiceAt, file: vfile });
  const sub = `txt/${line.id}.txt`;
  fs.writeFileSync(sub, line.sub);
  subs.push({ from: voiceAt, to: t + len - 0.15, file: sub, id: line.id });
  const out = `seg/${line.id}.mp4`;
  const [kind, arg] = line.scene.split(':');
  if (kind === 'clip') {
    const cues = JSON.parse(fs.readFileSync(`frames/${arg}/sfx.json`, 'utf8'));
    const ult = cues.find((c) => ULTS.includes(c.cue));
    // Start just before the ultimate fires.
    const start = Math.max(0, (ult ? ult.t : 1) - 0.35);
    ff(['-ss', start.toFixed(3), '-t', len.toFixed(3), '-i', `clips/${arg}.mp4`, ...ENC, out]);
    for (const c of cues) {
      if (c.t < start || c.t > start + len || !CUES[c.cue]) continue;
      sfx.push({ at: t + c.t - start, file: `${SFX_DIR}/${CUES[c.cue]}.wav`, vol: ULTS.includes(c.cue) ? 1.0 : VOL[CUES[c.cue]] ?? 0.6 });
    }
  } else if (kind === 'still' || kind === 'stills') {
    const names = arg.split(',');
    const each = len / names.length;
    const parts = names.map((name, i) => {
      const p = `seg/${line.id}_${i}.mp4`;
      const frames = Math.round(each * 30);
      ff(['-loop', '1', '-framerate', '30', '-t', each.toFixed(3), '-i', `stills/${name}.png`, '-vf',
        `scale=1920:1080,zoompan=z='1+0.04*on/${frames}':x='iw/2-(iw/zoom/2)':y='ih/2-(ih/zoom/2)':d=1:s=1920x1080:fps=30`,
        ...ENC, p]);
      sfx.push({ at: t + i * each, file: `${SFX_DIR}/click.wav`, vol: 0.5 });
      return p;
    });
    if (parts.length === 1) {
      fs.copyFileSync(parts[0], out);
    } else {
      ff([...parts.flatMap((p) => ['-i', p]), '-filter_complex', `${parts.map((_, i) => `[${i}]`).join('')}concat=n=${parts.length}:v=1:a=0`, ...ENC, out]);
    }
  } else if (kind === 'end') {
    ff(['-ss', '1.6', '-i', 'clips/a_hoason.mp4', '-frames:v', '1', 'seg/bg.png']);
    ff(['-loop', '1', '-framerate', '30', '-t', (len + 1.2).toFixed(3), '-i', 'seg/bg.png', '-i', ICON, '-filter_complex',
      '[0]scale=1920:1080,boxblur=18:3,eq=brightness=-0.3[b];[1]scale=240:240[i];[b][i]overlay=(W-w)/2:110[bi];' +
      `[bi]drawtext=fontfile=${FONT_T}:textfile=txt/title.txt:fontsize=124:fontcolor=0xF3D27A:borderw=5:bordercolor=0x2A1810:x=(w-text_w)/2:y=390,` +
      `drawtext=fontfile=${FONT_B}:textfile=txt/tagline.txt:fontsize=52:fontcolor=0xF3E6C8:borderw=3:bordercolor=0x2A1810:x=(w-text_w)/2:y=555,` +
      `drawtext=fontfile=${FONT_B}:textfile=txt/cta.txt:fontsize=58:fontcolor=white:box=1:boxcolor=0xA3271F:boxborderw=28:x=(w-text_w)/2:y=700,` +
      'fade=t=in:st=0:d=0.35', ...ENC, out]);
    sfx.push({ at: t, file: `${SFX_DIR}/gong.wav`, vol: 0.9 });
    segs.push(out);
    t += len + 1.2;
    return;
  }
  segs.push(out);
  t += len;
});
const TOTAL = t;
console.log('total', TOTAL.toFixed(2), 's,', sfx.length, 'effects');

// Video: concat the segments.
ff([...segs.flatMap((s) => ['-i', s]), '-filter_complex', `${segs.map((_, i) => `[${i}]`).join('')}concat=n=${segs.length}:v=1:a=0`, ...ENC, 'seg/master.mp4']);

// Audio: music (ducked under the voice) + voice + effects. Effects are mixed
// in batches so the filter graph stays manageable.
const mixBatch = (items, outFile) => {
  const inputs = items.flatMap((s) => ['-i', s.file]);
  const chains = items.map((s, i) => `[${i}]aresample=44100,aformat=channel_layouts=stereo,volume=${s.vol ?? 1},adelay=${Math.round(s.at * 1000)}|${Math.round(s.at * 1000)}[a${i}]`);
  ff([...inputs, '-filter_complex', `${chains.join(';')};${items.map((_, i) => `[a${i}]`).join('')}amix=inputs=${items.length}:normalize=0:duration=longest,apad=whole_dur=${TOTAL.toFixed(3)}[o]`,
    '-map', '[o]', '-t', TOTAL.toFixed(3), '-c:a', 'pcm_s16le', outFile]);
};
const batches = [];
for (let i = 0; i < sfx.length; i += 24) {
  const f = `seg/sfx_${batches.length}.wav`;
  mixBatch(sfx.slice(i, i + 24), f);
  batches.push({ file: f, at: 0 });
}
mixBatch(batches, 'seg/sfx.wav');
mixBatch(voices, 'seg/voice.wav');
ff(['-stream_loop', '-1', '-i', MUSIC, '-i', 'seg/voice.wav', '-i', 'seg/sfx.wav', '-filter_complex',
  `[0]atrim=0:${TOTAL.toFixed(3)},aresample=44100,aformat=channel_layouts=stereo,volume=0.55,afade=t=in:d=0.4,afade=t=out:st=${(TOTAL - 2).toFixed(2)}:d=2[m];` +
  '[1]asplit=2[v][vk];' +
  '[m][vk]sidechaincompress=threshold=0.03:ratio=8:attack=20:release=350[md];' +
  '[2]volume=0.8[fx];' +
  '[md][v][fx]amix=inputs=3:normalize=0,alimiter=limit=0.95[o]',
  '-map', '[o]', '-t', TOTAL.toFixed(3), '-c:a', 'pcm_s16le', 'seg/mix.wav']);

// Subtitles: two lines, bottom centre; the end card has its own text.
const subFilter = (fs_, y) => subs.filter((s) => s.id !== 's9').map((s) =>
  `drawtext=fontfile=${FONT_B}:textfile=${s.file}:fontsize=${fs_}:fontcolor=white:line_spacing=10:` +
  `borderw=6:bordercolor=0x1A0E0A:shadowcolor=black@0.55:shadowx=3:shadowy=3:text_align=C:x=(w-text_w)/2:y=${y}:` +
  `enable='between(t,${s.from.toFixed(2)},${s.to.toFixed(2)})':alpha='if(lt(t-${s.from.toFixed(2)},0.2),(t-${s.from.toFixed(2)})/0.2,1)'`).join(',');

ff(['-i', 'seg/master.mp4', '-i', 'seg/mix.wav', '-filter_complex', `[0]${subFilter(64, 'h-text_h-70')}[v]`,
  '-map', '[v]', '-map', '1:a', '-r', '30', '-c:v', 'libx264', '-crf', '18', '-preset', 'medium', '-pix_fmt', 'yuv420p',
  '-c:a', 'aac', '-b:a', '192k', '-movflags', '+faststart', 'out/kiem-hiep-promo2-16x9.mp4']);

ff(['-i', 'seg/master.mp4', '-i', 'seg/mix.wav', '-filter_complex',
  '[0]split[x][y];[x]scale=-2:1920,crop=1080:1920,boxblur=26:4,eq=brightness=-0.25[bg];[y]scale=1080:-2[fg];[bg][fg]overlay=0:(H-h)/2,' +
  `drawtext=fontfile=${FONT_T}:textfile=txt/title.txt:fontsize=96:fontcolor=0xF3D27A:borderw=5:bordercolor=0x2A1810:x=(w-text_w)/2:y=300:enable='lt(t,${(TOTAL - 5.5).toFixed(2)})',` +
  `${subFilter(62, 1340)},` +
  `drawtext=fontfile=${FONT_B}:textfile=txt/cta.txt:fontsize=48:fontcolor=white:box=1:boxcolor=0xA3271F:boxborderw=22:x=(w-text_w)/2:y=1560:enable='lt(t,${(TOTAL - 5.5).toFixed(2)})'[v]`,
  '-map', '[v]', '-map', '1:a', '-r', '30', '-c:v', 'libx264', '-crf', '18', '-preset', 'medium', '-pix_fmt', 'yuv420p',
  '-c:a', 'aac', '-b:a', '192k', '-movflags', '+faststart', 'out/kiem-hiep-promo2-9x16.mp4']);
console.log('done');
