// lib/features/home/widgets/map_view.dart
// El mapa detrás de una sola interfaz (Fase 3): Google Maps cuando hay clave
// (gestos nativos, rotar e inclinar con brújula, estilo nocturno propio,
// cámara limitada a La Guajira, estilo claro y nocturno propios). Sin clave (pruebas, web del admin) queda
// flutter_map con OpenStreetMap como respaldo.
// Lo demás de la app no sabe cuál se usa.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_map/flutter_map.dart' as fm;
import 'package:google_maps_flutter/google_maps_flutter.dart' as gm;
import 'package:latlong2/latlong.dart';

import '../../../core/env.dart';
import '../../../core/region.dart';
import '../../../models/map_alert.dart';
import '../../../models/route_result.dart';
import '../../../theme/design_tokens.dart';
import '../../../widgets/gs_alert_badge.dart';
import '../../../widgets/gs_vehicle_pin.dart';

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
    this.padding = EdgeInsets.zero,
    this.alerts = const [],
    this.onAlertTap,
    this.vehicle,
    this.vehicleService = 'mototaxi',
    this.onLongPressEnabled = true,
    this.onCameraMoveStarted,
    this.onCameraIdle,
    this.initialZoom,
  });

  /// Empezó a moverse la cámara (dedo o animación). Una vez por movimiento.
  final VoidCallback? onCameraMoveStarted;

  /// La cámara se detuvo: centro visible (con [padding] ya descontado).
  final ValueChanged<LatLng>? onCameraIdle;

  /// Zoom inicial; null = el de cada mapa.
  final double? initialZoom;

  /// El conductor que viene o con quien vas (ya interpolado: ver TripMap).
  final LatLng? vehicle;
  final String vehicleService;

  /// En el viaje no hay "¿Ir aquí?": la pulsación larga no hace nada.
  final bool onLongPressEnabled;

  /// Alertas tipo Waze: globos que se vuelven puntos al alejar el mapa.
  final List<MapAlert> alerts;
  final ValueChanged<MapAlert>? onAlertTap;

  /// Lo que tapan la tarjeta de la vía (arriba) y la hoja o el resumen de la
  /// ruta (abajo): la cámara centra y encuadra en lo que queda visible.
  final EdgeInsets padding;
  final LatLng initialCenter;
  final ValueChanged<MapViewController> onCreated;
  final ValueChanged<LatLng> onLongPress;
  final RouteResult? route;
  final LatLng? user;
  final LatLng? pin;

  // El mapa se repinta por su cuenta (arrastre, teselas): aislado del resto,
  // la hoja y los botones de encima no lo arrastran a repintar, ni al revés.
  @override
  Widget build(BuildContext context) => RepaintBoundary(
        child: useGoogleMaps ? _GoogleMapView(view: this) : _FlutterMapView(view: this),
      );
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
  String? _lightStyle;

  /// Tamaño actual de los pines (cambia solo al cruzar un umbral de zoom).
  AlertPinSize _pinSize = alertPinSizeFor(15.5);

  /// Último centro de la cámara; se entrega al detenerse (sin setState).
  gm.LatLng? _target;

  /// Imágenes de los pines ya dibujadas: tipo|tamaño|noche → ícono.
  final _pinCache = <String, gm.BitmapDescriptor>{};
  bool _drawingPins = false;

  String _pinKey(AlertKind k, AlertPinSize s, bool dark) => '${k.id}|${s.name}|$dark';

  /// Dibuja (una sola vez) las imágenes que faltan para los tipos visibles.
  Future<void> _ensurePins(bool dark) async {
    if (_drawingPins) return;
    final missing = {
      for (final a in widget.view.alerts)
        if (!_pinCache.containsKey(_pinKey(a.kind, _pinSize, dark))) a.kind,
    };
    if (missing.isEmpty) return;
    _drawingPins = true;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final size = _pinSize;
    for (final k in missing) {
      final bytes = await renderAlertPin(k, size, pixelRatio: dpr, dark: dark);
      _pinCache[_pinKey(k, size, dark)] = gm.BitmapDescriptor.bytes(
        bytes,
        imagePixelRatio: dpr,
      );
    }
    _drawingPins = false;
    if (mounted) setState(() {});
  }

  static gm.LatLng _g(LatLng p) => gm.LatLng(p.latitude, p.longitude);

  /// Imagen del conductor por servicio (se dibuja una vez).
  final _vehicleIcons = <String, gm.BitmapDescriptor>{};

  Future<void> _ensureVehicle(String service) async {
    if (_vehicleIcons.containsKey(service)) return;
    _vehicleIcons[service] = gm.BitmapDescriptor.defaultMarker; // reserva
    final dpr = MediaQuery.devicePixelRatioOf(context);
    final bytes = await renderVehiclePin(service, pixelRatio: dpr, brand: GSColors.brand);
    _vehicleIcons[service] = gm.BitmapDescriptor.bytes(bytes, imagePixelRatio: dpr);
    if (mounted) setState(() {});
  }

  @override
  void initState() {
    super.initState();
    rootBundle.loadString('assets/map_styles/night.json').then((s) {
      if (mounted) setState(() => _nightStyle = s);
    });
    // De día: menos comercios y colores más calmos, para que la ruta y los
    // marcadores se lean primero (como Google Maps en modo navegación).
    rootBundle.loadString('assets/map_styles/light.json').then((s) {
      if (mounted) setState(() => _lightStyle = s);
    });
  }

  @override
  Future<void> moveTo(LatLng p, {double zoom = 15.5}) async =>
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
        gm.LatLngBounds(southwest: gm.LatLng(s, w), northeast: gm.LatLng(n, e)), 56));
  }

  @override
  Widget build(BuildContext context) {
    final v = widget.view;
    final night = Theme.of(context).brightness == Brightness.dark;
    final legs = v.route?.legs ?? const [];
    if (v.alerts.isNotEmpty) unawaited(_ensurePins(night));
    if (v.vehicle != null) unawaited(_ensureVehicle(v.vehicleService));
    return gm.GoogleMap(
      initialCameraPosition:
          gm.CameraPosition(target: _g(v.initialCenter), zoom: v.initialZoom ?? 15.5),
      padding: v.padding,
      style: night ? _nightStyle : _lightStyle,
      onMapCreated: (c) {
        _c = c;
        v.onCreated(this);
      },
      // Gestos de fábrica: pellizcar, arrastrar, doble toque, rotar e inclinar.
      rotateGesturesEnabled: true,
      tiltGesturesEnabled: true,
      compassEnabled: true,
      // Punto azul nativo de "estás aquí" (como Google Maps); el botón propio
      // de ubicarme vive en el inicio.
      myLocationEnabled: v.user != null,
      myLocationButtonEnabled: false,
      mapToolbarEnabled: false,
      zoomControlsEnabled: false,
      minMaxZoomPreference: const gm.MinMaxZoomPreference(5, 19),
      cameraTargetBounds: gm.CameraTargetBounds(gm.LatLngBounds(
          southwest: _g(guajiraSouthWest), northeast: _g(guajiraNorthEast))),
      onLongPress: v.onLongPressEnabled
          ? (p) => v.onLongPress(LatLng(p.latitude, p.longitude))
          : null,
      // Al alejar o acercar, los pines cambian de tamaño solo al cruzar un
      // umbral (no en cada cuadro): globo grande, globo chico, punto.
      onCameraMoveStarted: v.onCameraMoveStarted,
      onCameraMove: (pos) {
        _target = pos.target;
        final next = alertPinSizeFor(pos.zoom);
        if (next != _pinSize) setState(() => _pinSize = next);
      },
      onCameraIdle: v.onCameraIdle == null
          ? null
          : () {
              final t = _target;
              if (t != null) v.onCameraIdle!(LatLng(t.latitude, t.longitude));
            },
      polylines: {
        if (v.route != null)
          for (var i = 0; i < v.route!.legs.length; i++)
            gm.Polyline(
              polylineId: gm.PolylineId('leg$i'),
              points: [for (final p in v.route!.legs[i].points) _g(p)],
              width: 7,
              color: v.route!.legs[i].liveColor,
              startCap: gm.Cap.roundCap,
              endCap: gm.Cap.roundCap,
              jointType: gm.JointType.round,
              patterns: v.route!.legs[i].mode == 'walk'
                  ? [gm.PatternItem.dot, gm.PatternItem.gap(8)]
                  : const [],
            ),
      },
      markers: {
        if (legs.isNotEmpty && legs.first.points.isNotEmpty)
          gm.Marker(
            markerId: const gm.MarkerId('origin'),
            position: _g(legs.first.points.first),
            icon: gm.BitmapDescriptor.defaultMarkerWithHue(gm.BitmapDescriptor.hueAzure),
            infoWindow: const gm.InfoWindow(title: 'Salida'),
          ),
        if (legs.isNotEmpty && legs.last.points.isNotEmpty)
          gm.Marker(
            markerId: const gm.MarkerId('dest'),
            position: _g(legs.last.points.last),
            infoWindow: gm.InfoWindow(title: v.route!.destinationLabel ?? 'Destino'),
          ),
        if (v.pin != null)
          gm.Marker(markerId: const gm.MarkerId('pin'), position: _g(v.pin!)),
        if (v.vehicle != null && _vehicleIcons[v.vehicleService] != null)
          gm.Marker(
            markerId: const gm.MarkerId('vehicle'),
            position: _g(v.vehicle!),
            icon: _vehicleIcons[v.vehicleService]!,
            anchor: const Offset(0.5, 0.5),
            zIndexInt: 5,
            infoWindow: const gm.InfoWindow(title: 'Tu conductor'),
          ),
        for (final a in v.alerts)
          if (_pinCache[_pinKey(a.kind, _pinSize, night)] case final icon?)
            gm.Marker(
              markerId: gm.MarkerId('alert-${a.id}'),
              position: _g(a.at),
              icon: icon,
              anchor: _pinSize == AlertPinSize.dot
                  ? const Offset(0.5, 0.5)
                  : const Offset(0.5, 1),
              // Lo grave queda encima de lo demás.
              zIndexInt: a.kind.severity == AlertSeverity.severe ? 3 : 2,
              consumeTapEvents: true,
              onTap: v.onAlertTap == null ? null : () => v.onAlertTap!(a),
            ),
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
  AlertPinSize _pinSize = alertPinSizeFor(14);

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
        initialZoom: v.initialZoom ?? 14,
        minZoom: 5.0,
        maxZoom: 19.0,
        cameraConstraint: fm.CameraConstraint.containCenter(
          bounds: fm.LatLngBounds(guajiraSouthWest, guajiraNorthEast),
        ),
        interactionOptions: const fm.InteractionOptions(flags: fm.InteractiveFlag.all),
        onLongPress: v.onLongPressEnabled ? (_, point) => v.onLongPress(point) : null,
        onPositionChanged: (camera, _) {
          final next = alertPinSizeFor(camera.zoom);
          if (next != _pinSize) setState(() => _pinSize = next);
        },
        onMapEvent: (e) {
          if (e is fm.MapEventMoveStart || e is fm.MapEventFlingAnimationStart) {
            v.onCameraMoveStarted?.call();
          } else if (e is fm.MapEventMoveEnd || e is fm.MapEventFlingAnimationEnd) {
            v.onCameraIdle?.call(e.camera.center);
          }
        },
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
                  color: leg.liveColor,
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
              alignment: Alignment.center,
              // Origen: punto con borde blanco (no el ícono de "ubicarme").
              child: Center(
                child: Container(
                  width: 18,
                  height: 18,
                  decoration: BoxDecoration(
                    color: GSColors.surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: GSColors.text, width: 5),
                  ),
                ),
              ),
            ),
            fm.Marker(
              point: v.route!.legs.last.points.last,
              width: 44,
              height: 44,
              alignment: Alignment.topCenter,
              // Destino: alfiler en tinta (el rojo es solo para la vía).
              child: Icon(Icons.location_on_rounded, color: GSColors.text, size: 44),
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
              child: Icon(Icons.location_on_rounded, color: GSColors.text, size: 44),
            ),
          if (v.vehicle != null)
            fm.Marker(
              point: v.vehicle!,
              width: vehiclePinSize + 8,
              height: vehiclePinSize + 8,
              child: Semantics(
                label: 'Tu conductor',
                child: Center(child: GSVehiclePin(service: v.vehicleService)),
              ),
            ),
          for (final a in v.alerts)
            fm.Marker(
              point: a.at,
              width: 48,
              height: 48,
              child: _AlertPinWidget(
                alert: a,
                size: _pinSize,
                onTap: v.onAlertTap == null ? null : () => v.onAlertTap!(a),
              ),
            ),
        ]),
      ],
    );
  }
}

