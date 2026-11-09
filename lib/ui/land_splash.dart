import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/content.dart';
import 'theme.dart';

/// Hints shown while a land is entered.
const landTips = [
  'Bật Tự động, nhân vật sẽ tự uống thuốc khi máu dưới 42%.',
  'Đánh hệ mình khắc được thêm 25% sát thương: Kim khắc Mộc, Mộc khắc Thổ, Thổ khắc Thủy, Thủy khắc Hỏa, Hỏa khắc Kim.',
  'Đi qua cây thuốc phát sáng ở bãi luyện công để hái dược liệu luyện đan.',
  'Thời gian bùa lợi của đan dược chỉ trôi khi đang chơi.',
  'Ải Ác Mộng đổi ma khí mỗi thứ Hai.',
  'Ở Bí cảnh, thắp đủ 3 trận nhãn mới phá được phong ấn của đầu lĩnh.',
  'Tháp Thử Luyện: cứ 5 tầng có một đầu lĩnh và ngọc.',
  'Khảm ngọc vào trang bị để tăng thêm chỉ số.',
  'Mỗi lần chuyển sinh, lượng nhặt được và lượng Bế quan đều tăng thêm.',
  'Nút Quay lại sẽ tạm dừng trận, không thoát ra ngoài.',
  'Rời game vẫn được thưởng Bế quan khi quay lại, tối đa 8 giờ.',
  'Cường hóa và thăng tinh trang bị giúp vượt ải khó dễ hơn nhiều.',
];

/// The painting of a land shown on entering it (1.11.2): its name, a line
/// about it and a hint, fading out on its own or on a tap.
class LandSplash extends StatefulWidget {
  const LandSplash({super.key, required this.map, required this.title, this.subtitle, required this.onDone});

  final MapDef map;
  final String title;
  final String? subtitle;
  final VoidCallback onDone;

  static const hold = Duration(milliseconds: 1700);
  static const fade = Duration(milliseconds: 350);

  @override
  State<LandSplash> createState() => _LandSplashState();
}

class _LandSplashState extends State<LandSplash> {
  final _tip = landTips[math.Random().nextInt(landTips.length)];
  bool _leaving = false;
  bool _started = false;

  String get _path => 'assets/art/land_${widget.map.theme.name}.webp';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // The hold counts from when the painting is up, not from when the
    // screen was built: the first frames of a fight can be slow.
    var held = false;
    void hold() {
      if (held) return;
      held = true;
      WidgetsBinding.instance.addPostFrameCallback((_) => Future.delayed(LandSplash.hold, _leave));
    }

    precacheImage(AssetImage(_path), context, onError: (_, _) => hold()).then((_) => hold());
  }

  void _leave() {
    if (!mounted || _leaving) return;
    setState(() => _leaving = true);
    Future.delayed(LandSplash.fade, () {
      if (mounted) widget.onDone();
    });
  }

  @override
  Widget build(BuildContext context) {
    final shadow = [const Shadow(color: Colors.black, blurRadius: 6, offset: Offset(0, 2))];
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _leave,
      child: AnimatedOpacity(
        opacity: _leaving ? 0 : 1,
        duration: LandSplash.fade,
        child: Stack(
          fit: StackFit.expand,
          children: [
            const ColoredBox(color: Colors.black),
            Image.asset(_path,
                fit: BoxFit.cover, filterQuality: FilterQuality.medium, errorBuilder: (_, _, _) => const SizedBox()),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x33000000), Color(0x11000000), Color(0xCC000000)],
                  stops: [0, 0.45, 1],
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 16),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title, style: titleStyle(30).copyWith(shadows: shadow)),
                    if (widget.subtitle != null)
                      Text(widget.subtitle!,
                          style: bold.copyWith(color: goldLight, shadows: shadow), maxLines: 2),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(Icons.lightbulb_outline, color: goldLight, size: 16),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text('Mẹo: $_tip',
                              style: small.copyWith(color: cream, fontSize: 12.5, shadows: shadow), maxLines: 2),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
