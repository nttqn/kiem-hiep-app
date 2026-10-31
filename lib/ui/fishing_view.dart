import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../core/fishing.dart';
import '../core/hero.dart';
import '../core/world_boss.dart';
import '../services/ads.dart';
import '../services/analytics.dart';
import '../services/save.dart';
import '../services/sound.dart';
import 'fish_book.dart';
import 'theme.dart';

enum _Fs { ready, waiting, bite, reel, caught, escaped }

/// The pond's mini-game, over the paused field: cast, wait for the float to
/// dip, strike in time, then strike again each time the needle crosses the
/// green mark. Rarer fish give a smaller mark, a faster needle and need
/// more strikes.
class FishingPanel extends StatefulWidget {
  const FishingPanel({super.key, required this.mapId, required this.onClose});
  final String mapId;
  final VoidCallback onClose;

  /// Dev build only: seconds before every bite, for screenshots.
  static double? debugBite;

  @override
  State<FishingPanel> createState() => _FishingPanelState();
}

class _FishingPanelState extends State<FishingPanel> with SingleTickerProviderStateMixin {
  HeroData get h => SaveService.instance.hero;
  final _rng = math.Random();
  late final Ticker _ticker;
  double _t = 0;

  _Fs _state = _Fs.ready;
  FishDef? _fish;
  double _biteAt = 0, _biteEnd = 0;
  int _hits = 0;
  double _zone = 0.5;
  double _phase = 0;
  String _message = '';
  List<String> _lines = const [];
  bool _adBusy = false;

