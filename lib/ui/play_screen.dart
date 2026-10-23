import 'dart:async';
import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/content.dart';
import '../core/tower.dart';
import '../core/hero.dart';
import '../core/world.dart';
import '../game/battle_game.dart';
import '../services/ads.dart';
import '../services/save.dart';
import '../services/sound.dart';
import 'hud.dart';
import 'theme.dart';

class PlayScreen extends StatefulWidget {
  const PlayScreen.field(MapDef this.map, {super.key}) : dungeon = null;
  const PlayScreen.dungeon(DungeonDef this.dungeon, {super.key}) : map = null;

  final MapDef? map;
  final DungeonDef? dungeon;

  /// Dev build only: battle without the HUD, for thumbnails.
  static bool debugHideHud = false;

  @override
  State<PlayScreen> createState() => _PlayScreenState();
}

class _Toast {
  _Toast(this.text, this.color, this.at);
  final String text;
  final Color color;
  final double at;
}

class _PlayScreenState extends State<PlayScreen> {
  late final HeroData hero = SaveService.instance.hero;
  late final World world;
  late final BattleGame game;
  final List<_Toast> _toasts = [];
  String? _banner;
  Color _bannerColor = goldLight;
  double _bannerAt = -10;
  bool _paused = false;
  bool _dead = false;
  bool? _cleared;
  int _stars = 0;
  Timer? _autosave;
  final Stopwatch _clock = Stopwatch()..start();
  double get _now => _clock.elapsedMilliseconds / 1000;

  // Joystick.
  int? _joyPointer;
  Offset? _joyBase;
  Offset _joyKnob = Offset.zero;
  static const _joyRadius = 56.0;

  final Set<LogicalKeyboardKey> _keys = {};

  @override
  void initState() {
    super.initState();
    world = widget.dungeon != null
        ? World.dungeon(hero, widget.dungeon!)
        : World.field(hero, widget.map!);
    world.auto = SaveService.instance.autoFight;
    game = BattleGame(world: world, onEvent: _onEvent, onSound: SoundService.instance.cue);
    SoundService.instance.setBattle(true);
    // Each map has its own tune; every dungeon shares the battle theme.
    SoundService.instance.playMusic(widget.dungeon != null ? 'battle' : widget.map!.theme.name);
    HardwareKeyboard.instance.addHandler(_onKey);
    _autosave = Timer.periodic(const Duration(seconds: 20), (_) => SaveService.instance.save());
    game.hudTick.addListener(_pruneToasts);
    final name = widget.dungeon?.name ?? widget.map!.name;
    _showBanner(name, goldLight);
  }

  @override
  void dispose() {
    HardwareKeyboard.instance.removeHandler(_onKey);
    _autosave?.cancel();
    _bannerTimer?.cancel();
    game.hudTick.removeListener(_pruneToasts);
    SaveService.instance.save();
    super.dispose();
  }

  void _pruneToasts() {
    final before = _toasts.length;
    _toasts.removeWhere((t) => _now - t.at > 3.2);
    if (before != _toasts.length) setState(() {});
  }

  void _showBanner(String text, Color c) {
    setState(() {
      _banner = text;
      _bannerColor = c;
      _bannerAt = _now;
    });
    // The HUD tick does not rebuild the banner, so clear it on time.
    _bannerTimer?.cancel();
    _bannerTimer = Timer(const Duration(milliseconds: 2700), () {
      if (mounted) setState(() => _banner = null);
    });
  }

  Timer? _bannerTimer;

  void _toast(String text, Color c) {
    setState(() {
      _toasts.add(_Toast(text, c, _now));
      if (_toasts.length > 4) _toasts.removeAt(0);
    });
  }

