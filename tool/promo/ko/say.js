// Voice lines for script.json in Korean (Edge TTS), loudness
// normalised to voice/<id>.wav. Run in the work folder: node say.js
// Needs node-edge-tts on NODE_PATH and FF (ffmpeg.exe) in the environment.
const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');
const { EdgeTTS } = require('node-edge-tts');

const VOICE = process.env.VOICE || 'ko-KR-InJoonNeural';
const RATE = process.env.RATE || '+8%';
const script = JSON.parse(fs.readFileSync(path.join(__dirname, 'script.json'), 'utf8'));

(async () => {
  fs.mkdirSync('voice', { recursive: true });
  for (const line of script) {
    const mp3 = `voice/${line.id}.mp3`;
    // The service sometimes closes with 1013 (busy): wait and try again.
    for (let attempt = 1; ; attempt++) {
      try {
        await new EdgeTTS({ voice: VOICE, lang: 'ko-KR', outputFormat: 'audio-24khz-96kbitrate-mono-mp3', rate: RATE, timeout: 30000 })
          .ttsPromise(line.say, mp3);
        break;
      } catch (e) {
        if (attempt >= 6) throw e;
        console.log('retry', line.id, String(e.message || e));
        await new Promise((r) => setTimeout(r, 4000 * attempt));
      }
    }
    execFileSync(process.env.FF, ['-hide_banner', '-loglevel', 'error', '-y', '-i', mp3,
      '-af', 'loudnorm=I=-16:TP=-1.5:LRA=11', '-ar', '44100', `voice/${line.id}.wav`]);
    console.log('ok', line.id);
  }
})().catch((e) => { console.error(e); process.exit(1); });
