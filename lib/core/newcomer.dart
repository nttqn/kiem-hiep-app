import 'comeback.dart' show daysBetween;
import 'festival.dart' show dayAfter;
import 'hero.dart';

/// Tân hiệp khách (1.24.0): a hero made while playing in Chinese, Korean or
/// English joins a server of Vietnamese masters who have played for a year.
/// Their first [newcomerDays] days get more EXP and gold from monsters, and
/// a few Song Bội Đan at the start, to catch up and find people to play
/// with. Heroes made before 1.24 or in Vietnamese are unchanged.
const int newcomerDays = 7;
const double newcomerExp = 0.5, newcomerGold = 0.5;

/// Song Bội Đan given when such a hero is made.
const int newcomerPills = 3;

/// Whether [lang] (a language code) gets the welcome.
bool newcomerLang(String lang) => lang.isNotEmpty && lang != 'vi';

/// The boost is on for [h] on Vietnam day [today].
bool newcomerOn(HeroData h, String today) =>
    newcomerLang(h.bornLang) && h.bornDay.isNotEmpty && daysBetween(h.bornDay, today) < newcomerDays;

/// The last day of [h]'s boost.
String newcomerUntil(HeroData h) => dayAfter(h.bornDay, newcomerDays - 1);
