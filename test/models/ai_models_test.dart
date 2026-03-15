// test/models/ai_models_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:gosmart/models/ai_models.dart';

void main() {
  group('ConversationTurn', () {
    test('toJson serializes correctly', () {
      const turn = ConversationTurn(role: 'user', content: 'Hola');
      expect(turn.toJson(), {'role': 'user', 'content': 'Hola'});
    });

    test('fromJson deserializes correctly', () {
      final turn = ConversationTurn.fromJson(
        {'role': 'assistant', 'content': 'Respuesta'},
      );
      expect(turn.role, 'assistant');
      expect(turn.content, 'Respuesta');
    });
  });

  group('Leg.fromJson', () {
    test('parses mode, duration, cost', () {
      final leg = Leg.fromJson(
        {'mode': 'bus', 'line': 'Bus Expreso', 'duration_min': 35, 'cost_cop': 2900},
      );
      expect(leg.mode, 'bus');
      expect(leg.line, 'Bus Expreso');
      expect(leg.durationMin, 35);
      expect(leg.costCop, 2900);
    });

    test('line is null when absent', () {
      final leg = Leg.fromJson(
        {'mode': 'walk', 'duration_min': 10, 'cost_cop': 0},
      );
      expect(leg.line, isNull);
    });
  });

  group('RouteOption.fromJson', () {
    test('parses full route with multiple legs', () {
      final json = {
        'id': 'route_fastest',
        'type': 'fastest',
        'total_duration_min': 35,
        'total_cost_cop': 2900,
        'total_co2_kg': 0.4,
        'legs': [
          {'mode': 'bus', 'line': 'Bus Expreso', 'duration_min': 35, 'cost_cop': 2900},
        ],
      };
      final route = RouteOption.fromJson(json);
      expect(route.id, 'route_fastest');
      expect(route.type, 'fastest');
      expect(route.totalDurationMin, 35);
      expect(route.totalCostCop, 2900);
      expect(route.totalCo2Kg, closeTo(0.4, 0.001));
      expect(route.legs.length, 1);
      expect(route.legs.first.line, 'Bus Expreso');
    });

    test('parses co2 as double when integer in JSON', () {
      final json = {
        'id': 'route_eco',
        'type': 'eco',
        'total_duration_min': 45,
        'total_cost_cop': 0,
        'total_co2_kg': 0,  // integer in JSON
        'legs': [
          {'mode': 'bike', 'duration_min': 45, 'cost_cop': 0},
        ],
      };
      final route = RouteOption.fromJson(json);
      expect(route.totalCo2Kg, isA<double>());
      expect(route.totalCo2Kg, 0.0);
    });
  });
}
