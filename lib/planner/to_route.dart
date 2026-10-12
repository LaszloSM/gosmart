// lib/planner/to_route.dart
// Del viaje planeado (puro) a la ruta que dibuja el mapa y muestra el detalle.
import 'package:flutter/material.dart';

import '../models/corridor_status.dart';
import '../models/route_result.dart';
import '../theme/design_tokens.dart';
import 'graph.dart';
import 'planner.dart';

Color legColor(TransitMode m) => switch (m) {
      TransitMode.walk => GSColors.walk,
      TransitMode.mototaxi || TransitMode.taxi => GSColors.taxi,
      _ => GSColors.bus,
    };

RouteResult routeFromTrip(PlannedTrip t, {CorridorStatus? corridor}) {
  String segName(String id) =>
      corridor?.segments.where((s) => s.id == id).firstOrNull?.name ?? id;
  String? segReason(String id) =>
      corridor?.segments.where((s) => s.id == id).firstOrNull?.reason;

  return RouteResult(
    legs: [
      for (final l in t.legs)
        RouteLeg(
          mode: l.mode == TransitMode.walk ? 'walk' : 'bus',
          // Línea recta entre puntos: el trazado calle a calle llega con la
          // API de rutas; el mapa lo dibuja como referencia.
          points: [l.from, l.to],
          color: legColor(l.mode),
          durationMin: l.minutes + l.waitMinutes,
          distanceKm: l.distanceKm,
          instruction: l.waitMinutes > 0
              ? '${l.instruction} (espera ~${l.waitMinutes} min)'
              : l.instruction,
          lineId: l.mode.label,
        ),
    ],
    distanceKm: t.distanceKm,
    durationMin: t.minutes,
    profile: t.mainMode == TransitMode.walk ? RouteProfile.walking : RouteProfile.driving,
    estimatedCostCop: t.fare.mid,
    fareMin: t.fare.min,
    fareMax: t.fare.max,
    category: 'public',
    notes: [
      if (t.usesDetour) 'Evita el cierre de la Troncal por el desvío Albania–Cuestecitas.',
      for (final s in t.warnings)
        'Precaución en ${segName(s)}${segReason(s) == null ? '' : ': ${segReason(s)}'}.',
    ],
  );
}
