// lib/features/trip/widgets/trip_map.dart
// El mapa del viaje: la ruta (la del planificador si sigue en memoria; si
// no, los tramos en línea recta), tu punto y el conductor. El conductor se
// desliza entre una consulta y la siguiente (cada ~4 s) en vez de saltar,
// como el carrito de Uber; se repinta a ~10 cuadros por segundo para no
// mover el mapa entero en cada cuadro.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/region.dart';
import '../../../models/dispatch_models.dart';
import '../../../models/route_result.dart';
import '../../../providers/active_route_provider.dart';
import '../../../providers/dispatch_provider.dart';
import '../../../services/location_service.dart';
import '../../../theme/design_tokens.dart';
import '../../home/widgets/map_view.dart';

/// La ruta del viaje en el mapa: los tramos como líneas rectas de su color.
RouteResult routeFromLegs(ChainedTrip t) {
  final legs = [
    for (final l in t.legs)
      if (l.from != null && l.to != null)
        RouteLeg(
          mode: l.mode == 'walk' ? 'walk' : (l.mode == 'mototaxi' || l.mode == 'taxi' ? l.mode : 'bus'),
          points: [l.from!, l.to!],
          color: GSColors.brand,
          durationMin: l.minutes ?? 0,
          distanceKm: const Distance().as(LengthUnit.Kilometer, l.from!, l.to!),
          fromLabel: l.fromLabel,
          toLabel: l.toLabel,
        ),
  ];
  return RouteResult(
    legs: legs,
    distanceKm: legs.fold(0.0, (a, l) => a + l.distanceKm),
    durationMin: legs.fold(0, (a, l) => a + l.durationMin),
    profile: 'driving',
    destinationLabel: t.destLabel,
  );
}

class TripMap extends ConsumerStatefulWidget {
  const TripMap({super.key, required this.trip, this.padding = EdgeInsets.zero});
  final ChainedTrip trip;
  final EdgeInsets padding;

  @override
  ConsumerState<TripMap> createState() => _TripMapState();
}

class _TripMapState extends ConsumerState<TripMap> with SingleTickerProviderStateMixin {
  MapViewController? _map;
  late final Ticker _ticker = createTicker(_onTick);

  LatLng? _shown; // lo que se pinta
  LatLng? _from; // desde dónde se desliza
  LatLng? _to; // hacia dónde
  Duration _start = Duration.zero;
  Duration _lastPaint = Duration.zero;
  static const _glide = Duration(milliseconds: 3600);

  Timer? _fitLater;

  @override
  void dispose() {
    _fitLater?.cancel();
    _ticker.dispose();
    super.dispose();
  }

  void _glideTo(LatLng next) {
    final reduce = MediaQuery.of(context).disableAnimations;
    if (_shown == null || reduce) {
      setState(() => _shown = next);
      return;
    }
    // Saltos grandes (otro conductor, GPS raro): sin deslizar.
    if (const Distance().as(LengthUnit.Meter, _shown!, next) > 1500) {
      setState(() => _shown = next);
      return;
    }
    _from = _shown;
    _to = next;
    _start = Duration.zero;
    _lastPaint = Duration.zero;
    if (_ticker.isActive) _ticker.stop();
    _ticker.start();
  }

  void _onTick(Duration elapsed) {
    if (_start == Duration.zero) _start = elapsed;
    final t = ((elapsed - _start).inMilliseconds / _glide.inMilliseconds).clamp(0.0, 1.0);
    // Repintar cada ~100 ms basta para que se vea continuo sobre un mapa.
    if (t < 1 && elapsed - _lastPaint < const Duration(milliseconds: 100)) return;
    _lastPaint = elapsed;
    final a = _from!, b = _to!;
    setState(() => _shown = LatLng(
          a.latitude + (b.latitude - a.latitude) * t,
          a.longitude + (b.longitude - a.longitude) * t,
        ));
    if (t >= 1) _ticker.stop();
  }

  List<LatLng> _framePoints(RouteResult r) => [for (final l in r.legs) ...l.points];

  @override
  Widget build(BuildContext context) {
    final planned = ref.watch(activeRouteProvider);
    final route = planned != null && planned.legs.isNotEmpty ? planned : routeFromLegs(widget.trip);
    final driver = ref.watch(tripDriverProvider);

    ref.listen<AssignedDriver?>(tripDriverProvider, (prev, next) {
      final at = next?.at;
      if (at == null) {
        if (_shown != null) setState(() => _shown = null);
        return;
      }
      _glideTo(at);
      // Con el conductor en camino, que se vean él y el punto de recogida.
      if (prev?.at == null) {
        final pickup = widget.trip.currentLeg?.from;
        _map?.fit([at, if (pickup != null) pickup]);
      }
    });

    final start = route.legs.isNotEmpty && route.legs.first.points.isNotEmpty
        ? route.legs.first.points.first
        : GSRegion.riohacha;
    return MapView(
      initialCenter: start,
      onCreated: (c) {
        _map = c;
        // Tras el primer cuadro (con el relleno de la hoja aplicado).
        _fitLater = Timer(const Duration(milliseconds: 300), () {
          if (mounted) c.fit(_framePoints(route));
        });
      },
      onLongPress: (_) {},
      onLongPressEnabled: false,
      route: route,
      user: locationService.last,
      padding: widget.padding,
      vehicle: _shown,
      vehicleService: driver?.service ?? 'mototaxi',
    );
  }
}
