// lib/models/driver_model.dart
// Registro del conductor (tablas `drivers`, `vehicles`, `driver_documents`).

enum DriverStatus { pending, approved, rejected, suspended }

DriverStatus _status(String? s) => switch (s) {
      'approved' => DriverStatus.approved,
      'rejected' => DriverStatus.rejected,
      'suspended' => DriverStatus.suspended,
      _ => DriverStatus.pending,
    };

/// Servicios que puede prestar un conductor, con su etiqueta en pantalla.
const driverServices = {
  'mototaxi': 'Mototaxi',
  'taxi': 'Taxi',
  'colectivo': 'Colectivo',
  'intermunicipal': 'Intermunicipal',
};

const driverZones = {
  'riohacha': 'Riohacha',
  'maicao': 'Maicao',
  'corredor': 'Troncal (Riohacha–Maicao)',
};

const payoutKinds = {
  'nequi': 'Nequi',
  'breb': 'Llave Bre-B',
  'daviplata': 'Daviplata',
};

/// Tipo de vehículo que corresponde a cada servicio.
String vehicleKindFor(String service) => switch (service) {
      'mototaxi' => 'moto',
      'colectivo' => 'camioneta',
      'intermunicipal' => 'buseta',
      _ => 'carro',
    };

/// Documentos que se piden; la tecnomecánica no aplica a vehículos nuevos.
const driverDocuments = {
  'cedula': 'Cédula (frente)',
  'licencia': 'Licencia de conducción',
  'soat': 'SOAT vigente',
  'tarjeta_propiedad': 'Tarjeta de propiedad',
  'tecnomecanica': 'Revisión técnico-mecánica',
  'foto': 'Tu foto (se ve el rostro)',
};
const requiredDriverDocuments = {
  'cedula',
  'licencia',
  'soat',
  'tarjeta_propiedad',
  'foto',
};

/// Placa en mayúsculas y sin espacios; null si no tiene forma de placa
/// colombiana (carro ABC123, moto ABC12D).
String? normalizePlate(String input) {
  final p = input.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  return RegExp(r'^[A-Z]{3}[0-9]{2}[0-9A-Z]$').hasMatch(p) ? p : null;
}

class DriverVehicle {
  const DriverVehicle({
    required this.plate,
    required this.kind,
    this.brand,
    this.color,
    this.seats = 1,
  });
  final String plate;
  final String kind;
  final String? brand;
  final String? color;
  final int seats;

  factory DriverVehicle.fromJson(Map<String, dynamic> j) => DriverVehicle(
        plate: j['plate'] as String,
        kind: j['kind'] as String,
        brand: j['brand'] as String?,
        color: j['color'] as String?,
        seats: (j['seats'] as num?)?.toInt() ?? 1,
      );
}

class DriverProfile {
  const DriverProfile({
    required this.userId,
    required this.fullName,
    required this.cedula,
    required this.phone,
    required this.service,
    required this.zone,
    required this.status,
    this.licenseNumber,
    this.payoutKind,
    this.payoutKey,
    this.reviewNote,
    this.available = false,
    this.vehicle,
    this.documents = const {},
  });

  final String userId;
  final String fullName;
  final String cedula;
  final String phone;
  final String service;
  final String zone;
  final DriverStatus status;
  final String? licenseNumber;
  final String? payoutKind;
  final String? payoutKey;
  final String? reviewNote;
  final bool available;
  final DriverVehicle? vehicle;

  /// Tipos de documento ya subidos.
  final Set<String> documents;

  Set<String> get missingDocuments =>
      requiredDriverDocuments.difference(documents);

  /// Listo para que un admin lo revise.
  bool get isComplete => vehicle != null && missingDocuments.isEmpty;

  factory DriverProfile.fromJson(Map<String, dynamic> j) {
    final vehicles = (j['vehicles'] as List?) ?? const [];
    final docs = (j['driver_documents'] as List?) ?? const [];
    return DriverProfile(
      userId: j['user_id'] as String,
      fullName: j['full_name'] as String,
      cedula: j['cedula'] as String,
      phone: j['phone'] as String,
      service: j['service'] as String,
      zone: j['zone'] as String,
      status: _status(j['status'] as String?),
      licenseNumber: j['license_number'] as String?,
      payoutKind: j['payout_kind'] as String?,
      payoutKey: j['payout_key'] as String?,
      reviewNote: j['review_note'] as String?,
      available: j['available'] as bool? ?? false,
      vehicle: vehicles.isEmpty
          ? null
          : DriverVehicle.fromJson(vehicles.first as Map<String, dynamic>),
      documents: {for (final d in docs) (d as Map)['kind'] as String},
    );
  }
}

/// Resumen de ganancias del conductor (driver_earnings, 023): hoy y 7 días.
class DriverEarnings {
  const DriverEarnings({
    this.todayTotal = 0,
    this.todayTrips = 0,
    this.todayCash = 0,
    this.weekTotal = 0,
    this.weekTrips = 0,
    this.weekCash = 0,
    this.rating,
    this.ratings = 0,
  });

  final int todayTotal;
  final int todayTrips;
  final int todayCash;
  final int weekTotal;
  final int weekTrips;
  final int weekCash;

  /// Promedio de estrellas; null con menos de 3 calificaciones.
  final double? rating;
  final int ratings;

  int get todayApp => todayTotal - todayCash;
  int get weekApp => weekTotal - weekCash;

  factory DriverEarnings.fromJson(Map<String, dynamic> j) {
    int i(String k) => (j[k] as num?)?.toInt() ?? 0;
    return DriverEarnings(
      todayTotal: i('today_total'),
      todayTrips: i('today_trips'),
      todayCash: i('today_cash'),
      weekTotal: i('week_total'),
      weekTrips: i('week_trips'),
      weekCash: i('week_cash'),
      rating: (j['rating'] as num?)?.toDouble(),
      ratings: i('ratings'),
    );
  }
}
