import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
  await SaveService.instance.load();
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
      home: const TitleScreen(),
    );
  }
}
