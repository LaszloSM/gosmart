// lib/features/corridor/report_screen.dart
// Reportar la vía en dos toques: qué pasa y dónde. Sin campo de texto: no se
// nombran personas ni comunidades (regla ética de la Fase 4). El tramo se
// toma del GPS; si estás lejos de la Troncal, lo eliges de la lista.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:uuid/uuid.dart';

import '../../providers/corridor_provider.dart';
import '../../services/corridor_service.dart';
import '../../services/location_service.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/gs_bottom_nav.dart';
import '../../widgets/gs_button.dart';
import '../../widgets/gs_choice_plates.dart';
import '../../widgets/gs_inline_error.dart';
import '../../widgets/gs_list_row.dart';
import '../../widgets/gs_toast.dart';

IconData reportKindIcon(String kind) => switch (kind) {
      'bloqueo' => Icons.block_rounded,
      'reten' => Icons.local_police_outlined,
      'accidente' => Icons.car_crash_outlined,
      'inundacion' => Icons.water_rounded,
      'hueco' => Icons.report_gmailerrorred_rounded,
      _ => Icons.check_circle_outline_rounded,
    };

class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key, this.locate});

  /// Inyectable en pruebas; por defecto, el GPS.
  final Future<LatLng?> Function()? locate;

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen> {
  String? _kind;
  String? _segmentId;
  LatLng? _at;
  bool _locating = true;
  bool _autoPicked = false;
  bool _sending = false;
  // Una llave por reporte: reintentos y cola offline no lo duplican.
  String _key = const Uuid().v4();

  @override
  void initState() {
    super.initState();
    _locate();
  }

  Future<void> _locate() async {
    final at = await (widget.locate ?? locationService.getCurrentPosition)();
    if (!mounted) return;
    setState(() {
      _at = at;
      _locating = false;
    });
  }

  void _maybeAutoPick(List<RoadSegmentGeo> segs) {
    if (_autoPicked || _at == null || _segmentId != null) return;
    _autoPicked = true;
    final near = nearestSegment(_at!, segs);
    if (near != null) _segmentId = near.id;
  }

  Future<void> _send() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _sending = true);
    try {
      final delivered = await corridorService.report(
        segmentId: _segmentId!,
        kind: _kind!,
        idempotencyKey: _key,
        at: _at,
      );
      ref.invalidate(corridorStatusProvider);
      GSToast.showWithMessenger(messenger,
          message: delivered
              ? 'Reporte enviado. Gracias por avisar.'
              : 'Sin señal: lo enviamos apenas tengas conexión.',
          type: GSToastType.success);
      setState(() {
        _kind = null;
        _key = const Uuid().v4();
      });
    } on RoadReportRejected catch (e) {
      GSToast.showWithMessenger(messenger,
          message: switch (e.code) {
            'rate_limited' => 'Ya enviaste varios reportes. Espera un rato.',
            'duplicate_report' => 'Ya reportaste esto aquí hace poco.',
            _ => 'No pudimos guardar ese reporte.',
          },
          type: GSToastType.error);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final segments = ref.watch(roadSegmentsProvider);
    segments.whenData(_maybeAutoPick);
    final ready = _kind != null && _segmentId != null && !_sending;

    return Scaffold(
      extendBody: true,
      backgroundColor: GSColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Reportar la vía'),
      ),
      body: ListView(
        padding: EdgeInsets.zero,
        children: [
          const GSSectionTitle('¿Qué pasa?'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: GSSpacing.s4),
            child: GSChoicePlates<String>(
              options: roadReportKinds,
              icons: reportKindIcon,
              selected: _kind,
              onChanged: (k) => setState(() => _kind = k),
            ),
          ),
          const GSSectionTitle('¿Dónde?'),
          segments.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(GSSpacing.s4),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) => Padding(
              padding: const EdgeInsets.symmetric(horizontal: GSSpacing.s4),
              child: GSInlineError(
                message: 'Sin señal no podemos cargar los tramos',
                onRetry: () => ref.invalidate(roadSegmentsProvider),
              ),
            ),
            data: (segs) => Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      GSSpacing.s4, 0, GSSpacing.s4, GSSpacing.s2),
                  child: Text(
                    _locating
                        ? 'Buscando en qué tramo estás…'
                        : _at == null
                            ? 'Sin GPS: elige el tramo.'
                            : _autoPicked && _segmentId != null
                                ? 'Te ubicamos en este tramo. Cámbialo si no es.'
                                : 'Estás lejos de la Troncal: elige el tramo.',
                    style: text.bodyMedium,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: GSSpacing.s4),
                  child: GSChoicePlates<String>(
                    options: {for (final s in segs) s.id: s.name},
                    selected: _segmentId,
                    onChanged: (id) => setState(() => _segmentId = id),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                GSSpacing.s4, GSSpacing.s5, GSSpacing.s4, 0),
            child: Text(
              'Solo pedimos qué pasa y dónde, nunca nombres de personas ni '
              'de comunidades. Otros viajeros confirman o desmienten.',
              style: text.bodySmall,
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
                GSSpacing.s4, GSSpacing.s4, GSSpacing.s4, 0),
            child: GSButton(
              label: 'Enviar reporte',
              leadingIcon: Icons.campaign_outlined,
              isLoading: _sending,
              onPressed: ready ? _send : null,
            ),
          ),
          SizedBox(
              height: MediaQuery.of(context).padding.bottom + GSSpacing.s4),
        ],
      ),
      bottomNavigationBar: const GSBottomNav(current: GSNavTab.report),
    );
  }
}
