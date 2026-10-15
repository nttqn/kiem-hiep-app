import 'dart:async';

import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One-shot effects plus the looping theme, all synthesised by
/// `tool/gen_audio.js`. Every call is a safe no-op until loading is done,
/// when muted, or if an asset fails to load.
class SoundService {
  SoundService._();
  static final SoundService instance = SoundService._();

  static const _key = 'sound_enabled';
  static const _files = [
    'swing', 'hit', 'shoot', 'slash', 'magic', 'boom', 'ice', 'poison',
    'fire', 'dash', 'die', 'bossdie', 'potion', 'coin', 'loot', 'herodie',
    'levelup', 'quest', 'click', 'gong',
  ];

  /// World cue (skill fx names and events) → sound file.
  static const _cues = {
    'hit': 'hit',
    'swing': 'swing',
    'shoot': 'shoot',
    'arcGold': 'slash',
    'arcFire': 'slash',
    'bell': 'magic',
    'healWater': 'magic',
    'earthShield': 'magic',
    'swordOrbit': 'magic',
    'quake': 'boom',
    'buddha': 'boom',
    'meteor': 'boom',
    'spikes': 'boom',
    'knife': 'shoot',
    'needle': 'shoot',
    'taiji': 'shoot',
    'poisonPalm': 'poison',
    'poisonCloud': 'poison',
    'iceBlade': 'ice',
    'iceField': 'ice',
    'snowStorm': 'ice',
    'fireDash': 'dash',
    'fireRing': 'fire',
    'die': 'die',
    'bossDie': 'bossdie',
    'potion': 'potion',
    'coin': 'coin',
    'loot': 'loot',
    'heroDie': 'herodie',
  };

  final ValueNotifier<bool> enabled = ValueNotifier<bool>(true);
  final Map<String, AudioPool> _pools = {};
  final Map<String, DateTime> _last = {};
  AudioPlayer? _music;
  bool _battle = false;
  bool _foreground = true;
  AppLifecycleListener? _lifecycle;

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      enabled.value = prefs.getBool(_key) ?? true;
    } catch (_) {}
    // Nothing here needs audio focus; taking it would let each effect pause
    // the theme on Android. The web plugin has no global context at all.
    if (!kIsWeb) {
      try {
        await AudioPlayer.global.setAudioContext(AudioContext(
          android: const AudioContextAndroid(audioFocus: AndroidAudioFocus.none),
          iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
        ));
      } catch (_) {}
    }
    for (final f in _files) {
      try {
        _pools[f] = await FlameAudio.createPool(
          '$f.wav',
          minPlayers: 1,
          maxPlayers: f == 'hit' || f == 'swing' || f == 'shoot' ? 3 : 2,
        ).timeout(const Duration(seconds: 5));
      } catch (_) {}
    }
    try {
      final player = AudioPlayer();
      await player.setReleaseMode(ReleaseMode.loop);
      await player.setVolume(0.5);
      await player
          .setSource(AssetSource('audio/theme.wav'))
          .timeout(const Duration(seconds: 10));
      _music = player;
    } catch (_) {}
    _lifecycle ??= AppLifecycleListener(onStateChange: (s) {
      _foreground = s == AppLifecycleState.resumed;
      _applyMusic();
    });
    _applyMusic();
  }

  /// Quieter theme during fights.
  void setBattle(bool v) {
    _battle = v;
    _guard(_music?.setVolume(v ? 0.22 : 0.5));
    _applyMusic();
  }

  void _applyMusic() {
    final m = _music;
    if (m == null) return;
    final should = enabled.value && _foreground;
    final playing = m.state == PlayerState.playing;
    if (should && !playing) {
      _guard(m.resume());
    } else if (!should && playing) {
      _guard(m.pause());
    }
  }

  /// Plays a world cue or a file name directly.
  void cue(String name, {double volume = 1}) {
    // Browsers refuse audio before the first tap; cues follow taps, so
    // this is where a blocked theme gets going.
    _applyMusic();
    if (!enabled.value) return;
    final file = _cues[name] ?? name;
    final now = DateTime.now();
    final last = _last[file];
    // Rapid repeats (a sweep hitting six monsters) collapse into one.
    if (last != null && now.difference(last).inMilliseconds < 70) return;
    _last[file] = now;
    try {
      _pools[file]?.start(volume: volume * (_battle ? 0.9 : 1));
    } catch (_) {}
  }

  Future<void> toggle() async {
    enabled.value = !enabled.value;
    _applyMusic();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_key, enabled.value);
    } catch (_) {}
  }

  static void _guard(Future<void>? f) {
    f?.catchError((Object _) {});
  }
}
