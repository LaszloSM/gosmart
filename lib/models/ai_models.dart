// lib/models/ai_models.dart

import 'route_result.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Traffic metadata embedded in RouteOption
// ─────────────────────────────────────────────────────────────────────────────

/// Lightweight traffic snapshot embedded in a [RouteOption].
/// No dependency on traffic_service.dart — pure data class.
class TrafficRouteMetadata {
  /// Human-readable Spanish label for the route card chip.
  /// e.g. "Tráfico alto · zona urbana (hora pico tarde)"
  final String label;

  /// Multiplier that was applied to produce [RouteOption.totalDurationMin].
  final double durationMultiplier;

  /// Hex color string for the chip (e.g. '#E53935', '#FB8C00', '#43A047').
  final String colorHex;

  const TrafficRouteMetadata({
    required this.label,
    required this.durationMultiplier,
    required this.colorHex,
  });
}

// ─────────────────────────────────────────────────────────────────────────────

class AiMessage {
  final String role; // 'user' | 'assistant'
  final String content;
  final DateTime timestamp;
  final List<RouteOption>? routes;
  final int? latencyMs;
  final String? source; // 'groq' | 'heuristic' | 'cache'
  /// Real Mapbox polylines for "Ver en mapa".
  /// Outer null = no real route data (heuristic fallback used).
  /// Inner null = that specific profile (walking/driving/cycling) failed.
  /// Index 0 = walking, 1 = driving, 2 = cycling.
  final List<RouteResult?>? routeResults;

  const AiMessage({
    required this.role,
    required this.content,
    required this.timestamp,
    this.routes,
    this.latencyMs,
    this.source,
    this.routeResults,
  });
}

class ConversationTurn {
  final String role; // 'user' | 'assistant'
  final String content;

  const ConversationTurn({required this.role, required this.content});

  Map<String, dynamic> toJson() => {'role': role, 'content': content};

  factory ConversationTurn.fromJson(Map<String, dynamic> json) =>
      ConversationTurn(
        role: json['role'] as String,
        content: json['content'] as String,
      );
}

class Leg {
  final String mode; // 'bus' | 'metro' | 'cable' | 'bike' | 'walk' | 'taxi'
  final String? line;
  final int durationMin;
  final int costCop;

  const Leg({
    required this.mode,
    this.line,
    required this.durationMin,
    required this.costCop,
  });

  factory Leg.fromJson(Map<String, dynamic> json) => Leg(
        mode: json['mode'] as String,
        line: json['line'] as String?,
        durationMin: json['duration_min'] as int,
        costCop: json['cost_cop'] as int,
      );
}

class RouteOption {
  final String id;
  final String type; // 'fastest' | 'cheapest' | 'eco'
  /// Already traffic-adjusted when [trafficMetadata] != null.
  final int totalDurationMin;
  /// Already traffic-adjusted (fare multiplier applied for variable-fare modes).
  final int totalCostCop;
  final double totalCo2Kg;
  final List<Leg> legs;

  /// Present when this route was built with traffic data.
  /// Null for routes generated without traffic context.
  final TrafficRouteMetadata? trafficMetadata;

  const RouteOption({
    required this.id,
    required this.type,
    required this.totalDurationMin,
    required this.totalCostCop,
    required this.totalCo2Kg,
    required this.legs,
    this.trafficMetadata,
  });

  factory RouteOption.fromJson(Map<String, dynamic> json) => RouteOption(
        id: json['id'] as String,
        type: json['type'] as String,
        totalDurationMin: json['total_duration_min'] as int,
        totalCostCop: json['total_cost_cop'] as int,
        totalCo2Kg: (json['total_co2_kg'] as num).toDouble(),
        legs: (json['legs'] as List)
            .map((l) => Leg.fromJson(l as Map<String, dynamic>))
            .toList(),
        // trafficMetadata is never serialized from JSON — built at call time
        // by AiService using the live TrafficService snapshot.
      );
}