  void _onEvent(GameEvent e) {
    switch (e.kind) {
      case EvKind.notice:
        if (e.text.startsWith('THĂNG CẤP')) SoundService.instance.cue('levelup');
        if (e.text.startsWith('Hoàn thành') || e.text.startsWith('Hằng ngày')) {
          SoundService.instance.cue('quest');
        }
        if (e.big) {
          _showBanner(e.text, Color(e.color));
        } else {
          _toast(e.text, Color(e.color));
        }
        SaveService.instance.save();
      case EvKind.loot:
        _toast(e.text, Color(e.color));
      case EvKind.wave || EvKind.boss:
        SoundService.instance.cue('gong');
        _showBanner(e.text, Color(e.color));
      case EvKind.heroDied:
        setState(() => _dead = true);
      case EvKind.cleared:
        SaveService.instance.save();
        setState(() {
          _cleared = true;
          _stars = e.value.round();
        });
      case EvKind.failed:
        SaveService.instance.save();
        setState(() => _cleared = false);
      case EvKind.shake:
        break;
    }
  }

  void _setPaused(bool v) {
    setState(() => _paused = v);
    game.halted = v || _dead || _cleared != null;
    if (v) SaveService.instance.save();
  }

  void _leave() {
    SaveService.instance.save();
    // Not in dispose: "Đánh lại" builds the next play screen before this
    // one is disposed, and must keep its own music.
    SoundService.instance.setBattle(false);
    SoundService.instance.playMusic('menu');
    Navigator.of(context).pop();
    // A full-screen ad only ever on the walk back to town, and rarely.
    AdsService.instance.maybeShowInterstitial();
  }

  bool _doubled = false;
  bool _adBusy = false;

  /// Plays a rewarded ad and runs [reward] if it was watched through.
  Future<void> _watchAd(VoidCallback reward) async {
    if (_adBusy) return;
    setState(() => _adBusy = true);
    final earned = await AdsService.instance.showRewarded();
    if (!mounted) return;
    setState(() => _adBusy = false);
    if (earned) {
      reward();
    } else {
      _toast('Chưa xem hết quảng cáo, chưa nhận thưởng', const Color(0xFFFF8A7A));
    }
  }

  Widget _adButton(String label, VoidCallback reward) {
    return ValueListenableBuilder<bool>(
      valueListenable: AdsService.instance.rewardedReady,
      builder: (_, ready, _) => LButton(
        label: ready ? label : 'Quảng cáo đang tải…',
        icon: Icons.ondemand_video,
        width: 280,
        color: const Color(0xFF8A5A10),
        enabled: ready && !_adBusy,
        onTap: () => _watchAd(reward),
      ),
    );
  }

  // ------------------------------------------------------------ input

  bool _onKey(KeyEvent e) {
    if (!mounted) return false;
    final k = e.logicalKey;
    final down = e is KeyDownEvent || e is KeyRepeatEvent;
    if (e is KeyDownEvent) {
      _keys.add(k);
      if (k == LogicalKeyboardKey.escape || k == LogicalKeyboardKey.keyP) {
        if (!_dead && _cleared == null) _setPaused(!_paused);
      }
      const skillKeys = [
        [LogicalKeyboardKey.digit1, LogicalKeyboardKey.keyU],
        [LogicalKeyboardKey.digit2, LogicalKeyboardKey.keyI],
        [LogicalKeyboardKey.digit3, LogicalKeyboardKey.keyO],
        [LogicalKeyboardKey.digit4, LogicalKeyboardKey.keyK],
        [LogicalKeyboardKey.digit5, LogicalKeyboardKey.keyL],
      ];
      for (var i = 0; i < skillKeys.length; i++) {
        if (skillKeys[i].contains(k)) _useSkill(i);
      }
      if (k == LogicalKeyboardKey.keyQ) world.input.hpPot = true;
      if (k == LogicalKeyboardKey.keyE) world.input.mpPot = true;
      if (k == LogicalKeyboardKey.keyT) _toggleAuto();
    } else if (e is KeyUpEvent) {
      _keys.remove(k);
    }
    if (!down && e is! KeyUpEvent) return false;
    bool any(List<LogicalKeyboardKey> ks) => ks.any(_keys.contains);
    if (_joyPointer == null) {
      var x = 0.0, y = 0.0;
      if (any([LogicalKeyboardKey.keyA, LogicalKeyboardKey.arrowLeft])) x -= 1;
      if (any([LogicalKeyboardKey.keyD, LogicalKeyboardKey.arrowRight])) x += 1;
      if (any([LogicalKeyboardKey.keyW, LogicalKeyboardKey.arrowUp])) y -= 1;
      if (any([LogicalKeyboardKey.keyS, LogicalKeyboardKey.arrowDown])) y += 1;
      world.input.moveX = x;
      world.input.moveY = y;
    }
    world.input.attack = any([LogicalKeyboardKey.keyJ, LogicalKeyboardKey.space]);
    return false;
  }

