// lib/features/driver/driver_work_panel.dart
// El trabajo del conductor disponible (DS6: una mano, 72 dp, dos acciones):
//   · con un viaje asignado → recoger y terminar
//   · mototaxi/taxi → solicitudes cercanas: Aceptar o Ofrecer otro precio
//   · colectivo/intermunicipal → publicar salida y ver cupos
// Mientras la pantalla está abierta se reporta la posición y se revisan
// solicitudes cada 5 s. Las solicitudes no llegan con la app cerrada (sin push).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../core/money.dart';
import '../../models/dispatch_models.dart';
import '../../models/driver_model.dart';
import '../../planner/graph.dart';
import '../../providers/planner_provider.dart';
import '../../services/dispatch_service.dart';
import '../../services/location_service.dart';
import '../../services/payment_service.dart';
import '../trust/rate_sheet.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/gs_button.dart';
import '../../widgets/gs_choice_plates.dart';
import '../../widgets/gs_list_row.dart';
import '../../widgets/gs_route_plate.dart';
import '../../widgets/gs_toast.dart';

class DriverWorkPanel extends ConsumerStatefulWidget {
  const DriverWorkPanel({
    super.key,
    required this.driver,
    this.locate,
    this.pollEvery = const Duration(seconds: 5),
  });

  final DriverProfile driver;
  final Future<LatLng?> Function()? locate;
  final Duration pollEvery;

  @override
  ConsumerState<DriverWorkPanel> createState() => _DriverWorkPanelState();
}

class _DriverWorkPanelState extends ConsumerState<DriverWorkPanel> {
  Timer? _timer;
  RideRequest? _active;
  List<NearbyRequest> _nearby = const [];
  List<ColectivoDeparture> _departures = const [];
  List<({String id, int amount, DateTime at})> _cash = const [];
  bool _gps = true;
  bool _loaded = false;
  String? _busy;

  bool get _isScheduled =>
      widget.driver.service == 'colectivo' ||
      widget.driver.service == 'intermunicipal';

  @override
  void initState() {
    super.initState();
    _tick();
    _timer = Timer.periodic(widget.pollEvery, (_) => _tick());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _tick() async {
    try {
      final at = await (widget.locate ?? locationService.getCurrentPosition)();
      if (at != null) await dispatchService.ping(at);
      final active = await dispatchService.myAssignedRide(widget.driver.userId);
      var nearby = const <NearbyRequest>[];
      var deps = const <ColectivoDeparture>[];
      if (active == null && at != null && !_isScheduled) {
        nearby = await dispatchService.nearby(at);
      }
      if (_isScheduled) deps = await dispatchService.myDepartures(widget.driver.userId);
      final cash = await paymentService.pendingCash(widget.driver.userId);
      if (!mounted) return;
      setState(() {
        _gps = at != null;
        _active = active;
        _nearby = nearby;
        _departures = deps;
        _cash = cash;
        _loaded = true;
      });
    } catch (_) {
      if (mounted) setState(() => _loaded = true);
    }
  }

  Future<void> _run(String key, Future<void> Function() action, {String? ok}) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = key);
    try {
      await action();
      if (ok != null) {
        GSToast.showWithMessenger(messenger, message: ok, type: GSToastType.success);
      }
      await _tick();
    } on DispatchException catch (e) {
      GSToast.showWithMessenger(messenger, message: e.message, type: GSToastType.error);
      await _tick();
    } on PaymentException catch (e) {
      GSToast.showWithMessenger(messenger, message: e.message, type: GSToastType.error);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    if (!_loaded) {
      return const Padding(
        padding: EdgeInsets.all(GSSpacing.s4),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    final a = _active;
    final main = a != null
        ? _activeRide(a, text)
        : _isScheduled
            ? _scheduled(text)
            : _nearbyList(text);
    if (_cash.isEmpty) return main;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const GSSectionTitle('Efectivo por confirmar'),
        for (final c in _cash)
          GSListRow(
            icon: Icons.payments_outlined,
            title: '¿Recibiste ${formatCop(c.amount)}?',
            subtitle: 'Confírmalo para que el pasajero tenga su recibo',
            trailing: TextButton(
              onPressed: _busy != null
                  ? null
                  : () => _run('cash-${c.id}',
                      () => paymentService.confirmCash(c.id),
                      ok: 'Efectivo confirmado'),
              child: const Text('Sí, recibí'),
            ),
          ),
        main,
      ],
    );
  }

