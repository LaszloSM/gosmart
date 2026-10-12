// lib/features/home/widgets/corridor_detail_sheet.dart
// Detalle de la Línea del corredor: tramo por tramo, con hora y reportes.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:url_launcher/url_launcher.dart';

import '../../../core/corridor_share.dart';
import '../../../core/env.dart';
import '../../../core/safety_links.dart' show whatsappUri;
import '../../../models/corridor_status.dart';
import '../../../providers/auth_provider.dart';
import '../../../providers/corridor_provider.dart';
import '../../../router/app_router.dart';
import '../../../services/corridor_service.dart';
import '../../../widgets/gs_button.dart';
import '../../../widgets/gs_toast.dart';
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
    builder: (_) =>
        SingleChildScrollView(child: CorridorDetailSheet(status: status)),
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
            const SizedBox(height: GSSpacing.s4),
            GSButton(
              label: 'Compartir por WhatsApp',
              leadingIcon: Icons.share_rounded,
              onPressed: () => launchUrl(
                whatsappUri(corridorShareMessage(status,
                    link: corridorPageLink(Env.shareBaseUrl))),
                mode: LaunchMode.externalApplication,
              ).catchError((_) => false),
            ),
            const SizedBox(height: GSSpacing.s2),
            GSButton(
              label: 'Reportar algo en la vía',
              leadingIcon: Icons.campaign_outlined,
              variant: GSButtonVariant.outline,
              onPressed: () {
                Navigator.of(context).pop();
                context.go(AppRoutes.report);
              },
            ),
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
        Icon(Icons.help_outline_rounded, color: GSColors.roadUnknown),
        const SizedBox(width: GSSpacing.s3),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Aún no tenemos reportes de la vía',
                  style: text.titleMedium),
              const SizedBox(height: GSSpacing.s1),
              Text(
                'Nadie ha reportado nada vigente. Si ves un bloqueo, un retén '
                'o una inundación, avisa a los demás.',
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SegmentSummary(segment: segment),
        if (segment.reportId != null) _VoteRow(reportId: segment.reportId!),
      ],
    );
  }
}

/// "¿Sigue ahí?": la confirmación cruzada que decide si un tramo se cierra.
class _VoteRow extends ConsumerStatefulWidget {
  const _VoteRow({required this.reportId});
  final String reportId;

  @override
  ConsumerState<_VoteRow> createState() => _VoteRowState();
}

class _VoteRowState extends ConsumerState<_VoteRow> {
  bool _busy = false;
  bool _done = false;

  Future<void> _vote(bool stillThere) async {
    if (ref.read(isGuestProvider)) {
      Navigator.of(context).pop();
      context.push(AppRoutes.login);
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await corridorService.vote(widget.reportId, stillThere: stillThere);
      ref.invalidate(corridorStatusProvider);
      setState(() => _done = true);
    } catch (e) {
      GSToast.showWithMessenger(messenger,
          message: e.toString().contains('cannot_vote_own')
              ? 'Ese reporte es tuyo: lo confirman otros.'
              : 'No pudimos guardar tu respuesta. Revisa tu conexión.',
          type: GSToastType.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    if (_done) {
      return Padding(
        padding: const EdgeInsets.only(bottom: GSSpacing.s3),
        child: Text('Gracias: tu respuesta cuenta.', style: text.bodySmall),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: GSSpacing.s3),
      child: Wrap(
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: GSSpacing.s2,
        children: [
          Text('¿Sigue ahí?', style: text.bodyMedium),
          TextButton(
            onPressed: _busy ? null : () => _vote(true),
            child: const Text('Sí, sigue'),
          ),
          TextButton(
            onPressed: _busy ? null : () => _vote(false),
            child: const Text('Ya no está'),
          ),
        ],
      ),
    );
  }
}

class _SegmentSummary extends StatelessWidget {
  const _SegmentSummary({required this.segment});
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
            style: TextStyle(
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