  /// Skill buttons map to the active skills in sect order: four on the arc,
  /// then the tuyệt kỹ.
  List<int> get _activeIdx => [
        for (var i = 0; i < hero.sect.skills.length; i++)
          if (!hero.sect.skills[i].isPassive) i,
      ];

  void _useSkill(int slot) {
    final idx = _activeIdx;
    if (slot < idx.length) world.input.skills.add(idx[slot]);
  }

  void _toggleAuto() {
    world.auto = !world.auto;
    SaveService.instance.setAuto(world.auto);
    _toast(world.auto ? 'Bật tự động đánh' : 'Tắt tự động đánh', goldLight);
  }

  void _joyDown(PointerDownEvent e) {
    if (_joyPointer != null) return;
    setState(() {
      _joyPointer = e.pointer;
      _joyBase = e.localPosition;
      _joyKnob = Offset.zero;
    });
  }

  void _joyMove(PointerMoveEvent e) {
    if (e.pointer != _joyPointer || _joyBase == null) return;
    var d = e.localPosition - _joyBase!;
    if (d.distance > _joyRadius * 1.3) {
      // Drag the base along so the stick never "runs out".
      _joyBase = e.localPosition - d / d.distance * _joyRadius * 1.3;
      d = e.localPosition - _joyBase!;
    }
    final len = math.min(d.distance, _joyRadius);
    final dir = d.distance > 0 ? d / d.distance : Offset.zero;
    setState(() => _joyKnob = dir * len);
    final mag = len / _joyRadius;
    world.input.moveX = mag < 0.15 ? 0 : dir.dx * mag;
    world.input.moveY = mag < 0.15 ? 0 : dir.dy * mag;
  }

  void _joyUp(PointerEvent e) {
    if (e.pointer != _joyPointer) return;
    setState(() {
      _joyPointer = null;
      _joyBase = null;
      _joyKnob = Offset.zero;
    });
    world.input.moveX = 0;
    world.input.moveY = 0;
  }

