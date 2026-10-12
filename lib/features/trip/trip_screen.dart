// lib/features/trip/trip_screen.dart
// Viaje encadenado (Fase 6): los tramos como placas en cadena y, abajo, lo que
// toca hacer ahora según el modo: caminar, pedir mototaxi/taxi (con ofertas
// estilo InDrive) o reservar cupo en un colectivo. Cada tramo se cierra solo
// y el viaje se completa cuando se cierran todos (máquina de estados en SQL).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/dispatch_models.dart';
import '../../providers/dispatch_provider.dart';
import '../../router/app_router.dart';
import '../../services/dispatch_service.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/gs_bottom_nav.dart';
import '../../widgets/gs_empty_state.dart';
import '../../widgets/gs_inline_error.dart';
import '../../widgets/gs_list_row.dart';
import '../../widgets/gs_route_plate.dart';
import '../../widgets/gs_toast.dart';
import '../safety/sos_sheet.dart';
import 'widgets/leg_panels.dart';

String legModeLabel(String mode) => switch (mode) {
      'walk' => 'A pie',
      'mototaxi' => 'Mototaxi',
      'taxi' => 'Taxi',
      'colectivo' => 'Colectivo',
      'transpadilla' => 'TransPadilla',
      'intermunicipal' => 'Intermunicipal',
      _ => mode,
    };

IconData legModeIcon(String mode) => switch (mode) {
      'walk' => Icons.directions_walk_rounded,
      'mototaxi' => Icons.two_wheeler_rounded,
      'taxi' => Icons.local_taxi_rounded,
      'colectivo' => Icons.airport_shuttle_rounded,
      'transpadilla' => Icons.directions_bus_rounded,
      _ => Icons.directions_bus_filled_rounded,
    };

class TripScreen extends ConsumerWidget {
  const TripScreen({super.key});

  Future<void> _cancel(BuildContext context, WidgetRef ref, ChainedTrip t) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cancelar el viaje?'),
        content: const Text('Los tramos que no han empezado se cancelan.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Seguir')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Cancelar viaje')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await dispatchService.cancelTrip(t.id);
      ref.invalidate(activeTripProvider);
    } on DispatchException catch (e) {
      GSToast.showWithMessenger(messenger,
          message: e.message, type: GSToastType.error);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trip = ref.watch(activeTripProvider);
    return Scaffold(
      extendBody: true,
      backgroundColor: GSColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Tu viaje'),
        actions: [
          IconButton(
            tooltip: 'Ayuda',
            icon: const Icon(Icons.health_and_safety_outlined),
            onPressed: () => showSosSheet(context),
          ),
        ],
      ),
      body: trip.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => Padding(
          padding: const EdgeInsets.all(GSSpacing.s4),
          child: GSInlineError(
            message: 'No pudimos cargar tu viaje',
            onRetry: () => ref.invalidate(activeTripProvider),
          ),
        ),
        data: (t) => t == null
            ? ListView(children: [
                GSEmptyState(
                  icon: Icons.route_rounded,
                  title: 'Sin viaje en curso',
                  subtitle: 'Planea a dónde vas y toca "Iniciar viaje". Aquí '
                      'pides cada tramo y ves a tu conductor.',
                  actionLabel: 'Planear un viaje',
                  onAction: () => context.push(AppRoutes.routePlanner),
                ),
              ])
            : RefreshIndicator(
                onRefresh: () async => ref.invalidate(activeTripProvider),
                child: ListView(
                  padding: EdgeInsets.zero,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          GSSpacing.s4, GSSpacing.s4, GSSpacing.s4, 0),
                      child: GSRoutePlate(
                        from: t.originLabel,
                        text: t.destLabel ?? 'Tu destino',
                        leading: Icons.route_rounded,
                        isActive: true,
                        size: GSPlateSize.md,
                        maxLines: 2,
                      ),
                    ),
                    const GSSectionTitle('Tramos'),
                    for (final l in t.legs)
                      _LegRow(leg: l, isCurrent: l.id == t.currentLeg?.id),
                    if (t.currentLeg != null) ...[
                      const GSSectionTitle('Ahora'),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: GSSpacing.s4),
                        child: CurrentLegPanel(
                            key: ValueKey(t.currentLeg!.id),
                            leg: t.currentLeg!),
                      ),
                    ],
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                          GSSpacing.s4, GSSpacing.s6, GSSpacing.s4, 0),
                      child: TextButton.icon(
                        onPressed: () => _cancel(context, ref, t),
                        icon: const Icon(Icons.close_rounded),
                        label: const Text('Cancelar viaje'),
                      ),
                    ),
                    SizedBox(
                        height: MediaQuery.of(context).padding.bottom +
                            GSSpacing.s4),
                  ],
                ),
              ),
      ),
      bottomNavigationBar: const GSBottomNav(current: GSNavTab.trip),
    );
  }
}

class _LegRow extends StatelessWidget {
  const _LegRow({required this.leg, required this.isCurrent});
  final TripLegRow leg;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final (icon, word) = switch (leg.status) {
      LegStatus.completed => (Icons.check_circle_rounded, 'Hecho'),
      LegStatus.cancelled => (Icons.cancel_outlined, 'Cancelado'),
      LegStatus.failed => (Icons.error_outline_rounded, 'No se pudo'),
      LegStatus.inProgress => (Icons.radio_button_checked_rounded, 'En camino'),
      LegStatus.awaitingDispatch => (Icons.hourglass_top_rounded, 'Esperando'),
      LegStatus.planned => (Icons.radio_button_unchecked_rounded, 'Pendiente'),
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          GSSpacing.s4, 0, GSSpacing.s4, GSSpacing.s2),
      child: GSRoutePlate(
        text: legModeLabel(leg.mode),
        leading: legModeIcon(leg.mode),
        size: GSPlateSize.sm,
        isActive: isCurrent,
        detail: '${leg.toLabel == null ? '' : 'Hasta ${leg.toLabel} · '}$word',
        detailMaxLines: 2,
        trailing: Icon(icon, color: GSColors.brand),
      ),
    );
  }
}
