# Narrated promo (v1.0.7)

46.8 s gameplay ad with a Vietnamese female voice-over (Google Translate TTS,
vi), Vietnamese subtitles, the battle theme ducked under the voice and the
game's own sound effects at the moments they fired.

1. Dev web build served on :8765 (see ../README.md).
2. `node capture.js frames all`: records each scene at 1920x1080 with the
   game at 1/6 speed and `sfx=1`, which prints every sound cue; the cue
   times go to frames/<scene>/sfx.json. Encode clips/<scene>.mp4 from
   frames/<scene>/list.txt as in ../README.md.
3. Voice lines from script.json: fetch
   translate.google.com/translate_tts?ie=UTF-8&client=tw-ob&tl=vi&q=<line>
   into voice/<id>.raw.mp3, then
   `ffmpeg -i raw.mp3 -af "atempo=1.12,loudnorm=I=-16:TP=-1.5:LRA=11,aresample=44100" -ac 2 voice/<id>.wav`.
   (Edge neural TTS via msedge-tts answered 403 on 2026-10-25.)
4. `node stills.js` for refine/rank stills; other stills come from store/phone.
5. `node build.js` writes out/kiem-hiep-promo2-16x9.mp4 and -9x16.mp4.
