import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../safety/sos_sheet.dart';
import '../../models/corridor_status.dart';
import '../../models/route_result.dart';
import '../../providers/active_route_provider.dart';
import '../../providers/corridor_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/selected_mode_provider.dart';
import '../../core/money.dart';
import '../../router/app_router.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/gs_bottom_nav.dart';
import '../../widgets/gs_button.dart';
import '../../widgets/gs_corridor_line.dart';
import '../../widgets/gs_meta_chip.dart';
import '../../widgets/gs_mode_visual.dart';
import '../../widgets/gs_pressable.dart';
import 'widgets/corridor_detail_sheet.dart';
import 'widgets/home_map.dart';
import 'widgets/home_sheet.dart';
import '../../core/clock.dart';

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
  final _routeCardKey = GlobalKey();
  final _corridorKey = GlobalKey();

  /// Altura de reposo de la hoja: se mide para que termine justo después de
  /// la pista (sin filas cortadas a la mitad bajo la barra), con cualquier
  /// pantalla y tamaño de texto.
  double _sheetInitial = 0.36;
  double _stackHeight = 0;

  /// Cuánto de la pantalla cubre la hoja ahora (cambia al arrastrarla): el
  /// mapa centra y encuadra en lo que queda libre, como en Uber.
  double _sheetExtent = 0.36;

  /// Alto del resumen de la ruta y de la tarjeta de la vía (medidos).
  double _routeCardHeight = 0;
  double _corridorBottom = 0;

  /// Relleno inferior visto DENTRO del Scaffold (incluye la barra, porque
  /// extendBody suma su alto); el context del State no lo ve.
  double _bodyBottomInset = 0;

  void _measure() {
    if (!mounted) return;
    final cb = _corridorKey.currentContext?.findRenderObject() as RenderBox?;
    if (cb != null && cb.hasSize) {
      final bottom = cb.localToGlobal(Offset.zero).dy + cb.size.height;
      if ((bottom - _corridorBottom).abs() > 1) setState(() => _corridorBottom = bottom);
    }
    final rb = _routeCardKey.currentContext?.findRenderObject() as RenderBox?;
    if (rb != null && rb.hasSize && (rb.size.height - _routeCardHeight).abs() > 1) {
      setState(() => _routeCardHeight = rb.size.height);
    }
    final box = _peekKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || _stackHeight <= 0) return;
    final visible = box.size.height + _bodyBottomInset;
    final fraction = (visible / _stackHeight).clamp(0.2, 0.75);
    if ((fraction - _sheetInitial).abs() < 0.005) return;
    setState(() {
      _sheetInitial = fraction;
      _sheetExtent = fraction;
    });
    if (_sheetCtrl.isAttached) _sheetCtrl.jumpTo(fraction);
  }

  @override
  void dispose() {
    _sheetCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final corridor = ref.watch(corridorStatusProvider);
    final route = ref.watch(activeRouteProvider);
    final topInset = MediaQuery.of(context).padding.top;
    // El saludo aparece cuando carga el perfil y cambia el alto de la parte
    // visible de la hoja: se vuelve a medir para no dejar el mototaxi cortado.
    ref.listen(profileProvider, (_, __) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _measure());
    });

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
          }
          WidgetsBinding.instance.addPostFrameCallback((_) => _measure());

          // Lo que tapa el mapa: arriba la tarjeta de la vía; abajo la hoja
          // (sigue al dedo al arrastrarla) o, con ruta, su resumen.
          final covered = route != null
              ? _routeCardHeight + inset + GSSpacing.s3
              : _sheetExtent * _stackHeight;
          final mapPadding = EdgeInsets.only(
            top: (_corridorBottom > 0 ? _corridorBottom : topInset + 96) + GSSpacing.s2,
            bottom: covered.clamp(0, _stackHeight * 0.8).toDouble(),
          );

          return Stack(
            children: [
              // El mapa ocupa toda la pantalla, también detrás de la barra
              // de estado; sus controles empiezan bajo la tarjeta de la vía.
              Positioned.fill(
                child: HomeMap(
                  controlsTop: mapPadding.top,
                  padding: mapPadding,
                ),
              ),

              // ── Estado de la Troncal: flota sobre el mapa ─────────────────
              Positioned(
                left: GSSpacing.s3,
                right: GSSpacing.s3,
                top: topInset + GSSpacing.s2,
                child: KeyedSubtree(
                  key: _corridorKey,
                  child: _CorridorHeader(corridor: corridor),
                ),
              ),

              // Sin ruta: la hoja "¿A dónde vas?". Con ruta: solo su resumen,
              // para que nada quede tapado a medias.
              if (route == null)
                NotificationListener<DraggableScrollableNotification>(
                  onNotification: (n) {
                    if ((n.extent - _sheetExtent).abs() > 0.004) {
                      setState(() => _sheetExtent = n.extent);
                    }
                    return false;
                  },
                  child: DraggableScrollableSheet(
                    controller: _sheetCtrl,
                    initialChildSize: _sheetInitial,
                    // La hoja no baja de su altura medida: nunca queda una
                    // fila cortada en reposo.
                    minChildSize: _sheetInitial,
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
                )
              else
                Positioned(
                  bottom: inset + GSSpacing.s3,
                  left: GSSpacing.s3,
                  right: GSSpacing.s3,
                  child: KeyedSubtree(
                    key: _routeCardKey,
                    child: _RouteCard(route: route),
                  ),
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

/// Ruta activa, como el resumen de InDrive/DiDi antes de pedir: el vehículo
/// grande, a qué hora llegas, el precio y los datos en píldoras. Entra
/// subiendo 16 dp con un fundido (250 ms, ease-out); la X la quita.
class _RouteCard extends ConsumerWidget {
  const _RouteCard({required this.route});
  final RouteResult route;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(selectedModeProvider);
    final text = Theme.of(context).textTheme;
    final price = route.estimatedCostCop > 0
        ? formatCop(route.fareMax ?? route.estimatedCostCop)
        : null;
    final km = route.distanceKm
        .toStringAsFixed(route.distanceKm < 10 ? 1 : 0)
        .replaceAll('.', ',');
    final fareLabel = switch (route.fareKind) {
      'oficial' => 'Tarifa oficial',
      'sugerida' => 'Tarifa sugerida',
      'ruta' => 'Pasaje de la ruta',
      _ => null,
    };
    final reduce = MediaQuery.of(context).disableAnimations;

    final card = DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(GSRadius.xl),
        boxShadow: GSShadow.float,
      ),
      child: Material(
        color: GSColors.surface,
        borderRadius: BorderRadius.circular(GSRadius.xl),
        clipBehavior: Clip.antiAlias,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
              GSSpacing.s4, GSSpacing.s4, GSSpacing.s2, GSSpacing.s4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 68,
                    height: 56,
                    decoration: BoxDecoration(
                      color: GSColors.brandTint,
                      borderRadius: BorderRadius.circular(GSRadius.md),
                    ),
                    child: Center(child: GSModeVisual(mode: mode, height: 40)),
                  ),
                  const SizedBox(width: GSSpacing.s3),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          mode,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleLarge,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          route.destinationLabel == null
                              ? 'Llegas ${arrivalClock(route.durationMin)}'
                              : 'A ${route.destinationLabel}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: text.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  if (price != null)
                    Padding(
                      padding: const EdgeInsets.only(
                          left: GSSpacing.s2, top: 2),
                      child: Text(
                        price,
                        style: text.headlineSmall
                            ?.copyWith(fontFeatures: GSFonts.tabular),
                      ),
                    ),
                  SizedBox(
                    width: GSSize.touchTarget,
                    height: GSSize.touchTarget,
                    child: IconButton(
                      tooltip: 'Quitar ruta',
                      padding: EdgeInsets.zero,
                      icon: Icon(Icons.close_rounded,
                          color: GSColors.textMuted, size: 22),
                      onPressed: () =>
                          ref.read(activeRouteProvider.notifier).state = null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: GSSpacing.s3),
              Padding(
                padding: const EdgeInsets.only(right: GSSpacing.s2),
                child: Wrap(
                  spacing: GSSpacing.s2,
                  runSpacing: GSSpacing.s2,
                  children: [
                    GSMetaChip(
                        icon: Icons.schedule_rounded,
                        label: '${route.durationMin} min'),
                    GSMetaChip(icon: Icons.route_rounded, label: '$km km'),
                    if (route.destinationLabel != null)
                      GSMetaChip(
                          icon: Icons.flag_rounded,
                          label: 'Llegas ${arrivalClock(route.durationMin)}'),
                    if (fareLabel != null)
                      GSMetaChip(
                          icon: Icons.sell_rounded,
                          label: fareLabel,
                          emphasis: true),
                  ],
                ),
              ),
              const SizedBox(height: GSSpacing.s4),
              Padding(
                padding: const EdgeInsets.only(right: GSSpacing.s2),
                child: Row(
                  children: [
                    Expanded(
                      child: GSButton(
                        label: 'Ver viaje',
                        trailingIcon: Icons.arrow_forward_rounded,
                        isFullWidth: true,
                        onPressed: () => context.push(AppRoutes.routeDetail),
                      ),
                    ),
                    const SizedBox(width: GSSpacing.s2),
                    GSPressable(
                      onTap: () => showSosSheet(context),
                      semanticLabel: 'Ayuda: SOS',
                      child: Container(
                        width: GSSize.button,
                        height: GSSize.button,
                        decoration: BoxDecoration(
                          color: GSColors.roadClosedTint,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(Icons.health_and_safety_rounded,
                            color: GSColors.roadClosed),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (reduce) return card;
    return TweenAnimationBuilder<double>(
      key: ValueKey(route),
      tween: Tween(begin: 0, end: 1),
      duration: GSDuration.normal,
      curve: GSCurve.enter,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 16 * (1 - t)), child: child),
      ),
      child: card,
    );
  }
}
