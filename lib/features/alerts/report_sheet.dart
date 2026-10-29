// lib/features/alerts/report_sheet.dart
// Reportar como en Waze: un toque en el botón del mapa, un toque en lo que
// ves. Se reporta donde estás (GPS); si estás sobre la Troncal, el reporte
// queda en su tramo y cambia el estado de la vía. Sin GPS se elige el tramo.
// Sin texto libre (regla ética): solo tipos cerrados.
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';

import '../../core/motion.dart';
import '../../models/map_alert.dart';
import '../../providers/auth_provider.dart';
import '../../providers/corridor_provider.dart';
import '../../providers/map_alerts_provider.dart';
import '../../router/app_router.dart';
import '../../services/corridor_service.dart';
import '../../services/location_service.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/gs_alert_badge.dart';
import '../../widgets/gs_button.dart';
import '../../widgets/gs_pressable.dart';

/// Abre la hoja de reportar. [locate] se inyecta en pruebas.
Future<void> showReportSheet(BuildContext context,
    {Future<LatLng?> Function()? locate}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    sheetAnimationStyle: MediaQuery.of(context).disableAnimations
        ? AnimationStyle.noAnimation
        : null,
    builder: (_) => ReportSheet(locate: locate),
  );
}

class ReportSheet extends ConsumerStatefulWidget {
  const ReportSheet({super.key, this.locate});
  final Future<LatLng?> Function()? locate;

  @override
  ConsumerState<ReportSheet> createState() => _ReportSheetState();
}

enum _Phase { locating, choose, sending, done }

class _ReportSheetState extends ConsumerState<ReportSheet> {
  _Phase _phase = _Phase.locating;
  LatLng? _at;
  RoadSegmentGeo? _segment;
  String? _sendingKind;
  String? _error;
  bool _queued = false;
  AlertKind? _sent;

  /// Sin GPS: el tramo elegido a mano.
  String? _manualSegment;

  /// Lo elegido en la cuadrícula; se publica al confirmar (un toque en
  /// movimiento no publica nada por error).
  AlertKind? _picked;

  @override
  void initState() {
    super.initState();
    _locate();
  }

  Future<void> _locate() async {
    final at = locationService.last ??
        await (widget.locate ?? locationService.getCurrentPosition)();
    if (!mounted) return;
    // Se puede reportar ya; el tramo (si estás sobre la Troncal) llega después.
    setState(() {
      _at = at;
      _phase = _Phase.choose;
    });
    if (at == null) return;
    try {
      final segs = await ref
          .read(roadSegmentsProvider.future)
          .timeout(const Duration(seconds: 4));
      // Sobre la vía (300 m): el reporte cuenta para el estado del tramo.
      final seg = nearestSegment(at, segs, maxMeters: 300);
      if (mounted && seg != null) setState(() => _segment = seg);
    } catch (_) {}
  }

