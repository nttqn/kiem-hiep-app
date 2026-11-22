# 劍俠五行 promo (Traditional Chinese, for TW/HK Google Ads)

About 40 s narrated ad. The male Taiwanese voice is zh-TW-YunJheNeural at +8%.
Subtitles use Microsoft JhengHei Bold. The pipeline is the same as ../v170:

1. Build and serve the dev web build:

   ```
   flutter build web -t lib/dev_entry.dart -o build/web_dev
   node tool/shots/serve.js build/web_dev 8767
   ```

2. The stills are the zh_Hant store shots in store/zh_Hant/phone. Make them
   with `LANG_SHOT=zh_Hant PORT=8767 node tool/shots/store_shots.js phone`.

3. Prepare a work folder:
   - `npm i node-edge-tts@1`, and put both it and Playwright on NODE_PATH.
   - Copy `C:/Windows/Fonts/msjhbd.ttc` into `fonts/`.

4. In the work folder, run these steps with `FF` set to ffmpeg.exe:
   - Voice lines: `node say.js`.
   - Capture each scene: `PORT=8767 node capture.js frames <scene>`.
   - Encode each scene to `clips/<scene>.mp4`:
     `ffmpeg -f concat -safe 0 -i frames/<scene>/list.txt -vf fps=30 ...`
   - Assemble: `node build.js`.

The outputs are not committed:

- out/kiem-hiep-zh-16x9.mp4
- out/kiem-hiep-zh-9x16.mp4
- out/kiem-hiep-zh-1x1.mp4

Copy them to store/video/.

`node thumbs.js` cuts the YouTube thumbnails from the same clips; copy them
into store/youtube/. `node ads.js` makes the Google Ads images
(1.91:1, 1:1, 4:5); copy them into store/ads/zh_Hant/. It also prints the
lengths of the headlines and descriptions. The channel banner is
tool/gen_banner_test.dart.
