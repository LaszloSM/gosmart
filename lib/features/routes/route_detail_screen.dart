// lib/features/routes/route_detail_screen.dart
// Detalle de la ruta activa: resumen en placa, tramos encadenados y tarifa de
// referencia. Iniciar el viaje llega en la Fase 6; aquí no se finge.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:uuid/uuid.dart';

import '../../providers/auth_provider.dart';
import '../../providers/dispatch_provider.dart';
import '../../services/dispatch_service.dart';
import '../../widgets/gs_toast.dart';
import '../../core/money.dart';
import '../../models/route_result.dart';
import '../../providers/active_route_provider.dart';
import '../../providers/selected_mode_provider.dart';
import '../../router/app_router.dart';
import '../../services/eco_service.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/gs_button.dart';
import '../../widgets/gs_empty_state.dart';
import '../../widgets/gs_list_row.dart';
import '../../widgets/gs_route_plate.dart';
import '../safety/trip_share_section.dart';

class RouteDetailScreen extends ConsumerStatefulWidget {
  const RouteDetailScreen({super.key});

  @override
  ConsumerState<RouteDetailScreen> createState() => _RouteDetailScreenState();
}

class _RouteDetailScreenState extends ConsumerState<RouteDetailScreen> {
  bool _starting = false;
  // Una llave por pantalla: tocar dos veces no crea dos viajes.
  final _tripKey = const Uuid().v4();

  Future<void> _startTrip(RouteResult route) async {
    if (ref.read(isGuestProvider)) {
      context.push(AppRoutes.login);
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    setState(() => _starting = true);
    try {
      await dispatchService.createTrip(
        route,
        originLabel: route.legs.first.fromLabel ?? 'Tu ubicación',
        destLabel:
            route.destinationLabel ?? route.legs.last.toLabel ?? 'Tu destino',
        idempotencyKey: _tripKey,
      );
      ref.invalidate(activeTripProvider);
      router.go(AppRoutes.trip);
    } on DispatchException catch (e) {
      GSToast.showWithMessenger(messenger,
          message: e.message, type: GSToastType.error);
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final route = ref.watch(activeRouteProvider);
    final mode = ref.watch(selectedModeProvider);

    return Scaffold(
      backgroundColor: GSColors.background,
      appBar: AppBar(title: const Text('Tu ruta')),
      body: route == null
          ? ListView(children: [
              GSEmptyState(
                icon: Icons.route_rounded,
                title: 'Sin ruta todavía',
                subtitle: 'Elige a dónde vas y en qué, y aquí verás los '
                    'tramos, el tiempo y la tarifa.',
                actionLabel: 'Planear una ruta',
                onAction: () => context.pushReplacement(AppRoutes.routePlanner),
              ),
            ])
          : _RouteBody(route: route, mode: mode),
      bottomNavigationBar: route == null
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    GSSpacing.s4, GSSpacing.s2, GSSpacing.s4, GSSpacing.s3),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GSButton(
                      label: 'Iniciar viaje',
                      leadingIcon: Icons.play_arrow_rounded,
                      isLoading: _starting,
                      onPressed: _starting ? null : () => _startTrip(route),
                    ),
                    const SizedBox(height: GSSpacing.s2),
                    GSButton(
                      label: 'Ver en el mapa',
                      leadingIcon: Icons.map_outlined,
                      variant: GSButtonVariant.outline,
                      onPressed: () => context.go(AppRoutes.home),
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}

class _RouteBody extends StatelessWidget {
  const _RouteBody({required this.route, required this.mode});
  final RouteResult route;
  final String mode;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final co2 = EcoService.co2SavedGrams(
        profile: route.profile, distanceKm: route.distanceKm);

    return ListView(
      padding: const EdgeInsets.only(bottom: GSSpacing.s6),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
              GSSpacing.s4, GSSpacing.s4, GSSpacing.s4, 0),
          child: GSRoutePlate(
            text: 'En $mode',
            leading: modeIconFor(mode),
            isActive: true,
            size: GSPlateSize.lg,
            detail:
                '${route.durationMin} min · ${route.distanceKm.toStringAsFixed(1)} km',
          ),
        ),
        const GSSectionTitle('Tramos'),
        const SizedBox(height: GSSpacing.s2),
        for (var i = 0; i < route.legs.length; i++)
          _LegStep(
            leg: route.legs[i],
            routeMode: mode,
            isLast: i == route.legs.length - 1,
          ),
        for (final note in route.notes)
          Padding(
            padding: const EdgeInsets.fromLTRB(
                GSSpacing.s4, GSSpacing.s3, GSSpacing.s4, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline_rounded,
                    size: 20, color: GSColors.brand),
                const SizedBox(width: GSSpacing.s2),
                Expanded(child: Text(note, style: text.bodyMedium)),
              ],
            ),
          ),
        if (route.estimatedCostCop > 0) ...[
          const GSSectionTitle('Tarifa'),
          GSListRow(
            icon: Icons.payments_outlined,
            title: 'Precio de referencia',
            subtitle: 'Aún sin verificar en la calle; puede variar.',
            value: route.fareMin != null &&
                    route.fareMax != null &&
                    route.fareMax! > route.fareMin!
                ? '${formatCop(route.fareMin!)}–${formatCop(route.fareMax!)}'
                : formatCop(route.estimatedCostCop),
          ),
        ],
        if (co2 > 0) ...[
          const Divider(indent: GSSpacing.s4),
          GSListRow(
            icon: Icons.directions_walk_rounded,
            title: 'Ahorras ${EcoService.formatCo2Saved(co2)} de CO₂',
            subtitle: 'Frente a hacer el mismo trayecto en carro',
          ),
        ],
        TripShareSection(
          destination: route.destinationLabel ?? 'mi destino',
          mode: mode,
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
              GSSpacing.s4, GSSpacing.s4, GSSpacing.s4, 0),
          child: Text(
            'Al iniciar el viaje pides cada tramo: mototaxi o taxi con '
            'conductores cercanos, o un cupo en el colectivo.',
            style: text.bodySmall,
          ),
        ),
      ],
    );
  }
}

