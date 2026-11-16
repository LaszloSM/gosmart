// lib/features/trip/trip_detail_screen.dart
// Detalle de un viaje del historial, como InDrive: el recorrido en el mapa,
// cómo terminó, con quién (nombre de pila, vehículo y placa), cuánto y cómo se
// pagó, las horas (pedido, aceptado, terminado), el motivo si se canceló y
// cada intento si se pidió más de una vez. "Pedir de nuevo" y "Ver recibo".
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../core/clock.dart';
import '../../core/money.dart';
import '../../models/route_result.dart';
import '../../models/trip_history.dart';
import '../../router/app_router.dart';
import '../../services/dispatch_service.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/gs_button.dart';
import '../../widgets/gs_inline_error.dart';
import '../../widgets/gs_list_row.dart';
import '../home/widgets/map_view.dart';
import 'trip_history_screen.dart';
import 'trip_screen.dart' show legModeIcon, legModeLabel;
import 'widgets/cancel_sheet.dart';
import 'widgets/trip_visuals.dart';

class TripDetailScreen extends ConsumerStatefulWidget {
  const TripDetailScreen({super.key, required this.item, this.load, this.showMap = true});

  /// Lo que ya se sabe (del historial): se pinta al instante y se completa.
  final HistoryItem item;

  /// Para pruebas: de dónde sale el detalle.
  final Future<TripDetail?> Function(HistoryItem)? load;

  /// Sin mapa en pruebas (las teselas no cargan).
  final bool showMap;

  @override
  ConsumerState<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends ConsumerState<TripDetailScreen> {
  late Future<TripDetail?> _f = _load();

  Future<TripDetail?> _load() =>
      (widget.load ?? dispatchService.historyDetail)(widget.item);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GSColors.background,
      appBar: AppBar(title: const Text('Detalle del viaje')),
      body: FutureBuilder<TripDetail?>(
        future: _f,
        builder: (context, snap) {
          final loading = snap.connectionState != ConnectionState.done;
          // Mientras carga se ve lo del historial; si falla, igual y un aviso.
          final d = snap.data ?? TripDetail(item: widget.item);
          return ListView(
            padding: const EdgeInsets.only(bottom: GSSpacing.s8),
            children: [
              if (widget.showMap && d.item.from != null && d.item.to != null)
                _RouteMap(from: d.item.from!, to: d.item.to!),
              if (loading) const LinearProgressIndicator(minHeight: 2),
              if (!loading && (snap.hasError || snap.data == null))
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                      GSSpacing.s4, GSSpacing.s3, GSSpacing.s4, 0),
                  child: GSInlineError(
                    message: 'No pudimos cargar todo el detalle',
                    onRetry: () => setState(() => _f = _load()),
                  ),
                ),
              _DetailBody(detail: d),
            ],
          );
        },
      ),
    );
  }
}

class _RouteMap extends StatelessWidget {
  const _RouteMap({required this.from, required this.to});
  final LatLng from;
  final LatLng to;

  @override
  Widget build(BuildContext context) {
    final route = RouteResult(
      legs: [
        RouteLeg(
          mode: 'drive',
          transitMode: 'mototaxi',
          points: [from, to],
          color: GSColors.taxi,
          durationMin: 0,
          distanceKm: 0,
        ),
      ],
      distanceKm: 0,
      durationMin: 0,
      profile: RouteProfile.driving,
    );
    return SizedBox(
      height: 200,
      child: MapView(
        initialCenter: LatLng((from.latitude + to.latitude) / 2,
            (from.longitude + to.longitude) / 2),
        initialZoom: 13,
        route: route,
        pin: to,
        onLongPressEnabled: false,
        onLongPress: (_) {},
        padding: const EdgeInsets.all(GSSpacing.s6),
        onCreated: (c) => Future.delayed(
            const Duration(milliseconds: 300), () => c.fit([from, to])),
      ),
    );
  }
}

String _payLabel(String? m) => switch (m) {
      'cash' => 'Efectivo',
      'wallet' => 'Saldo GoSmart',
      'qr' => 'QR',
      _ => 'Sin pago registrado',
    };

String _rideStatusLabel(RideCard r, {required bool asDriver}) => switch (r.status) {
      'completed' => 'Completado',
      'accepted' => asDriver ? 'Ibas por el pasajero' : 'El conductor iba en camino',
      'in_progress' => 'En curso',
      'open' => 'Buscando conductor',
      'expired' => 'Nadie aceptó a tiempo',
      _ => r.cancelledBy == 'driver'
          ? (asDriver ? 'Lo cancelaste' : 'Lo canceló el conductor')
          : (asDriver ? 'Lo canceló el pasajero' : 'Lo cancelaste'),
    };

