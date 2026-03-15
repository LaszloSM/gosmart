// lib/models/ai_models.dart

class AiMessage {
  final String role; // 'user' | 'assistant'
  final String content;
  final DateTime timestamp;
  final List<RouteOption>? routes;
  final int? latencyMs;
  final String? source; // 'gemini' | 'heuristic' | 'cache'

  const AiMessage({
    required this.role,
    required this.content,
    required this.timestamp,
    this.routes,
    this.latencyMs,
    this.source,
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
  final int totalDurationMin;
  final int totalCostCop;
  final double totalCo2Kg;
  final List<Leg> legs;

  const RouteOption({
    required this.id,
    required this.type,
    required this.totalDurationMin,
    required this.totalCostCop,
    required this.totalCo2Kg,
    required this.legs,
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
      );
}
