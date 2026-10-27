import 'dart:async';

import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// One-shot effects (`tool/gen_audio.js`) and background music, one track
/// per map plus menu and battle (`tool/gen_music.js`), each with its own
/// on/off switch. Every call is a safe no-op until loading is done, when
/// muted, or if an asset fails to load.
class SoundService {
  SoundService._();
  static final SoundService instance = SoundService._();

  static const _key = 'sound_enabled';
  static const sfxFiles = [
    'swing', 'hit', 'shoot', 'slash', 'magic', 'boom', 'ice', 'poison',
    'fire', 'dash', 'die', 'bossdie', 'potion', 'coin', 'loot', 'herodie',
    'levelup', 'quest', 'click', 'gong',
  ];

  /// Effect [name]'s file under assets/audio/ (FlameAudio's cache prefix).
  static String sfxAsset(String name) => '$name.wav';

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
    'buddhaPalm': 'boom',
    'venomCloud': 'poison',
    'iceNova': 'ice',
    'fireLine': 'fire',
    'swordStorm': 'magic',
    'die': 'die',
    'bossDie': 'bossdie',
    'potion': 'potion',
    'coin': 'coin',
    'loot': 'loot',
    'heroDie': 'herodie',
  };

  /// Sound effects on/off.
  final ValueNotifier<bool> sfxOn = ValueNotifier<bool>(true);

  /// Background music on/off, separate from the effects.
  final ValueNotifier<bool> musicOn = ValueNotifier<bool>(true);

  final Map<String, AudioPool> _pools = {};
  final Map<String, _LowLatencyPool> _android = {};
  final Map<String, DateTime> _last = {};
  bool _battle = false;
  bool _foreground = true;
  AppLifecycleListener? _lifecycle;

  // Two players so one track can fade out while the next fades in.
  final List<AudioPlayer?> _players = [null, null];
  int _cur = 0;
  String? _track;
  String? _wanted = 'menu';
  Timer? _fade;
  bool _ready = false;

  /// iOS cannot play Ogg; everything else gets the gapless Ogg loops.
  static String get _ext =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS ? 'm4a' : 'ogg';

  double get _musicVolume => _battle ? 0.42 : 0.55;

  Future<void> init() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final old = prefs.getBool(_key);
      sfxOn.value = prefs.getBool('sfx_on') ?? old ?? true;
      musicOn.value = prefs.getBool('music_on') ?? old ?? true;
    } catch (_) {}
    // Nothing here needs audio focus; taking it would let each effect pause
    // the music on Android. The web plugin has no global context at all.
    if (!kIsWeb) {
      try {
        await AudioPlayer.global.setAudioContext(AudioContext(
          android: const AudioContextAndroid(audioFocus: AndroidAudioFocus.none),
          iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
        ));
      } catch (_) {}
    }
    // Music first, so the menu theme is not held up by twenty effects
    // loading one by one.
    for (var i = 0; i < 2; i++) {
      try {
        final p = AudioPlayer();
        await p.setReleaseMode(ReleaseMode.loop);
        _players[i] = p;
      } catch (_) {}
    }
    _ready = true;
    _lifecycle ??= AppLifecycleListener(onStateChange: (s) {
      _foreground = s == AppLifecycleState.resumed;
      _applyMusic();
    });
    if (_wanted != null) playMusic(_wanted!);
    for (final f in sfxFiles) {
      final size = f == 'hit' || f == 'swing' || f == 'shoot' ? 3 : 2;
      // Android MediaPlayer crashes some phones (Galaxy J7, Android 8) when
      // a pooled effect completes: audioplayers stops and re-prepares it
      // from a native callback. SoundPool has no completion callback.
      // If SoundPool fails, fall back to the MediaPlayer pool rather than
      // going silent.
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
        try {
          _android[f] = await _LowLatencyPool.create(sfxAsset(f), size)
              .timeout(const Duration(seconds: 5));
          continue;
        } catch (e) {
          debugPrint('SoundPool load failed for $f: $e');
        }
      }
      try {
        _pools[f] = await FlameAudio.createPool(
          sfxAsset(f),
          minPlayers: 1,
          maxPlayers: size,
        ).timeout(const Duration(seconds: 5));
      } catch (_) {}
    }
  }

  /// Switches the background music: 'menu', 'battle', or a map theme
  /// name (grass, bamboo, cave, desert, snow, volcano, fortress).
  void playMusic(String track) {
    _wanted = track;
    if (!_ready || !musicOn.value || !_foreground) return;
    if (track == _track) {
      _applyMusic();
      return;
    }
    final next = 1 - _cur;
    final incoming = _players[next];
    final outgoing = _players[_cur];
    if (incoming == null) return;
    _track = track;
    _cur = next;
    () async {
      try {
        await incoming.setVolume(0);
        await incoming
            .setSource(AssetSource('audio/music/$track.$_ext'))
            .timeout(const Duration(seconds: 8));
        // A newer request may have arrived while this one was loading.
        if (_track != track) return;
        await incoming.resume();
        _crossfade(incoming, outgoing);
      } catch (_) {}
    }();
  }

  void _crossfade(AudioPlayer incoming, AudioPlayer? outgoing) {
    _fade?.cancel();
    var step = 0;
    const steps = 16;
    final target = _musicVolume;
    _fade = Timer.periodic(const Duration(milliseconds: 50), (t) {
      step++;
      final k = step / steps;
      _guard(incoming.setVolume(target * k));
      if (outgoing != null) _guard(outgoing.setVolume(target * (1 - k)));
      if (step >= steps) {
        t.cancel();
        if (outgoing != null) _guard(outgoing.stop());
      }
    });
  }

  /// Slightly quieter music while fighting, so hits read clearly.
  void setBattle(bool v) {
    _battle = v;
    if (_fade?.isActive ?? false) return;
    _guard(_players[_cur]?.setVolume(_musicVolume));
  }

  void _applyMusic() {
    final m = _players[_cur];
    if (m == null || !_ready) return;
    final should = musicOn.value && _foreground;
    if (should && _track == null && _wanted != null) {
      playMusic(_wanted!);
      return;
    }
    final playing = m.state == PlayerState.playing;
    if (should && !playing && _track != null) {
      _guard(m.resume());
    } else if (!should && playing) {
      _guard(m.pause());
    }
  }

  /// Plays a world cue or a file name directly.
  void cue(String name, {double volume = 1}) {
    // Browsers refuse audio before the first tap; cues follow taps, so
    // this is where blocked music gets going.
    _applyMusic();
    if (!sfxOn.value) return;
    final file = _cues[name] ?? name;
    final now = DateTime.now();
    final last = _last[file];
    // Rapid repeats (a sweep hitting six monsters) collapse into one.
    if (last != null && now.difference(last).inMilliseconds < 70) return;
    _last[file] = now;
    try {
      final v = volume * (_battle ? 0.9 : 1);
      _pools[file]?.start(volume: v);
      _android[file]?.start(v);
    } catch (_) {}
  }

  Future<void> toggleSfx() async {
    sfxOn.value = !sfxOn.value;
    await _store('sfx_on', sfxOn.value);
  }

  Future<void> toggleMusic() async {
    musicOn.value = !musicOn.value;
    if (musicOn.value) {
      _track = null;
      if (_wanted != null) playMusic(_wanted!);
    } else {
      _applyMusic();
    }
    await _store('music_on', musicOn.value);
  }

  static Future<void> _store(String k, bool v) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(k, v);
    } catch (_) {}
  }

  static void _guard(Future<void>? f) {
    f?.catchError((Object _) {});
  }
}

/// A few SoundPool-backed players for one effect, used round-robin.
class _LowLatencyPool {
  _LowLatencyPool._(this._players);
  final List<AudioPlayer> _players;
  int _next = 0;

  static Future<_LowLatencyPool> create(String file, int size) async {
    final players = <AudioPlayer>[];
    for (var i = 0; i < size; i++) {
      final p = AudioPlayer()..audioCache = FlameAudio.audioCache;
      await p.setPlayerMode(PlayerMode.lowLatency);
      await p.setReleaseMode(ReleaseMode.stop);
      await p.setSource(AssetSource(file));
      players.add(p);
    }
    return _LowLatencyPool._(players);
  }

  void start(double volume) {
    final p = _players[_next];
    _next = (_next + 1) % _players.length;
    () async {
      try {
        // SoundPool never reports completion, so the player still counts
        // as playing; stop first or resume() is ignored.
        await p.stop();
        await p.setVolume(volume);
        await p.resume();
      } catch (_) {}
    }();
  }
}
