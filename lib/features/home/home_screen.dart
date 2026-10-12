import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/corridor_status.dart';
import '../../models/route_result.dart';
import '../../providers/active_route_provider.dart';
import '../../providers/corridor_provider.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/gs_bottom_nav.dart';
import '../../widgets/gs_corridor_line.dart';
import 'widgets/corridor_detail_sheet.dart';
import 'widgets/home_map.dart';
import 'widgets/home_sheet.dart';

/// Inicio (DS1): Línea del corredor → mapa de fondo → hoja "¿A dónde vas?".
/// Funciona sin cuenta (DS3); las acciones que la necesitan la piden.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _sheetCtrl = DraggableScrollableController();

  static const _sheetMin = 0.14;
  static const _sheetInitial = 0.36;

  @override
  void dispose() {
    _sheetCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Con una ruta activa la hoja baja para dejar ver el mapa.
    ref.listen<RouteResult?>(activeRouteProvider, (prev, next) {
      if (!_sheetCtrl.isAttached) return;
      if (next != null && prev == null) {
        _sheetCtrl.animateTo(_sheetMin,
            duration: GSDuration.sheetOut, curve: GSCurve.exit);
      } else if (next == null && prev != null) {
        _sheetCtrl.animateTo(_sheetInitial,
            duration: GSDuration.sheetIn, curve: GSCurve.enter);
      }
    });

    final corridor = ref.watch(corridorStatusProvider);
    final route = ref.watch(activeRouteProvider);

    return Scaffold(
      extendBody: true,
      backgroundColor: GSColors.background,
      body: Column(
        children: [
          // ── Línea del corredor: el estado de la vía en 1 segundo ──────────
          ColoredBox(
            color: GSColors.surface,
            child: SafeArea(
              bottom: false,
              child: _CorridorHeader(corridor: corridor),
            ),
          ),

          // ── Mapa + hoja inferior ───────────────────────────────────────────
          Expanded(
            child: Stack(
              children: [
                const Positioned.fill(child: HomeMap()),
                DraggableScrollableSheet(
                  controller: _sheetCtrl,
                  initialChildSize: _sheetInitial,
                  minChildSize: _sheetMin,
                  maxChildSize: 0.8,
                  snap: true,
                  snapSizes: const [_sheetMin, _sheetInitial],
                  builder: (context, scrollController) => DecoratedBox(
                    decoration: BoxDecoration(
                      color: GSColors.surface,
                      borderRadius: GSRadius.sheetRadius,
                      boxShadow: GSShadow.sheet,
                    ),
                    child: HomeSheetContent(
                        scrollController: scrollController),
                  ),
                ),
                if (route != null)
                  Positioned(
                    bottom: GSSize.bottomNav +
                        MediaQuery.of(context).padding.bottom,
                    left: 0,
                    right: 0,
                    child: _RouteBanner(route: route),
                  ),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: const GSBottomNav(current: GSNavTab.home),
    );
  }
}

class _CorridorHeader extends StatelessWidget {
  const _CorridorHeader({required this.corridor});
  final AsyncValue<CorridorStatus> corridor;

  @override
  Widget build(BuildContext context) {
    final status = corridor.valueOrNull;
    return GSCorridorLine(
      status: status,
      isLoading: corridor.isLoading,
      onTap: () => showCorridorDetailSheet(
        context,
        status ?? const CorridorStatus.noData(),
      ),
    );
  }
}

class _RouteBanner extends ConsumerWidget {
  const _RouteBanner({required this.route});
  final RouteResult route;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.only(left: GSSpacing.s4),
      decoration: const BoxDecoration(
        color: GSColors.brand,
        borderRadius: BorderRadius.vertical(top: Radius.circular(GSRadius.lg)),
      ),
      child: Row(
        children: [
          Icon(RouteProfile.iconFor(route.profile),
              color: GSColors.onBrand, size: 20),
          const SizedBox(width: GSSpacing.s3),
          Expanded(
            child: Text(
              '${route.durationMin} min · ${route.distanceKm.toStringAsFixed(1)} km',
              style: const TextStyle(
                fontFamily: GSFonts.mono,
                color: GSColors.onBrand,
                fontWeight: FontWeight.w600,
                fontSize: 17,
              ),
            ),
          ),
          IconButton(
            tooltip: 'Quitar ruta',
            icon: const Icon(Icons.close, color: GSColors.onBrand),
            onPressed: () =>
                ref.read(activeRouteProvider.notifier).state = null,
          ),
        ],
      ),
    );
  }
}
