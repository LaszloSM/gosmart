// lib/features/home/widgets/map_view.dart
// El mapa detrás de una sola interfaz (Fase 3): Google Maps cuando hay clave
// (gestos nativos, rotar e inclinar con brújula, estilo nocturno propio,
// cámara limitada a La Guajira). Sin clave (pruebas, web del admin) queda
// flutter_map con OpenStreetMap como respaldo.
// Lo demás de la app no sabe cuál se usa.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import 'package:latlong2/latlong.dart';

import '../../../core/env.dart';
import '../../../core/region.dart';
import '../../../models/route_result.dart';
import '../../../theme/design_tokens.dart';

/// Lo que el inicio le pide a la cámara, sea cual sea el mapa.
abstract class MapViewController {
  Future<void> moveTo(LatLng p, {double zoom = 14});
  Future<void> fit(List<LatLng> points);
}

/// true si hay una clave de Google con forma válida y el proveedor es google.
bool get useGoogleMaps {
  try {
    return Env.mapProvider == 'google' && Env.googleMapsApiKey.startsWith('AIza');
  } catch (_) {
    return false; // sin .env (pruebas)
  }
}

/// Límites de cámara: La Guajira y alrededores.
const guajiraSouthWest = LatLng(10.3, -73.7);
const guajiraNorthEast = LatLng(12.6, -71.0);

class MapView extends StatelessWidget {
  const MapView({
    super.key,
    required this.initialCenter,
    required this.onCreated,
    required this.onLongPress,
    this.route,
    this.user,
    this.pin,
  });

  final LatLng initialCenter;
  final ValueChanged<MapViewController> onCreated;
  final ValueChanged<LatLng> onLongPress;
  final RouteResult? route;
  final LatLng? user;
  final LatLng? pin;

  @override
  Widget build(BuildContext context) => useGoogleMaps
      ? _GoogleMapView(view: this)
      : _FlutterMapView(view: this);
}

// ── Google Maps ──────────────────────────────────────────────────────────────
class _GoogleMapView extends StatefulWidget {
  const _GoogleMapView({required this.view});
  final MapView view;

  @override
  State<_GoogleMapView> createState() => _GoogleMapViewState();
}

class _GoogleMapViewState extends State<_GoogleMapView> implements MapViewController {
  gm.GoogleMapController? _c;
  String? _nightStyle;

  static gm.LatLng _g(LatLng p) => gm.LatLng(p.latitude, p.longitude);

  @override
  void initState() {
    super.initState();
    rootBundle.loadString('assets/map_styles/night.json').then((s) {
      if (mounted) setState(() => _nightStyle = s);
    });
  }

  @override
  Future<void> moveTo(LatLng p, {double zoom = 14}) async =>
      _c?.animateCamera(gm.CameraUpdate.newLatLngZoom(_g(p), zoom));

  @override
  Future<void> fit(List<LatLng> points) async {
    if (points.length < 2 || _c == null) return;
    var s = points.first.latitude, n = s, w = points.first.longitude, e = w;
    for (final p in points) {
      if (p.latitude < s) s = p.latitude;
      if (p.latitude > n) n = p.latitude;
      if (p.longitude < w) w = p.longitude;
      if (p.longitude > e) e = p.longitude;
    }
    await _c!.animateCamera(gm.CameraUpdate.newLatLngBounds(
        gm.LatLngBounds(southwest: gm.LatLng(s, w), northeast: gm.LatLng(n, e)), 64));
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.view;
    final night = Theme.of(context).brightness == Brightness.dark;
    return gm.GoogleMap(
      initialCameraPosition: gm.CameraPosition(target: _g(v.initialCenter), zoom: 14),
      style: night ? _nightStyle : null,
      onMapCreated: (c) {
        _c = c;
        v.onCreated(this);
      },
      // Gestos de fábrica: pellizcar, arrastrar, doble toque, rotar e inclinar.
      rotateGesturesEnabled: true,
      tiltGesturesEnabled: true,
      compassEnabled: true,
      myLocationButtonEnabled: false,
      mapToolbarEnabled: false,
      zoomControlsEnabled: false,
      minMaxZoomPreference: const gm.MinMaxZoomPreference(5, 19),
      cameraTargetBounds: gm.CameraTargetBounds(gm.LatLngBounds(
          southwest: _g(guajiraSouthWest), northeast: _g(guajiraNorthEast))),
      onLongPress: (p) => v.onLongPress(LatLng(p.latitude, p.longitude)),
      polylines: {
        if (v.route != null)
          for (var i = 0; i < v.route!.legs.length; i++)
            gm.Polyline(
              polylineId: gm.PolylineId('leg$i'),
              points: [for (final p in v.route!.legs[i].points) _g(p)],
              width: 6,
              color: v.route!.legs[i].color,
              patterns: v.route!.legs[i].mode == 'walk'
                  ? [gm.PatternItem.dot, gm.PatternItem.gap(8)]
                  : const [],
            ),
      },
      markers: {
        if (v.user != null)
          gm.Marker(
            markerId: const gm.MarkerId('user'),
            position: _g(v.user!),
            icon: gm.BitmapDescriptor.defaultMarkerWithHue(gm.BitmapDescriptor.hueAzure),
            infoWindow: const gm.InfoWindow(title: 'Estás aquí'),
          ),
        if (v.route != null && v.route!.legs.isNotEmpty)
          gm.Marker(
            markerId: const gm.MarkerId('dest'),
            position: _g(v.route!.legs.last.points.last),
            infoWindow: gm.InfoWindow(title: v.route!.destinationLabel ?? 'Destino'),
          ),
        if (v.pin != null)
          gm.Marker(markerId: const gm.MarkerId('pin'), position: _g(v.pin!)),
      },
    );
  }
}