  Future<void> _send(AlertKind kind) async {
    if (_phase == _Phase.sending) return;
    final segmentId = _segment?.id ?? _manualSegment;
    if (_at == null && segmentId == null) {
      setState(() => _error = 'Elige primero el tramo de la Troncal.');
      return;
    }
    setState(() {
      _phase = _Phase.sending;
      _sendingKind = kind.id;
      _error = null;
    });
    try {
      final reached = await corridorService.report(
        segmentId: segmentId,
        kind: kind.id,
        idempotencyKey: const Uuid().v4(),
        at: _at,
      );
      if (!mounted) return;
      setState(() {
        _queued = !reached;
        _sent = kind;
        _phase = _Phase.done;
      });
      if (reached) ref.read(mapAlertsProvider.notifier).refresh();
      ref.invalidate(corridorStatusProvider);
      await Future<void>.delayed(const Duration(milliseconds: 1600));
      if (mounted) Navigator.of(context).maybePop();
    } on RoadReportRejected catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.choose;
        _sendingKind = null;
        _error = switch (e.code) {
          'rate_limited' => 'Ya hiciste varios reportes en esta hora. Intenta más tarde.',
          'duplicate_report' => 'Ya reportaste esto aquí hace poco. Gracias.',
          'out_of_region' => 'Por ahora solo se reporta en La Guajira.',
          _ => 'No pudimos enviar el reporte. Intenta de nuevo.',
        };
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isGuest = ref.watch(isGuestProvider);
    final bottom = MediaQuery.of(context).padding.bottom;
    return Container(
      decoration: BoxDecoration(
        color: GSColors.surface,
        borderRadius: GSRadius.sheetRadius,
      ),
      padding: EdgeInsets.fromLTRB(
          GSSpacing.s4, GSSpacing.s3, GSSpacing.s4, bottom + GSSpacing.s5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: GSColors.line,
                borderRadius: BorderRadius.circular(GSRadius.full),
              ),
            ),
          ),
          const SizedBox(height: GSSpacing.s4),
          AnimatedSize(
            duration: MediaQuery.of(context).disableAnimations
                ? const Duration(milliseconds: 1) // cero rompe AnimatedSize
                : GSDuration.normal,
            curve: GSCurve.enter,
            alignment: Alignment.topCenter,
            child: AnimatedSwitcher(
              duration: MediaQuery.of(context).disableAnimations
                  ? Duration.zero
                  : GSDuration.fast,
              child: isGuest
                  ? const _GuestPrompt(key: ValueKey('guest'))
                  : _phase == _Phase.done
                      ? _Done(key: const ValueKey('done'), kind: _sent!, queued: _queued)
                      : _chooser(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chooser(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final where = _phase == _Phase.locating
        ? 'Buscando dónde estás…'
        : _segment != null
            ? 'En la Troncal · ${_segment!.name}'
            : _at != null
                ? 'Se reporta donde estás ahora'
                : 'Sin GPS: elige el tramo de la Troncal';
    final kinds = [
      ...AlertKind.all,
      if (_segment != null || _manualSegment != null) AlertKind.despejado,
    ];
    return Column(
      key: const ValueKey('choose'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('¿Qué ves en la vía?', style: text.headlineSmall),
        const SizedBox(height: 2),
        Row(
          children: [
            Icon(
              _at != null ? Icons.my_location_rounded : Icons.location_off_rounded,
              size: GSSize.iconSm,
              color: GSColors.textMuted,
            ),
            const SizedBox(width: GSSpacing.s1),
            Expanded(
              child: Text(where,
                  maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodyMedium),
            ),
          ],
        ),
        if (_phase != _Phase.locating && _at == null) ...[
          const SizedBox(height: GSSpacing.s3),
          _SegmentPicker(
            selected: _manualSegment,
            onChanged: (id) => setState(() => _manualSegment = id),
          ),
        ],
        const SizedBox(height: GSSpacing.s5),
        // Cuatro por fila: los globos grandes de Waze, con la palabra debajo.
        LayoutBuilder(builder: (context, box) {
          final w = (box.maxWidth - GSSpacing.s2 * 3) / 4;
          return Wrap(
            spacing: GSSpacing.s2,
            runSpacing: GSSpacing.s4,
            children: [
              for (var i = 0; i < kinds.length; i++)
                SizedBox(
                  width: w,
                  child: _KindTile(
                    kind: kinds[i],
                    busy: _sendingKind == kinds[i].id,
                    selected: _picked?.id == kinds[i].id,
                    enabled: _phase == _Phase.choose,
                    onTap: () => setState(() {
                      _picked = kinds[i];
                      _error = null;
                    }),
                  // Entrada corta y escalonada: es una acción poco frecuente.
                  ).gsEnter(context, delay: (i * 18).ms, duration: 160.ms, scale: 0.9),
                ),
            ],
          );
        }),
        const SizedBox(height: GSSpacing.s5),
        GSButton(
          label: _picked == null ? 'Elige qué ves' : 'Reportar ${_picked!.label.toLowerCase()}',
          leadingIcon: Icons.add_location_alt_rounded,
          isLoading: _phase == _Phase.sending,
          onPressed: _picked == null || _phase != _Phase.choose ? null : () => _send(_picked!),
        ),
        if (_error != null) ...[
          const SizedBox(height: GSSpacing.s4),
          Text(_error!,
              textAlign: TextAlign.center,
              style: text.bodyMedium?.copyWith(color: GSColors.roadClosed)),
        ],
        const SizedBox(height: GSSpacing.s4),
        Text(
          'Solo qué pasa y dónde: nunca nombres de personas ni de comunidades. '
          'Otros confirman o desmienten.',
          textAlign: TextAlign.center,
          style: text.bodySmall,
        ),
      ],
    );
  }
}

class _KindTile extends StatelessWidget {
  const _KindTile({
    required this.kind,
    required this.busy,
    required this.enabled,
    required this.onTap,
    this.selected = false,
  });
  final AlertKind kind;
  final bool busy;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GSPressable(
      onTap: enabled ? onTap : null,
      semanticLabel: kind.label,
      selected: selected,
      child: Column(
        children: [
          SizedBox(
            width: 68,
            height: 68,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Elegido: anillo de marca alrededor del globo.
                AnimatedContainer(
                  duration: MediaQuery.of(context).disableAnimations ? Duration.zero : GSDuration.fast,
                  curve: GSCurve.enter,
                  width: 68,
                  height: 68,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                        color: selected ? GSColors.brand : Colors.transparent, width: 3),
                  ),
                ),
                AnimatedScale(
                  scale: selected ? 1.06 : 1,
                  duration: MediaQuery.of(context).disableAnimations ? Duration.zero : GSDuration.fast,
                  curve: GSCurve.enter,
                  child: GSAlertBadge(kind: kind, size: 58),
                ),
                if (busy)
                  SizedBox(
                    width: 68,
                    height: 68,
                    child: CircularProgressIndicator(
                        strokeWidth: 3, color: GSColors.text),
                  ),
              ],
            ),
          ),
          const SizedBox(height: GSSpacing.s2),
          MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.4,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                kind.label,
                maxLines: 1,
                style: TextStyle(
                  fontFamily: GSFonts.sans,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  color: GSColors.text,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Gracias: el globo del tipo enviado crece con un rebote pequeño (momento
/// poco frecuente, se permite) y la sheet se cierra sola.
class _Done extends StatelessWidget {
  const _Done({super.key, required this.kind, required this.queued});
  final AlertKind kind;
  final bool queued;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: GSSpacing.s4),
      child: Column(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              GSAlertBadge(kind: kind, size: 84),
              Positioned(
                right: -4,
                bottom: -4,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: GSColors.brand,
                    shape: BoxShape.circle,
                    border: Border.all(color: GSColors.surface, width: 3),
                  ),
                  child: Icon(Icons.check_rounded, size: GSSize.iconMd, color: GSColors.onBrand),
                ).gsPop(context, delay: 120.ms, from: 0.4),
              ),
            ],
          ).gsPop(context, from: 0.85),
          const SizedBox(height: GSSpacing.s4),
          Text(queued ? 'Lo enviamos al volver la señal' : 'Gracias, ya lo ven los demás',
              textAlign: TextAlign.center, style: text.titleLarge),
          const SizedBox(height: GSSpacing.s1),
          Text(
            queued
                ? '${kind.label}: quedó guardado en tu teléfono.'
                : '${kind.label} en el mapa. Otros lo confirman o lo desmienten.',
            textAlign: TextAlign.center,
            style: text.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _GuestPrompt extends StatelessWidget {
  const _GuestPrompt({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Entra para reportar', style: text.headlineSmall),
        const SizedBox(height: GSSpacing.s1),
        Text(
          'Ver las alertas es libre. Para reportar te pedimos cuenta: así '
          'cuidamos que nadie llene el mapa de reportes falsos.',
          style: text.bodyMedium,
        ),
        const SizedBox(height: GSSpacing.s5),
        GSButton(
          label: 'Entrar',
          onPressed: () {
            Navigator.of(context).pop();
            context.push(AppRoutes.login);
          },
        ),
      ],
    );
  }
}

/// Sin GPS: los tramos de la Troncal en píldoras para elegir dónde.
class _SegmentPicker extends ConsumerWidget {
  const _SegmentPicker({required this.selected, required this.onChanged});
  final String? selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final segs = ref.watch(roadSegmentsProvider).valueOrNull ?? const [];
    return Wrap(
      spacing: GSSpacing.s2,
      runSpacing: GSSpacing.s2,
      children: [
        for (final s in segs)
          ChoiceChip(
            label: Text(s.name),
            selected: selected == s.id,
            onSelected: (_) => onChanged(s.id),
          ),
      ],
    );
  }
}