  // ------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_dead || _cleared != null) return;
        _setPaused(!_paused);
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: LayoutBuilder(
          builder: (context, box) {
            final size = box.biggest;
            return Stack(
              children: [
                Positioned.fill(child: GameWidget(game: game)),
                // Joystick zone: the left half under the HUD.
                Positioned(
                  left: 0,
                  top: 0,
                  bottom: 0,
                  width: size.width * 0.48,
                  child: Listener(
                    behavior: HitTestBehavior.opaque,
                    onPointerDown: _joyDown,
                    onPointerMove: _joyMove,
                    onPointerUp: _joyUp,
                    onPointerCancel: _joyUp,
                  ),
                ),
                Positioned.fill(
                  child: SafeArea(
                    child: ValueListenableBuilder<int>(
                      valueListenable: game.hudTick,
                      builder: (_, _, _) => PlayScreen.debugHideHud ? const SizedBox.shrink() : _hud(size),
                    ),
                  ),
                ),
                if (_banner != null && _now - _bannerAt < 2.6) _bannerView(),
                if (_paused) _pauseOverlay(),
                if (_dead) _deadOverlay(),
                if (_cleared != null) _resultOverlay(),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _hud(Size size) {
    final ids = _activeIdx;
    return Stack(
      children: [
        Positioned(left: 8, top: 6, child: HeroFrame(world: world)),
        Positioned(left: 8, top: 80, child: QuestTracker(hero: hero)),
        Positioned(
          left: 0,
          right: 0,
          top: 4,
          child: Center(child: TopInfo(world: world)),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 64,
          child: IgnorePointer(
            child: Column(
              children: [
                for (final t in _toasts)
                  Opacity(
                    opacity: (1 - math.max(0, _now - t.at - 2.4) / 0.8).clamp(0, 1),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 3),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xAA120A08),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(t.text, style: bold.copyWith(fontSize: 13, color: t.color)),
                    ),
                  ),
              ],
            ),
          ),
        ),
        Positioned(
          right: 8,
          top: 6,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Column(
                children: [
                  RoundIcon(icon: Icons.pause, onTap: () => _setPaused(true)),
                  const SizedBox(height: 6),
                  AutoToggle(on: world.auto, onTap: _toggleAuto),
                ],
              ),
              const SizedBox(width: 6),
              if (world.mode == WorldMode.field) MiniMap(world: world),
            ],
          ),
        ),
        Positioned(left: 60, right: 60, bottom: 2, child: ExpStrip(hero: hero)),
        if (_joyBase != null)
          Positioned(
            left: _joyBase!.dx - _joyRadius,
            top: _joyBase!.dy - _joyRadius - MediaQuery.paddingOf(context).top,
            child: IgnorePointer(child: JoystickView(knob: _joyKnob, radius: _joyRadius)),
          )
        else
          Positioned(
            left: 70,
            bottom: 40,
            child: IgnorePointer(
              child: Opacity(opacity: 0.45, child: JoystickView(knob: Offset.zero, radius: _joyRadius)),
            ),
          ),
        // Combat buttons.
        Positioned(
          right: 18,
          bottom: 22,
          child: SizedBox(
            width: 290,
            height: 225,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: AttackButton(
                    hanh: hero.hanh,
                    onDown: () => world.input.attack = true,
                    onUp: () => world.input.attack = false,
                  ),
                ),
                for (var k = 0; k < ids.length && k < 4; k++)
                  _skillAt(k, ids[k]),
                if (ids.length > 4 && hero.skillOpen(ids[4])) _ultimateAt(ids[4]),
                Positioned(
                  left: 0,
                  bottom: 0,
                  child: PotionButton(
                    count: hero.hpPots,
                    color: const Color(0xFFE84B4A),
                    ready: world.player.potCd <= 0,
                    onTap: () => world.input.hpPot = true,
                  ),
                ),
                Positioned(
                  left: 0,
                  bottom: 58,
                  child: PotionButton(
                    count: hero.mpPots,
                    color: const Color(0xFF4A7AE8),
                    ready: world.player.potCd <= 0,
                    onTap: () => world.input.mpPot = true,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _skillAt(int k, int idx) {
    // An arc from left of the attack button up to above it.
    const r = 120.0;
    final a = math.pi + k * (math.pi / 2) / 3;
    final cx = 290 - 42 + math.cos(a) * r;
    final cy = 225 - 42 + math.sin(a) * r;
    const s = 56.0;
    final sk = hero.sect.skills[idx];
    final lv = hero.skillLv[idx];
    final cd = world.player.cd[idx];
    return Positioned(
      left: cx - s / 2,
      top: cy - s / 2,
      child: SkillButton(
        skill: sk,
        hanh: hero.hanh,
        size: s,
        learned: lv > 0,
        unlockLevel: sk.unlock,
        cooldown: lv > 0 && cd > 0 ? (cd / (sk.cooldown * (1 - hero.stats.cdr))).clamp(0, 1) : 0,
        cdText: cd >= 0.1 ? cd.toStringAsFixed(cd < 1 ? 1 : 0) : null,
        noMp: lv > 0 && world.player.mp < sk.mpAt(lv),
        onTap: () => world.input.skills.add(idx),
      ),
    );
  }

  /// The tuyệt kỹ: a bigger button above the potions, shown from level 60.
  Widget _ultimateAt(int idx) {
    const s = 64.0;
    final sk = hero.sect.skills[idx];
    final lv = hero.skillLv[idx];
    final cd = world.player.cd[idx];
    return Positioned(
      left: -6,
      bottom: 116,
      child: SkillButton(
        skill: sk,
        hanh: hero.hanh,
        size: s,
        learned: lv > 0,
        unlockLevel: sk.unlock,
        cooldown: lv > 0 && cd > 0 ? (cd / (sk.cooldown * (1 - hero.stats.cdr))).clamp(0, 1) : 0,
        cdText: cd >= 0.1 ? cd.toStringAsFixed(cd < 1 ? 1 : 0) : null,
        noMp: lv > 0 && world.player.mp < sk.mpAt(lv),
        onTap: () => world.input.skills.add(idx),
      ),
    );
  }

  Widget _bannerView() {
    final age = _now - _bannerAt;
    final a = age < 0.2 ? age / 0.2 : (age > 2.0 ? (2.6 - age) / 0.6 : 1.0);
    return Positioned(
      left: 0,
      right: 0,
      top: MediaQuery.sizeOf(context).height * 0.26,
      child: IgnorePointer(
        child: Opacity(
          opacity: a.clamp(0, 1),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0x00120A08), Color(0xCC120A08), Color(0x00120A08)]),
                border: Border.symmetric(horizontal: BorderSide(color: _bannerColor.withValues(alpha: 0.7))),
              ),
              child: Text(_banner!, style: titleStyle(26, color: _bannerColor)),
            ),
          ),
        ),
      ),
    );
  }

  Widget _dim(Widget child) => Positioned.fill(
        child: Container(
          color: const Color(0xAA000000),
          alignment: Alignment.center,
          child: child,
        ),
      );

  Widget _pauseOverlay() {
    return _dim(
      Panel(
        padding: const EdgeInsets.all(18),
        child: SizedBox(
          width: 340,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Tạm dừng', style: titleStyle(26)),
              const SizedBox(height: 6),
              Text('${hero.name} · Cấp ${hero.level} · ${fmt(hero.gold)} lượng', style: small),
              const SizedBox(height: 14),
              LButton(label: 'Tiếp tục', width: 240, color: jade, onTap: () => _setPaused(false)),
              const SizedBox(height: 8),
              LButton(label: 'Về thành', width: 240, onTap: _leave),
              const SizedBox(height: 8),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ValueListenableBuilder<bool>(
                    valueListenable: SoundService.instance.musicOn,
                    builder: (_, on, _) => LButton(
                      label: on ? 'Nhạc: Bật' : 'Nhạc: Tắt',
                      width: 116,
                      small: true,
                      color: const Color(0xFF5A4A3A),
                      icon: on ? Icons.music_note : Icons.music_off,
                      onTap: SoundService.instance.toggleMusic,
                    ),
                  ),
                  const SizedBox(width: 8),
                  ValueListenableBuilder<bool>(
                    valueListenable: SoundService.instance.sfxOn,
                    builder: (_, on, _) => LButton(
                      label: on ? 'Tiếng: Bật' : 'Tiếng: Tắt',
                      width: 116,
                      small: true,
                      color: const Color(0xFF5A4A3A),
                      icon: on ? Icons.volume_up : Icons.volume_off,
                      onTap: SoundService.instance.toggleSfx,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text('Bàn phím: WASD đi · J/Space đánh · 1-4 chiêu · Q/E thuốc · T tự động',
                  style: small.copyWith(fontSize: 11), textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }

  void _resume() {
    setState(() => _dead = false);
    game.halted = _paused;
  }

  Widget _deadOverlay() {
    game.halted = true;
    final inDungeon = widget.dungeon != null;
    return _dim(
      Panel(
        padding: const EdgeInsets.all(18),
        child: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Trọng thương!', style: titleStyle(28, color: const Color(0xFFFF7A6A))),
              const SizedBox(height: 6),
              Text(
                inDungeon
                    ? 'Bạn ngã xuống giữa ải. Có thể hồi sinh tại chỗ một lần.'
                    : 'Bạn bị đánh bại. Hồi sinh ở cổng sẽ mất 3% kinh nghiệm của cấp hiện tại.',
                style: body,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 14),
              _adButton('Hồi sinh tại chỗ', () {
                world.reviveHere();
                _resume();
              }),
              const SizedBox(height: 8),
              if (inDungeon)
                LButton(
                  label: 'Bỏ cuộc',
                  width: 280,
                  onTap: () {
                    setState(() => _dead = false);
                    world.giveUp();
                    game.halted = false;
                  },
                )
              else ...[
                LButton(
                  label: 'Hồi sinh ở cổng',
                  width: 280,
                  color: jade,
                  onTap: () {
                    world.revive();
                    _resume();
                  },
                ),
                const SizedBox(height: 8),
                LButton(
                  label: 'Về thành',
                  width: 280,
                  onTap: () {
                    world.revive();
                    _leave();
                  },
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _resultOverlay() {
    final ok = _cleared == true;
    final d = widget.dungeon!;
    if (d.isTower) return _towerResult(ok, d);
    return _dim(
      Panel(
        padding: const EdgeInsets.all(18),
        child: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(ok ? 'Vượt ải thành công!' : 'Vượt ải thất bại',
                  style: titleStyle(26, color: ok ? goldLight : const Color(0xFFFF7A6A))),
              const SizedBox(height: 6),
              if (ok) ...[
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (var i = 0; i < 3; i++)
                      Icon(i < _stars ? Icons.star : Icons.star_border, color: goldLight, size: 40),
                  ],
                ),
                Text('Thời gian: ${world.finishTime.toStringAsFixed(1)} giây '
                    '(3 sao ≤ ${d.threeStar.round()}s, 2 sao ≤ ${d.twoStar.round()}s)',
                    style: small),
                const SizedBox(height: 6),
                for (final l in world.rewardLines) Text(l, style: bold.copyWith(color: cream)),
                const SizedBox(height: 10),
                if (!_doubled)
                  _adButton('Nhân đôi lượng & kinh nghiệm', () {
                    hero.gold += hero.lastDungeonGold;
                    hero.gainExp(hero.lastDungeonExp);
                    SaveService.instance.save();
                    setState(() => _doubled = true);
                    _toast('+${hero.lastDungeonGold} lượng · +${hero.lastDungeonExp.round()} kinh nghiệm',
                        goldLight);
                  })
                else
                  Text('Đã nhân đôi phần thưởng!', style: bold.copyWith(color: goldLight)),
              ] else
                Text('Hãy luyện thêm cấp, nâng trang bị rồi quay lại.', style: body),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  LButton(label: 'Về thành', onTap: _leave),
                  const SizedBox(width: 10),
                  LButton(
                    label: 'Đánh lại',
                    color: jade,
                    onTap: () {
                      SaveService.instance.save();
                      Navigator.of(context).pushReplacement(fadeRoute(PlayScreen.dungeon(d)));
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Tower floor done or failed: climb on, retry, or go home.
  Widget _towerResult(bool ok, DungeonDef d) {
    final next = ok ? d.floor + 1 : d.floor;
    return _dim(
      Panel(
        padding: const EdgeInsets.all(18),
        child: SizedBox(
          width: 380,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(ok ? 'Vượt tầng ${d.floor}!' : 'Dừng bước ở tầng ${d.floor}',
                  style: titleStyle(26, color: ok ? goldLight : const Color(0xFFFF7A6A))),
              const SizedBox(height: 4),
              Text('Tầng cao nhất: ${hero.towerBest}', style: small),
              const SizedBox(height: 8),
              if (ok) ...[
                for (final l in world.rewardLines) Text(l, style: bold.copyWith(color: cream)),
                const SizedBox(height: 10),
                if (hero.lastDungeonGold > 0 && !_doubled)
                  _adButton('Nhân đôi lượng & kinh nghiệm', () {
                    hero.gold += hero.lastDungeonGold;
                    hero.gainExp(hero.lastDungeonExp);
                    SaveService.instance.save();
                    setState(() => _doubled = true);
                    _toast('+${hero.lastDungeonGold} lượng', goldLight);
                  })
                else if (_doubled)
                  Text('Đã nhân đôi phần thưởng!', style: bold.copyWith(color: goldLight)),
              ] else
                Text('Quái tầng này quá mạnh. Hãy nâng trang bị, ngọc, kỹ năng rồi thử lại.', style: body),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  LButton(label: 'Về thành', onTap: _leave),
                  const SizedBox(width: 10),
                  LButton(
                    label: ok ? 'Lên tầng $next' : 'Thử lại',
                    color: jade,
                    onTap: () {
                      SaveService.instance.save();
                      Navigator.of(context).pushReplacement(fadeRoute(PlayScreen.dungeon(towerFloor(next))));
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
