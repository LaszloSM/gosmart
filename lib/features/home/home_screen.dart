import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../safety/sos_sheet.dart';
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

/// Inicio, como Uber/DiDi con Google Maps: mapa a pantalla completa, la
/// tarjeta del estado de la Troncal flotando arriba y una hoja blanca abajo
/// con "¿A dónde vas?". Funciona sin cuenta (DS3).
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  final _sheetCtrl = DraggableScrollableController();
  final _peekKey = GlobalKey();

  /// Con ruta activa la hoja se oculta: el banner de la ruta es el asomo.
  static const _sheetHidden = 0.0;

  /// Altura de reposo de la hoja: se mide para que termine justo después de
  /// la pista (sin filas cortadas a la mitad bajo la barra), con cualquier
  /// pantalla y tamaño de texto.
  double _sheetInitial = 0.36;
  double _stackHeight = 0;

  /// Relleno inferior visto DENTRO del Scaffold (incluye la barra, porque
  /// extendBody suma su alto); el context del State no lo ve.
  double _bodyBottomInset = 0;

  void _measurePeek() {
    final box = _peekKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || _stackHeight <= 0 || !mounted) return;
    final visible = box.size.height + _bodyBottomInset;
    final fraction = (visible / _stackHeight).clamp(0.2, 0.75);
    if ((fraction - _sheetInitial).abs() < 0.005) return;
    setState(() => _sheetInitial = fraction);
    if (_sheetCtrl.isAttached) {
      _sheetCtrl.jumpTo(
          ref.read(activeRouteProvider) == null ? fraction : _sheetHidden);
    }
  }

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
      final double? target = next != null && prev == null
          ? _sheetHidden
          : next == null && prev != null
              ? _sheetInitial
              : null;
      if (target == null) return;
      if (MediaQuery.of(context).disableAnimations) {
        _sheetCtrl.jumpTo(target);
      } else {
        _sheetCtrl.animateTo(target,
            duration: target == _sheetHidden
                ? GSDuration.sheetOut
                : GSDuration.sheetIn,
            curve: GSCurve.enter);
      }
    });

    final corridor = ref.watch(corridorStatusProvider);
    final route = ref.watch(activeRouteProvider);

    final topInset = MediaQuery.of(context).padding.top;

    return Scaffold(
      extendBody: true,
      backgroundColor: GSColors.background,
      body: AnnotatedRegion<SystemUiOverlayStyle>(
        value: GSColors.isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        child: LayoutBuilder(builder: (context, box) {
          final inset = MediaQuery.of(context).padding.bottom;
          if (box.maxHeight != _stackHeight || inset != _bodyBottomInset) {
            _stackHeight = box.maxHeight;
            _bodyBottomInset = inset;
            WidgetsBinding.instance
                .addPostFrameCallback((_) => _measurePeek());
          }
          return Stack(
            children: [
              // El mapa ocupa toda la pantalla, también detrás de la barra
              // de estado; sus controles empiezan bajo la tarjeta de la vía.
              Positioned.fill(
                child: HomeMap(controlsTop: topInset + 96),
              ),

              // ── Estado de la Troncal: flota sobre el mapa ─────────────────
              Positioned(
                left: GSSpacing.s3,
                right: GSSpacing.s3,
                top: topInset + GSSpacing.s2,
                child: _CorridorHeader(corridor: corridor),
              ),

              DraggableScrollableSheet(
                controller: _sheetCtrl,
                initialChildSize: _sheetInitial,
                // Sin ruta, la hoja no baja de su altura medida: nunca
                // queda una fila cortada en reposo.
                minChildSize: route != null ? _sheetHidden : _sheetInitial,
                maxChildSize: 0.86,
                snap: true,
                builder: (context, scrollController) => DecoratedBox(
                  decoration: BoxDecoration(
                    color: GSColors.surface,
                    borderRadius: GSRadius.sheetRadius,
                    boxShadow: GSShadow.sheet,
                  ),
                  child: HomeSheetContent(
                      scrollController: scrollController, peekKey: _peekKey),
                ),
              ),
              if (route != null)
                Positioned(
                  bottom: MediaQuery.of(context).padding.bottom + GSSpacing.s3,
                  left: GSSpacing.s3,
                  right: GSSpacing.s3,
                  child: _RouteBanner(route: route),
                ),
            ],
          );
        }),
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
      floating: true,
      onTap: () => showCorridorDetailSheet(
        context,
        status ?? const CorridorStatus.noData(),
      ),
    );
  }
}

/// Ruta activa: tarjeta flotante como la de "viaje en curso" de Uber. Toca
/// para ver los tramos; la X la quita.
class _RouteBanner extends ConsumerWidget {
  const _RouteBanner({required this.route});
  final RouteResult route;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(selectedModeProvider);
    final text = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(GSRadius.xl),
        boxShadow: GSShadow.float,
      ),
      child: Material(
        color: GSColors.surface,
        borderRadius: BorderRadius.circular(GSRadius.xl),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.push(AppRoutes.routeDetail),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
                GSSpacing.s4, GSSpacing.s3, GSSpacing.s1, GSSpacing.s3),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: GSColors.brand,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(modeIconFor(mode), color: GSColors.onBrand),
                ),
                const SizedBox(width: GSSpacing.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${route.durationMin} min · '
                        '${route.distanceKm.toStringAsFixed(1)} km',
                        style: text.titleLarge?.copyWith(
                            fontFeatures: GSFonts.tabular),
                      ),
                      Text(
                        route.destinationLabel == null
                            ? 'Toca para ver los tramos'
                            : 'A ${route.destinationLabel} · ver tramos',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: text.bodyMedium,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Ayuda',
                  icon: Icon(Icons.health_and_safety_outlined,
                      color: GSColors.roadClosed),
                  onPressed: () => showSosSheet(context),
                ),
                IconButton(
                  tooltip: 'Quitar ruta',
                  icon: Icon(Icons.close_rounded, color: GSColors.textMuted),
                  onPressed: () =>
                      ref.read(activeRouteProvider.notifier).state = null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
