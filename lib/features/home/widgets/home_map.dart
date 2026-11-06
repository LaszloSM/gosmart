// lib/features/home/widgets/home_map.dart
// Mapa de fondo del inicio: GPS, ruta activa y "¿Ir aquí?" con pulsación larga.
// El mapa en sí (Google o flutter_map) vive en map_view.dart.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/region.dart';
import '../../alerts/alert_banner.dart';
import '../../alerts/alert_detail_sheet.dart';
import '../../alerts/report_sheet.dart';
import '../../../providers/map_alerts_provider.dart';
import '../../../models/route_result.dart';
import '../../../providers/active_route_provider.dart';
import '../../../router/app_router.dart';
import '../../../services/geocoding_service.dart';
import '../../../services/location_service.dart';
import '../../../services/road_snap.dart';
import '../../../theme/design_tokens.dart';
import '../../../widgets/gs_pressable.dart';
import '../../../widgets/gs_toast.dart';
import 'map_view.dart';

class HomeMap extends ConsumerStatefulWidget {
  const HomeMap({
    super.key,
    this.controlsTop = GSSpacing.s3,
    this.padding = EdgeInsets.zero,
    this.sheetExtent,
    this.stackHeight = 0,
    this.fixedBottom,
  });

  /// Dónde empiezan los avisos de arriba (bajo la barra de estado).
  final double controlsTop;

  /// Fracción de pantalla que tapa la hoja, en vivo: los botones flotantes
  /// (ubicarme, reportar) la siguen sin reconstruir el mapa.
  final ValueListenable<double>? sheetExtent;
  final double stackHeight;

  /// Con ruta activa: alto fijo del resumen (los botones van encima).
  final double? fixedBottom;

  /// Parte del mapa tapada arriba y abajo (ver MapView.padding).
  final EdgeInsets padding;

  @override
  ConsumerState<HomeMap> createState() => _HomeMapState();
}

class _HomeMapState extends ConsumerState<HomeMap> with WidgetsBindingObserver {
  MapViewController? _map;

  LatLng _userPosition = locationService.last ?? GSRegion.riohacha;
  bool _hasFix = locationService.last != null;
  LatLng? _longPressPoint;

  Timer? _alertsTimer;
  StreamSubscription<LatLng>? _positions;
  StreamSubscription<LatLng>? _watch;

