const { EdgeTTS } = require('node-edge-tts');
const [voice, rate, pitch, out, ...w] = process.argv.slice(2);
new EdgeTTS({ voice, lang: 'vi-VN', outputFormat: 'audio-24khz-96kbitrate-mono-mp3', rate, pitch, timeout: 30000 })
  .ttsPromise(w.join(' '), out).then(() => console.log('ok', out), (e) => { console.error('ERR', out, e); process.exit(1); });
