// lib/services/traffic_service.dart
// GoSmart Traffic Service — heuristic traffic estimation for Colombian cities.
//
// ┌──────────────────────────────────────────────────────────────────────────┐
// │ HOW TO SWAP IN A REAL-TIME TRAFFIC API                                  │
// │                                                                         │
// │ 1. Create a new class that implements ITrafficService, e.g.:            │
// │      class GoogleTrafficService implements ITrafficService { ... }       │
// │                                                                         │
// │ 2. Implement the 4 methods using the real API's congestion data.        │
// │    The contract guarantees callers only depend on TrafficFactor /        │
// │    TrafficCondition — your implementation details are invisible.         │
// │                                                                         │
// │ 3. Change the singleton at the bottom of this file:                     │
// │      final ITrafficService trafficService = GoogleTrafficService();      │
// │                                                                         │
// │ No other files need to change. The route planner, AI service, and any   │
// │ future consumers all call through the ITrafficService interface.         │
// └──────────────────────────────────────────────────────────────────────────┘

import 'package:flutter/painting.dart';

import '../models/traffic_model.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Interface contract
// ─────────────────────────────────────────────────────────────────────────────

/// Abstract traffic service that any implementation (heuristic, Google, HERE,
/// TomTom) must satisfy.
///
/// All methods are synchronous in the heuristic version. A real-time API
/// implementation would likely make these async — if that happens, change the
/// return types to Future<T> and update callers with `await`.
abstract class ITrafficService {
  /// Returns the numeric traffic factor for a given time and zone.
  ///
  /// [now] defaults to `DateTime.now()` if omitted — useful for testing.
  /// [zone] defaults to `ZoneType.urban` (most conservative estimate).
  TrafficFactor getTrafficFactor({DateTime? now, ZoneType zone});

  /// Adjusts a base duration (in minutes) by the traffic factor.
  /// Always rounds up — passengers prefer over-estimates to under-estimates.
  int adjustDuration(int baseDurationMin, TrafficFactor factor);

  /// Adjusts a base fare (in COP) by the traffic factor.
  /// Only meaningful for variable-fare modes (taxi, rideshare).
  /// Fixed-fare modes (bus, metro) should pass [TrafficFactor.baseline].
  int adjustFare(int baseCostCop, TrafficFactor factor);

  /// Returns a human-readable traffic condition with label and color.
  TrafficCondition getCurrentCondition({DateTime? now, ZoneType zone});
}

// ─────────────────────────────────────────────────────────────────────────────
// Heuristic implementation (MVP)
// ─────────────────────────────────────────────────────────────────────────────

/// Duration multiplier table — weekday values.
///
/// ┌──────────────────┬─────────┬─────────┬─────────────┐
/// │ Period           │ Urban   │ Center  │ Residential  │
/// ├──────────────────┼─────────┼─────────┼─────────────┤
/// │ Morning rush     │  1.50   │  1.35   │   1.15      │
/// │ Daytime          │  1.20   │  1.15   │   1.05      │
/// │ Evening rush     │  1.65   │  1.45   │   1.20      │
/// │ Night            │  1.00   │  1.00   │   1.00      │
/// └──────────────────┴─────────┴─────────┴─────────────┘
///
/// Rationale:
/// - Evening rush is worst (Bogotá avg speed drops to ~12 km/h on Autopista
///   Norte during 5-7 PM per Secretaría de Movilidad 2024 data).
/// - Morning rush is slightly lighter because school trips end by 8 AM.
/// - Urban corridors get highest multipliers; residential zones barely affected.
/// - Night is always 1.0 (free-flow baseline).
///
/// Weekend adjustment: all multipliers reduced 25% toward 1.0.
/// Formula: weekendMultiplier = 1.0 + (weekdayMultiplier - 1.0) * 0.75
///
/// Fare multiplier table (only affects variable-fare modes like taxi):
///
/// ┌──────────────────┬─────────┬─────────┬─────────────┐
/// │ Period           │ Urban   │ Center  │ Residential  │
/// ├──────────────────┼─────────┼─────────┼─────────────┤
/// │ Morning rush     │  1.20   │  1.15   │   1.05      │
/// │ Daytime          │  1.10   │  1.05   │   1.00      │
/// │ Evening rush     │  1.30   │  1.20   │   1.10      │
/// │ Night            │  1.00   │  1.00   │   1.00      │
/// └──────────────────┴─────────┴─────────┴─────────────┘
///
/// Fare multipliers are lower than duration multipliers because taxis charge
/// by distance AND time — congestion adds time-cost but not distance-cost.
class HeuristicTrafficService implements ITrafficService {
  // ── Multiplier lookup tables ─────────────────────────────────────────────

