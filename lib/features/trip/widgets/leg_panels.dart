// lib/features/trip/widgets/leg_panels.dart
// Lo que toca hacer en el tramo actual, según el modo.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/money.dart';
import '../../../models/dispatch_models.dart';
import '../../../providers/dispatch_provider.dart';
import '../../../services/dispatch_service.dart';
import '../../../services/payment_service.dart';
import '../../trust/rate_sheet.dart';
import '../trip_screen.dart' show legModeLabel;
import '../../../providers/wallet_provider.dart';
import 'package:go_router/go_router.dart';
import '../../../router/app_router.dart';
import '../../../theme/design_tokens.dart';
import '../../../widgets/gs_button.dart';
import '../../../widgets/gs_list_row.dart';
import '../../../widgets/gs_toast.dart';

/// Tarifa sugerida para pedir: el medio del rango de referencia, en $500.
int suggestedFare(TripLegRow l) {
  final mid = l.fareMax > 0 ? (l.fareMin + l.fareMax) / 2 : 5000;
  return ((mid / 500).round() * 500).clamp(1000, 500000).toInt();
}

class CurrentLegPanel extends ConsumerWidget {
  const CurrentLegPanel({super.key, required this.leg});
  final TripLegRow leg;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return switch (leg.mode) {
      'mototaxi' || 'taxi' => RideLegPanel(leg: leg),
      'colectivo' ||
      'transpadilla' ||
      'intermunicipal' =>
        ScheduledLegPanel(leg: leg),
      _ => SimpleLegPanel(leg: leg),
    };
  }
}

/// Avanza un tramo hasta [to], pasando por en curso si hace falta.
Future<void> advanceLeg(WidgetRef ref, ScaffoldMessengerState messenger,
    TripLegRow leg, LegStatus to,
    {int? agreedFare}) async {
  try {
    if (to == LegStatus.completed && leg.status != LegStatus.inProgress) {
      await dispatchService.legTransition(leg.id, LegStatus.inProgress,
          agreedFare: agreedFare);
    }
    await dispatchService.legTransition(leg.id, to, agreedFare: agreedFare);
    ref.invalidate(activeTripProvider);
  } on DispatchException catch (e) {
    GSToast.showWithMessenger(messenger,
        message: e.message, type: GSToastType.error);
  }
}

// ── A pie ────────────────────────────────────────────────────────────────────
class SimpleLegPanel extends ConsumerWidget {
  const SimpleLegPanel({super.key, required this.leg});
  final TripLegRow leg;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
            'Camina hasta ${leg.toLabel ?? 'el siguiente punto'}'
            '${leg.minutes == null ? '' : ' (unos ${leg.minutes} min)'}.',
            style: text.bodyLarge),
        const SizedBox(height: GSSpacing.s3),
        GSButton(
          label: 'Ya llegué',
          leadingIcon: Icons.check_rounded,
          onPressed: () => advanceLeg(
              ref, ScaffoldMessenger.of(context), leg, LegStatus.completed),
        ),
      ],
    );
  }
}

// ── Colectivo, TransPadilla, intermunicipal ─────────────────────────────────
class ScheduledLegPanel extends ConsumerStatefulWidget {
  const ScheduledLegPanel({super.key, required this.leg});
  final TripLegRow leg;

  @override
  ConsumerState<ScheduledLegPanel> createState() => _ScheduledLegPanelState();
}

class _ScheduledLegPanelState extends ConsumerState<ScheduledLegPanel> {
  late Future<List<ColectivoDeparture>> _deps;
  String? _reservedId;
  String? _busy;
  final _key = const Uuid().v4();

  @override
  void initState() {
    super.initState();
    _deps = _load();
  }

  Future<List<ColectivoDeparture>> _load() {
    final l = widget.leg;
    if (l.fromNode == null || l.toNode == null) return Future.value(const []);
    return dispatchService.departures(l.fromNode!, l.toNode!);
  }

