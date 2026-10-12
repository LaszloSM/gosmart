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
    this.header = const [],
    this.locate,
    this.pollEvery = const Duration(seconds: 5),
  });

  final DriverProfile driver;

  /// Lo que va arriba de la lista (la placa de estado del conductor).
  final List<Widget> header;
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
  String? _selectedId;
  /// Hora del último dato bueno cuando la red falla (null = hay señal).
  DateTime? _offlineSince;
  DateTime? _lastOk;

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
        _lastOk = DateTime.now();
        _offlineSince = null;
      });
    } catch (_) {
      // Sin señal no es "nadie pide": se dice y se conserva lo último.
      if (mounted) {
        setState(() {
          _loaded = true;
          _offlineSince = _lastOk ?? DateTime.now();
        });
      }
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
    final list = <Widget>[
      ...widget.header,
      if (!_loaded)
        const Padding(
          padding: EdgeInsets.all(GSSpacing.s4),
          child: Center(child: CircularProgressIndicator()),
        )
      else ...[
        if (_offlineSince != null)
          _note(text, 'Sin señal · reintentando. Último dato a las '
              '${_hhmm(_offlineSince!)}.'),
        if (_cash.isNotEmpty) ...[
          const GSSectionTitle('Efectivo por confirmar'),
          for (final c in _cash)
            GSListRow(
              icon: Icons.payments_outlined,
              title: '¿Recibiste ${formatCop(c.amount)}?',
              subtitle: 'Confírmalo abajo para que el pasajero tenga su recibo',
            ),
        ],
        if (_active != null)
          _activeRideInfo(_active!, text)
        else if (_isScheduled)
          ..._scheduledInfo(text)
        else
          ..._nearbyInfo(text),
      ],
    ];
    final actions = _loaded ? _thumbActions() : const <Widget>[];
    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.only(bottom: GSSpacing.s4),
            children: list,
          ),
        ),
        if (actions.isNotEmpty)
          // Zona del pulgar (DS6): solo lo que toca ahora, máximo 2 acciones de 72 dp.
          DecoratedBox(
            decoration: BoxDecoration(
              color: GSColors.surface,
              border: Border(top: BorderSide(color: GSColors.line)),
            ),
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    GSSpacing.s4, GSSpacing.s3, GSSpacing.s4, GSSpacing.s3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < actions.length; i++) ...[
                      if (i > 0) const SizedBox(height: GSSpacing.s2),
                      actions[i],
                    ],
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _big(String label, VoidCallback? onPressed,
          {bool outline = false, String? busyKey, IconData? icon}) =>
      GSButton(
        label: label,
        size: GSButtonSize.driver,
        leadingIcon: icon,
        variant: outline ? GSButtonVariant.outline : GSButtonVariant.primary,
        isLoading: busyKey != null && _busy == busyKey,
        onPressed: _busy != null ? null : onPressed,
      );

  /// Prioridad: viaje activo > efectivo por confirmar > solicitud elegida > salidas.
  List<Widget> _thumbActions() {
    final a = _active;
    if (a != null) {
      final picked = a.status == RideStatus.inProgress;
      return [
        _big(picked ? 'Terminar viaje' : 'Recogí al pasajero', () async {
          await _run(a.id, () => dispatchService.transitionRide(
              a.id, picked ? RideStatus.completed : RideStatus.inProgress),
              ok: picked ? 'Viaje terminado' : null);
          if (picked && mounted) {
            await showRateSheet(context, requestId: a.id, asDriver: true);
          }
        }, busyKey: a.id),
        if (!picked)
          _big('No puedo llegar', () => _confirmCancel(a), outline: true),
      ];
    }
    if (_cash.isNotEmpty) {
      final c = _cash.first;
      return [
        _big('Sí, recibí ${formatCop(c.amount)}',
            () => _run('cash-${c.id}', () => paymentService.confirmCash(c.id),
                ok: 'Efectivo confirmado'),
            busyKey: 'cash-${c.id}', icon: Icons.payments_outlined),
      ];
    }
    if (_isScheduled) {
      return [
        _big('Publicar salida', () => showModalBottomSheet<void>(
              context: context,
              isScrollControlled: true,
              showDragHandle: true,
              builder: (_) => PublishDepartureSheet(onDone: _tick),
            ), icon: Icons.add_rounded),
      ];
    }
    final r = _selected;
    if (r == null) return const [];
    return [
      _big('Aceptar ${formatCop(r.offeredFare)}',
          () => _run(r.id, () => dispatchService.acceptRide(r.id),
              ok: 'Viaje aceptado. Ve por el pasajero.'),
          busyKey: r.id),
      if (r.myOffer == null)
        _big('Ofrecer ${formatCop(r.offeredFare + 1000)}',
            () => _run('offer-${r.id}',
                () => dispatchService.counterOffer(r.id, r.offeredFare + 1000),
                ok: 'Oferta enviada'),
            outline: true, busyKey: 'offer-${r.id}'),
    ];
  }

  Future<void> _confirmCancel(RideRequest r) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cancelar este viaje?'),
        content: const Text('El pasajero tendrá que pedir otro conductor.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Seguir')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Cancelar viaje')),
        ],
      ),
    );
    if (ok == true) {
      await _run('cancel', () => dispatchService.transitionRide(r.id, RideStatus.cancelled));
    }
  }

  NearbyRequest? get _selected {
    if (_nearby.isEmpty) return null;
    return _nearby.firstWhere((r) => r.id == _selectedId, orElse: () => _nearby.first);
  }

  List<Widget> _nearbyInfo(TextTheme text) => [
        const GSSectionTitle('Solicitudes cerca'),
        if (!_gps)
          _note(text, 'Activa el GPS: sin ubicación no podemos mostrarte '
              'solicitudes cercanas.')
        else if (_offlineSince != null)
          const SizedBox.shrink()
        else if (_nearby.isEmpty)
          _note(text, 'Nadie está pidiendo cerca ahora. Esta lista se '
              'actualiza sola mientras la pantalla esté abierta.'),
        for (final r in _nearby)
          Padding(
            padding: const EdgeInsets.fromLTRB(
                GSSpacing.s4, 0, GSSpacing.s4, GSSpacing.s3),
            child: DriverRequestCard(
              request: r,
              selected: r.id == _selected?.id,
              onTap: () => setState(() => _selectedId = r.id),
            ),
          ),
      ];

  Widget _note(TextTheme text, String s) => Padding(
        padding: const EdgeInsets.fromLTRB(
            GSSpacing.s4, GSSpacing.s2, GSSpacing.s4, GSSpacing.s2),
        child: Text(s, style: text.bodyMedium),
      );

  Widget _activeRideInfo(RideRequest r, TextTheme text) {
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
            maxLines: 3,
            detail: 'Tarifa acordada ${formatCop(r.agreedFare ?? r.offeredFare)}',
          ),
          const SizedBox(height: GSSpacing.s3),
          Text(
            picked
                ? 'Lleva al pasajero a ${r.destLabel ?? 'su destino'}.'
                : 'Ve por el pasajero en ${r.originLabel ?? 'el punto de salida'}.',
            style: text.bodyLarge,
          ),
        ],
      ),
    );
  }

  List<Widget> _scheduledInfo(TextTheme text) => [
        const GSSectionTitle('Tus salidas'),
        if (_departures.isEmpty && _offlineSince == null)
          _note(text, 'Publica tu próxima salida para que los pasajeros '
              'reserven cupo.'),
        for (final d in _departures)
          GSListRow(
            icon: Icons.event_seat_outlined,
            title: '${d.seatsTaken} de ${d.seatsTotal} cupos reservados',
            subtitle: 'De ${_nodeName(d.fromNode)} a ${_nodeName(d.toNode)} · '
                '${d.status == 'full' ? 'llena' : 'abierta'}',
            value: formatCop(d.fare),
          ),
      ];

  String _nodeName(String id) =>
      ref.read(transportGraphProvider).valueOrNull?.graph.nodes[id]?.name ?? id;
}