// ── flutter_map (OSM, respaldo) ───────────────────────────────────────────────
class _FlutterMapView extends StatefulWidget {
  const _FlutterMapView({required this.view});
  final MapView view;

  @override
  State<_FlutterMapView> createState() => _FlutterMapViewState();
}

class _FlutterMapViewState extends State<_FlutterMapView> implements MapViewController {
  final _c = fm.MapController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.view.onCreated(this));
  }

  @override
  Future<void> moveTo(LatLng p, {double zoom = 14}) async => _c.move(p, zoom);

  @override
  Future<void> fit(List<LatLng> points) async {
    if (points.length < 2) return;
    _c.fitCamera(fm.CameraFit.bounds(
      bounds: fm.LatLngBounds.fromPoints(points),
      padding: const EdgeInsets.fromLTRB(40, 80, 40, 240),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.view;
    return fm.FlutterMap(
      mapController: _c,
      options: fm.MapOptions(
        initialCenter: v.initialCenter,
        initialZoom: 14,
        minZoom: 5.0,
        maxZoom: 19.0,
        cameraConstraint: fm.CameraConstraint.containCenter(
          bounds: fm.LatLngBounds(guajiraSouthWest, guajiraNorthEast),
        ),
        interactionOptions: const fm.InteractionOptions(flags: fm.InteractiveFlag.all),
        onLongPress: (_, point) => v.onLongPress(point),
      ),
      children: [
        // Estilo claro: DESIGN.md pide legibilidad al sol.
        fm.TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.gosmart.app',
          maxNativeZoom: 19,
        ),
        if (v.route != null)
          fm.PolylineLayer(
            polylines: [
              for (final leg in v.route!.legs)
                fm.Polyline(
                  points: leg.points,
                  strokeWidth: 5.0,
                  color: leg.color,
                  borderColor: GSColors.surface,
                  borderStrokeWidth: 1.5,
                ),
            ],
          ),
        fm.MarkerLayer(markers: [
          if (v.route != null && v.route!.legs.isNotEmpty) ...[
            fm.Marker(
              point: v.route!.legs.first.points.first,
              width: 36,
              height: 36,
              child: _Dot(color: GSColors.brand, icon: Icons.my_location),
            ),
            fm.Marker(
              point: v.route!.legs.last.points.last,
              width: 40,
              height: 40,
              // Destino en tinta: el rojo es solo para la vía.
              child: _Dot(color: GSColors.text, icon: Icons.location_on),
            ),
          ],
          // Posición del usuario (sin animación: nada en bucle).
          if (v.user != null)
            fm.Marker(
              point: v.user!,
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
          if (v.pin != null)
            fm.Marker(
              point: v.pin!,
              width: 44,
              height: 44,
              alignment: Alignment.topCenter,
              child: Icon(Icons.location_on, color: GSColors.text, size: 44),
            ),
        ]),
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

/// Centro inicial cuando aún no hay GPS.
const defaultMapCenter = GSRegion.riohacha;