  Future<void> _reserve(ColectivoDeparture d) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = d.id);
    try {
      await dispatchService.reserveSeat(d.id, 1, _key,
          tripLegId: widget.leg.id);
      setState(() => _reservedId = d.id);
      GSToast.showWithMessenger(messenger,
          message: 'Cupo reservado', type: GSToastType.success);
    } on DispatchException catch (e) {
      GSToast.showWithMessenger(messenger,
          message: e.message, type: GSToastType.error);
      setState(() => _deps = _load());
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final l = widget.leg;
    final messenger = ScaffoldMessenger.of(context);
    final onBoard = l.status == LegStatus.inProgress;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          onBoard
              ? 'Vas en ${legModeLabel(l.mode)} hacia ${l.toLabel ?? 'tu parada'}.'
              : 'Sube en ${l.fromLabel ?? 'el punto'} hacia ${l.toLabel ?? 'tu parada'}.',
          style: text.bodyLarge,
        ),
        if (!onBoard && l.mode != 'transpadilla')
          FutureBuilder<List<ColectivoDeparture>>(
            future: _deps,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.all(GSSpacing.s3),
                  child: Center(child: CircularProgressIndicator()),
                );
              }
              // Sin señal no es lo mismo que "no hay salidas".
              if (snap.hasError) {
                return Padding(
                  padding: const EdgeInsets.only(top: GSSpacing.s2),
                  child: Row(children: [
                    Expanded(
                      child: Text('Sin señal: no pudimos ver las salidas.',
                          style: text.bodyMedium),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _deps = _load()),
                      child: const Text('Reintentar'),
                    ),
                  ]),
                );
              }
              final deps = snap.data ?? const [];
              if (deps.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(top: GSSpacing.s2),
                  child: Text(
                    'Aún no hay salidas publicadas. Los colectivos salen cuando '
                    'se llenan: ve al punto y pregunta.',
                    style: text.bodyMedium,
                  ),
                );
              }
              return Column(children: [
                for (final d in deps)
                  GSListRow(
                    icon: Icons.event_seat_outlined,
                    title: 'Sale cerca de las ${_hhmm(d.departAt)}',
                    subtitle: '${d.seatsLeft} '
                        '${d.seatsLeft == 1 ? 'cupo libre' : 'cupos libres'} · '
                        'hora estimada',
                    value: formatCop(d.fare),
                    trailing: _reservedId == d.id
                        ? Icon(Icons.check_circle_rounded,
                            color: GSColors.brand)
                        : _busy == d.id
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2.5))
                            : null,
                    onTap:
                        _reservedId == null && _busy == null && d.seatsLeft > 0
                            ? () => _reserve(d)
                            : null,
                  ),
              ]);
            },
          ),
        const SizedBox(height: GSSpacing.s3),
        if (l.mode != 'transpadilla') ...[
          GSButton(
            label: 'Pagar con QR',
            leadingIcon: Icons.qr_code_scanner_rounded,
            variant: GSButtonVariant.outline,
            onPressed: () => context.push('${AppRoutes.scanPay}?leg=${l.id}'),
          ),
          const SizedBox(height: GSSpacing.s2),
        ],
        GSButton(
          label: onBoard ? 'Llegué' : 'Ya voy a bordo',
          leadingIcon:
              onBoard ? Icons.check_rounded : Icons.directions_bus_rounded,
          onPressed: () => advanceLeg(ref, messenger, l,
              onBoard ? LegStatus.completed : LegStatus.inProgress),
        ),
      ],
    );
  }
}

String _hhmm(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '$h:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'a. m.' : 'p. m.'}';
}

// ── Mototaxi / taxi (estilo InDrive) ────────────────────────────────────────
class RideLegPanel extends ConsumerStatefulWidget {
  const RideLegPanel({super.key, required this.leg, this.pollEvery});
  final TripLegRow leg;

  /// Cada cuánto se revisa la solicitud. null = 4 s.
  final Duration? pollEvery;

  @override
  ConsumerState<RideLegPanel> createState() => _RideLegPanelState();
}

class _RideLegPanelState extends ConsumerState<RideLegPanel> {
  RideRequest? _request;
  List<RideOffer> _offers = const [];
  AssignedDriver? _driver;
  late int _fare = suggestedFare(widget.leg);
  String _key = const Uuid().v4();
  bool _busy = false;
  bool _loaded = false;
  bool _paid = false;
  Timer? _timer;
  // Una llave por pago: reintentos sin señal no cobran dos veces.
  final _payKey = const Uuid().v4();

  String get _service => widget.leg.mode;

