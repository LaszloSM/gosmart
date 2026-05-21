// lib/services/eco_service.dart
class EcoService {
  static const Map<String, double> _emissionGPerKm = {
    'driving': 170,
    'taxi':    150,
    'bus':     80,
    'metro':   30,
    'cycling': 0,
    'walking': 0,
  };

  /// CO₂ ahorrado en gramos versus ir en auto particular.
  static double co2SavedGrams({
    required String profile,
    required double distanceKm,
  }) {
    final emission = _emissionGPerKm[profile] ?? 170;
    return (_emissionGPerKm['driving']! - emission) * distanceKm;
  }

  /// Eco-puntos a otorgar por un viaje (mínimo 5 si hay ahorro, 0 si no).
  static int ecoPointsForTrip({
    required String profile,
    required double distanceKm,
  }) {
    final saved = co2SavedGrams(profile: profile, distanceKm: distanceKm);
    if (saved <= 0) return 0;
    return (saved / 10).round().clamp(5, 500);
  }

  /// Convierte gramos de CO₂ ahorrado a texto legible.
  static String formatCo2Saved(double grams) {
    if (grams < 1000) return '${grams.toStringAsFixed(0)} g';
    return '${(grams / 1000).toStringAsFixed(2)} kg';
  }

  /// Equivalencia en árboles (aprox. 21 kg CO₂/árbol/año).
  static double treesEquivalent(double grams) => grams / 21000;
}
