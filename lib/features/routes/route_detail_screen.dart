import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/route_result.dart';
import '../../providers/active_route_provider.dart';
import '../../providers/selected_mode_provider.dart';
import '../../router/app_router.dart';
import '../../services/eco_service.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/gs_button.dart';
import '../../widgets/gs_bottom_sheet.dart';

class RouteDetailScreen extends ConsumerWidget {
  const RouteDetailScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final route = ref.watch(activeRouteProvider);
    final mode  = ref.watch(selectedModeProvider);

    return Scaffold(
      backgroundColor: GSColors.bg,
      appBar: AppBar(
        title: const Text('Detalle de ruta'),
        leading: BackButton(onPressed: () => context.pop()),
      ),
      body: route == null
          ? _EmptyRoute(onPlan: () => context.go(AppRoutes.routePlanner))
          : _RouteBody(route: route, mode: mode),
    );
  }
}

// ─── Empty state ─────────────────────────────────────────────────────────────

class _EmptyRoute extends StatelessWidget {
  final VoidCallback onPlan;
  const _EmptyRoute({required this.onPlan});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.route_rounded, size: 56, color: GSColors.accent),
          const SizedBox(height: GSSpacing.s4),
          const Text('No hay ruta activa',
              style: TextStyle(color: Colors.white70, fontSize: 16)),
          const SizedBox(height: GSSpacing.s4),
          GSButton(label: 'Planificar ruta', onPressed: onPlan),
        ],
      ),
    );
  }
}

// ─── Route body ──────────────────────────────────────────────────────────────

class _RouteBody extends StatelessWidget {
  final RouteResult route;
  final String mode;
  const _RouteBody({required this.route, required this.mode});

  @override
  Widget build(BuildContext context) {
    final co2Saved = EcoService.co2SavedGrams(
      profile: route.profile,
      distanceKm: route.distanceKm,
    );
    final pts = EcoService.ecoPointsForTrip(
      profile: route.profile,
      distanceKm: route.distanceKm,
    );

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(GSSpacing.s4),
            children: [
              _SummaryCard(route: route, co2Saved: co2Saved, pts: pts),
              const SizedBox(height: GSSpacing.s4),
              const Text(
                'Segmentos del viaje',
                style: TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 13),
              ),
              const SizedBox(height: GSSpacing.s3),
              ...route.legs.map((leg) => _LegCard(leg: leg)),
              if (route.estimatedCostCop > 0) ...[
                const SizedBox(height: GSSpacing.s3),
                _CostCard(costCop: route.estimatedCostCop),
              ],
              const SizedBox(height: GSSpacing.s4),
            ],
          ),
        ),
        _BottomAction(route: route, mode: mode),
      ],
    );
  }
}

// ─── Summary card ─────────────────────────────────────────────────────────────

class _SummaryCard extends StatelessWidget {
  final RouteResult route;
  final double co2Saved;
  final int pts;
  const _SummaryCard(
      {required this.route, required this.co2Saved, required this.pts});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(GSSpacing.s4),
      decoration: BoxDecoration(
        color: GSColors.surface,
        borderRadius: BorderRadius.circular(GSRadius.lg),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _Stat(
            icon: Icons.schedule_rounded,
            label: 'Duración',
            value: '${route.durationMin} min',
            color: GSColors.accent,
          ),
          _Stat(
            icon: Icons.straighten_rounded,
            label: 'Distancia',
            value: '${route.distanceKm.toStringAsFixed(1)} km',
            color: Colors.white70,
          ),
          if (co2Saved > 0)
            _Stat(
              icon: Icons.eco_rounded,
              label: 'CO₂ ahorrado',
              value: EcoService.formatCo2Saved(co2Saved),
              color: GSColors.eco,
            ),
          if (pts > 0)
            _Stat(
              icon: Icons.stars_rounded,
              label: 'Eco-puntos',
              value: '+$pts',
              color: GSColors.accentAlt,
            ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _Stat(
      {required this.icon,
      required this.label,
      required this.value,
      required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(icon, color: color, size: 22),
        const SizedBox(height: 4),
        Text(value,
            style: TextStyle(
                color: color, fontWeight: FontWeight.bold, fontSize: 14)),
        Text(label,
            style: const TextStyle(color: Colors.white38, fontSize: 10)),
      ],
    );
  }
}

// ─── Leg card ─────────────────────────────────────────────────────────────────

class _LegCard extends StatelessWidget {
  final RouteLeg leg;
  const _LegCard({required this.leg});

