// lib/features/routes/route_detail_screen.dart
// Detalle de la ruta, como las indicaciones de Google Maps: resumen con el
// tiempo grande y una barra de tramos proporcional, la lista de tramos en una
// línea de tiempo y la tarifa de referencia.
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
          : DecoratedBox(
              // Superficie propia: el contenido no se ve a medias detrás.
              decoration: BoxDecoration(
                color: GSColors.surface,
                boxShadow: GSShadow.sheet,
              ),
              child: SafeArea(
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
    final fare = route.estimatedCostCop <= 0
        ? null
        : route.fareMin != null &&
                route.fareMax != null &&
                route.fareMax! > route.fareMin!
            ? '${formatCop(route.fareMin!)} - ${formatCop(route.fareMax!)}'
            : formatCop(route.estimatedCostCop);

    return ListView(
      padding: const EdgeInsets.only(bottom: GSSpacing.s6),
      children: [
        // ── Resumen ────────────────────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(
              GSSpacing.s4, GSSpacing.s3, GSSpacing.s4, 0),
          child: Container(
            padding: const EdgeInsets.all(GSSpacing.s4),
            decoration: BoxDecoration(
              color: GSColors.surface,
              borderRadius: BorderRadius.circular(GSRadius.lg),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${route.durationMin} min',
                            style: text.displaySmall
                                ?.copyWith(fontFeatures: GSFonts.tabular),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${route.distanceKm.toStringAsFixed(1)} km · en $mode',
                            style: text.bodyMedium
                                ?.copyWith(fontFeatures: GSFonts.tabular),
                          ),
                          if (route.destinationLabel != null)
                            Text(
                              'Hasta ${route.destinationLabel}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: text.bodyMedium,
                            ),
                        ],
                      ),
                    ),
                    if (fare != null) ...[
                      const SizedBox(width: GSSpacing.s3),
                      _FareBadge(fare: fare),
                    ],
                  ],
                ),
                const SizedBox(height: GSSpacing.s4),
                _LegBar(route: route, routeMode: mode),
              ],
            ),
          ),
        ),

        // ── Tramos ─────────────────────────────────────────────────────────
        const GSSectionTitle('Tramos'),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: GSSpacing.s4),
          child: Container(
            padding: const EdgeInsets.fromLTRB(
                GSSpacing.s4, GSSpacing.s4, GSSpacing.s4, GSSpacing.s2),
            decoration: BoxDecoration(
              color: GSColors.surface,
              borderRadius: BorderRadius.circular(GSRadius.lg),
            ),
            child: Column(
              children: [
                for (var i = 0; i < route.legs.length; i++)
                  _LegStep(
                    leg: route.legs[i],
                    routeMode: mode,
                    isLast: i == route.legs.length - 1,
                  ),
              ],
            ),
          ),
        ),
        for (final note in route.notes)
          Padding(
            padding: const EdgeInsets.fromLTRB(
                GSSpacing.s4, GSSpacing.s3, GSSpacing.s4, 0),
            child: Container(
              padding: const EdgeInsets.all(GSSpacing.s3),
              decoration: BoxDecoration(
                color: GSColors.brandTint,
                borderRadius: BorderRadius.circular(GSRadius.md),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.info_outline_rounded,
                      size: 20, color: GSColors.brand),
                  const SizedBox(width: GSSpacing.s2),
                  Expanded(
                      child: Text(note,
                          style:
                              text.bodyMedium?.copyWith(color: GSColors.text))),
                ],
              ),
            ),
          ),
        if (fare != null || co2 > 0) ...[
          const GSSectionTitle('Tarifa'),
          GSGroup(children: [
            if (fare != null)
              GSListRow(
                icon: Icons.payments_outlined,
                title: 'Precio de referencia',
                subtitle: 'Aún sin verificar en la calle; puede variar.',
                value: fare,
              ),
            if (co2 > 0)
              GSListRow(
                icon: Icons.eco_outlined,
                title: 'Ahorras ${EcoService.formatCo2Saved(co2)} de CO₂',
                subtitle: 'Frente a hacer el mismo trayecto en carro',
              ),
          ]),
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

/// Precio de referencia en una píldora, como el precio de una opción en Uber.
class _FareBadge extends StatelessWidget {
  const _FareBadge({required this.fare});
  final String fare;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: GSColors.brandTint,
        borderRadius: BorderRadius.circular(GSRadius.full),
      ),
      child: Text(
        fare,
        style: TextStyle(
          fontFamily: GSFonts.mono,
          fontFeatures: GSFonts.tabular,
          fontSize: 15,
          fontWeight: FontWeight.w800,
          color: GSColors.brand,
        ),
      ),
    );
  }
}