String _minutesBetween(DateTime a, DateTime b) {
  final m = b.difference(a).inMinutes;
  if (m < 1) return 'menos de 1 min';
  if (m < 60) return '$m min';
  return '${m ~/ 60} h ${m % 60} min';
}

class _DetailBody extends ConsumerWidget {
  const _DetailBody({required this.detail});
  final TripDetail detail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final item = detail.item;
    final ride = detail.mainRide;
    final (statusLabel, tone) = item.statusText;
    final (statusIcon, statusColor) = historyToneStyle(tone);
    final price = item.price;
    final rides = detail.rides;
    final mode = item.mainMode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Resumen ────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(
              GSSpacing.s4, GSSpacing.s4, GSSpacing.s4, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.createdAt == null ? 'Viaje' : tripWhen(item.createdAt!),
                      style: text.labelLarge?.copyWith(color: GSColors.textMuted),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(legModeIcon(mode), size: GSSize.iconMd, color: GSColors.text),
                        const SizedBox(width: GSSpacing.s1),
                        Flexible(
                          child: Text(
                            '${legModeLabel(mode)}${item.asDriver ? ' · como conductor' : ''}',
                            style: text.titleLarge,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: GSSpacing.s1),
                    Row(
                      children: [
                        Icon(statusIcon, size: GSSize.iconSm, color: statusColor),
                        const SizedBox(width: GSSpacing.s1),
                        Flexible(
                          child: Text(statusLabel,
                              style: text.titleSmall?.copyWith(color: statusColor)),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              if (price != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(formatCop(price),
                        style: text.headlineSmall
                            ?.copyWith(fontFeatures: GSFonts.tabular)),
                    Text(
                      item.totalPaid > 0
                          ? (item.asDriver ? 'Cobrado' : 'Pagado')
                          : (ride?.agreedFare != null ? 'Acordado' : 'Ofrecido'),
                      style: text.bodySmall,
                    ),
                  ],
                ),
            ],
          ),
        ),

        // ── Recorrido ──────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(
              GSSpacing.s4, GSSpacing.s4, GSSpacing.s4, 0),
          child: Container(
            padding: const EdgeInsets.all(GSSpacing.s4),
            decoration: BoxDecoration(
              color: GSColors.surface,
              borderRadius: BorderRadius.circular(GSRadius.lg),
            ),
            child: Column(
              children: [
                _Stop(
                  icon: Icons.trip_origin_rounded,
                  color: GSColors.brand,
                  title: item.originLabel ?? 'Salida',
                  time: ride?.createdAt ?? item.createdAt,
                ),
                Padding(
                  padding: const EdgeInsets.only(left: 9),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Container(width: 2, height: 18, color: GSColors.line),
                  ),
                ),
                _Stop(
                  icon: Icons.location_on_rounded,
                  color: GSColors.text,
                  title: item.destLabel ?? 'Destino',
                  time: tone == HistoryTone.done ? (ride?.finishedAt ?? item.endedAt) : null,
                ),
              ],
            ),
          ),
        ),

        // ── Con quién ──────────────────────────────────────────────────────
        if (ride?.otherName != null) ...[
          GSSectionTitle(item.asDriver ? 'Pasajero' : 'Conductor'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: GSSpacing.s4),
            child: Container(
              padding: const EdgeInsets.all(GSSpacing.s3),
              decoration: BoxDecoration(
                color: GSColors.surface,
                borderRadius: BorderRadius.circular(GSRadius.lg),
              ),
              child: Row(
                children: [
                  DriverAvatar(name: ride!.otherName!, size: 44),
                  const SizedBox(width: GSSpacing.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(ride.otherName!, style: text.titleMedium),
                        if (ride.vehicle != null)
                          Text(ride.vehicle!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.bodySmall),
                        if (ride.myStars != null)
                          Semantics(
                            label: 'Le diste ${ride.myStars} de 5 estrellas',
                            excludeSemantics: true,
                            child: Row(children: [
                              for (var i = 0; i < 5; i++)
                                Icon(
                                  i < ride.myStars! ? Icons.star_rounded : Icons.star_outline_rounded,
                                  size: GSSize.iconSm,
                                  color: GSColors.text,
                                ),
                            ]),
                          ),
                      ],
                    ),
                  ),
                  if (ride.plate != null) ...[
                    const SizedBox(width: GSSpacing.s2),
                    _Plate(ride.plate!),
                  ],
                ],
              ),
            ),
          ),
        ],

        // ── Datos ──────────────────────────────────────────────────────────
        const GSSectionTitle('Detalles'),
        GSGroup(children: [
          if (ride != null) ...[
            GSListRow(
              icon: Icons.sell_rounded,
              title: ride.agreedFare != null ? 'Tarifa acordada' : 'Tarifa ofrecida',
              value: formatCop(ride.fare),
              subtitle: ride.agreedFare != null && ride.agreedFare != ride.offeredFare
                  ? 'Ofreciste ${formatCop(ride.offeredFare)}'
                  : null,
            ),
            GSListRow(
              icon: Icons.payments_rounded,
              title: 'Pago',
              value: _payLabel(ride.payMethod),
            ),
            if (ride.createdAt != null)
              GSListRow(
                icon: Icons.schedule_rounded,
                title: 'Pedido',
                value: formatClock(ride.createdAt!),
              ),
            if (ride.acceptedAt != null)
              GSListRow(
                icon: Icons.how_to_reg_rounded,
                title: 'Aceptado',
                value: formatClock(ride.acceptedAt!),
                subtitle: ride.createdAt == null
                    ? null
                    : 'Tardó ${_minutesBetween(ride.createdAt!, ride.acceptedAt!)} en conseguir conductor',
              ),
            if (ride.finishedAt != null)
              GSListRow(
                icon: ride.status == 'completed' ? Icons.flag_rounded : Icons.cancel_rounded,
                title: ride.status == 'completed' ? 'Terminado' : 'Cerrado',
                value: formatClock(ride.finishedAt!),
                subtitle: ride.status == 'completed' && ride.acceptedAt != null
                    ? 'Duró ${_minutesBetween(ride.acceptedAt!, ride.finishedAt!)}'
                    : null,
              ),
          ] else
            const GSListRow(
              icon: Icons.info_rounded,
              title: 'No se pidió conductor',
              subtitle: 'El viaje se planeó pero no se llegó a pedir.',
            ),
          if (ride != null && ride.status == 'cancelled')
            GSListRow(
              icon: Icons.cancel_rounded,
              title: _rideStatusLabel(ride, asDriver: item.asDriver),
              subtitle: ride.cancelReason == null
                  ? 'Antes de que alguien aceptara'
                  : cancelReasonLabel(ride.cancelReason!),
            ),
        ]),

        // ── Intentos (si se pidió más de una vez) ──────────────────────────
        if (rides.length > 1) ...[
          GSSectionTitle('Intentos (${rides.length})'),
          GSGroup(children: [
            for (final r in rides)
              GSListRow(
                icon: legModeIcon(r.service),
                title: _rideStatusLabel(r, asDriver: false),
                subtitle: [
                  if (r.createdAt != null) formatClock(r.createdAt!),
                  if (r.otherName != null) r.otherName!,
                  if (r.cancelReason != null) cancelReasonLabel(r.cancelReason!),
                ].join(' · '),
                value: formatCop(r.fare),
              ),
          ]),
        ],

        // ── Acciones ───────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(
              GSSpacing.s4, GSSpacing.s5, GSSpacing.s4, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (tone == HistoryTone.active && !item.asDriver)
                GSButton(
                  label: 'Ver viaje en curso',
                  leadingIcon: Icons.navigation_rounded,
                  onPressed: () => context.go(AppRoutes.trip),
                )
              else if (item.canRepeat)
                GSButton(
                  label: 'Pedir de nuevo',
                  leadingIcon: Icons.replay_rounded,
                  onPressed: () => repeatTrip(context, ref, item),
                ),
              if (!item.asDriver && item.status == 'completed') ...[
                const SizedBox(height: GSSpacing.s2),
                GSButton(
                  label: 'Ver recibo',
                  leadingIcon: Icons.receipt_long_rounded,
                  variant: GSButtonVariant.outline,
                  onPressed: () => context.push('${AppRoutes.receipt}?id=${item.id}'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _Stop extends StatelessWidget {
  const _Stop({required this.icon, required this.color, required this.title, this.time});
  final IconData icon;
  final Color color;
  final String title;
  final DateTime? time;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: GSSize.iconMd, color: color),
        const SizedBox(width: GSSpacing.s3),
        Expanded(
          child: Text(title, maxLines: 3, overflow: TextOverflow.ellipsis, style: text.bodyLarge),
        ),
        if (time != null) ...[
          const SizedBox(width: GSSpacing.s2),
          Text(formatClock(time!),
              style: text.bodySmall?.copyWith(fontFeatures: GSFonts.tabular)),
        ],
      ],
    );
  }
}

/// Placa colombiana (amarilla), igual a la del viaje en curso.
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
