// lib/models/traffic_model.dart
// GoSmart Traffic — data classes for traffic-aware route adjustments.
//
// Pure Dart with no Flutter dependencies except [Color], which is needed
// for the traffic condition indicator in the UI.

import 'package:flutter/painting.dart';

/// Zone classification for traffic density estimation.
///
/// Colombian cities have distinct traffic patterns by zone:
/// - [urban]: major corridors (Av. Boyacá, Autopista Norte in Bogotá, etc.)
/// - [center]: downtown / historical center (La Candelaria, El Poblado core)
/// - [residential]: barrios with lower through-traffic
enum ZoneType { urban, center, residential }

/// Time-of-day traffic period, calibrated for Colombian cities.
///
/// Peak hours based on Secretaría de Movilidad de Bogotá data:
/// - Morning rush: 6:00–9:00 (school + office commute)
/// - Daytime: 9:00–17:00 (moderate, steady flow)
/// - Evening rush: 17:00–20:00 (heaviest, return commute + commerce)
/// - Night: 20:00–6:00 (minimal traffic)
enum TrafficPeriod { morningRush, day, eveningRush, night }

/// A traffic factor encapsulates duration and fare multipliers for a given
/// time + zone combination.
///
/// Multipliers are >= 1.0 (traffic never makes trips faster or cheaper than
/// the base estimate, which represents free-flow / off-peak conditions).
class TrafficFactor {
  /// How much longer a trip takes compared to base (free-flow) duration.
  /// 1.0 = no delay, 1.5 = 50% longer, etc.
  final double durationMultiplier;

  /// How much more a trip costs compared to base fare.
  /// Fixed-fare modes (metro, TransMilenio) are unaffected (multiplier = 1.0).
  /// Variable-fare modes (taxi, InDriver) increase with congestion.
  final double fareMultiplier;

  /// The detected time period.
  final TrafficPeriod period;

  /// The zone used for this calculation.
  final ZoneType zone;

  const TrafficFactor({
    required this.durationMultiplier,
    required this.fareMultiplier,
    required this.period,
    required this.zone,
  });

  /// Free-flow / off-peak baseline — no adjustments.
  static const baseline = TrafficFactor(
    durationMultiplier: 1.0,
    fareMultiplier: 1.0,
    period: TrafficPeriod.night,
    zone: ZoneType.residential,
  );
}

/// Human-readable traffic condition with a color indicator for the UI.
class TrafficCondition {
  /// The underlying numeric factor.
  final TrafficFactor factor;

  /// Short label shown in the UI (e.g. "Tráfico alto", "Fluido").
  final String label;

  /// Color for the traffic badge/chip.
  final Color indicatorColor;

  const TrafficCondition({
    required this.factor,
    required this.label,
    required this.indicatorColor,
  });
}
