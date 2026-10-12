import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/corridor_status.dart';
import '../../models/route_result.dart';
import '../../providers/active_route_provider.dart';
import '../../providers/corridor_provider.dart';
import '../../providers/selected_mode_provider.dart';
import '../../router/app_router.dart';
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
          // Shell ultramar con la Línea sobre una placa blanca.
          AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle.light,
            child: ColoredBox(
              color: GSColors.brand,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(GSSpacing.s3,
                      GSSpacing.s2, GSSpacing.s3, GSSpacing.s3),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(GSRadius.md),
                    child: _CorridorHeader(corridor: corridor),
                  ),
                ),
              ),
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

/// Ruta activa sobre la hoja: toca para ver los tramos, la X la quita.
class _RouteBanner extends ConsumerWidget {
  const _RouteBanner({required this.route});
  final RouteResult route;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(selectedModeProvider);
    return Material(
      color: GSColors.brand,
      borderRadius:
          const BorderRadius.vertical(top: Radius.circular(GSRadius.lg)),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => context.push(AppRoutes.routeDetail),
        child: Container(
          decoration: const BoxDecoration(
            border: Border(
                bottom: BorderSide(color: GSColors.stripe, width: 4)),
          ),
          padding: const EdgeInsets.only(left: GSSpacing.s4),
          child: Row(
            children: [
              Icon(modeIconFor(mode), color: GSColors.onBrand),
              const SizedBox(width: GSSpacing.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${route.durationMin} min · '
                      '${route.distanceKm.toStringAsFixed(1)} km',
                      style: const TextStyle(
                        fontFamily: GSFonts.display,
                        fontFeatures: GSFonts.tabular,
                        color: GSColors.onBrand,
                        fontWeight: FontWeight.w800,
                        fontSize: 22,
                      ),
                    ),
                    const Text(
                      'Toca para ver los tramos',
                      style: TextStyle(
                        fontFamily: GSFonts.sans,
                        color: GSColors.onBrandMuted,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Quitar ruta',
                icon: const Icon(Icons.close_rounded, color: GSColors.onBrand),
                onPressed: () =>
                    ref.read(activeRouteProvider.notifier).state = null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
