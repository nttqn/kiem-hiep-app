# 1.7.0 promo (Nam Minh voice)

38 s narrated ad for the 1.7.0 features (skill effects, run-and-hit, mount
looks, Luyện thể, newbie mount), male voice vi-VN-NamMinhNeural at +5%.
Same pipeline as ../narrated (dev web build on :8765, `node capture.js frames all`,
encode clips, `node stills.js`, voice lines via say.js + loudnorm,
`node build.js`); FF in build.js points at a local ffmpeg 8.1 build.
Script lines may carry `"at"` to pick where in the clip a scene starts.
Outputs (gitignored): store/video/kiem-hiep-promo3-16x9.mp4, -9x16.mp4.