  /// El usuario tocó "Mi ubicación": la próxima lectura mueve la cámara.
  bool _followNext = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Cualquier lectura (de aquí, del planificador o del aviso de alertas)
    // mueve el punto azul.
    _positions = locationService.positions.listen(_onPosition);
    // Resolver el GPS después del primer frame (no async en initState).
    WidgetsBinding.instance.addPostFrameCallback((_) => _recenter(quiet: true));
    // Las alertas cambian rápido (un retén dura 2 h): se refrescan cada 90 s
    // mientras el mapa está abierto.
    _alertsTimer = Timer.periodic(const Duration(seconds: 90), (_) {
      if (mounted) ref.read(mapAlertsProvider.notifier).refresh();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _alertsTimer?.cancel();
    _positions?.cancel();
    _watch?.cancel();
    super.dispose();
  }

  /// Al volver de los ajustes (prendió el GPS o dio permiso), reintentar.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_hasFix) {
      _recenter(quiet: true);
    }
  }

  void _onPosition(LatLng p) {
    if (!mounted) return;
    setState(() {
      _userPosition = p;
      _hasFix = true;
    });
    if (_followNext) {
      _followNext = false;
      _map?.moveTo(p);
    }
  }

  /// Llevar el mapa a donde estás. Si falta GPS o permiso, lo dice y ofrece
  /// arreglarlo; [quiet] (al abrir) no molesta si el usuario no lo pidió.
  Future<void> _recenter({bool quiet = false}) async {
    final messenger = ScaffoldMessenger.of(context);
    _followNext = true;
    // Mientras llega la lectura nueva, ir ya a la última conocida.
    if (_hasFix) _map?.moveTo(_userPosition);
    final pos = await locationService.getCurrentPosition();
    if (!mounted) return;
    if (pos != null) {
      _onPosition(pos);
      _map?.moveTo(pos);
      _startWatching();
      return;
    }
    final issue = locationService.lastIssue ?? LocationIssue.noFix;
    if (quiet && issue == LocationIssue.noFix) return;
    GSToast.showWithMessenger(
      messenger,
      message: locationIssueText(issue),
      type: GSToastType.warning,
      duration: const Duration(seconds: 6),
      actionLabel: issue == LocationIssue.noFix ? 'Reintentar' : 'Activar',
      onAction: () async {
        await locationService.fix(issue);
        if (mounted) _recenter();
      },
    );
  }

  /// Con permiso, el punto sigue al celular mientras el mapa está abierto.
  void _startWatching() {
    _watch ??= locationService.watch(distanceFilter: 15).listen((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final activeRoute = ref.watch(activeRouteProvider);
    final alerts = ref.watch(visibleAlertsProvider);

    // Encuadrar la ruta cuando se activa una nueva.
    ref.listen<RouteResult?>(activeRouteProvider, (prev, next) {
      // Venga de donde venga (planificador, asistente), la ruta va por la
      // vía: los tramos rectos se cambian por el trazado de calles.
      if (next != null && next.legs.any((l) => l.points.length == 2)) {
        roadSnapper.snap(next).then((snapped) {
          if (!identical(snapped, next) &&
              identical(ref.read(activeRouteProvider), next)) {
            ref.read(activeRouteProvider.notifier).state = snapped;
          }
        });
      }
      if (next != null && next.legs.isNotEmpty) {
        // Tras aplicar el relleno nuevo (resumen de la ruta abajo) se encuadra.
        Future.delayed(const Duration(milliseconds: 350), () {
          if (!mounted) return;
          _map?.fit(next.legs.expand((l) => l.points).toList());
        });
      }
    });

    return Stack(
      children: [
        MapView(
          initialCenter: _userPosition,
          onCreated: (c) => _map = c,
          onLongPress: (point) => setState(() => _longPressPoint = point),
          route: activeRoute,
          user: _hasFix ? _userPosition : null,
          pin: _longPressPoint,
          padding: widget.padding,
          alerts: alerts,
          onAlertTap: (a) => showAlertDetail(context, a),
        ),

        // Arriba: "¿Ir aquí?" tras la pulsación larga, o el aviso de alerta
        // cercana (Waze) mientras te mueves.
        Positioned(
          left: GSSpacing.s3,
          right: GSSpacing.s3,
          top: widget.controlsTop,
          child: _longPressPoint != null
              ? _GoHereCard(
                  point: _longPressPoint!,
                  onConfirm: () {
                    ref.read(pendingDestinationProvider.notifier).state =
                        _longPressPoint;
                    setState(() => _longPressPoint = null);
                    context.push(AppRoutes.routePlanner);
                  },
                  onCancel: () => setState(() => _longPressPoint = null),
                )
              : const AlertProximityBanner(),
        ),

        // Abajo: ubicarme (izquierda) y reportar (derecha), justo encima de
        // la hoja; la siguen al arrastrarla y se ocultan si la hoja sube mucho.
        _FloatingControls(
          sheetExtent: widget.sheetExtent,
          stackHeight: widget.stackHeight,
          fixedBottom: widget.fixedBottom,
          onRecenter: () => _recenter(),
          onReport: () => showReportSheet(context),
        ),
      ],
    );
  }
}

/// Sin hoja (hay ruta): nada que escuchar.
final _noSheet = ValueNotifier<double>(0);

/// Los dos botones flotantes del mapa. Escuchan la fracción viva de la hoja.
class _FloatingControls extends StatelessWidget {
  const _FloatingControls({
    required this.sheetExtent,
    required this.stackHeight,
    required this.fixedBottom,
    required this.onRecenter,
    required this.onReport,
  });
  final ValueListenable<double>? sheetExtent;
  final double stackHeight;
  final double? fixedBottom;
  final VoidCallback onRecenter;
  final VoidCallback onReport;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: sheetExtent ?? _noSheet,
      builder: (context, extent, child) {
        final bottom = (fixedBottom ?? extent * stackHeight) + GSSpacing.s3;
        // Con la hoja casi arriba no hay mapa que ubicar: se van.
        final hidden = fixedBottom == null && extent > 0.62;
        return Positioned(
          left: GSSpacing.s3,
          right: GSSpacing.s3,
          bottom: bottom,
          child: IgnorePointer(
            ignoring: hidden,
            child: AnimatedOpacity(
              opacity: hidden ? 0 : 1,
              duration: MediaQuery.of(context).disableAnimations
                  ? Duration.zero
                  : GSDuration.fast,
              child: child,
            ),
          ),
        );
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          _RoundFab(
            tooltip: 'Mi ubicación',
            icon: Icons.my_location_rounded,
            background: GSColors.surface,
            foreground: GSColors.brand,
            onTap: onRecenter,
          ),
          const Spacer(),
          // Como Waze: se reporta también con una ruta en pantalla.
          _RoundFab(
            tooltip: 'Reportar en la vía',
            icon: Icons.add_location_alt_rounded,
            background: GSColors.alertCaution,
            foreground: GSColors.onAlertCaution,
            size: 60,
            onTap: onReport,
          ),
        ],
      ),
    );
  }
}

/// Botón redondo flotante con sombra y la presión de 0.97 (GSPressable).
class _RoundFab extends StatelessWidget {
  const _RoundFab({
    required this.tooltip,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onTap,
    this.size = GSSize.touchTarget + 4,
  });
  final String tooltip;
  final IconData icon;
  final Color background;
  final Color foreground;
  final VoidCallback onTap;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: GSPressable(
        onTap: onTap,
        semanticLabel: tooltip,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: background,
            shape: BoxShape.circle,
            boxShadow: GSShadow.float,
          ),
          child: Icon(icon, color: foreground, size: size * 0.46),
        ),
      ),
    );
  }
}

class _GoHereCard extends StatelessWidget {
  const _GoHereCard({
    required this.point,
    required this.onConfirm,
    required this.onCancel,
  });
  final LatLng point;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(
          GSSpacing.s4, GSSpacing.s2, GSSpacing.s2, GSSpacing.s2),
      decoration: BoxDecoration(
        color: GSColors.surface,
        borderRadius: BorderRadius.circular(GSRadius.lg),
        boxShadow: GSShadow.float,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('¿Ir aquí?', style: text.titleMedium),
                // La dirección del punto (calle o lugar cercano), no coordenadas.
                FutureBuilder<String?>(
                  future: geocodingService.reverse(point),
                  builder: (context, snap) => Text(
                    snap.data ??
                        (snap.connectionState == ConnectionState.done
                            ? 'Punto en el mapa'
                            : 'Buscando la dirección…'),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodySmall,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: onCancel,
            style: TextButton.styleFrom(foregroundColor: GSColors.textMuted),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: onConfirm,
            style: FilledButton.styleFrom(
              minimumSize: const Size(0, GSSize.touchTarget),
              padding: const EdgeInsets.symmetric(horizontal: GSSpacing.s4),
            ),
            child: const Text('Buscar ruta'),
          ),
        ],
      ),
    );
  }
}
