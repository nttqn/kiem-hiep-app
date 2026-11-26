import 'dart:ui';

/// Chế độ máy yếu: drops the soft glows (blur is the costliest thing a weak
/// GPU draws), screen shake and purely decorative effects. Set from
/// LiteMode (services/perf.dart).
bool liteGraphics = false;

/// Rung màn hình (Cài đặt), on by default; Chế độ máy yếu turns it off too.
bool screenShake = true;

/// World units visible top to bottom in battle (Tầm nhìn); set from
/// ViewRange (services/perf.dart).
double viewSpan = 460;

final Map<double, MaskFilter> _blurs = {};

/// A soft glow of [sigma], or none in Chế độ máy yếu.
MaskFilter? softBlur(double sigma) =>
    liteGraphics ? null : _blurs.putIfAbsent(sigma, () => MaskFilter.blur(BlurStyle.normal, sigma));