/// Solicitud entrante: tarifa, distancias, origen y destino. Las acciones
/// (Aceptar / Ofrecer) van en la zona del pulgar para la que esté elegida.
class DriverRequestCard extends StatelessWidget {
  const DriverRequestCard({
    super.key,
    required this.request,
    this.selected = false,
    this.onTap,
  });

  final NearbyRequest request;
  final bool selected;
  final VoidCallback? onTap;

  static String km(double v) => v.toStringAsFixed(1).replaceAll('.', ',');

  @override
  Widget build(BuildContext context) {
    final r = request;
    final text = Theme.of(context).textTheme;
    return Material(
      color: GSColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(GSRadius.lg),
        side: BorderSide(
            color: selected ? GSColors.brand : GSColors.line,
            width: selected ? 2 : 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                  color: selected ? GSColors.stripe : Colors.transparent, width: 4),
            ),
          ),
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
              Text('Recoger a ${km(r.pickupKm)} km · viaje de ${km(r.tripKm)} km',
                  style: text.bodyMedium?.copyWith(fontFeatures: GSFonts.tabular)),
              const SizedBox(height: GSSpacing.s2),
              Text('Desde ${r.originLabel ?? 'punto marcado'}',
                  style: text.bodyLarge, maxLines: 3, overflow: TextOverflow.ellipsis),
              Text('Hasta ${r.destLabel ?? 'punto marcado'}',
                  style: text.bodyLarge, maxLines: 3, overflow: TextOverflow.ellipsis),
              if (r.myOffer != null)
                Text('Ofreciste ${formatCop(r.myOffer!)}', style: text.bodySmall),
            ],
          ),
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
      IconButton(tooltip: 'Menos', iconSize: 32, constraints: _driverTap, onPressed: minus, icon: const Icon(Icons.remove_rounded)),
      Text(value, style: text.titleMedium?.copyWith(fontFeatures: GSFonts.tabular)),
      IconButton(tooltip: 'Más', iconSize: 32, constraints: _driverTap, onPressed: plus, icon: const Icon(Icons.add_rounded)),
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
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: GSSize.touchTargetDriver),
              child: GSButton(
                label: 'Publicar',
                size: GSButtonSize.driver,
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

String _hhmm(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '$h:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'a. m.' : 'p. m.'}';
}

/// Pasos −/+ del modo conductor: 72 dp (DS6).
const _driverTap = BoxConstraints.tightFor(
    width: GSSize.touchTargetDriver, height: GSSize.touchTargetDriver);
