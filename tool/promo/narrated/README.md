# Narrated promo (v1.0.7)

39.4 s gameplay ad with a Vietnamese female voice-over (Edge neural TTS,
vi-VN-HoaiMyNeural, pitch -15Hz), Vietnamese subtitles, the battle theme ducked under the voice and the
game's own sound effects at the moments they fired.

1. Dev web build served on :8765 (see ../README.md).
2. `node capture.js frames all`: records each scene at 1920x1080 with the
   game at 1/6 speed and `sfx=1`, which prints every sound cue; the cue
   times go to frames/<scene>/sfx.json. Encode clips/<scene>.mp4 from
   frames/<scene>/list.txt as in ../README.md.
3. Voice lines from script.json (needs `npm i node-edge-tts@1.2.11`; msedge-tts
   and the readaloud endpoint answer 403 since Microsoft's v2 token, 2026-10):
   `node say.js vi-VN-HoaiMyNeural +0% -15Hz voice/<id>.raw.mp3 "<line>"`, then
   `ffmpeg -i raw.mp3 -af "silenceremove=start_periods=1:start_threshold=-45dB,areverse,silenceremove=start_periods=1:start_threshold=-45dB,areverse,loudnorm=I=-16:TP=-1.5:LRA=11" -ar 44100 -ac 2 voice/<id>.wav`.
   The user picked this voice over the others (samples in store/video/giong-doc-thu).
4. `node stills.js` for refine/rank stills; other stills come from store/phone.
5. `node build.js` writes out/kiem-hiep-promo2-16x9.mp4 and -9x16.mp4.
