// lib/features/trip/trip_screen.dart
// Viaje encadenado (Fase 6): los tramos como placas en cadena y, abajo, lo que
// toca hacer ahora según el modo: caminar, pedir mototaxi/taxi (con ofertas
// estilo InDrive) o reservar cupo en un colectivo. Cada tramo se cierra solo
// y el viaje se completa cuando se cierran todos (máquina de estados en SQL).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/dispatch_models.dart';
import '../../providers/active_route_provider.dart';
import '../../providers/auth_provider.dart';
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
import 'widgets/trip_map.dart';
import 'widgets/trip_visuals.dart';
import '../../widgets/gs_pressable.dart';
import '../../widgets/gs_button.dart';
import '../../widgets/gs_nav_spacer.dart';

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
    // Sin viaje, nadie que pintar en el mapa.
    ref.listen<AsyncValue<ChainedTrip?>>(activeTripProvider, (prev, next) {
      if (next.valueOrNull == null && next.hasValue) {
        ref.read(tripDriverProvider.notifier).state = null;
        // El viaje terminó o se canceló: su ruta ya no va en el inicio.
        if (prev?.valueOrNull != null) {
          ref.read(activeRouteProvider.notifier).state = null;
        }
      }
    });
    final t = trip.valueOrNull;
    if (t != null) return _ActiveTrip(trip: t, onCancel: () => _cancel(context, ref, t));
    return Scaffold(
      extendBody: true,
      backgroundColor: GSColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Tu viaje'),
        actions: [
          IconButton(
            tooltip: 'Ayuda',
            icon: const Icon(Icons.health_and_safety_rounded),
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
        data: (_) => ListView(children: [
          GSEmptyState(
            icon: Icons.route_rounded,
            title: 'Sin viaje en curso',
            subtitle: ref.watch(isGuestProvider)
                ? 'Planea a dónde vas sin cuenta. Para iniciar el viaje, '
                    'pedir mototaxi o reservar cupo, entra a tu cuenta.'
                : 'Planea a dónde vas y toca "Iniciar viaje". Aquí '
                    'pides cada tramo y ves a tu conductor en el mapa.',
            actionLabel: 'Planear un viaje',
            onAction: () => context.push(AppRoutes.routePlanner),
          ),
          const _RecentTrips(),
          const GSNavSpacer(),
        ]),
      ),
      bottomNavigationBar: const GSBottomNav(current: GSNavTab.trip),
    );
  }
}

/// Viaje en curso como en Uber/InDrive: el mapa de fondo con la ruta y el
/// conductor, y una hoja que se arrastra con lo que toca ahora.
class _ActiveTrip extends ConsumerStatefulWidget {
  const _ActiveTrip({required this.trip, required this.onCancel});
  final ChainedTrip trip;
  final VoidCallback onCancel;

  @override
  ConsumerState<_ActiveTrip> createState() => _ActiveTripState();
}

class _ActiveTripState extends ConsumerState<_ActiveTrip> {
  /// Lo que tapa la hoja, ya asentado (el mapa no se reacomoda en cada cuadro).
  double _extent = 0.56;
  Timer? _settle;

  @override
  void dispose() {
    _settle?.cancel();
    super.dispose();
  }