String _legLabel(RouteLeg leg, String routeMode) => switch (leg.mode) {
      'walk' => 'A pie',
      'bus' => leg.lineId ?? routeMode,
      'taxi' => 'Taxi',
      _ => routeMode,
    };

IconData _legIcon(RouteLeg leg, String routeMode) => switch (leg.mode) {
      'walk' => Icons.directions_walk_rounded,
      'taxi' => Icons.local_taxi_rounded,
      _ => modeIconFor(_legLabel(leg, routeMode)),
    };

/// Barra de tramos proporcional al tiempo (Google Maps): cada tramo es un
/// segmento de su color con su ícono; a pie va en gris claro.
class _LegBar extends StatelessWidget {
  const _LegBar({required this.route, required this.routeMode});
  final RouteResult route;
  final String routeMode;

  @override
  Widget build(BuildContext context) {
    final total = route.legs.fold<int>(0, (a, l) => a + l.durationMin);
    return Semantics(
      label: route.legs
          .map((l) => '${_legLabel(l, routeMode)} ${l.durationMin} min')
          .join(', '),
      excludeSemantics: true,
      child: Row(
        children: [
          for (var i = 0; i < route.legs.length; i++) ...[
            if (i > 0) const SizedBox(width: 3),
            Expanded(
              flex: total == 0
                  ? 1
                  : (route.legs[i].durationMin * 100 ~/ total).clamp(8, 100),
              child: Container(
                height: 30,
                decoration: BoxDecoration(
                  color: route.legs[i].mode == 'walk'
                      ? GSColors.surfaceSunken
                      : route.legs[i].liveColor,
                  borderRadius: BorderRadius.circular(GSRadius.sm),
                ),
                child: Icon(
                  _legIcon(route.legs[i], routeMode),
                  size: 18,
                  color: route.legs[i].mode == 'walk'
                      ? GSColors.text
                      : route.legs[i].onLiveColor,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Un tramo en la línea de tiempo: ícono del modo en un círculo de su color,
/// línea hacia el siguiente (punteada si es a pie), nombre, indicación y
/// minutos a la derecha.
class _LegStep extends StatelessWidget {
  const _LegStep({
    required this.leg,
    required this.routeMode,
    required this.isLast,
  });
  final RouteLeg leg;
  final String routeMode;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final walk = leg.mode == 'walk';
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 40,
            child: Column(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: walk ? GSColors.surfaceSunken : leg.liveColor,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _legIcon(leg, routeMode),
                    size: 22,
                    color: walk ? GSColors.text : leg.onLiveColor,
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: walk
                        ? Column(
                            children: [
                              for (var i = 0; i < 4; i++)
                                Container(
                                  width: 4,
                                  height: 4,
                                  margin: const EdgeInsets.only(top: 5),
                                  decoration: BoxDecoration(
                                    color: GSColors.textDisabled,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          )
                        : Container(
                            width: 4,
                            margin: const EdgeInsets.symmetric(vertical: 4),
                            decoration: BoxDecoration(
                              color: leg.liveColor,
                              borderRadius:
                                  BorderRadius.circular(GSRadius.full),
                            ),
                          ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: GSSpacing.s3),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                  top: 2, bottom: isLast ? GSSpacing.s2 : GSSpacing.s5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(_legLabel(leg, routeMode),
                            style: text.titleMedium),
                      ),
                      Text(
                        '${leg.durationMin} min',
                        style: text.titleMedium
                            ?.copyWith(fontFeatures: GSFonts.tabular),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
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
    );
  }
}
