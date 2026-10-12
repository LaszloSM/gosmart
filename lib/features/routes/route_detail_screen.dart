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
        Padding(
          padding: const EdgeInsets.fromLTRB(
              GSSpacing.s4, GSSpacing.s5, GSSpacing.s4, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              _BigNumber(value: '${route.durationMin}', unit: 'min'),
              const SizedBox(width: GSSpacing.s6),
              _BigNumber(
                  value: route.distanceKm.toStringAsFixed(1), unit: 'km'),
            ],
          ),
        ),
        const GSSectionTitle('Tramos'),
        const SizedBox(height: GSSpacing.s2),
        for (var i = 0; i < route.legs.length; i++)
          _LegStep(
            leg: route.legs[i],
            isFirst: i == 0,
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

class _BigNumber extends StatelessWidget {
  const _BigNumber({required this.value, required this.unit});
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    return Text.rich(
      TextSpan(children: [
        TextSpan(
          text: value,
          style: const TextStyle(
            fontFamily: GSFonts.display,
            fontFeatures: GSFonts.tabular,
            fontSize: 44,
            fontWeight: FontWeight.w800,
            height: 1,
            color: GSColors.text,
          ),
        ),
        TextSpan(
          text: ' $unit',
          style: const TextStyle(
            fontFamily: GSFonts.sans,
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: GSColors.textMuted,
          ),
        ),
      ]),
    );
  }
}

/// Un tramo de la cadena: punto y línea del color del modo a la izquierda,
/// instrucción y minutos a la derecha.
class _LegStep extends StatelessWidget {
  const _LegStep({required this.leg, required this.isFirst, required this.isLast});
  final RouteLeg leg;
  final bool isFirst;
  final bool isLast;

  IconData get _icon => switch (leg.mode) {
        'bus' => Icons.directions_bus_rounded,
        'walk' => Icons.directions_walk_rounded,
        'taxi' => Icons.local_taxi_rounded,
        _ => Icons.directions_car_rounded,
      };

  String get _fallback => switch (leg.mode) {
        'walk' => 'Camina',
        'bus' => 'Ve en el vehículo',
        _ => 'Sigue la ruta',
      };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return IntrinsicHeight(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: GSSpacing.s4),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: 40,
              child: Column(
                children: [
                  Expanded(
                    child: Container(
                        width: 4,
                        color: isFirst ? Colors.transparent : leg.color),
                  ),
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: GSColors.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: leg.color, width: 3),
                    ),
                    child: Icon(_icon, size: 20, color: GSColors.text),
                  ),
                  Expanded(
                    child: Container(
                        width: 4,
                        color: isLast ? Colors.transparent : leg.color),
                  ),
                ],
              ),
            ),
            const SizedBox(width: GSSpacing.s3),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: GSSpacing.s3),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(leg.instruction ?? _fallback,
                        style: text.titleMedium,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis),
                    if (leg.lineId != null)
                      Text('Línea ${leg.lineId}', style: text.bodySmall),
                  ],
                ),
              ),
            ),
            const SizedBox(width: GSSpacing.s3),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${leg.durationMin} min',
                    style: const TextStyle(
                      fontFamily: GSFonts.mono,
                      fontFeatures: GSFonts.tabular,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: GSColors.text,
                    )),
                Text('${leg.distanceKm.toStringAsFixed(1)} km',
                    style: text.bodySmall
                        ?.copyWith(fontFeatures: GSFonts.tabular)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
