// lib/features/home/widgets/home_map.dart
// Mapa de fondo del inicio: GPS, ruta activa y "¿Ir aquí?" con pulsación larga.
// El mapa en sí (Google o flutter_map) vive en map_view.dart.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/region.dart';
import '../../../models/route_result.dart';
import '../../../providers/active_route_provider.dart';
import '../../../router/app_router.dart';
import '../../../services/location_service.dart';
import '../../../theme/design_tokens.dart';
import 'map_view.dart';

class HomeMap extends ConsumerStatefulWidget {
  const HomeMap({super.key, this.controlsTop = GSSpacing.s3});

  /// Dónde empiezan los controles flotantes (bajo la tarjeta de la vía).
  final double controlsTop;

  @override
  ConsumerState<HomeMap> createState() => _HomeMapState();
}

class _HomeMapState extends ConsumerState<HomeMap> {
  MapViewController? _map;

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
      _map?.moveTo(pos);
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
        ),

        // Arriba del mapa: la hoja inferior tapa la parte de abajo.
        if (_longPressPoint != null)
          Positioned(
            left: GSSpacing.s3,
            right: GSSpacing.s3,
            top: widget.controlsTop,
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
            right: GSSpacing.s3,
            top: widget.controlsTop,
            child: Column(
              children: [
                _MapButton(
                  tooltip: 'Mi ubicación',
                  icon: Icons.my_location_rounded,
                  onPressed: _recenter,
                ),
                if (googleMapsAvailable) ...[
                  const SizedBox(height: GSSpacing.s2),
                  _MapButton(
                    tooltip: 'Tipo de mapa',
                    icon: Icons.layers_outlined,
                    onPressed: () => _chooseMap(context),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// Botón redondo flotante sobre el mapa (como el de Google Maps).
class _MapButton extends StatelessWidget {
  const _MapButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });
  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: GSShadow.float),
      child: Material(
        color: GSColors.surface,
        shape: const CircleBorder(),
        child: IconButton(
          tooltip: tooltip,
          onPressed: onPressed,
          constraints: const BoxConstraints.tightFor(
            width: GSSize.touchTarget,
            height: GSSize.touchTarget,
          ),
          icon: Icon(icon, color: GSColors.brand),
        ),
      ),
    );
  }
}

/// Elegir el mapa: Google o el alternativo (OpenStreetMap). El alternativo no
/// necesita llave; sirve si Google se ve gris en un teléfono.
void _chooseMap(BuildContext context) {
  final current = useGoogleMaps ? 'google' : 'osm';
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheet) {
      final text = Theme.of(sheet).textTheme;
      Widget option(String value, IconData icon, String title, String detail) {
        final selected = current == value;
        return ListTile(
          leading: Icon(icon, color: selected ? GSColors.brand : GSColors.textMuted),
          title: Text(title),
          subtitle: Text(detail),
          trailing: selected
              ? Icon(Icons.check_circle_rounded, color: GSColors.brand)
              : null,
          onTap: () {
            setMapChoice(value);
            Navigator.of(sheet).pop();
          },
        );
      }

      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  GSSpacing.s4, 0, GSSpacing.s4, GSSpacing.s2),
              child: Text('Tipo de mapa', style: text.titleLarge),
            ),
            option('google', Icons.map_rounded, 'Google Maps',
                'Gira, inclina y muestra lugares'),
            option('osm', Icons.public_rounded, 'Mapa alternativo',
                'OpenStreetMap; úsalo si el mapa se ve gris'),
            const SizedBox(height: GSSpacing.s3),
          ],
        ),
      );
    },
  );
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
