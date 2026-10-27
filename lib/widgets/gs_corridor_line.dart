// lib/widgets/gs_corridor_line.dart
// Línea del corredor (DESIGN.md): diagrama tipo metro de la Troncal,
// Riohacha (km 0) → Maicao. El desvío Albania–Cuestecitas va en el detalle.
// El estado va siempre con ícono + palabra; el color nunca va solo.
import 'package:flutter/material.dart';

import '../models/corridor_status.dart';
import '../theme/design_tokens.dart';

Color roadColor(RoadState state) => switch (state) {
      RoadState.open => GSColors.roadOpen,
      RoadState.caution => GSColors.roadCaution,
      RoadState.closed => GSColors.roadClosed,
      RoadState.unknown => GSColors.roadUnknown,
    };

IconData roadIcon(RoadState state) => switch (state) {
      RoadState.open => Icons.check_circle_rounded,
      RoadState.caution => Icons.warning_rounded,
      RoadState.closed => Icons.block_rounded,
      RoadState.unknown => Icons.help_outline_rounded,
    };

/// "hace 5 min", "hace 2 h" o la hora, para la etiqueta en mono.
String corridorAge(DateTime updatedAt, {DateTime? now}) {
  final diff = (now ?? DateTime.now()).difference(updatedAt);
  if (diff.inMinutes < 1) return 'ahora';
  if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'hace ${diff.inHours} h';
  final local = updatedAt.toLocal();
  return '${local.day}/${local.month}';
}

class GSCorridorLine extends StatelessWidget {
  const GSCorridorLine({
    super.key,
    required this.status,
    this.isLoading = false,
    this.onTap,
    this.floating = false,
  });

  /// null mientras carga por primera vez.
  final CorridorStatus? status;
  final bool isLoading;
  final VoidCallback? onTap;

  /// Sobre el mapa: tarjeta flotante redondeada con sombra (como la píldora de
  /// tráfico de Google Maps). Si no, una franja con línea inferior.
  final bool floating;

  @override
  Widget build(BuildContext context) {
    final data = status ?? const CorridorStatus.noData();
    final summary = data.summary;
    final grey = data.isStale;
    final worst = data.worstSegment;

    final word = isLoading && status == null ? 'Cargando' : summary.label;
    final detail = isLoading
        ? 'actualizando'
        : data.updatedAt != null
            ? corridorAge(data.updatedAt!)
            : null;

    final semantics = StringBuffer('Troncal Riohacha–Maicao: $word');
    if (worst?.reason != null) {
      semantics.write(', ${worst!.reason} km ${worst.kmFrom.round()}');
    }
    if (detail != null) semantics.write(', $detail');

    return Semantics(
      button: onTap != null,
      label: semantics.toString(),
      excludeSemantics: true,
      child: Container(
        decoration: floating
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(GSRadius.lg),
                boxShadow: GSShadow.float,
              )
            : null,
        child: Material(
          color: GSColors.surface,
          borderRadius: floating ? BorderRadius.circular(GSRadius.lg) : null,
          clipBehavior: floating ? Clip.antiAlias : Clip.none,
          child: InkWell(
            onTap: onTap,
            child: Container(
              constraints: BoxConstraints(
                  minHeight: floating ? 64 : GSSize.corridorLine),
              padding: EdgeInsets.fromLTRB(GSSpacing.s4,
                  floating ? GSSpacing.s3 : GSSpacing.s2, GSSpacing.s3,
                  floating ? GSSpacing.s3 : GSSpacing.s2),
              decoration: floating
                  ? null
                  : BoxDecoration(
                      border: Border(bottom: BorderSide(color: GSColors.line)),
                    ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Troncal del Caribe',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: GSFonts.sans,
                            fontSize: 15,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.1,
                            color: GSColors.text,
                          ),
                        ),
                      ),
                      const SizedBox(width: GSSpacing.s2),
                      _StatusChip(state: summary, word: word, grey: grey),
                    ],
                  ),
                  const SizedBox(height: GSSpacing.s2),
                  SizedBox(
                    height: 14,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: _CorridorPainter(status: data, grey: grey),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      const _EndLabel('Riohacha'),
                      Expanded(
                        child: detail == null
                            ? const SizedBox.shrink()
                            : Text(
                                detail,
                                textAlign: TextAlign.center,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontFamily: GSFonts.mono,
                                  fontFeatures: GSFonts.tabular,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: GSColors.textMuted,
                                ),
                              ),
                      ),
                      const _EndLabel('Maicao'),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Estado en píldora: ícono + palabra. Cerrada y Precaución van sobre su
/// tinte; Abierta y Sin datos, con borde del color (el texto queda ≥ 7:1).
class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.state, required this.word, required this.grey});
  final RoadState state;
  final String word;
  final bool grey;

  @override
  Widget build(BuildContext context) {
    final color = grey ? GSColors.roadUnknown : roadColor(state);
    final fill = grey
        ? null
        : switch (state) {
            RoadState.caution => GSColors.roadCautionTint,
            RoadState.closed => GSColors.roadClosedTint,
            _ => null,
          };
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
      decoration: BoxDecoration(
        color: fill ?? GSColors.surface,
        borderRadius: BorderRadius.circular(GSRadius.full),
        border: fill == null ? Border.all(color: color, width: 1.5) : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(roadIcon(state), size: 16, color: color),
          const SizedBox(width: 4),
          Text(
            word,
            style: TextStyle(
              fontFamily: GSFonts.sans,
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _EndLabel extends StatelessWidget {
  const _EndLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      style: TextStyle(
        fontFamily: GSFonts.sans,
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: GSColors.textMuted,
        height: 1.2,
      ),
    );
  }
}

/// Dibuja la Troncal como una línea gruesa con un color por tramo.
/// Las posiciones son esquemáticas (proporcionales al km), no geográficas.
class _CorridorPainter extends CustomPainter {
  _CorridorPainter({required this.status, required this.grey});

  final CorridorStatus status;
  final bool grey;

  static const _stroke = 6.0;
  static const _stop = 4.0;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;
    const left = _stop + 1;
    final right = size.width - _stop - 1;
    final width = right - left;

    double xFor(double km) =>
        left + width * (km / CorridorStatus.lengthKm).clamp(0.0, 1.0);

    Paint linePaint(RoadState s) => Paint()
      ..color = grey ? GSColors.roadUnknown : roadColor(s)
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.round;

    // El ramal Albania–Cuestecitas no se dibuja a 56 dp: sin sus km reales
    // (Fase 4) un trazo sin etiqueta se lee como un error. Va en el detalle.

    // Tramos principales.
    final main = status.mainSegments.toList()
      ..sort((a, b) => a.kmFrom.compareTo(b.kmFrom));
    if (main.isEmpty) {
      canvas.drawLine(
          Offset(left, y), Offset(right, y), linePaint(RoadState.unknown));
    }
    for (final seg in main) {
      canvas.drawLine(
        Offset(xFor(seg.kmFrom), y),
        Offset(xFor(seg.kmTo), y),
        linePaint(seg.state),
      );
    }

    // Estaciones en los extremos: anillo de tinta sobre la superficie.
    // (Las puntas redondas de cada tramo se tocan sin dejar huecos.)
    final fill = Paint()..color = GSColors.surface;
    final ring = Paint()
      ..color = GSColors.text
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final x in [left, right]) {
      canvas.drawCircle(Offset(x, y), _stop, fill);
      canvas.drawCircle(Offset(x, y), _stop, ring);
    }
  }

  @override
  bool shouldRepaint(_CorridorPainter old) =>
      old.status != status || old.grey != grey;
}