  static const _durationTable = {
    TrafficPeriod.morningRush: {
      ZoneType.urban: 1.50,
      ZoneType.center: 1.35,
      ZoneType.residential: 1.15,
    },
    TrafficPeriod.day: {
      ZoneType.urban: 1.20,
      ZoneType.center: 1.15,
      ZoneType.residential: 1.05,
    },
    TrafficPeriod.eveningRush: {
      ZoneType.urban: 1.65,
      ZoneType.center: 1.45,
      ZoneType.residential: 1.20,
    },
    TrafficPeriod.night: {
      ZoneType.urban: 1.00,
      ZoneType.center: 1.00,
      ZoneType.residential: 1.00,
    },
  };

  static const _fareTable = {
    TrafficPeriod.morningRush: {
      ZoneType.urban: 1.20,
      ZoneType.center: 1.15,
      ZoneType.residential: 1.05,
    },
    TrafficPeriod.day: {
      ZoneType.urban: 1.10,
      ZoneType.center: 1.05,
      ZoneType.residential: 1.00,
    },
    TrafficPeriod.eveningRush: {
      ZoneType.urban: 1.30,
      ZoneType.center: 1.20,
      ZoneType.residential: 1.10,
    },
    TrafficPeriod.night: {
      ZoneType.urban: 1.00,
      ZoneType.center: 1.00,
      ZoneType.residential: 1.00,
    },
  };

  // ── Helpers ──────────────────────────────────────────────────────────────

  static TrafficPeriod _periodFromHour(int hour) {
    if (hour >= 6 && hour < 9) return TrafficPeriod.morningRush;
    if (hour >= 9 && hour < 17) return TrafficPeriod.day;
    if (hour >= 17 && hour < 20) return TrafficPeriod.eveningRush;
    return TrafficPeriod.night;
  }

  static bool _isWeekend(DateTime dt) => dt.weekday >= 6;

  /// Reduces a weekday multiplier 25% toward 1.0 for weekends.
  static double _weekendAdjust(double weekdayMultiplier) =>
      1.0 + (weekdayMultiplier - 1.0) * 0.75;

  // ── ITrafficService implementation ───────────────────────────────────────

  @override
  TrafficFactor getTrafficFactor({
    DateTime? now,
    ZoneType zone = ZoneType.urban,
  }) {
    final dt = now ?? DateTime.now();
    final period = _periodFromHour(dt.hour);
    final weekend = _isWeekend(dt);

    var durationMul = _durationTable[period]![zone]!;
    var fareMul = _fareTable[period]![zone]!;

    if (weekend) {
      durationMul = _weekendAdjust(durationMul);
      fareMul = _weekendAdjust(fareMul);
    }

    return TrafficFactor(
      durationMultiplier: durationMul,
      fareMultiplier: fareMul,
      period: period,
      zone: zone,
    );
  }

  @override
  int adjustDuration(int baseDurationMin, TrafficFactor factor) =>
      (baseDurationMin * factor.durationMultiplier).ceil();

  @override
  int adjustFare(int baseCostCop, TrafficFactor factor) =>
      (baseCostCop * factor.fareMultiplier).ceil();

  @override
  TrafficCondition getCurrentCondition({
    DateTime? now,
    ZoneType zone = ZoneType.urban,
  }) {
    final factor = getTrafficFactor(now: now, zone: zone);
    final mul = factor.durationMultiplier;

    // Thresholds chosen so that the label matches driver intuition:
    // < 1.10 → "Fluido" (green)   — negligible delay
    // 1.10-1.30 → "Moderado" (yellow) — noticeable but manageable
    // 1.30-1.50 → "Alto" (orange) — significant delays
    // ≥ 1.50 → "Muy alto" (red)   — gridlock conditions
    final String label;
    final Color color;

    if (mul < 1.10) {
      label = 'Fluido';
      color = const Color(0xFF3CB371); // GSColors.eco
    } else if (mul < 1.30) {
      label = 'Moderado';
      color = const Color(0xFFFFA502); // GSColors.warning
    } else if (mul < 1.50) {
      label = 'Alto';
      color = const Color(0xFFFF6B35); // between warning and error
    } else {
      label = 'Muy alto';
      color = const Color(0xFFFF4757); // GSColors.error
    }

    return TrafficCondition(
      factor: factor,
      label: label,
      indicatorColor: color,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Singleton — change this line to swap implementations.
// ─────────────────────────────────────────────────────────────────────────────

/// Top-level singleton following the same pattern as [aiService],
/// [profileService], etc.
///
/// To switch to a real-time API, replace [HeuristicTrafficService] with your
/// new implementation class. All callers reference [trafficService] through
/// the [ITrafficService] interface, so no other files need to change.
final ITrafficService trafficService = HeuristicTrafficService();
