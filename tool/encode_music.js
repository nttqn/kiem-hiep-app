// Encodes build/music/*.wav (from gen_music.js) into the game's assets:
// Ogg Vorbis for Android (loops gaplessly) and AAC .m4a for iOS, which
// cannot play Ogg. FFMPEG must point at an ffmpeg with libvorbis.
//   FFMPEG=/path/to/ffmpeg node tool/encode_music.js
const { execFileSync } = require('child_process');
const fs = require('fs');
const path = require('path');

const ff = process.env.FFMPEG || 'ffmpeg';
const src = path.join(__dirname, '..', 'build', 'music');
const out = path.join(__dirname, '..', 'assets', 'audio', 'music');
fs.mkdirSync(out, { recursive: true });
for (const f of fs.readdirSync(src).filter((f) => f.endsWith('.wav'))) {
  const name = f.slice(0, -4);
  execFileSync(ff, ['-hide_banner', '-loglevel', 'error', '-y', '-i', path.join(src, f),
    '-c:a', 'libvorbis', '-q:a', '3', path.join(out, name + '.ogg')]);
  execFileSync(ff, ['-hide_banner', '-loglevel', 'error', '-y', '-i', path.join(src, f),
    '-c:a', 'aac', '-b:a', '96k', path.join(out, name + '.m4a')]);
  const kb = (p) => Math.round(fs.statSync(p).size / 1024);
  console.log(name, kb(path.join(out, name + '.ogg')) + 'KB ogg', kb(path.join(out, name + '.m4a')) + 'KB m4a');
}
