# Promo video

Gameplay ads (16:9 for YouTube/Google Ads, 9:16 for TikTok/Reels/Shorts),
recorded from the dev web build and assembled with ffmpeg.

1. `flutter build web -t lib/dev_entry.dart --no-tree-shake-icons`, copy
   `build/web` to `build/web_dev`, serve it: `node tool/shots/serve.js build/web_dev 8765`.
2. In a work folder holding `fonts/` (BeVietnamPro-Bold/ExtraBold,
   PlayfairDisplay from assets/fonts), `icon.png` (store/icon-512.png),
   `stills/1-4.png` (store/phone 06-08 + `node still.js` for the leaderboard)
   and `txt/` (captions, UTF-8): `node capture.js frames` records each scene
   through Chrome's screencast with the game slowed down (`slow=4`, the dev
   flag `BattleGame.debugSpeed`) so every frame is caught, then the frame
   timings are divided back; encode each to `clips/<scene>.mp4`
   (`ffmpeg -f concat -safe 0 -i frames/<scene>/list.txt -vf fps=30 ...`).
3. `bash build.sh` (point FF at an ffmpeg with libx264) writes
   `out/kiem-hiep-promo-16x9.mp4` and `out/kiem-hiep-promo-9x16.mp4`.
