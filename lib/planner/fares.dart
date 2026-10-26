// lib/planner/fares.dart
// Precio de los tramos de mototaxi y taxi: UN valor, como el que se cobra.
// - Taxi: tarifa oficial de Riohacha (Instramd, Resolución 0922 de 2025):
//   $6.300 el primer kilómetro y $1.300 cada kilómetro adicional o fracción;
//   recargo nocturno y dominical. Se redondea a $100 como el taxímetro.
// - Mototaxi: servicio informal sin tarifa oficial. Se muestra la tarifa
//   SUGERIDA (estilo InDrive): base por los primeros km y un tanto por km,
//   redondeada a $500. El pasajero puede ofrecer otra al pedir.
// Los valores vienen de `fare_rules` (014/020); estos son el respaldo offline.
import 'graph.dart';

/// Precio de un tramo o de un viaje. [min] == [max] cuando hay un solo
/// precio; con varios tramos se suman. La app muestra [price].
class FareRange {
  const FareRange(this.min, this.max);
  const FareRange.exact(int v) : this(v, v);
  final int min;
  final int max;
  int get mid => (min + max) ~/ 2;

  /// El precio que se muestra: el valor único (o el alto si viene un rango
  /// de datos viejos, para no prometer menos de lo que se cobra).
  int get price => max;
  bool get isZero => max == 0;
  FareRange operator +(FareRange o) => FareRange(min + o.min, max + o.max);
  static const zero = FareRange(0, 0);
}

class FareRule {
  const FareRule({
    required this.base,
    required this.perKm,
    this.includedKm = 0,
    this.minimum = 0,
    this.nightFactor = 1.2,
    this.roundTo = 500,
  });

  /// Lo que cuesta arrancar, con [includedKm] incluidos.
  final int base;

  /// Por cada km adicional o fracción.
  final int perKm;
  final double includedKm;
  final int minimum;

  /// Recargo nocturno (21:00–5:00) y dominical.
  final double nightFactor;
  final int roundTo;
}

const defaultFareRules = <TransitMode, FareRule>{
  TransitMode.mototaxi:
      FareRule(base: 3000, perKm: 500, includedKm: 2, minimum: 3000, roundTo: 500),
  TransitMode.taxi: FareRule(
      base: 6300, perKm: 1300, includedKm: 1, minimum: 6300, nightFactor: 1.15, roundTo: 100),
};

bool isNight(DateTime t) => t.hour >= 21 || t.hour < 5;
bool _surcharge(DateTime t) => isNight(t) || t.weekday == DateTime.sunday;

/// Precio único del tramo según la regla del modo; cero si el modo no tiene regla.
FareRange estimateFare(
  TransitMode mode,
  double km, {
  required DateTime at,
  Map<TransitMode, FareRule> rules = defaultFareRules,
}) {
  final r = rules[mode];
  if (r == null) return FareRange.zero;
  final extraKm = (km - r.includedKm).clamp(0, double.infinity);
  var v = (r.base + r.perKm * extraKm.ceil()).toDouble();
  if (v < r.minimum) v = r.minimum.toDouble();
  if (_surcharge(at)) v *= r.nightFactor;
  final step = r.roundTo <= 0 ? 100 : r.roundTo;
  final price = ((v / step).ceil() * step).toInt();
  return FareRange.exact(price);
}
