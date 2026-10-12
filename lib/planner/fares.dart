// lib/planner/fares.dart
// Tarifa justa: un RANGO de referencia por distancia y hora para los tramos
// informales (mototaxi, taxi). Los valores son provisionales hasta el
// levantamiento de campo (Fase 1) y la app los muestra como "referencia".
import 'graph.dart';

class FareRange {
  const FareRange(this.min, this.max);
  final int min;
  final int max;
  int get mid => (min + max) ~/ 2;
  FareRange operator +(FareRange o) => FareRange(min + o.min, max + o.max);
  static const zero = FareRange(0, 0);
}

class FareRule {
  const FareRule({
    required this.base,
    required this.perKm,
    this.minimum = 0,
    this.nightFactor = 1.2,
    this.spread = 0.25,
  });

  /// Arranque en COP.
  final int base;
  final int perKm;
  final int minimum;

  /// Recargo nocturno (21:00–5:00).
  final double nightFactor;

  /// Ancho del rango: ±25 % alrededor del valor central.
  final double spread;
}

/// Reglas por modo. PROVISIONALES: se reemplazan por `fare_rules` (014).
const defaultFareRules = <TransitMode, FareRule>{
  TransitMode.mototaxi: FareRule(base: 2000, perKm: 700, minimum: 3000),
  TransitMode.taxi: FareRule(base: 4000, perKm: 1300, minimum: 7000),
};

bool isNight(DateTime t) => t.hour >= 21 || t.hour < 5;

/// Rango redondeado a $500, como se cobra en la calle.
FareRange estimateFare(
  TransitMode mode,
  double km, {
  required DateTime at,
  Map<TransitMode, FareRule> rules = defaultFareRules,
}) {
  final r = rules[mode];
  if (r == null) return FareRange.zero;
  var mid = r.base + r.perKm * km;
  if (mid < r.minimum) mid = r.minimum.toDouble();
  if (isNight(at)) mid *= r.nightFactor;
  int round500(double v) => ((v / 500).round() * 500).clamp(500, 1 << 31);
  return FareRange(round500(mid * (1 - r.spread)), round500(mid * (1 + r.spread)));
}
