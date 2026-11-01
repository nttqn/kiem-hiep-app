import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/duel.dart';
import '../core/hero.dart';
import '../services/analytics.dart';
import '../services/cloud.dart';
import '../services/duel.dart';
import '../services/save.dart';
import 'cloud_panel.dart';
import 'play_screen.dart';
import 'sub_screen.dart';
import 'theme.dart';

/// Tỷ võ lobby (trial): open a room and share its code, or join a friend's.
class DuelScreen extends StatefulWidget {
  const DuelScreen({super.key});

  @override
  State<DuelScreen> createState() => _DuelScreenState();
}

class _DuelScreenState extends State<DuelScreen> {
  HeroData get h => SaveService.instance.hero;
  DuelService get svc => DuelService.instance;

  String? _code;
  bool _busy = false;
  String? _error;
  bool _started = false;
  StreamSubscription<DuelInfo>? _wait;
  final _input = TextEditingController();

  DuelInfo? get _me {
    final uid = svc.uid;
    return uid == null ? null : DuelInfo.of(h, uid);
  }

  @override
  void dispose() {
    _wait?.cancel();
    _input.dispose();
    // A room nobody came to goes away with the screen.
    final code = _code;
    if (code != null && !_started) svc.close(code);
    super.dispose();
  }

  Future<void> _create() async {
    final me = _me;
    if (me == null) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final code = await svc.create(me);
      if (!mounted) return;
      setState(() {
        _code = code;
        _busy = false;
      });
      _wait = svc.guestOf(code).listen((foe) => _start(DuelRoom(code, host: true, foe: foe)));
    } catch (e) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Không tạo được phòng, kiểm tra mạng rồi thử lại';
        });
      }
    }
  }

  void _cancel() {
    final code = _code;
    _wait?.cancel();
    setState(() => _code = null);
    if (code != null) svc.close(code);
  }

  Future<void> _join() async {
    final me = _me;
    final code = _input.text.trim();
    if (me == null || code.length != 6) {
      setState(() => _error = 'Nhập đủ 6 số mã phòng');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final (foe, why) = await svc.join(code, me);
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = why;
    });
    if (foe != null) _start(DuelRoom(code, host: false, foe: foe));
  }

  void _start(DuelRoom room) {
    if (_started || !mounted) return;
    _started = true;
    _wait?.cancel();
    Analytics.instance.log('duel_start', {'host': room.host ? 1 : 0, 'level': h.level});
    Navigator.of(context).pushReplacement(fadeRoute(PlayScreen.duel(room)));
  }

  @override
  Widget build(BuildContext context) {
    return SubScreen(
      title: 'Tỷ võ (thử nghiệm)',
      child: ListenableBuilder(
        listenable: CloudSave.instance,
        builder: (context, _) => _body(),
      ),
    );
  }

  Widget _body() {
    if (h.level < duelOpenLevel && h.rebirths == 0) {
      return Center(child: Text('Tỷ võ mở ở cấp $duelOpenLevel', style: titleStyle(20)));
    }
    if (!svc.available || svc.uid == null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Đăng nhập để tỷ võ với bạn bè', style: titleStyle(20)),
            const SizedBox(height: 6),
            Text('Cần đăng nhập Google hoặc Apple (Lưu trữ đám mây) để tạo hay vào phòng.', style: body),
            const SizedBox(height: 12),
            if (svc.available)
              LButton(label: 'Đăng nhập', icon: Icons.cloud, color: jade, onTap: () => showCloudPanel(context)),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Panel(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          child: Text(
            'Đấu trực tiếp 1-1 với người chơi khác trong 2 phút. Dùng chỉ số thật, không bình máu, '
            'không linh thú, hiệp khách hay tự động; sát thương hai bên giảm một nửa. Hết giờ, ai còn nhiều '
            '% sinh lực hơn thắng. Bản thử nghiệm: chưa có thưởng, mạng chậm có thể giật.',
            style: small.copyWith(fontSize: 11.5, color: cream),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _hostPanel()),
              const SizedBox(width: 10),
              Expanded(child: _joinPanel()),
            ],
          ),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(_error!, style: bold.copyWith(color: const Color(0xFFFF8A7A)), textAlign: TextAlign.center),
          ),
      ],
    );
  }

  Widget _hostPanel() {
    final code = _code;
    return Panel(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Text('Tạo phòng', style: titleStyle(20)),
          const Spacer(),
          if (code == null) ...[
            Text('Tạo phòng rồi gửi mã cho bạn.', style: body, textAlign: TextAlign.center),
            const SizedBox(height: 10),
            LButton(label: 'Tạo phòng', icon: Icons.add, color: jade, enabled: !_busy, onTap: _create),
          ] else ...[
            Text('Mã phòng', style: small),
            GestureDetector(
              onTap: () {
                Clipboard.setData(ClipboardData(text: code));
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Đã chép mã phòng'), duration: Duration(seconds: 1)));
              },
              child: Text(code, style: titleStyle(40, color: goldLight).copyWith(letterSpacing: 6)),
            ),
            Text('Đang chờ đối thủ nhập mã…', style: body),
            const SizedBox(height: 10),
            LButton(label: 'Hủy', small: true, onTap: _cancel),
          ],
          const Spacer(),
        ],
      ),
    );
  }

  Widget _joinPanel() {
    return Panel(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          Text('Vào phòng', style: titleStyle(20)),
          const Spacer(),
          SizedBox(
            width: 200,
            child: TextField(
              controller: _input,
              enabled: _code == null,
              keyboardType: TextInputType.number,
              maxLength: 6,
              textAlign: TextAlign.center,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              style: titleStyle(28, color: cream).copyWith(letterSpacing: 6),
              decoration: const InputDecoration(hintText: '000000', counterText: ''),
              onSubmitted: (_) => _join(),
            ),
          ),
          const SizedBox(height: 10),
          LButton(label: 'Vào', icon: Icons.login, color: jade, enabled: !_busy && _code == null, onTap: _join),
          const Spacer(),
        ],
      ),
    );
  }
}
