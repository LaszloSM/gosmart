// lib/models/emergency_contact.dart
// Contacto de emergencia (tabla `emergency_contacts`, máximo 5 por usuario).
class EmergencyContact {
  const EmergencyContact({
    required this.id,
    required this.name,
    required this.phone,
    this.relation,
  });

  final String id;
  final String name;

  /// Siempre en formato +57XXXXXXXXXX (lo exige la base de datos).
  final String phone;
  final String? relation;

  factory EmergencyContact.fromJson(Map<String, dynamic> j) => EmergencyContact(
        id: j['id'] as String,
        name: j['name'] as String,
        phone: j['phone'] as String,
        relation: j['relation'] as String?,
      );

  /// "300 123 4567" para leerlo en pantalla.
  String get displayPhone {
    final d = phone.startsWith('+57') ? phone.substring(3) : phone;
    if (d.length != 10) return phone;
    return '${d.substring(0, 3)} ${d.substring(3, 6)} ${d.substring(6)}';
  }
}
