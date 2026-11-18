// lib/core/address.dart
// Direcciones colombianas escritas a mano: "cl 14 #10-20", "Cra 7 No. 12 - 30",
// "calle 24 # 7h-45". Se reconocen y se escriben bonito para que la dirección
// que ve el conductor sea la que escribió la persona. Dart puro, probado.

const _streetWords = {
  'calle': 'Calle', 'cl': 'Calle', 'cll': 'Calle', 'clle': 'Calle',
  'carrera': 'Carrera', 'cra': 'Carrera', 'cr': 'Carrera', 'kr': 'Carrera',
  'kra': 'Carrera', 'crr': 'Carrera',
  'diagonal': 'Diagonal', 'dg': 'Diagonal', 'diag': 'Diagonal',
  'transversal': 'Transversal', 'tv': 'Transversal', 'tr': 'Transversal',
  'trans': 'Transversal',
  'avenida': 'Avenida', 'av': 'Avenida', 'avda': 'Avenida',
};

final _address = RegExp(
  r'^\s*([a-záéíóú]+)\.?\s*(\d{1,3}\s*[a-z]?(?:\s*bis)?)\s*'
  r'(?:#|n[o°º]\.?|num\.?|numero|número)\s*'
  r'(\d{1,3}\s*[a-z]?)\s*(?:-\s*(\d{1,3}))?\s*(.*)$',
  caseSensitive: false,
);

/// true si lo escrito parece una dirección con número de casa
/// ("Calle 14 # 10-20"), no solo una calle ("Calle 14").
bool looksLikeAddress(String q) {
  final m = _address.firstMatch(q);
  return m != null && _streetWords.containsKey(m.group(1)!.toLowerCase());
}

/// "cl 14 #10-20" → "Calle 14 # 10-20"; null si no es una dirección.
/// Lo que sigue al número (barrio, ciudad) se conserva tal cual.
String? normalizeAddress(String q) {
  final m = _address.firstMatch(q);
  if (m == null) return null;
  final street = _streetWords[m.group(1)!.toLowerCase()];
  if (street == null) return null;
  String up(String s) => s.replaceAll(RegExp(r'\s+'), '').toUpperCase();
  final plate = m.group(4) == null ? up(m.group(3)!) : '${up(m.group(3)!)}-${m.group(4)}';
  final rest = m.group(5)!.trim();
  return '$street ${up(m.group(2)!).replaceAll('BIS', ' Bis')} # $plate'
      '${rest.isEmpty ? '' : ' $rest'}';
}

/// Calle que cruza según la nomenclatura colombiana: en "Calle 24 # 14-45"
/// el 14 es la Carrera 14 (la casa está a 45 m de esa esquina).
const _crossing = {
  'Calle': 'Carrera',
  'Carrera': 'Calle',
  'Diagonal': 'Transversal',
  'Transversal': 'Diagonal',
  'Avenida': 'Carrera',
};

/// La esquina de una dirección, para la Geocoding API: "Calle 24 # 14-45"
/// → "Calle 24 & Carrera 14". null si no es una dirección.
String? crossingQuery(String q) {
  final m = _address.firstMatch(q);
  if (m == null) return null;
  final street = _streetWords[m.group(1)!.toLowerCase()];
  final cross = street == null ? null : _crossing[street];
  if (cross == null) return null;
  String up(String s) => s.replaceAll(RegExp(r'\s+'), '').toUpperCase();
  return '$street ${up(m.group(2)!)} & $cross ${up(m.group(3)!)}';
}
