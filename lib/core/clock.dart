// lib/core/clock.dart
// Horas como las dice la gente en la costa: "3:40 p. m." (12 h). Una sola
// función para toda la app: llegada estimada, salidas del colectivo, avisos.

/// "3:40 p. m." para [t] (hora local del teléfono).
String formatClock(DateTime t) {
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  // Espacios sin corte: "p. m." nunca se parte en dos líneas.
  return '$h:${t.minute.toString().padLeft(2, '0')}\u00A0'
      '${t.hour < 12 ? 'a.\u00A0m.' : 'p.\u00A0m.'}';
}

/// Hora de llegada si sales ahora y el viaje dura [minutes].
/// OJO: no se muestra al pasajero (con trancones y esperas no es exacta);
/// en su lugar va [durationRange]. Se deja para pruebas y usos internos.
String arrivalClock(int minutes, {DateTime? now}) =>
    formatClock((now ?? DateTime.now()).add(Duration(minutes: minutes)));

/// Duración aproximada en rango, "9–12 min": nunca una hora exacta de
/// llegada, porque puede haber esperas y trancones.
String durationRange(int minutes) {
  final low = minutes < 1 ? 1 : minutes;
  final spread = (low * 0.3).round();
  final high = low + (spread < 3 ? 3 : spread);
  if (low >= 60) {
    String h(int m) => m % 60 == 0 ? '${m ~/ 60} h' : '${m ~/ 60} h ${m % 60} min';
    return '${h(low)} – ${h(high)}';
  }
  return '$low–$high\u00A0min';
}