  Widget _nearbyList(TextTheme text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const GSSectionTitle('Solicitudes cerca'),
        if (!_gps)
          _note(text, 'Activa el GPS: sin ubicación no podemos mostrarte '
              'solicitudes cercanas.')
        else if (_nearby.isEmpty)
          _note(text, 'Nadie está pidiendo cerca ahora. Esta lista se '
              'actualiza sola mientras la pantalla esté abierta.'),
        for (final r in _nearby)
          Padding(
            padding: const EdgeInsets.fromLTRB(
                GSSpacing.s4, 0, GSSpacing.s4, GSSpacing.s3),
            child: DriverRequestCard(
              request: r,
              busy: _busy == r.id,
              onAccept: () => _run(r.id, () => dispatchService.acceptRide(r.id),
                  ok: 'Viaje aceptado. Ve por el pasajero.'),
              onCounter: () => _run(r.id,
                  () => dispatchService.counterOffer(r.id, r.offeredFare + 1000),
                  ok: 'Oferta enviada'),
            ),
          ),
      ],
    );
  }

  Widget _note(TextTheme text, String s) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: GSSpacing.s4),
        child: Text(s, style: text.bodyMedium),
      );

  Widget _activeRide(RideRequest r, TextTheme text) {
    final picked = r.status == RideStatus.inProgress;
    return Padding(
      padding: const EdgeInsets.all(GSSpacing.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GSRoutePlate(
            from: r.originLabel,
            text: r.destLabel ?? 'Destino',
            leading: Icons.route_rounded,
            isActive: true,
            maxLines: 2,
            detail: 'Tarifa acordada ${formatCop(r.agreedFare ?? r.offeredFare)}',
          ),
          const SizedBox(height: GSSpacing.s3),
          Text(
            picked
                ? 'Lleva al pasajero a ${r.destLabel ?? 'su destino'}.'
                : 'Ve por el pasajero en ${r.originLabel ?? 'el punto de salida'}.',
            style: text.bodyLarge,
          ),
          const SizedBox(height: GSSpacing.s4),
          SizedBox(
            height: GSSize.touchTargetDriver,
            child: GSButton(
              label: picked ? 'Terminar viaje' : 'Recogí al pasajero',
              size: GSButtonSize.lg,
              isLoading: _busy == r.id,
              onPressed: _busy != null
                  ? null
                  : () async {
                      await _run(r.id, () => dispatchService.transitionRide(
                          r.id, picked ? RideStatus.completed : RideStatus.inProgress),
                          ok: picked ? 'Viaje terminado' : null);
                      if (picked && mounted) {
                        await showRateSheet(context, requestId: r.id, asDriver: true);
                      }
                    },
            ),
          ),
          if (!picked)
            TextButton(
              onPressed: _busy != null
                  ? null
                  : () => _run('cancel', () => dispatchService.transitionRide(
                      r.id, RideStatus.cancelled)),
              child: const Text('No puedo llegar: cancelar'),
            ),
        ],
      ),
    );
  }

  Widget _scheduled(TextTheme text) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const GSSectionTitle('Tus salidas'),
        if (_departures.isEmpty)
          _note(text, 'Publica tu próxima salida para que los pasajeros '
              'reserven cupo.'),
        for (final d in _departures)
          GSListRow(
            icon: Icons.event_seat_outlined,
            title: '${d.seatsTaken} de ${d.seatsTotal} cupos reservados',
            subtitle: '${_nodeName(d.fromNode)} → ${_nodeName(d.toNode)} · '
                '${d.status == 'full' ? 'llena' : 'abierta'}',
            value: formatCop(d.fare),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
              GSSpacing.s4, GSSpacing.s4, GSSpacing.s4, 0),
          child: SizedBox(
            height: GSSize.touchTargetDriver,
            child: GSButton(
              label: 'Publicar salida',
              size: GSButtonSize.lg,
              leadingIcon: Icons.add_rounded,
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                showDragHandle: true,
                builder: (_) => PublishDepartureSheet(onDone: _tick),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _nodeName(String id) =>
      ref.read(transportGraphProvider).valueOrNull?.graph.nodes[id]?.name ?? id;
}

/// Solicitud entrante: origen, destino, distancias y dos botones grandes.
class DriverRequestCard extends StatelessWidget {
  const DriverRequestCard({
    super.key,
    required this.request,
    required this.onAccept,
    required this.onCounter,
    this.busy = false,
  });

  final NearbyRequest request;
  final VoidCallback onAccept;
  final VoidCallback onCounter;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final r = request;
    final text = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: GSColors.surface,
        borderRadius: BorderRadius.circular(GSRadius.lg),
        border: Border.all(color: GSColors.line, width: 1.5),
      ),
      child: Padding(
        padding: const EdgeInsets.all(GSSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              formatCop(r.offeredFare),
              style: TextStyle(
                fontFamily: GSFonts.display,
                fontFeatures: GSFonts.tabular,
                fontSize: 32,
                fontWeight: FontWeight.w800,
                color: GSColors.text,
              ),
            ),
            Text('Recoger a ${r.pickupKm.toStringAsFixed(1)} km · '
                'viaje de ${r.tripKm.toStringAsFixed(1)} km',
                style: text.bodyMedium?.copyWith(fontFeatures: GSFonts.tabular)),
            const SizedBox(height: GSSpacing.s2),
            Text('Desde ${r.originLabel ?? 'punto marcado'}',
                style: text.bodyLarge, maxLines: 2, overflow: TextOverflow.ellipsis),
            Text('Hasta ${r.destLabel ?? 'punto marcado'}',
                style: text.bodyLarge, maxLines: 2, overflow: TextOverflow.ellipsis),
            if (r.myOffer != null)
              Text('Ofreciste ${formatCop(r.myOffer!)}', style: text.bodySmall),
            const SizedBox(height: GSSpacing.s3),
            SizedBox(
              height: GSSize.touchTargetDriver,
              child: GSButton(
                label: 'Aceptar ${formatCop(r.offeredFare)}',
                size: GSButtonSize.lg,
                isLoading: busy,
                onPressed: busy ? null : onAccept,
              ),
            ),
            const SizedBox(height: GSSpacing.s2),
            SizedBox(
              height: GSSize.touchTargetDriver,
              child: GSButton(
                label: 'Ofrecer ${formatCop(r.offeredFare + 1000)}',
                size: GSButtonSize.lg,
                variant: GSButtonVariant.outline,
                onPressed: busy || r.myOffer != null ? null : onCounter,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Publicar una salida de colectivo: desde, hasta, en cuánto, cupos y tarifa.
class PublishDepartureSheet extends ConsumerStatefulWidget {
  const PublishDepartureSheet({super.key, required this.onDone});
  final Future<void> Function() onDone;

  @override
  ConsumerState<PublishDepartureSheet> createState() =>
      _PublishDepartureSheetState();
}

class _PublishDepartureSheetState extends ConsumerState<PublishDepartureSheet> {
  String? _from;
  String? _to;
  int _inMinutes = 30;
  int _seats = 4;
  int _fare = 14000;
  bool _busy = false;

  Future<void> _publish() async {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    setState(() => _busy = true);
    try {
      await dispatchService.publishDeparture(
        fromNode: _from!,
        toNode: _to!,
        departAt: DateTime.now().add(Duration(minutes: _inMinutes)),
        seats: _seats,
        fare: _fare,
      );
      nav.pop();
      GSToast.showWithMessenger(messenger,
          message: 'Salida publicada', type: GSToastType.success);
      await widget.onDone();
    } on DispatchException catch (e) {
      GSToast.showWithMessenger(messenger,
          message: e.message, type: GSToastType.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _stepper(String label, String value, VoidCallback? minus, VoidCallback? plus) {
    final text = Theme.of(context).textTheme;
    return Row(children: [
      Expanded(child: Text(label, style: text.bodyLarge)),
      IconButton(tooltip: 'Menos', onPressed: minus, icon: const Icon(Icons.remove_rounded)),
      Text(value, style: text.titleMedium?.copyWith(fontFeatures: GSFonts.tabular)),
      IconButton(tooltip: 'Más', onPressed: plus, icon: const Icon(Icons.add_rounded)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final nodes = ref.watch(transportGraphProvider).valueOrNull?.graph.nodes;
    final text = Theme.of(context).textTheme;
    final options = <String, String>{
      for (final n in nodes?.values ?? const <GraphNode>[]) n.id: n.name
    };
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(GSSpacing.s4, 0, GSSpacing.s4,
            GSSpacing.s4 + MediaQuery.of(context).viewInsets.bottom),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Publicar salida', style: text.titleLarge),
            const SizedBox(height: GSSpacing.s3),
            Text('Desde', style: text.titleSmall),
            const SizedBox(height: GSSpacing.s2),
            GSChoicePlates<String>(
                options: options, selected: _from,
                onChanged: (v) => setState(() => _from = v)),
            const SizedBox(height: GSSpacing.s3),
            Text('Hasta', style: text.titleSmall),
            const SizedBox(height: GSSpacing.s2),
            GSChoicePlates<String>(
                options: {...options}..remove(_from), selected: _to,
                onChanged: (v) => setState(() => _to = v)),
            const SizedBox(height: GSSpacing.s3),
            _stepper('Sale en', '$_inMinutes min',
                _inMinutes > 0 ? () => setState(() => _inMinutes -= 10) : null,
                _inMinutes < 600 ? () => setState(() => _inMinutes += 10) : null),
            _stepper('Cupos', '$_seats',
                _seats > 1 ? () => setState(() => _seats--) : null,
                _seats < 30 ? () => setState(() => _seats++) : null),
            _stepper('Pasaje', formatCop(_fare),
                _fare > 1000 ? () => setState(() => _fare -= 500) : null,
                () => setState(() => _fare += 500)),
            const SizedBox(height: GSSpacing.s3),
            SizedBox(
              height: GSSize.touchTargetDriver,
              child: GSButton(
                label: 'Publicar',
                size: GSButtonSize.lg,
                isLoading: _busy,
                onPressed: _from != null && _to != null && !_busy ? _publish : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