  IconData get _icon => switch (leg.mode) {
        'bus'    => Icons.directions_bus_rounded,
        'metro'  => Icons.subway_rounded,
        'bike'   => Icons.pedal_bike_rounded,
        'walk'   => Icons.directions_walk_rounded,
        'taxi'   => Icons.local_taxi_rounded,
        _        => Icons.directions_car_rounded,
      };

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: GSSpacing.s3),
      padding: const EdgeInsets.all(GSSpacing.s3),
      decoration: BoxDecoration(
        color: GSColors.surface,
        borderRadius: BorderRadius.circular(GSRadius.md),
        border: Border(left: BorderSide(color: leg.color, width: 4)),
      ),
      child: Row(
        children: [
          Icon(_icon, color: leg.color, size: 24),
          const SizedBox(width: GSSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  leg.instruction ?? leg.mode.toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                if (leg.lineId != null)
                  Text('Línea ${leg.lineId}',
                      style: TextStyle(color: leg.color, fontSize: 11)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('${leg.durationMin} min',
                  style: const TextStyle(
                      color: Colors.white70, fontWeight: FontWeight.bold)),
              Text('${leg.distanceKm.toStringAsFixed(1)} km',
                  style: const TextStyle(
                      color: Colors.white38, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Cost card ────────────────────────────────────────────────────────────────

class _CostCard extends StatelessWidget {
  final int costCop;
  const _CostCard({required this.costCop});

  @override
  Widget build(BuildContext context) {
    final formatted = costCop
        .toString()
        .replaceAllMapped(
            RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (m) => '${m[1]}.');
    return Container(
      padding: const EdgeInsets.symmetric(
          horizontal: GSSpacing.s4, vertical: GSSpacing.s3),
      decoration: BoxDecoration(
        color: GSColors.surface,
        borderRadius: BorderRadius.circular(GSRadius.md),
      ),
      child: Row(
        children: [
          const Icon(Icons.account_balance_wallet_rounded,
              color: GSColors.accent, size: 20),
          const SizedBox(width: GSSpacing.s3),
          const Text('Costo estimado',
              style: TextStyle(color: Colors.white70)),
          const Spacer(),
          Text(
            '\$$formatted COP',
            style: const TextStyle(
                color: GSColors.accent, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}

// ─── Bottom action ────────────────────────────────────────────────────────────

class _BottomAction extends StatelessWidget {
  final RouteResult route;
  final String mode;
  const _BottomAction({required this.route, required this.mode});

  void _showConfirm(BuildContext context) {
    GSBottomSheet.show(
      context: context,
      title: 'Iniciar viaje',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Modo: $mode · ${route.durationMin} min · '
            '${route.distanceKm.toStringAsFixed(1)} km',
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: GSSpacing.s5),
          GSButton(
            label: 'Confirmar viaje',
            isFullWidth: true,
            onPressed: () {
              Navigator.of(context).pop();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Viaje iniciado — buen trayecto'),
                  backgroundColor: GSColors.eco,
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(
        GSSpacing.s5,
        0,
        GSSpacing.s5,
        MediaQuery.of(context).padding.bottom + GSSpacing.s4,
      ),
      child: GSButton(
        label: 'Iniciar viaje',
        isFullWidth: true,
        leadingIcon: Icons.navigation_rounded,
        onPressed: () => _showConfirm(context),
      ),
    );
  }
}