/// Centro inicial cuando aún no hay GPS.
const defaultMapCenter = GSRegion.riohacha;


/// Pin de alerta en el mapa de respaldo: crece y se encoge con el zoom en
/// 200 ms (ease-out), como Waze; con "quitar animaciones" cambia sin más.
class _AlertPinWidget extends StatelessWidget {
  const _AlertPinWidget({required this.alert, required this.size, this.onTap});
  final MapAlert alert;
  final AlertPinSize size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final d = switch (size) {
      AlertPinSize.dot => 14.0,
      AlertPinSize.small => 28.0,
      AlertPinSize.full => 40.0,
    };
    final reduce = MediaQuery.of(context).disableAnimations;
    return Semantics(
      button: onTap != null,
      label: '${alert.kind.label}, ${alertAge(alert.happenedAt)}',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: Center(
          child: AnimatedSwitcher(
            duration: reduce ? Duration.zero : GSDuration.fast,
            switchInCurve: GSCurve.enter,
            transitionBuilder: (child, anim) => ScaleTransition(
              scale: Tween(begin: 0.6, end: 1.0).animate(anim),
              child: FadeTransition(opacity: anim, child: child),
            ),
            child: size == AlertPinSize.dot
                ? Container(
                    key: const ValueKey('dot'),
                    width: d,
                    height: d,
                    decoration: BoxDecoration(
                      color: alertColors(alert.kind).$1,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                  )
                : GSAlertBadge(key: ValueKey(size), kind: alert.kind, size: d),
          ),
        ),
      ),
    );
  }
}