  @override
  void initState() {
    super.initState();
    _ticker = createTicker((d) {
      final now = d.inMicroseconds / 1e6;
      final dt = now - _t;
      _t = now;
      _step(dt);
    })
      ..start();
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  int get _rar => _fish?.rarity.index ?? 0;

  /// Needle position 0..1, sweeping back and forth.
  double get _needle {
    final p = _phase % 2;
    return p < 1 ? p : 2 - p;
  }

  void _step(double dt) {
    switch (_state) {
      case _Fs.waiting:
        if (_t >= _biteAt) {
          SoundService.instance.cue('loot');
          setState(() {
            _state = _Fs.bite;
            _biteEnd = _t + 0.95 - 0.1 * _rar;
          });
          return;
        }
      case _Fs.bite:
        if (_t > _biteEnd) {
          _escape('Cá đã nhả mồi. Phải giật nhanh hơn!');
          return;
        }
      case _Fs.reel:
        _phase += dt * fishSpeed[_rar] * (1 + 0.12 * _hits);
      case _Fs.ready || _Fs.caught || _Fs.escaped:
        break;
    }
    setState(() {});
  }

  void _cast() {
    if (!h.fishCast(vnDayKey())) return;
    SaveService.instance.save();
    setState(() {
      _fish = rollFish(widget.mapId, _rng);
      _state = _Fs.waiting;
      _biteAt = _t + (FishingPanel.debugBite ?? 1.2 + _rng.nextDouble() * 2.6);
      _hits = 0;
      _phase = _rng.nextDouble();
    });
  }

  void _escape(String why) {
    setState(() {
      _state = _Fs.escaped;
      _message = why;
    });
  }

  void _newZone() {
    final w = fishZone[_rar];
    _zone = w / 2 + _rng.nextDouble() * (1 - w);
  }

  /// The strike button: in time on a bite, or on the mark while reeling.
  void _strike() {
    switch (_state) {
      case _Fs.waiting:
        _escape('Giật sớm quá, cá hoảng sợ bỏ đi.');
      case _Fs.bite:
        SoundService.instance.cue('hit');
        setState(() {
          _state = _Fs.reel;
          _newZone();
        });
      case _Fs.reel:
        final w = fishZone[_rar];
        if ((_needle - _zone).abs() > w / 2) {
          _escape('Trượt nhịp, ${_fish!.name} vùng thoát!');
          return;
        }
        SoundService.instance.cue('hit');
        _hits++;
        if (_hits >= fishHits[_rar]) {
          _land();
        } else {
          setState(_newZone);
        }
      case _Fs.ready || _Fs.caught || _Fs.escaped:
        break;
    }
  }

  void _land() {
    final f = _fish!;
    final lines = h.catchFish(f, _rng);
    SoundService.instance.cue(f.rarity.index >= 2 ? 'levelup' : 'loot');
    Analytics.instance.log('fish_catch', {'id': f.id, 'rarity': f.rarity.index});
    SaveService.instance.save();
    setState(() {
      _state = _Fs.caught;
      _lines = lines;
    });
  }

  Future<void> _adBait() async {
    if (_adBusy) return;
    setState(() => _adBusy = true);
    final earned = await AdsService.instance.showRewarded();
    if (!mounted) return;
    setState(() => _adBusy = false);
    if (earned && h.fishAddAd(vnDayKey())) {
      SaveService.instance.save();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    h.fishRollDay(vnDayKey());
    final f = _fish;
    final bait = h.fishBaitLeft;
    final playing = _state == _Fs.waiting || _state == _Fs.bite || _state == _Fs.reel;
    return Panel(
      padding: const EdgeInsets.all(14),
      child: SizedBox(
        width: 540,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.phishing, color: goldLight),
                const SizedBox(width: 6),
                Text('Câu cá', style: titleStyle(22)),
                const SizedBox(width: 10),
                Visibility(
                  visible: !playing,
                  maintainSize: true,
                  maintainAnimation: true,
                  maintainState: true,
                  child: LButton(
                    label: 'Ngư phổ',
                    small: true,
                    color: const Color(0xFF2E6A8A),
                    onTap: () => showFishBook(context, h).then((_) => setState(() {})),
                  ),
                ),
                const Spacer(),
                Text('Mồi câu: $bait', style: bold.copyWith(color: bait > 0 ? cream : const Color(0xFFFF8A7A))),
              ],
            ),
            const SizedBox(height: 6),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: playing ? (_) => _strike() : null,
              child: SizedBox(
                height: 130,
                child: CustomPaint(
                  painter: _PondPainter(
                    t: _t,
                    state: _state,
                    needle: _needle,
                    zone: _zone,
                    zoneW: fishZone[_rar],
                    hits: _hits,
                    need: fishHits[_rar],
                    fishColor: f == null ? null : Color(fishRarityColors[f.rarity.index]),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(height: 62, child: _status(f)),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: playing
                      ? LButton(label: 'Giật cần!', color: seal, onTap: _strike)
                      : LButton(
                          label: _state == _Fs.ready ? 'Thả câu' : 'Câu tiếp',
                          color: jade,
                          enabled: bait > 0,
                          onTap: _cast,
                        ),
                ),
                const SizedBox(width: 8),
                // Shown (greyed) while reeling too: popping in when a fish
                // landed put it under a finger still tapping "Giật cần!".
                if (h.fishAds == 0)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: LButton(
                      label: '+$fishAdBait mồi',
                      icon: Icons.ondemand_video,
                      small: true,
                      color: const Color(0xFF7A5A1A),
                      enabled: !playing && !_adBusy,
                      onTap: _adBait,
                    ),
                  ),
                LButton(label: 'Rời đi', small: true, color: const Color(0xFF5A4A3A), onTap: playing ? null : widget.onClose),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _status(FishDef? f) {
    switch (_state) {
      case _Fs.ready:
        return Text(
          'Thả câu rồi chờ phao chìm. Khi thấy "!", chạm Giật cần thật nhanh; sau đó chạm mỗi lần kim chạy vào vạch xanh. '
          'Cá càng quý vạch càng hẹp.',
          style: small,
        );
      case _Fs.waiting:
        return Center(child: Text('Đang chờ cá cắn câu…', style: body.copyWith(color: creamDim)));
      case _Fs.bite:
        return Center(child: Text('CẮN CÂU! Giật ngay!', style: titleStyle(22, color: const Color(0xFFFF8A5A))));
      case _Fs.reel:
        return Center(
          child: Text('Kéo cá: ${_hits + 1}/${fishHits[_rar]} · chạm khi kim vào vạch xanh',
              style: bold.copyWith(color: cream)),
        );
      case _Fs.caught:
        final c = Color(fishRarityColors[f!.rarity.index]);
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${f.name} [${fishRarityNames[f.rarity.index]}]', style: bold.copyWith(color: c, fontSize: 16)),
            Text(f.desc, style: small.copyWith(fontStyle: FontStyle.italic), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(_lines.join(' · '), style: small.copyWith(color: cream), maxLines: 1, overflow: TextOverflow.ellipsis),
          ],
        );
      case _Fs.escaped:
        return Center(child: Text(_message, style: body.copyWith(color: const Color(0xFFFF9A7A))));
    }
  }
}

class _PondPainter extends CustomPainter {
  _PondPainter({
    required this.t,
    required this.state,
    required this.needle,
    required this.zone,
    required this.zoneW,
    required this.hits,
    required this.need,
    required this.fishColor,
  });

  final double t;
  final _Fs state;
  final double needle, zone, zoneW;
  final int hits, need;
  final Color? fishColor;

  @override
  void paint(Canvas c, Size s) {
    final r = RRect.fromRectAndRadius(Offset.zero & s, const Radius.circular(10));
    c.drawRRect(
        r,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF3A7A9A), Color(0xFF16384A)],
          ).createShader(Offset.zero & s));
    // Light on the water.
    for (var k = 0; k < 6; k++) {
      final x = (k * 97 + t * 18) % s.width;
      c.drawLine(Offset(x, 20.0 + k * 17), Offset(x + 30, 20.0 + k * 17),
          Paint()
            ..color = const Color(0x22FFFFFF)
            ..strokeWidth = 2);
    }
    final fx = s.width * 0.5;
    final reel = state == _Fs.reel;
    final waterY = reel ? 40.0 : s.height * 0.5;
    // The line from the top edge to the float.
    final bob = switch (state) {
      _Fs.waiting => math.sin(t * 3) * 2,
      _Fs.bite => 8 + math.sin(t * 30) * 4,
      _ => 0.0,
    };
    final floatY = waterY + bob;
    c.drawLine(Offset(fx - 120, 0), Offset(fx, floatY - 10),
        Paint()
          ..color = const Color(0xAAFFFFFF)
          ..strokeWidth = 1);
    if (state != _Fs.caught && state != _Fs.escaped) {
      c.drawOval(Rect.fromCenter(center: Offset(fx, waterY + 4), width: 34 + bob.abs() * 2, height: 8),
          Paint()
            ..color = const Color(0x55FFFFFF)
            ..style = PaintingStyle.stroke);
      c.drawOval(Rect.fromCenter(center: Offset(fx, floatY - 4), width: 10, height: 16), Paint()..color = const Color(0xFFE84B3A));
      c.drawOval(Rect.fromCenter(center: Offset(fx, floatY + 3), width: 10, height: 8), Paint()..color = const Color(0xFFF3E6C8));
    }
    if (state == _Fs.bite) {
      final tp = TextPainter(
        text: const TextSpan(text: '!', style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900, color: Color(0xFFFFD34A))),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(c, Offset(fx + 18, floatY - 50));
    }
    if (fishColor != null && (state == _Fs.reel || state == _Fs.caught)) {
      // The fish's shadow thrashing under the surface.
      final sx = fx + math.sin(t * (state == _Fs.reel ? 7 : 2)) * 30;
      final body = Paint()..color = fishColor!.withValues(alpha: state == _Fs.caught ? 0.9 : 0.45);
      c.drawOval(Rect.fromCenter(center: Offset(sx, waterY + 26), width: 56, height: 20), body);
      c.drawPath(
          Path()
            ..moveTo(sx - 26, waterY + 26)
            ..lineTo(sx - 42, waterY + 16)
            ..lineTo(sx - 42, waterY + 36)
            ..close(),
          body);
    }
    if (reel) {
      // The strike bar: green mark, the needle, and strikes so far.
      final bar = Rect.fromLTWH(24, s.height - 34, s.width - 48, 20);
      c.drawRRect(RRect.fromRectAndRadius(bar, const Radius.circular(6)), Paint()..color = const Color(0xCC120A08));
      final zx = bar.left + bar.width * (zone - zoneW / 2);
      c.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(zx, bar.top + 2, bar.width * zoneW, bar.height - 4), const Radius.circular(4)),
          Paint()..color = const Color(0xFF5AD07A));
      final nx = bar.left + bar.width * needle;
      c.drawRect(Rect.fromLTWH(nx - 2, bar.top - 6, 4, bar.height + 12), Paint()..color = const Color(0xFFFFD34A));
      for (var k = 0; k < need; k++) {
        c.drawCircle(Offset(bar.right - 8 - k * 16.0, bar.top - 12), 5,
            Paint()..color = k < hits ? const Color(0xFF5AD07A) : const Color(0x66FFFFFF));
      }
    }
  }

  @override
  bool shouldRepaint(_PondPainter old) => true;
}
