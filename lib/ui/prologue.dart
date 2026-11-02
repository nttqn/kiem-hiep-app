import 'package:flutter/material.dart';

import '../core/costumes.dart';
import '../core/hero.dart';
import '../render/art_figures.dart';
import 'backdrop.dart';
import 'theme.dart';

/// Lời mở đầu for a new hero: three short pages (the land, the sect
/// master's first charge, how to fight) and a button straight into that
/// first fight. True when the player chose to set off.
Future<bool> showPrologue(BuildContext context, HeroData h) async {
  final go = await Navigator.of(context).push<bool>(
    PageRouteBuilder(
      opaque: true,
      pageBuilder: (_, _, _) => _Prologue(h),
      transitionsBuilder: (_, a, _, child) => FadeTransition(opacity: a, child: child),
    ),
  );
  return go ?? false;
}

class _Prologue extends StatefulWidget {
  const _Prologue(this.h);
  final HeroData h;

  @override
  State<_Prologue> createState() => _PrologueState();
}

class _PrologueState extends State<_Prologue> {
  int _page = 0;

  HeroData get h => widget.h;

  List<(String, String, Widget?)> get _pages => [
        (
          'Lạc An, năm loạn thế',
          'Huyết Ma Giáo trỗi dậy, sơn tặc và yêu thú tràn khắp ngoại thành. Dân lành khốn khổ, '
              'võ lâm chia rẽ. Giang hồ đang cần một người dám đứng ra.',
          null,
        ),
        (
          'Chưởng môn ${h.sect.name}',
          '"Đồ nhi, ngươi đã học xong căn bản của bổn môn. Ngoài thành sói hoang đang hại dân làng. '
              'Xuống núi diệt trừ chúng, đó là bài khảo nghiệm đầu tiên của ngươi."',
          FigurePreview(hanh: h.hanh, female: h.female, scale: 1.3, gear: const HeroGear(weapon: 4, hat: 4, armor: 4, belt: 4, boots: 4, cape: true), costume: costumeById['chuongmon']),
        ),
        (
          'Bí quyết hành tẩu',
          '• Kéo cần điều khiển bên trái để đi, chạm nút tia chớp để đánh, chạm các vòng tròn để ra chiêu.\n'
              '• Bật TỰ ĐỘNG: nhân vật tự đánh, tự uống thuốc, tự cộng điểm và tự mặc đồ tốt hơn.\n'
              '• Về thành: nhận quà mỗi ngày, Mục tiêu 7 ngày và nhiệm vụ chính tuyến để lên cấp nhanh.',
          FigurePreview.of(h, scale: 1.3),
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final pages = _pages;
    final (title, text, art) = pages[_page];
    final last = _page == pages.length - 1;
    return Scaffold(
      body: Backdrop(
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 16),
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 350),
              child: Row(
                key: ValueKey(_page),
                children: [
                  if (art != null) ...[
                    SizedBox(width: 170, child: FittedBox(child: art)),
                    const SizedBox(width: 18),
                  ],
                  Expanded(
                    child: Panel(
                      padding: const EdgeInsets.all(18),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(title, style: titleStyle(26)),
                          const SizedBox(height: 10),
                          Text(text, style: body.copyWith(fontSize: 15, height: 1.45)),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              for (var i = 0; i < pages.length; i++)
                                Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.only(right: 6),
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: i == _page ? goldLight : creamDim.withValues(alpha: 0.4),
                                  ),
                                ),
                              const Spacer(),
                              if (!last)
                                TextButton(
                                  onPressed: () => Navigator.of(context).pop(false),
                                  child: const Text('Bỏ qua'),
                                ),
                              const SizedBox(width: 6),
                              LButton(
                                label: last ? 'Lên đường' : 'Tiếp',
                                icon: last ? Icons.directions_run : Icons.arrow_forward,
                                color: jade,
                                small: true,
                                onTap: () => last ? Navigator.of(context).pop(true) : setState(() => _page++),
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
          ),
        ),
      ),
    );
  }
}
