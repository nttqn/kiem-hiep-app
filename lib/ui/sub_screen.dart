import 'package:flutter/material.dart';

import '../services/save.dart';
import 'backdrop.dart';
import 'theme.dart';
import '../core/i18n.dart';

/// A full-screen page over the dimmed backdrop with a title strip.
class SubScreen extends StatelessWidget {
  const SubScreen({super.key, required this.title, required this.child, this.actions = const []});
  final String title;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final h = SaveService.instance.hero;
    // Small phones: tabs and the level do not all fit beside the title.
    final narrow = actions.isNotEmpty && MediaQuery.sizeOf(context).width < 860;
    return Scaffold(
      body: Backdrop(
        town: true,
        child: Container(
          color: const Color(0xAA0E0806),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 12, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back, color: goldLight),
                      ),
                      // 1.25: the title on a painted paper scroll.
                      SizedBox(
                        height: 42,
                        child: Stack(
                          fit: StackFit.passthrough,
                          children: [
                            Positioned.fill(
                              child: SliceFrame(uiTitleArt,
                                  slice: SliceFrame.title.$1, imageSize: SliceFrame.title.$2, scale: narrow ? 7 : 5.2),
                            ),
                            Padding(
                              padding: EdgeInsets.symmetric(horizontal: narrow ? 24 : 34),
                              child: Center(
                                widthFactor: 1,
                                child: Text(title,
                                    style: titleStyle(narrow ? 18 : 20, color: lacquer)
                                        .copyWith(shadows: const [Shadow(color: Color(0x80FFFFFF), offset: Offset(0, 1))]),
                                    maxLines: 1),
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Tabs slide sideways when the screen is too narrow.
                      Expanded(
                        child: Align(
                          alignment: Alignment.centerRight,
                          child: SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(mainAxisSize: MainAxisSize.min, children: actions),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ListenableBuilder(
                        listenable: SaveService.instance,
                        builder: (_, _) => Row(
                          children: [
                            const Icon(Icons.monetization_on, color: goldLight, size: 18),
                            const SizedBox(width: 4),
                            Text(fmt(h.gold), style: bold),
                            if (!narrow) ...[
                              const SizedBox(width: 12),
                              Text(tr('Cấp {level}', {'level': h.level}), style: bold.copyWith(color: goldLight)),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Expanded(child: child),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
