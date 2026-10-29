// lib/core/motion.dart
// Entradas con flutter_animate, siempre con la misma voz (DESIGN.md · Motion):
// ease-out fuerte, cortas, desde algo ya visible (nunca escala 0) y nada si el
// sistema pide "quitar animaciones".
import 'package:flutter/widgets.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../theme/design_tokens.dart';

extension GSMotion on Widget {
  /// Aparece con fundido y, si se pide, desde [scale] o desplazado [slide]
  /// (en fracciones de su tamaño). Para listas: delay = índice × 18–30 ms.
  Widget gsEnter(
    BuildContext context, {
    Duration delay = Duration.zero,
    Duration duration = const Duration(milliseconds: 180),
    double scale = 1,
    Offset slide = Offset.zero,
    Curve curve = GSCurve.enter,
  }) {
    if (MediaQuery.of(context).disableAnimations) return this;
    Animate a = animate(delay: delay).fadeIn(duration: duration, curve: curve);
    if (scale != 1) {
      a = a.scaleXY(begin: scale, end: 1, duration: duration, curve: curve);
    }
    if (slide != Offset.zero) {
      a = a.slide(begin: slide, end: Offset.zero, duration: duration, curve: curve);
    }
    return a;
  }

  /// Un momento de celebración (poco frecuente): crece con un rebote pequeño.
  Widget gsPop(BuildContext context, {Duration delay = Duration.zero, double from = 0.6}) {
    if (MediaQuery.of(context).disableAnimations) return this;
    return animate(delay: delay)
        .fadeIn(duration: 120.ms)
        .scaleXY(begin: from, end: 1, duration: 300.ms, curve: Curves.easeOutBack);
  }
}
