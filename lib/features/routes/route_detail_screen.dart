// lib/features/routes/route_detail_screen.dart
// Detalle de la ruta activa: resumen en placa, tramos encadenados y tarifa de
// referencia. Iniciar el viaje llega en la Fase 6; aquí no se finge.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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

class RouteDetailScreen extends ConsumerWidget {
  const RouteDetailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
                child: GSButton(
                  label: 'Ver en el mapa',
                  leadingIcon: Icons.map_outlined,
                  onPressed: () => context.go(AppRoutes.home),
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
        if (route.estimatedCostCop > 0) ...[
          const GSSectionTitle('Tarifa'),
          GSListRow(
            icon: Icons.payments_outlined,
            title: 'Precio de referencia',
            subtitle: 'Aún sin verificar en la calle; puede variar.',
            value: formatCop(route.estimatedCostCop),
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
        Padding(
          padding: const EdgeInsets.fromLTRB(
              GSSpacing.s4, GSSpacing.s4, GSSpacing.s4, 0),
          child: Text(
            'Pronto vas a poder iniciar el viaje, pedir mototaxi y pagar '
            'cada tramo desde aquí.',
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