  @override
  void initState() {
    super.initState();
    _resume();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// true si no se pudo saber si ya hay una solicitud: no se ofrece pedir
  /// otra (con llave nueva podría quedar doble).
  bool _unknown = false;

  Future<void> _resume() async {
    try {
      _request = await dispatchService.requestForLeg(widget.leg.id);
      _unknown = false;
    } catch (_) {
      _unknown = true;
    }
    if (!mounted) return;
    setState(() => _loaded = true);
    if (_request != null) _startPolling();
  }

  void _startPolling() {
    _timer?.cancel();
    _timer = Timer.periodic(
        widget.pollEvery ?? const Duration(seconds: 4), (_) => _poll());
    _poll();
  }

  Future<void> _poll() async {
    final r = _request;
    if (r == null) return;
    try {
      final fresh = await dispatchService.fetchRequest(r.id);
      if (fresh == null || !mounted) return;
      final offers = fresh.status == RideStatus.open
          ? await dispatchService.offersFor(fresh.id)
          : const <RideOffer>[];
      final driver = fresh.status == RideStatus.accepted ||
              fresh.status == RideStatus.inProgress
          ? await dispatchService.driverFor(fresh.id)
          : null;
      if (!mounted) return;
      setState(() {
        _request = fresh;
        _offers = offers;
        _driver = driver;
      });
      await _syncLeg(fresh);
    } catch (_) {
      // Sin señal: se reintenta en el próximo ciclo.
    }
  }

  /// El tramo sigue al viaje del conductor: recoge → en curso; termina → hecho.
  Future<void> _syncLeg(RideRequest r) async {
    final leg = widget.leg;
    final messenger = ScaffoldMessenger.of(context);
    if (r.status == RideStatus.inProgress &&
        leg.status != LegStatus.inProgress) {
      await advanceLeg(ref, messenger, leg, LegStatus.inProgress,
          agreedFare: r.agreedFare);
    } else if (r.status == RideStatus.completed) {
      _timer?.cancel();
      // D5: el tramo se cierra pagado. Si aún no se pagó, se espera el pago.
      if (_paid || await paymentService.isRidePaid(r.id)) {
        await advanceLeg(ref, messenger, leg, LegStatus.completed,
            agreedFare: r.agreedFare);
      }
    }
  }

  Future<void> _pay(String method) async {
    final r = _request;
    if (r == null) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await paymentService.payRide(r.id, method, _payKey);
      ref.invalidate(walletProvider);
      setState(() => _paid = true);
      GSToast.showWithMessenger(messenger,
          message: method == 'cash'
              ? 'Listo: paga ${formatCop(r.agreedFare ?? r.offeredFare)} en efectivo.'
              : 'Pagaste ${formatCop(r.agreedFare ?? r.offeredFare)} con tu saldo de prueba.',
          type: GSToastType.success);
      if (r.status == RideStatus.completed) {
        if (mounted) {
          await showRateSheet(context, requestId: r.id, asDriver: false);
        }
        await _syncLeg(r);
      }
    } on PaymentException catch (e) {
      GSToast.showWithMessenger(messenger,
          message: e.message, type: GSToastType.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _sendRequest() async {
    final l = widget.leg;
    if (l.from == null || l.to == null) return;
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      if (l.status == LegStatus.planned) {
        await dispatchService.legTransition(l.id, LegStatus.awaitingDispatch);
      }
      final id = await dispatchService.requestRide(
        service: _service,
        origin: l.from!,
        originLabel: l.fromLabel ?? 'Punto de salida',
        dest: l.to!,
        destLabel: l.toLabel ?? 'Destino',
        offeredFare: _fare,
        idempotencyKey: _key,
        tripLegId: l.id,
      );
      _request = await dispatchService.fetchRequest(id);
      _startPolling();
    } on DispatchException catch (e) {
      GSToast.showWithMessenger(messenger,
          message: e.message, type: GSToastType.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _acceptOffer(RideOffer o) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await dispatchService.acceptOffer(o.id);
      await _poll();
    } on DispatchException catch (e) {
      GSToast.showWithMessenger(messenger,
          message: e.message, type: GSToastType.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _cancelRequest() async {
    final r = _request;
    if (r == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await dispatchService.transitionRide(r.id, RideStatus.cancelled);
    } on DispatchException catch (e) {
      GSToast.showWithMessenger(messenger,
          message: e.message, type: GSToastType.error);
      return;
    }
    _timer?.cancel();
    setState(() {
      _request = null;
      _offers = const [];
      _key = const Uuid().v4();
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final r = _request;
    final label = _service == 'taxi' ? 'taxi' : 'mototaxi';
    if (!_loaded) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_unknown) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Sin señal: no sabemos si ya pediste este tramo.',
              style: text.bodyLarge),
          TextButton(
            onPressed: () {
              setState(() => _loaded = false);
              _resume();
            },
            child: const Text('Reintentar'),
          ),
        ],
      );
    }

    // 1. Sin pedir: elegir tarifa y pedir.
    if (r == null ||
        r.status == RideStatus.cancelled ||
        (r.status == RideStatus.open && !r.isLive(DateTime.now())) ||
        r.status == RideStatus.expired) {
      final expired = r != null && r.status != RideStatus.cancelled;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            expired
                ? 'Nadie aceptó a tiempo. Sube un poco la tarifa o vuelve a pedir.'
                : 'Pide un $label hasta ${widget.leg.toLabel ?? 'tu destino'}. '
                    'Los conductores cercanos aceptan o te ofrecen otro precio.',
            style: text.bodyLarge,
          ),
          const SizedBox(height: GSSpacing.s3),
          Row(
            children: [
              IconButton(
                tooltip: 'Bajar \$500',
                onPressed:
                    _fare > 1000 ? () => setState(() => _fare -= 500) : null,
                icon: const Icon(Icons.remove_rounded),
              ),
              Expanded(
                child: Text(
                  formatCop(_fare),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: GSFonts.display,
                    fontFeatures: GSFonts.tabular,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
                    color: GSColors.text,
                  ),
                ),
              ),
              IconButton(
                tooltip: 'Subir \$500',
                onPressed: () => setState(() => _fare += 500),
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          if (widget.leg.fareMax > 0)
            Text(
              'Referencia: ${formatCop(widget.leg.fareMin)}–${formatCop(widget.leg.fareMax)}',
              textAlign: TextAlign.center,
              style: text.bodySmall,
            ),
          const SizedBox(height: GSSpacing.s3),
          GSButton(
            label: 'Pedir $label por ${formatCop(_fare)}',
            isLoading: _busy,
            onPressed: _busy
                ? null
                : () {
                    if (expired) _key = const Uuid().v4();
                    _sendRequest();
                  },
          ),
        ],
      );
    }

    // 2. Esperando: ofertas.
    if (r.status == RideStatus.open) {
      final left =
          r.expiresAt.difference(DateTime.now()).inSeconds.clamp(0, 999);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2.5)),
            const SizedBox(width: GSSpacing.s3),
            Expanded(
              child: Text(
                  'Buscando $label por ${formatCop(r.offeredFare)}… '
                  '(${left ~/ 60}:${(left % 60).toString().padLeft(2, '0')})',
                  style: text.bodyLarge),
            ),
          ]),
          for (final o in _offers)
            GSListRow(
              icon: Icons.local_offer_outlined,
              title: 'Un conductor ofrece ${formatCop(o.fare)}',
              onTap: _busy ? null : () => _acceptOffer(o),
              trailing: const Text('Aceptar'),
            ),
          const SizedBox(height: GSSpacing.s2),
          TextButton(
              onPressed: _cancelRequest,
              child: const Text('Cancelar solicitud')),
        ],
      );
    }

    // 3. Asignado o en camino.
    final d = _driver;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          r.status == RideStatus.inProgress
              ? 'Vas con ${d?.firstName ?? 'tu conductor'}.'
              : '${d?.firstName ?? 'Tu conductor'} viene por ti.',
          style: text.titleLarge,
        ),
        if (d?.plate != null)
          Text('Placa ${d!.plate}${d.vehicle == null ? '' : ' · ${d.vehicle}'}',
              style: text.bodyLarge?.copyWith(fontFeatures: GSFonts.tabular)),
        if (d != null)
          Text(
            d.rating == null
                ? 'Conductor nuevo en GoSmart'
                : '${d.rating!.toStringAsFixed(1)} de 5 · ${d.ratings} calificaciones',
            style: text.bodyMedium?.copyWith(fontFeatures: GSFonts.tabular),
          ),
        Text('Tarifa acordada: ${formatCop(r.agreedFare ?? r.offeredFare)}',
            style: text.bodyMedium),
        const SizedBox(height: GSSpacing.s2),
        if (r.status == RideStatus.accepted)
          Text('Revisa que la placa coincida antes de subir.',
              style: text.bodySmall),
        if (r.status == RideStatus.accepted)
          TextButton(onPressed: _cancelRequest, child: const Text('Cancelar')),
        if (r.status != RideStatus.accepted && !_paid) ...[
          const SizedBox(height: GSSpacing.s3),
          Text(
            r.status == RideStatus.completed
                ? 'Llegaste. Paga el tramo para cerrarlo.'
                : 'Puedes pagar ya o al llegar.',
            style: text.bodyMedium,
          ),
          const SizedBox(height: GSSpacing.s2),
          GSButton(
            label:
                'Pagar ${formatCop(r.agreedFare ?? r.offeredFare)} con saldo de prueba',
            leadingIcon: Icons.account_balance_wallet_outlined,
            isLoading: _busy,
            onPressed: _busy ? null : () => _pay('wallet'),
          ),
          const SizedBox(height: GSSpacing.s2),
          GSButton(
            label: 'Pago en efectivo',
            leadingIcon: Icons.payments_outlined,
            variant: GSButtonVariant.outline,
            onPressed: _busy ? null : () => _pay('cash'),
          ),
        ],
        if (_paid)
          Padding(
            padding: const EdgeInsets.only(top: GSSpacing.s2),
            child: Text('Tramo pagado.', style: text.bodyMedium),
          ),
      ],
    );
  }
}
