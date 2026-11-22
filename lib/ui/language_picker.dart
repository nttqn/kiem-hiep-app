import 'package:flutter/material.dart';

import '../core/i18n.dart';
import '../services/ads.dart';
import '../services/language.dart';
import 'theme.dart';
import 'title_screen.dart';
import 'town_screen.dart';

/// Lets the player pick the game's language. The open screens are rebuilt
/// from scratch in it: the hero list from the title, the town from inside.
Future<void> pickLanguage(BuildContext context, {required bool inTown}) async {
  final picked = await showDialog<Lang>(
    context: context,
    builder: (ctx) => SimpleDialog(
      backgroundColor: lacquer,
      // Both languages, so a player stuck in the wrong one still finds it.
      title: Text(tr('Ngôn ngữ · 語言'), style: titleStyle(20)),
      children: [
        for (final l in Lang.values)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, l),
            child: Row(
              children: [
                Icon(l == currentLang ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                    color: goldLight, size: 20),
                const SizedBox(width: 10),
                Text(l.label, style: bold.copyWith(fontSize: 15)),
              ],
            ),
          ),
      ],
    ),
  );
  if (picked == null || picked == currentLang) return;
  await LanguageService.instance.set(picked);
  AdsService.navigatorKey.currentState?.pushAndRemoveUntil(
    fadeRoute(inTown ? const TownScreen() : const TitleScreen()),
    (_) => false,
  );
}

/// The globe on the hero list.
class LanguageButton extends StatelessWidget {
  const LanguageButton({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
        tooltip: tr('Ngôn ngữ · 語言'),
        icon: const Icon(Icons.translate, color: goldLight),
        onPressed: () => pickLanguage(context, inTown: false),
      );
}
