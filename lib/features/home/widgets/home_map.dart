// lib/features/home/widgets/home_map.dart
// Mapa de fondo del inicio: GPS, ruta activa y "¿Ir aquí?" con pulsación larga.
// Todo el código del mapa vive aquí para facilitar el cambio a Google Maps (Fase 3).
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/env.dart';
import '../../../core/region.dart';
import '../../../models/route_result.dart';
import '../../../providers/active_route_provider.dart';
import '../../../router/app_router.dart';
import '../../../services/location_service.dart';
import '../../../theme/design_tokens.dart';

class HomeMap extends ConsumerStatefulWidget {
  const HomeMap({super.key});

  @override
  ConsumerState<HomeMap> createState() => _HomeMapState();
}

class _HomeMapState extends ConsumerState<HomeMap> {
  final _mapController = MapController();

  LatLng _userPosition = GSRegion.riohacha;
  bool _hasFix = false;
  LatLng? _longPressPoint;

  @override
  void initState() {
    super.initState();
    // Resolver el GPS después del primer frame (no async en initState).
    WidgetsBinding.instance.addPostFrameCallback((_) => _recenter());
  }

  Future<void> _recenter() async {
    final pos = await locationService.getCurrentPosition();
    if (pos != null && mounted) {
      setState(() {
        _userPosition = pos;
        _hasFix = true;
      });
      _mapController.move(pos, 14);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activeRoute = ref.watch(activeRouteProvider);

    // Encuadrar la ruta cuando se activa una nueva.
    ref.listen<RouteResult?>(activeRouteProvider, (prev, next) {
      if (next != null && next.legs.isNotEmpty) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          final allPoints = next.legs.expand((l) => l.points).toList();
          if (allPoints.length > 1) {
            _mapController.fitCamera(
              CameraFit.bounds(
                bounds: LatLngBounds.fromPoints(allPoints),
                padding: const EdgeInsets.fromLTRB(40, 80, 40, 240),
              ),
            );
          }
        });
      }
    });

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            initialCenter: _userPosition,
            initialZoom: 14,
            minZoom: 5.0,
            maxZoom: 19.0,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
            ),
            onLongPress: (tapPosition, point) {
              setState(() => _longPressPoint = point);
            },
          ),
          children: [
            // Estilo claro: DESIGN.md pide legibilidad al sol.
            TileLayer(
              urlTemplate: Env.mapboxToken.isNotEmpty
                  ? 'https://api.mapbox.com/styles/v1/mapbox/streets-v12/tiles/{z}/{x}/{y}@2x'
                      '?access_token=${Env.mapboxToken}'
                  : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              tileSize: Env.mapboxToken.isNotEmpty ? 512 : 256,
              zoomOffset: Env.mapboxToken.isNotEmpty ? -1 : 0,
              userAgentPackageName: 'com.gosmart.app',
              maxNativeZoom: 19,
            ),
            if (activeRoute != null)
              PolylineLayer(
                polylines: activeRoute.legs
                    .map((leg) => Polyline(
                          points: leg.points,
                          strokeWidth: 5.0,
                          color: leg.color,
                          borderColor: GSColors.surface,
                          borderStrokeWidth: 1.5,
                        ))
                    .toList(),
              ),
            if (activeRoute != null && activeRoute.legs.isNotEmpty)
              MarkerLayer(
                markers: [
                  Marker(
                    point: activeRoute.legs.first.points.first,
                    width: 36,
                    height: 36,
                    child: _Dot(
                        color: GSColors.brand, icon: Icons.my_location),
                  ),
                  Marker(
                    point: activeRoute.legs.last.points.last,
                    width: 40,
                    height: 40,
                    // Destino en tinta: el rojo es solo para la vía.
                    child: _Dot(
                        color: GSColors.text, icon: Icons.location_on),
                  ),
                ],
              ),
            // Posición del usuario (sin animación: DESIGN.md, nada en bucle).
            if (_hasFix)
              MarkerLayer(
                markers: [
                  Marker(
                    point: _userPosition,
                    width: 24,
                    height: 24,
                    child: Container(
                      decoration: BoxDecoration(
                        color: GSColors.brand,
                        shape: BoxShape.circle,
                        border: Border.all(color: GSColors.surface, width: 3),
                        boxShadow: GSShadow.md,
                      ),
                    ),
                  ),
                ],
              ),
            if (_longPressPoint != null)
              MarkerLayer(
                markers: [
                  Marker(
                    point: _longPressPoint!,
                    width: 44,
                    height: 44,
                    alignment: Alignment.topCenter,
                    child: Icon(
                      Icons.location_on,
                      color: GSColors.text,
                      size: 44,
                    ),
                  ),
                ],
              ),
          ],
        ),

        // Arriba del mapa: la hoja inferior tapa la parte de abajo.
        if (_longPressPoint != null)
          Positioned(
            left: GSSpacing.s4,
            right: GSSpacing.s4,
            top: GSSpacing.s3,
            child: _GoHereCard(
              point: _longPressPoint!,
              onConfirm: () {
                ref.read(pendingDestinationProvider.notifier).state =
                    _longPressPoint;
                setState(() => _longPressPoint = null);
                context.push(AppRoutes.routePlanner);
              },
              onCancel: () => setState(() => _longPressPoint = null),
            ),
          )
        else
          Positioned(
            right: GSSpacing.s4,
            top: GSSpacing.s3,
            child: Material(
              color: GSColors.surface,
              shape: CircleBorder(
                side: BorderSide(color: GSColors.line),
              ),
              elevation: 0,
              child: IconButton(
                tooltip: 'Mi ubicación',
                onPressed: _recenter,
                constraints: const BoxConstraints.tightFor(
                  width: GSSize.touchTarget,
                  height: GSSize.touchTarget,
                ),
                icon: Icon(Icons.my_location, color: GSColors.brand),
              ),
            ),
          ),
      ],
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.color, required this.icon});
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: GSColors.surface, width: 2),
        boxShadow: GSShadow.md,
      ),
      child: Icon(icon, color: GSColors.onBrand, size: 18),
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
        border: Border.all(color: GSColors.line),
        boxShadow: GSShadow.md,
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('¿Ir aquí?', style: text.titleMedium),
                Text(
                  '${point.latitude.toStringAsFixed(4)}, '
                  '${point.longitude.toStringAsFixed(4)}',
                  style: TextStyle(
                    fontFamily: GSFonts.mono, fontFeatures: GSFonts.tabular,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: GSColors.textMuted,
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
