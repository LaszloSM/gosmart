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
import '../../../core/clock.dart';
import '../../../core/motion.dart';
import '../../../widgets/gs_vehicle_pin.dart';
import '../../safety/sos_sheet.dart';
import 'trip_visuals.dart';

/// Tarifa con la que se pide: el precio del tramo (taxi: oficial; mototaxi:
/// sugerida), en múltiplos de $100.
int suggestedFare(TripLegRow l) {
  final v = l.fareMax > 0 ? l.fareMax : 5000;
  return ((v / 100).round() * 100).clamp(1000, 500000).toInt();
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
                    icon: Icons.event_seat_rounded,
                    title: 'Sale cerca de las ${formatClock(d.departAt)}',
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


// ── Mototaxi / taxi (estilo InDrive) ────────────────────────────────────────
class RideLegPanel extends ConsumerStatefulWidget {
  const RideLegPanel({super.key, required this.leg, this.pollEvery, this.preview});
  final TripLegRow leg;

  /// Solo para pruebas y capturas: arranca en ese estado sin ir a la red.
  final ({RideRequest? request, List<RideOffer> offers, AssignedDriver? driver, bool paid})?
      preview;

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

  /// Forma de pago elegida al pedir; decide cuál botón va primero al pagar.
  String _method = 'wallet';
  Timer? _timer;
  // Una llave por pago: reintentos sin señal no cobran dos veces.
  final _payKey = const Uuid().v4();

  String get _service => widget.leg.mode;

  @override
  void initState() {
    super.initState();
    final p = widget.preview;
    if (p != null) {
      _request = p.request;
      _offers = p.offers;
      _driver = p.driver;
      _paid = p.paid;
      _loaded = true;
      return;
    }
    _resume();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _clock?.cancel();
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

  /// Mientras se busca, el reloj de la solicitud baja de a un segundo.
  Timer? _clock;

  void _startPolling() {
    _clock?.cancel();
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && _request?.status == RideStatus.open) setState(() {});
    });
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
      // El mapa del viaje pinta y desliza al conductor.
      ref.read(tripDriverProvider.notifier).state = driver;
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
    ref.read(tripDriverProvider.notifier).state = null;
    setState(() {
      _request = null;
      _offers = const [];
      _driver = null;
      _key = const Uuid().v4();
    });
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final r = _request;
    final label = _service == 'taxi' ? 'taxi' : 'mototaxi';
    final reduce = MediaQuery.of(context).disableAnimations;
    if (!_loaded) {
      return const Padding(
        padding: EdgeInsets.all(GSSpacing.s6),
        child: Center(child: CircularProgressIndicator()),
      );
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

    final Widget body;
    final String phase;
    // 1. Sin pedir: proponer tarifa, forma de pago y pedir.
    if (r == null ||
        r.status == RideStatus.cancelled ||
        (r.status == RideStatus.open && !r.isLive(DateTime.now())) ||
        r.status == RideStatus.expired) {
      phase = 'ask';
      body = _askView(context, r, label);
    } else if (r.status == RideStatus.open) {
      // 2. Buscando: radar y ofertas.
      phase = 'search';
      body = _searchView(context, r, label);
    } else {
      // 3. Viene, vas con él, pagar.
      phase = 'ride-${r.status.name}-$_paid';
      body = _rideView(context, r);
    }
    // Entre fases: fundido con un leve deslizamiento (Material shared axis).
    return AnimatedSwitcher(
      duration: reduce ? Duration.zero : GSDuration.normal,
      switchInCurve: GSCurve.enter,
      switchOutCurve: GSCurve.exit,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.topCenter,
        children: [...previous, if (current != null) current],
      ),
      transitionBuilder: (child, a) => FadeTransition(
        opacity: a,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(a),
          child: child,
        ),
      ),
      child: KeyedSubtree(key: ValueKey(phase), child: body),
    );
  }

  Widget _askView(BuildContext context, RideRequest? r, String label) {
    final text = Theme.of(context).textTheme;
    final expired = r != null && r.status != RideStatus.cancelled;
    final leg = widget.leg;
    final balance = ref.watch(walletBalanceProvider);
    final hint = leg.fareMax <= 0
        ? null
        : leg.mode == 'taxi'
            ? 'Tarifa oficial: ${formatCop(leg.fareMax)}'
            : 'Sugerida: ${formatCop(leg.fareMax)}. Puedes ofrecer otra.';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(expired ? 'Nadie aceptó a tiempo' : 'Tu oferta', style: text.titleLarge),
        const SizedBox(height: 2),
        Text(
          expired
              ? 'Sube un poco la tarifa o vuelve a pedir.'
              : 'Los conductores cercanos aceptan o te proponen otro precio.',
          style: text.bodyMedium,
        ),
        const SizedBox(height: GSSpacing.s4),
        FareComposer(
          fare: _fare,
          onChanged: (v) => setState(() => _fare = v.clamp(1000, 500000).toInt()),
          hint: hint,
        ),
        const SizedBox(height: GSSpacing.s4),
        PayMethodPicker(
          method: _method,
          balance: balance > 0 ? balance : null,
          onChanged: (m) => setState(() => _method = m),
        ),
        if (_method == 'wallet' && balance < _fare)
          Padding(
            padding: const EdgeInsets.only(top: GSSpacing.s2),
            child: Text('Tu saldo no alcanza: podrás pagar en efectivo.',
                style: text.bodySmall),
          ),
        const SizedBox(height: GSSpacing.s4),
        GSButton(
          label: 'Pedir $label por ${formatCop(_fare)}',
          leadingIcon: vehicleIcon(_service),
          size: GSButtonSize.lg,
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

  Widget _searchView(BuildContext context, RideRequest r, String label) {
    final text = Theme.of(context).textTheme;
    final left = r.expiresAt.difference(DateTime.now());
    final secs = left.inSeconds.clamp(0, 999);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(child: SearchingRadar(icon: vehicleIcon(_service))),
        const SizedBox(height: GSSpacing.s3),
        Text(
          _offers.isEmpty
              ? 'Buscando $label por ${formatCop(r.offeredFare)}…'
              : _offers.length == 1
                  ? 'Un conductor te hizo una oferta'
                  : '${_offers.length} conductores te hicieron ofertas',
          textAlign: TextAlign.center,
          style: text.titleMedium,
        ),
        const SizedBox(height: 2),
        Text(
          'Quedan ${secs ~/ 60}:${(secs % 60).toString().padLeft(2, '0')} · '
          'avisamos a los conductores cerca',
          textAlign: TextAlign.center,
          style: text.bodySmall?.copyWith(fontFeatures: GSFonts.tabular),
        ),
        const SizedBox(height: GSSpacing.s3),
        CountdownBar(left: left, total: const Duration(minutes: 3)),
        const SizedBox(height: GSSpacing.s3),
        for (var i = 0; i < _offers.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: GSSpacing.s2),
            child: OfferCard(
              key: ValueKey(_offers[i].id),
              offer: _offers[i],
              index: i,
              myFare: r.offeredFare,
              busy: _busy,
              onAccept: () => _acceptOffer(_offers[i]),
            ),
          ),
        TextButton(
          onPressed: _cancelRequest,
          style: TextButton.styleFrom(foregroundColor: GSColors.textMuted),
          child: const Text('Cancelar solicitud'),
        ),
      ],
    );
  }

  Widget _rideView(BuildContext context, RideRequest r) {
    final text = Theme.of(context).textTheme;
    final d = _driver;
    final fare = r.agreedFare ?? r.offeredFare;
    final pickup = widget.leg.from;
    final eta = d?.at != null && pickup != null ? etaMinutes(d!.at!, pickup) : null;
    final coming = r.status == RideStatus.accepted;
    final done = r.status == RideStatus.completed;
    final title = coming
        ? '${d?.firstName ?? 'Tu conductor'} viene por ti'
        : done
            ? 'Llegaste'
            : 'Vas con ${d?.firstName ?? 'tu conductor'}';
    final subtitle = coming
        ? (eta == null ? 'En camino al punto de recogida' : 'Llega en unos $eta min')
        : done
            ? 'Paga el tramo para cerrarlo.'
            : 'Hacia ${widget.leg.toLabel ?? 'tu destino'}';
    final cashFirst = _method == 'cash';
    final payWallet = GSButton(
      label: 'Pagar ${formatCop(fare)} con saldo de prueba',
      leadingIcon: Icons.account_balance_wallet_rounded,
      variant: cashFirst ? GSButtonVariant.outline : GSButtonVariant.primary,
      isLoading: _busy && !cashFirst,
      onPressed: _busy ? null : () => _pay('wallet'),
    );
    final payCash = GSButton(
      label: 'Pago en efectivo',
      leadingIcon: Icons.payments_rounded,
      variant: cashFirst ? GSButtonVariant.primary : GSButtonVariant.outline,
      isLoading: _busy && cashFirst,
      onPressed: _busy ? null : () => _pay('cash'),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: text.titleLarge),
                  Text(subtitle, style: text.bodyMedium?.copyWith(fontFeatures: GSFonts.tabular)),
                ],
              ),
            ),
            if (coming && eta != null) _EtaBadge(minutes: eta),
          ],
        ),
        const SizedBox(height: GSSpacing.s3),
        _DriverCard(driver: d, fare: formatCop(fare)),
        if (coming) ...[
          const SizedBox(height: GSSpacing.s2),
          Row(
            children: [
              Icon(Icons.verified_user_rounded, size: GSSize.iconSm, color: GSColors.textMuted),
              const SizedBox(width: GSSpacing.s2),
              Expanded(
                child: Text('Revisa que la placa coincida antes de subir.',
                    style: text.bodySmall),
              ),
            ],
          ),
          const SizedBox(height: GSSpacing.s2),
          Row(
            children: [
              Expanded(
                child: GSButton(
                  label: 'Ayuda',
                  leadingIcon: Icons.health_and_safety_rounded,
                  variant: GSButtonVariant.outline,
                  onPressed: () => showSosSheet(context),
                ),
              ),
              const SizedBox(width: GSSpacing.s2),
              Expanded(
                child: GSButton(
                  label: 'Cancelar',
                  leadingIcon: Icons.close_rounded,
                  variant: GSButtonVariant.ghost,
                  onPressed: _cancelRequest,
                ),
              ),
            ],
          ),
        ],
        if (!coming && !_paid) ...[
          const SizedBox(height: GSSpacing.s4),
          if (!done)
            Padding(
              padding: const EdgeInsets.only(bottom: GSSpacing.s2),
              child: Text('Puedes pagar ya o al llegar.', style: text.bodyMedium),
            ),
          if (cashFirst) payCash else payWallet,
          const SizedBox(height: GSSpacing.s2),
          if (cashFirst) payWallet else payCash,
        ],
        if (_paid)
          Padding(
            padding: const EdgeInsets.only(top: GSSpacing.s3),
            child: Row(
              children: [
                Icon(Icons.check_circle_rounded, color: GSColors.brand),
                const SizedBox(width: GSSpacing.s2),
                Text('Tramo pagado', style: text.titleMedium),
              ],
            ).gsPop(context, from: 0.9),
          ),
      ],
    );
  }
}

