/// Compares dotted versions ('1.3.1' < '1.4.0' < '1.10.0'); missing or
/// unreadable parts count as 0.
int compareVersions(String a, String b) {
  List<int> parts(String v) => [for (final p in v.trim().split('.')) int.tryParse(p.split('+').first) ?? 0];
  final x = parts(a), y = parts(b);
  for (var i = 0; i < x.length || i < y.length; i++) {
    final d = (i < x.length ? x[i] : 0) - (i < y.length ? y[i] : 0);
    if (d != 0) return d.sign;
  }
  return 0;
}

/// What to do about a newer build in the store: nothing, offer it (the
/// player may wait a day), or require it (this version is below [min], the
/// oldest the developer still lets play).
enum UpdatePlan { none, offer, force }

UpdatePlan updatePlan({
  required bool available,
  required String current,
  String? min,
  required bool snoozedToday,
}) {
  if (!available) return UpdatePlan.none;
  if (min != null && min.isNotEmpty && compareVersions(current, min) < 0) return UpdatePlan.force;
  return snoozedToday ? UpdatePlan.none : UpdatePlan.offer;
}
