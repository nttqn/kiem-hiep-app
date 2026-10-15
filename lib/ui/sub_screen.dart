import 'package:flutter/material.dart';

import '../services/save.dart';
import 'backdrop.dart';
import 'theme.dart';

/// A full-screen page over the dimmed backdrop with a title strip.
class SubScreen extends StatelessWidget {
  const SubScreen({super.key, required this.title, required this.child, this.actions = const []});
  final String title;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final h = SaveService.instance.hero;
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
                      Text(title, style: titleStyle(22)),
                      const Spacer(),
                      ...actions,
                      const SizedBox(width: 8),
                      ListenableBuilder(
                        listenable: SaveService.instance,
                        builder: (_, _) => Row(
                          children: [
                            const Icon(Icons.monetization_on, color: goldLight, size: 18),
                            const SizedBox(width: 4),
                            Text(fmt(h.gold), style: bold),
                            const SizedBox(width: 12),
                            Text('Cấp ${h.level}', style: bold.copyWith(color: goldLight)),
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