/// Minutos que faltan, en una píldora de marca (lo que más se mira).
class _EtaBadge extends StatelessWidget {
  const _EtaBadge({required this.minutes});
  final int minutes;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Llega en $minutes minutos',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: GSSpacing.s3, vertical: GSSpacing.s2),
        decoration: BoxDecoration(
          color: GSColors.brand,
          borderRadius: BorderRadius.circular(GSRadius.full),
        ),
        child: Column(
          children: [
            Text('$minutes',
                style: TextStyle(
                  fontFamily: GSFonts.sans,
                  fontFeatures: GSFonts.tabular,
                  fontSize: 22,
                  height: 1,
                  fontWeight: FontWeight.w800,
                  color: GSColors.onBrand,
                )),
            Text('min',
                style: TextStyle(
                  fontFamily: GSFonts.sans,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: GSColors.onBrand,
                )),
          ],
        ),
      ),
    );
  }
}

/// Conductor asignado como en InDrive/DiDi: inicial con la calificación,
/// el vehículo, la placa como una placa de verdad y la tarifa acordada.
class _DriverCard extends StatelessWidget {
  const _DriverCard({required this.driver, required this.fare});

  final AssignedDriver? driver;
  final String fare;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final d = driver;
    return Container(
      padding: const EdgeInsets.all(GSSpacing.s3),
      decoration: BoxDecoration(
        color: GSColors.surface,
        borderRadius: BorderRadius.circular(GSRadius.lg),
        border: Border.all(color: GSColors.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              DriverAvatar(name: d?.firstName ?? '?'),
              const SizedBox(width: GSSpacing.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      d?.firstName ?? 'Tu conductor',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: text.titleMedium,
                    ),
                    if (d?.vehicle != null)
                      Text(d!.vehicle!,
                          maxLines: 1, overflow: TextOverflow.ellipsis, style: text.bodySmall),
                    Row(
                      children: [
                        Icon(Icons.star_rounded, size: GSSize.iconSm, color: GSColors.text),
                        const SizedBox(width: 2),
                        Flexible(
                          child: Text(
                            d?.rating == null
                                ? 'Conductor nuevo en GoSmart'
                                : '${d!.rating!.toStringAsFixed(1).replaceAll('.', ',')} (${d.ratings})',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: text.bodySmall?.copyWith(fontFeatures: GSFonts.tabular),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (d?.plate != null) ...[
                const SizedBox(width: GSSpacing.s2),
                _Plate(d!.plate!),
              ],
            ],
          ),
          const Divider(height: GSSpacing.s6),
          Row(
            children: [
              Text('Tarifa acordada', style: text.bodyMedium),
              const Spacer(),
              Text(fare, style: text.titleLarge?.copyWith(fontFeatures: GSFonts.tabular)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Placa colombiana: fondo amarillo, borde de tinta y letras gruesas
/// tabulares. Se lee de un vistazo para compararla con la moto.
class _Plate extends StatelessWidget {
  const _Plate(this.plate);
  final String plate;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Placa $plate',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: const Color(0xFFFFD43B),
          borderRadius: BorderRadius.circular(GSRadius.sm),
          border: Border.all(color: const Color(0xFF14161B), width: 2),
        ),
        child: Text(
          plate,
          style: const TextStyle(
            fontFamily: GSFonts.sans,
            fontFeatures: GSFonts.tabular,
            fontSize: 16,
            fontWeight: FontWeight.w800,
            letterSpacing: 1,
            color: Color(0xFF14161B),
          ),
        ),
      ),
    );
  }
}
