import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'services/ads.dart';
import 'services/chat.dart';
import 'services/cloud.dart';
import 'services/leaderboard.dart';
import 'services/notify.dart';
import 'services/perf.dart';
import 'services/save.dart';
import 'services/sound.dart';
import 'ui/theme.dart';
import 'ui/title_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // The joystick and skill pad are laid out for a wide screen.
  SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  // Not awaited: a slow or broken audio asset must never delay the first frame.
  SoundService.instance.init();
  await LiteMode.instance.load();
  await SaveService.instance.load();
  await Leaderboard.instance.load();
  await ChatService.instance.load();
  // Not awaited: reminders are a nicety.
  NotifyService.instance.init();
  // Not awaited either: the game starts offline and syncs when it can.
  CloudSave.instance.init();
  AdsService.instance.init();
  runApp(const KiemHiepApp());
}

class KiemHiepApp extends StatelessWidget {
  const KiemHiepApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: gameTitle,
      debugShowCheckedModeBanner: false,
      theme: buildTheme(),
      // Every screen is laid out for a landscape phone at the normal text
      // size; a large system font size overflows the town grid, the HUD and
      // the dialogs, so it is capped a little above normal.
      builder: (context, child) {
        final mq = MediaQuery.of(context);
        return MediaQuery(
          data: mq.copyWith(textScaler: mq.textScaler.clamp(maxScaleFactor: 1.1)),
          child: child!,
        );
      },
      home: const TitleScreen(),
    );
  }
}
