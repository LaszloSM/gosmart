// lib/widgets/gs_corridor_line.dart
// Línea del corredor (DESIGN.md): diagrama tipo metro de la Troncal,
// Riohacha (km 0) → Maicao, con el desvío Albania–Cuestecitas como ramal.
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
  });

  /// null mientras carga por primera vez.
  final CorridorStatus? status;
  final bool isLoading;
  final VoidCallback? onTap;

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
      child: Material(
        color: GSColors.surface,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: GSSize.corridorLine,
            padding: const EdgeInsets.symmetric(horizontal: GSSpacing.s4),
            decoration: const BoxDecoration(
              border: Border(bottom: BorderSide(color: GSColors.line)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Row(
                        children: [
                          _EndLabel('Riohacha'),
                          Spacer(),
                          _EndLabel('Maicao'),
                        ],
                      ),
                      const SizedBox(height: GSSpacing.s1),
                      SizedBox(
                        height: 14,
                        width: double.infinity,
                        child: CustomPaint(
                          painter: _CorridorPainter(status: data, grey: grey),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: GSSpacing.s3),
                _SummaryTag(
                  state: summary,
                  word: word,
                  detail: detail,
                  grey: grey,
                ),
              ],
            ),
          ),
        ),
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
      style: const TextStyle(
        fontFamily: GSFonts.sans,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: GSColors.textMuted,
        height: 1.2,
      ),
    );
  }
}

class _SummaryTag extends StatelessWidget {
  const _SummaryTag({
    required this.state,
    required this.word,
    required this.detail,
    required this.grey,
  });

  final RoadState state;
  final String word;
  final String? detail;
  final bool grey;

  @override
  Widget build(BuildContext context) {
    final color = grey ? GSColors.roadUnknown : roadColor(state);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(roadIcon(state), size: GSSize.iconSm, color: color),
            const SizedBox(width: GSSpacing.s1),
            Text(
              word,
              style: TextStyle(
                fontFamily: GSFonts.sans,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
        if (detail != null)
          Text(
            detail!,
            style: const TextStyle(
              fontFamily: GSFonts.mono, fontFeatures: GSFonts.tabular,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: GSColors.textMuted,
            ),
          ),
      ],
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

  /// Punto del ramal Albania–Cuestecitas sobre la línea (fracción del largo).
  /// Esquemático hasta tener `road_segments` con los km reales (Fase 4).
  static const _branchAt = 0.55;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height * 0.35;
    const left = _stop + 1;
    final right = size.width - _stop - 1;
    final width = right - left;

    double xFor(double km) =>
        left + width * (km / CorridorStatus.lengthKm).clamp(0.0, 1.0);

    Paint linePaint(RoadState s) => Paint()
      ..color = grey ? GSColors.roadUnknown : roadColor(s)
      ..strokeWidth = _stroke
      ..strokeCap = StrokeCap.butt;

    // Ramal: un trazo corto hacia abajo, más delgado que la línea principal.
    final branch = status.segments.where((s) => s.isBranch);
    final branchState =
        branch.isEmpty ? RoadState.unknown : branch.first.state;
    final bx = left + width * _branchAt;
    canvas.drawLine(
      Offset(bx, y),
      Offset(bx + size.height * 0.6, size.height),
      linePaint(branchState)
        ..strokeWidth = _stroke / 2
        ..strokeCap = StrokeCap.round,
    );

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
