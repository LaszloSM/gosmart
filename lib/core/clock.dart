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
String arrivalClock(int minutes, {DateTime? now}) =>
    formatClock((now ?? DateTime.now()).add(Duration(minutes: minutes)));
