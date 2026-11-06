// lib/widgets/gs_alert_badge.dart
// La alerta como la dibuja Waze: un globo redondo de color con el ícono en
// blanco (o tinta sobre ámbar), borde blanco y una puntita que señala el
// lugar. Lejos (zoom bajo) se vuelve un punto de color.
// El mismo dibujo sale como widget (hojas, preferencias) y como imagen para
// los marcadores de Google Maps (renderAlertPin).
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/map_alert.dart';
import '../theme/design_tokens.dart';

/// Fondo y figura de una alerta según su gravedad.
(Color, Color) alertColors(AlertKind kind) => switch (kind.severity) {
      AlertSeverity.severe => (GSColors.alertSevere, GSColors.onAlertSevere),
      AlertSeverity.caution => (GSColors.alertCaution, GSColors.onAlertCaution),
      AlertSeverity.clear => (GSColors.alertClear, GSColors.onAlertClear),
    };

/// Globo redondo con el ícono, para la interfaz (no el mapa).
class GSAlertBadge extends StatelessWidget {
  const GSAlertBadge({super.key, required this.kind, this.size = 48, this.ring = true});

  final AlertKind kind;
  final double size;

  /// Borde blanco: sí sobre el mapa o fondos de color; no hace falta en filas.
  final bool ring;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = alertColors(kind);
    return ExcludeSemantics(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          border: ring ? Border.all(color: Colors.white, width: size * 0.06) : null,
          boxShadow: ring
              ? [
                  BoxShadow(
                    color: GSColors.palette.shadowInk.withValues(alpha: 0.22),
                    blurRadius: size * 0.18,
                    offset: Offset(0, size * 0.05),
                  )
                ]
              : null,
        ),
        child: kind.id == 'hueco'
            ? CustomPaint(painter: _PotholePainter(fg), size: Size.square(size))
            : Icon(kind.icon, size: size * 0.54, color: fg),
      ),
    );
  }
}

/// El hueco no tiene ícono en Material: se dibuja uno propio en el mismo
/// trazo redondeado (un hueco ovalado con dos grietas), como el de Waze.
void paintPothole(Canvas canvas, Offset center, double size, Color color) {
  final line = Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = size * 0.06
    ..strokeCap = StrokeCap.round;
  final cx = center.dx, cy = center.dy, s = size;
  // La vía en perspectiva: dos bordes que se juntan hacia arriba…
  canvas.drawLine(Offset(cx - s * 0.30, cy + s * 0.30), Offset(cx - s * 0.11, cy - s * 0.30), line);
  canvas.drawLine(Offset(cx + s * 0.30, cy + s * 0.30), Offset(cx + s * 0.11, cy - s * 0.30), line);
  // …la raya del centro arriba…
  canvas.drawLine(Offset(cx, cy - s * 0.28), Offset(cx, cy - s * 0.17), line);
  // …y el hueco en medio del carril.
  canvas.drawOval(
      Rect.fromCenter(center: Offset(cx, cy + s * 0.1), width: s * 0.34, height: s * 0.17),
      Paint()..color = color);
}

class _PotholePainter extends CustomPainter {
  _PotholePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) =>
      paintPothole(canvas, size.center(Offset.zero), size.shortestSide, color);

  @override
  bool shouldRepaint(_PotholePainter old) => old.color != color;
}

/// Tamaños del pin en el mapa según el zoom (como Waze: lejos, puntos).
enum AlertPinSize { dot, small, full }

/// Calle a la vista: globo completo; barrio: globo chico; ciudad: punto.
AlertPinSize alertPinSizeFor(double zoom) => zoom < 13.5
    ? AlertPinSize.dot
    : zoom < 15
        ? AlertPinSize.small
        : AlertPinSize.full;

/// Más lejos que esto (varias ciudades a la vista) solo se ve lo grave: el
/// resto taparía el mapa y no sirve a esa distancia.
const alertFarZoom = 12.0;

bool alertVisibleAt(AlertKind kind, double zoom) =>
    zoom >= alertFarZoom || kind.severity == AlertSeverity.severe;

/// Medidas en dp del pin: ancho y alto de la imagen.
Size alertPinLogicalSize(AlertPinSize s) => switch (s) {
      AlertPinSize.dot => const Size(16, 16),
      AlertPinSize.small => const Size(30, 36),
      AlertPinSize.full => const Size(42, 50),
    };

/// Dibuja el pin en PNG para un marcador de Google Maps. El ancla va en la
/// punta (0.5, 1) para el globo y al centro para el punto.
Future<Uint8List> renderAlertPin(AlertKind kind, AlertPinSize size,
    {required double pixelRatio, bool dark = false}) async {
  final logical = alertPinLogicalSize(size);
  final w = logical.width * pixelRatio, h = logical.height * pixelRatio;
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, w, h));
  final (bg, fg) = alertColors(kind);
  final ring = Paint()..color = dark ? const Color(0xFF1B1E25) : Colors.white;
  final fill = Paint()..color = bg;
  final shadow = Paint()
    ..color = Colors.black.withValues(alpha: 0.28)
    ..maskFilter = MaskFilter.blur(BlurStyle.normal, 2 * pixelRatio);

  if (size == AlertPinSize.dot) {
    final c = Offset(w / 2, h / 2);
    final r = w / 2 - 1.5 * pixelRatio;
    canvas.drawCircle(c + Offset(0, 0.6 * pixelRatio), r, shadow);
    canvas.drawCircle(c, r, ring);
    canvas.drawCircle(c, r - 2.2 * pixelRatio, fill);
  } else {
    final d = w - 4 * pixelRatio; // diámetro del globo
    final c = Offset(w / 2, 2 * pixelRatio + d / 2);
    final r = d / 2;
    // Puntita hacia abajo, del ancho de un tercio del globo.
    final tail = Path()
      ..moveTo(c.dx - r * 0.42, c.dy + r * 0.72)
      ..lineTo(c.dx, h - 1 * pixelRatio)
      ..lineTo(c.dx + r * 0.42, c.dy + r * 0.72)
      ..close();
    canvas.drawPath(tail.shift(Offset(0, 0.8 * pixelRatio)), shadow);
    canvas.drawCircle(c + Offset(0, 0.8 * pixelRatio), r, shadow);
    canvas.drawPath(tail, ring);
    canvas.drawCircle(c, r, ring);
    final inner = r - (size == AlertPinSize.full ? 2.6 : 2.0) * pixelRatio;
    canvas.drawCircle(c, inner, fill);
    if (kind.id == 'hueco') {
      paintPothole(canvas, c, inner * 2, fg);
      final image = await recorder.endRecording().toImage(w.ceil(), h.ceil());
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return bytes!.buffer.asUint8List();
    }
    // El ícono con la fuente de Material Icons.
    final tp = TextPainter(
      text: TextSpan(
        text: String.fromCharCode(kind.icon.codePoint),
        style: TextStyle(
          fontFamily: kind.icon.fontFamily,
          package: kind.icon.fontPackage,
          fontSize: inner * 1.15,
          color: fg,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
  }

  final image = await recorder.endRecording().toImage(w.ceil(), h.ceil());
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return bytes!.buffer.asUint8List();
}