  bool _onSheet(DraggableScrollableNotification n) {
    _settle?.cancel();
    _settle = Timer(const Duration(milliseconds: 140), () {
      if (mounted && (n.extent - _extent).abs() > 0.02) setState(() => _extent = n.extent);
    });
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.trip;
    final text = Theme.of(context).textTheme;
    final top = MediaQuery.paddingOf(context).top;
    return Scaffold(
      extendBody: true,
      backgroundColor: GSColors.background,
      body: LayoutBuilder(builder: (context, box) {
        final h = box.maxHeight;
        return Stack(
          children: [
            Positioned.fill(
              child: TripMap(
                trip: t,
                padding: EdgeInsets.only(top: top + 64, bottom: h * _extent.clamp(0.0, 0.7)),
              ),
            ),
            // Arriba: hacia dónde vas y el botón de ayuda, flotando.
            Positioned(
              top: top + GSSpacing.s2,
              left: GSSpacing.s3,
              right: GSSpacing.s3,
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: GSSize.touchTarget,
                      padding: const EdgeInsets.symmetric(horizontal: GSSpacing.s4),
                      decoration: BoxDecoration(
                        color: GSColors.surface,
                        borderRadius: BorderRadius.circular(GSRadius.full),
                        boxShadow: GSShadow.float,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.flag_rounded, size: GSSize.iconMd, color: GSColors.brand),
                          const SizedBox(width: GSSpacing.s2),
                          Expanded(
                            child: Text(
                              'Hacia ${t.destLabel ?? 'tu destino'}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: text.titleSmall,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: GSSpacing.s2),
                  Tooltip(
                    message: 'Ayuda',
                    child: GSPressable(
                      onTap: () => showSosSheet(context),
                      semanticLabel: 'Ayuda',
                      child: Container(
                        width: GSSize.touchTarget,
                        height: GSSize.touchTarget,
                        decoration: BoxDecoration(
                          color: GSColors.surface,
                          shape: BoxShape.circle,
                          boxShadow: GSShadow.float,
                        ),
                        child: Icon(Icons.health_and_safety_rounded, color: GSColors.brand),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            NotificationListener<DraggableScrollableNotification>(
              onNotification: _onSheet,
              child: DraggableScrollableSheet(
                initialChildSize: 0.56,
                minChildSize: 0.28,
                maxChildSize: 0.94,
                snap: true,
                snapSizes: const [0.56],
                builder: (context, controller) => Container(
                  decoration: BoxDecoration(
                    color: GSColors.background,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(GSRadius.xl)),
                    boxShadow: GSShadow.sheet,
                  ),
                  child: RefreshIndicator(
                    onRefresh: () async => ref.invalidate(activeTripProvider),
                    child: SingleChildScrollView(
                      controller: controller,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: GSSpacing.s4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: GSSpacing.s2),
                              width: 40,
                              height: 4,
                              decoration: BoxDecoration(
                                color: GSColors.line,
                                borderRadius: BorderRadius.circular(GSRadius.full),
                              ),
                            ),
                          ),
                          Text(t.destLabel ?? 'Tu destino',
                              maxLines: 2, overflow: TextOverflow.ellipsis, style: text.headlineSmall),
                          if (t.originLabel != null)
                            Text('Desde ${t.originLabel}',
                                maxLines: 2, overflow: TextOverflow.ellipsis, style: text.bodyMedium),
                          const SizedBox(height: GSSpacing.s3),
                          LegTimeline(
                            legs: t.legs,
                            currentId: t.currentLeg?.id,
                            iconFor: legModeIcon,
                            labelFor: legModeLabel,
                          ),
                          const SizedBox(height: GSSpacing.s4),
                          if (t.currentLeg != null)
                            Container(
                              padding: const EdgeInsets.all(GSSpacing.s4),
                              decoration: BoxDecoration(
                                color: GSColors.surface,
                                borderRadius: BorderRadius.circular(GSRadius.lg),
                              ),
                              child: CurrentLegPanel(
                                  key: ValueKey(t.currentLeg!.id), leg: t.currentLeg!),
                            ),
                          const SizedBox(height: GSSpacing.s5),
                          Text('Tramos', style: text.titleLarge),
                          const SizedBox(height: GSSpacing.s3),
                          for (final l in t.legs)
                            _LegRow(leg: l, isCurrent: l.id == t.currentLeg?.id),
                          const SizedBox(height: GSSpacing.s2),
                          GSButton(
                            label: 'Cancelar viaje',
                            variant: GSButtonVariant.ghost,
                            leadingIcon: Icons.close_rounded,
                            onPressed: widget.onCancel,
                          ),
                          const GSNavSpacer(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      }),
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
      LegStatus.cancelled => (Icons.cancel_rounded, 'Cancelado'),
      LegStatus.failed => (Icons.error_rounded, 'No se pudo'),
      LegStatus.inProgress => (Icons.radio_button_checked_rounded, 'En camino'),
      LegStatus.awaitingDispatch => (Icons.hourglass_top_rounded, 'Esperando'),
      LegStatus.planned => (Icons.radio_button_unchecked_rounded, 'Pendiente'),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: GSSpacing.s2),
      child: GSRoutePlate(
        text: legModeLabel(leg.mode),
        leading: legModeIcon(leg.mode),
        size: GSPlateSize.sm,
        isActive: isCurrent,
        // El estado primero: es lo que se busca de un vistazo.
        detail: '$word${leg.toLabel == null ? '' : ' · hasta ${leg.toLabel}'}',
        detailMaxLines: 4,
        trailing: Icon(icon, color: GSColors.brand),
      ),
    );
  }
}

/// Viajes terminados con su recibo (D5: un recibo por viaje). "Repetir" abre
/// el planificador con el mismo origen y destino (como Uber): se elige otra
/// vez en qué ir y se ven los precios de hoy.
class _RecentTrips extends ConsumerWidget {
  const _RecentTrips();

  void _repeat(BuildContext context, WidgetRef ref, RecentTrip t) {
    ref.read(pendingPlanProvider.notifier).state = PlannerPreset(
      origin: t.origin!,
      originLabel: t.originLabel ?? 'Salida del viaje anterior',
      dest: t.dest!,
      destLabel: t.destLabel ?? 'Destino del viaje anterior',
    );
    context.push(AppRoutes.routePlanner);
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trips = ref.watch(recentTripsProvider).valueOrNull ?? const [];
    if (trips.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const GSSectionTitle('Viajes recientes'),
        for (final t in trips) ...[
          GSListRow(
            icon: t.status == 'completed'
                ? Icons.receipt_long_rounded
                : Icons.cancel_rounded,
            title: t.destLabel ?? 'Viaje',
            subtitle: '${t.at.day}/${t.at.month} · '
                '${t.status == 'completed' ? 'Ver recibo' : 'Cancelado'}',
            onTap: t.status == 'completed'
                ? () => context.push('${AppRoutes.receipt}?id=${t.id}')
                : null,
            trailing: t.canRepeat
                ? GSButton(
                    label: 'Repetir',
                    leadingIcon: Icons.replay_rounded,
                    variant: GSButtonVariant.outline,
                    size: GSButtonSize.sm,
                    isFullWidth: false,
                    semanticLabel: 'Repetir el viaje a ${t.destLabel ?? 'ese destino'}',
                    onPressed: () => _repeat(context, ref, t),
                  )
                : null,
          ),
          const Divider(indent: GSSpacing.s4),
        ],
      ],
    );
  }
}
