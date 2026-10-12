// test/models/driver_model_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:gosmart/models/driver_model.dart';

void main() {
  test('placa colombiana: carro y moto, con espacios o guion', () {
    expect(normalizePlate('abc 123'), 'ABC123');
    expect(normalizePlate('abc-12d'), 'ABC12D');
    expect(normalizePlate('AB1234'), isNull);
    expect(normalizePlate('XYZ'), isNull);
  });

  test('servicio → tipo de vehículo', () {
    expect(vehicleKindFor('mototaxi'), 'moto');
    expect(vehicleKindFor('taxi'), 'carro');
    expect(vehicleKindFor('colectivo'), 'camioneta');
  });

  test('registro completo solo con vehículo y documentos obligatorios', () {
    final base = {
      'user_id': 'u',
      'full_name': 'Ana Pérez',
      'cedula': '1118555444',
      'phone': '+573001234567',
      'service': 'mototaxi',
      'zone': 'riohacha',
      'status': 'pending',
    };
    final sinNada = DriverProfile.fromJson(base);
    expect(sinNada.isComplete, isFalse);
    expect(sinNada.missingDocuments, requiredDriverDocuments);

    final completo = DriverProfile.fromJson({
      ...base,
      'vehicles': [
        {'plate': 'ABC12D', 'kind': 'moto', 'seats': 1}
      ],
      'driver_documents': [
        for (final k in requiredDriverDocuments) {'kind': k}
      ],
    });
    expect(completo.isComplete, isTrue);
    expect(completo.status, DriverStatus.pending);
  });

  test('estado desconocido se toma como pendiente, nunca como aprobado', () {
    final d = DriverProfile.fromJson({
      'user_id': 'u', 'full_name': 'X', 'cedula': '12345', 'phone': '+573001234567',
      'service': 'taxi', 'zone': 'maicao', 'status': 'raro',
    });
    expect(d.status, DriverStatus.pending);
  });
}