/// Un tramo como placa pequeña; las placas se encadenan con una línea del
/// color del modo, como los rótulos de una ruta con transbordos.
class _LegStep extends StatelessWidget {
  const _LegStep({
    required this.leg,
    required this.routeMode,
    required this.isLast,
  });
  final RouteLeg leg;
  final String routeMode;
  final bool isLast;

  String get _modeLabel => switch (leg.mode) {
        'walk' => 'A pie',
        'bus' => leg.lineId ?? routeMode,
        'taxi' => 'Taxi',
        _ => routeMode,
      };

  IconData get _icon => switch (leg.mode) {
        'walk' => Icons.directions_walk_rounded,
        'taxi' => Icons.local_taxi_rounded,
        _ => modeIconFor(_modeLabel),
      };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: GSSpacing.s4),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Conector de la cadena.
            SizedBox(
              width: 20,
              child: Column(
                children: [
                  const SizedBox(height: 22),
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: leg.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  if (!isLast)
                    Expanded(child: Container(width: 4, color: leg.color)),
                ],
              ),
            ),
            const SizedBox(width: GSSpacing.s3),
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(bottom: isLast ? 0 : GSSpacing.s4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    GSRoutePlate(
                      text: _modeLabel,
                      leading: _icon,
                      size: GSPlateSize.sm,
                      trailing: Text(
                        '${leg.durationMin} min',
                        style: TextStyle(
                          fontFamily: GSFonts.mono,
                          fontFeatures: GSFonts.tabular,
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: GSColors.text,
                        ),
                      ),
                    ),
                    const SizedBox(height: GSSpacing.s2),
                    Text(
                      '${leg.instruction ?? 'Sigue la ruta'} · '
                      '${leg.distanceKm.toStringAsFixed(1)} km',
                      style: text.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
