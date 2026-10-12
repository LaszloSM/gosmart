// lib/features/home/widgets/corridor_detail_sheet.dart
// Detalle de la Línea del corredor: tramo por tramo, con hora y reportes.
import 'package:flutter/material.dart';

import '../../../models/corridor_status.dart';
import '../../../theme/design_tokens.dart';
import '../../../widgets/gs_corridor_line.dart';

Future<void> showCorridorDetailSheet(
  BuildContext context,
  CorridorStatus status,
) {
  return showModalBottomSheet<void>(
    context: context,
    // Con "quitar animaciones" la hoja aparece sin deslizarse.
    sheetAnimationStyle: MediaQuery.of(context).disableAnimations
        ? AnimationStyle.noAnimation
        : null,
    showDragHandle: true,
    builder: (_) => CorridorDetailSheet(status: status),
  );
}

class CorridorDetailSheet extends StatelessWidget {
  const CorridorDetailSheet({super.key, required this.status});

  final CorridorStatus status;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final segments = status.mainSegments
        .where((s) => s.state != RoadState.unknown)
        .toList()
      ..sort((a, b) => a.kmFrom.compareTo(b.kmFrom));

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
            GSSpacing.s4, 0, GSSpacing.s4, GSSpacing.s6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('La Troncal · Riohacha – Maicao', style: text.titleLarge),
            const SizedBox(height: GSSpacing.s1),
            Text(
              status.updatedAt == null
                  ? 'Sin actualizaciones todavía'
                  : status.isStale
                      ? 'Sin señal. Último dato ${corridorAge(status.updatedAt!)}'
                      : 'Actualizado ${corridorAge(status.updatedAt!)}',
              style: text.bodySmall?.copyWith(fontFamily: GSFonts.mono, fontFeatures: GSFonts.tabular),
            ),
            const SizedBox(height: GSSpacing.s4),
            if (!status.hasData)
              _NoDataNote(text: text)
            else
              for (final seg in segments) ...[
                _SegmentRow(segment: seg),
                const Divider(),
              ],
          ],
        ),
      ),
    );
  }
}

class _NoDataNote extends StatelessWidget {
  const _NoDataNote({required this.text});
  final TextTheme text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.help_outline_rounded, color: GSColors.roadUnknown),
        const SizedBox(width: GSSpacing.s3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Aún no tenemos reportes de la vía',
                  style: text.titleMedium),
              const SizedBox(height: GSSpacing.s1),
              Text(
                'Pronto vas a poder ver y reportar bloqueos, retenes e '
                'inundaciones de la Troncal aquí mismo.',
                style: text.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SegmentRow extends StatelessWidget {
  const _SegmentRow({required this.segment});
  final CorridorSegment segment;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final color = roadColor(segment.state);
    final title = segment.reason ?? segment.state.label;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: GSSpacing.s3),
      child: Row(
        children: [
          Icon(roadIcon(segment.state), color: color),
          const SizedBox(width: GSSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: text.titleMedium?.copyWith(color: color),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
                if (segment.reports > 0)
                  Text(
                    segment.reports == 1
                        ? '1 reporte'
                        : '${segment.reports} reportes',
                    style: text.bodySmall,
                  ),
              ],
            ),
          ),
          Text(
            'km ${segment.kmFrom.round()}–${segment.kmTo.round()}',
            style: const TextStyle(
              fontFamily: GSFonts.mono, fontFeatures: GSFonts.tabular,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: GSColors.text,
            ),
          ),
        ],
      ),
    );
  }
}
