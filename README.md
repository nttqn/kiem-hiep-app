# Kiếm Hiệp Ngũ Hành (working title)

Offline 2D top-down action RPG in the võ lâm style: five sects built on the
five phases (ngũ hành), real-time combat with joystick + skill buttons,
autopilot fighting, field grinding, dungeons (vượt ải), a 43-step main quest
and daily quests. Flutter + Flame, landscape, all art drawn in code, all
sound synthesised.

## Layout

- `lib/core` — pure Dart, no Flutter: `hanh.dart` (phase cycle),
  `sects.dart` (5 sects × 6 skills), `items.dart` (gear, rarity, forging),
  `content.dart` (monsters, 7 maps, 14 dungeons, main quests), `hero.dart`
  (saved character, stats, levelling, quests, balance formulas),
  `world.dart` (combat sim, monster AI, autopilot, dungeon waves),
  `scenery.dart` (procedural props).
- `lib/render` — Canvas art: `art_figures.dart` (heroes and the six monster
  body plans), `art_scenery.dart`, `art_fx.dart`, `world_renderer.dart`.
- `lib/game/battle_game.dart` — Flame loop around a `World`.
- `lib/ui` — title/slots, sect creation, town hub, play screen + HUD,
  character/skills/bag/forge, shop, maps, dungeons, quests.
- `lib/services` — `save.dart` (3 slots in shared_preferences),
  `sound.dart`.
- `lib/dev_entry.dart` — opens any screen with a ready-made hero, for
  screenshots: `?screen=play&sect=3&level=30&map=hoangsa`.

## Tools

- `flutter test` — core tests plus `balance_test.dart`, which plays every
  sect on autopilot and prints levels reached over time
  (`--dart-define=SIM_MIN=480 --dart-define=SIM_LOG=true` for a long run).
- `node tool/gen_audio.js` — regenerates `assets/audio/*.wav`.
- `flutter test tool/gen_icon_test.dart` then `dart run flutter_launcher_icons`.
- Screenshots: `flutter build web -t lib/dev_entry.dart -o build/web_dev`,
  `node tool/shots/serve.js build/web_dev 8765`, then
  `NODE_PATH=<playwright install> node tool/shots/shots.js [name]`.

Android builds run on GitHub Actions (`.github/workflows/build-apk.yml`);
this machine has no Android SDK.
