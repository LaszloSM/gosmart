// lib/services/driver_service.dart
// Registro y estado del conductor. La aprobación la hace un admin en el
// servidor (`admin_review_driver`); desde aquí nunca se cambia el estado.
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_client.dart';
import '../models/driver_model.dart';

class DriverService {
  SupabaseClient get _db => GoSmartSupabase.client;

  Future<DriverProfile?> fetchMine(String userId) async {
    final row = await _db
        .from('drivers')
        .select('*, vehicles(*), driver_documents(kind)')
        .eq('user_id', userId)
        .maybeSingle();
    return row == null ? null : DriverProfile.fromJson(row);
  }

  /// Crea o actualiza el registro y su vehículo.
  Future<void> saveRegistration({
    required String userId,
    required String fullName,
    required String cedula,
    required String phone,
    required String service,
    required String zone,
    required String licenseNumber,
    required String plate,
    String? brand,
    String? color,
    int seats = 1,
    String? payoutKind,
    String? payoutKey,
  }) async {
    await _db.from('drivers').upsert({
      'user_id': userId,
      'full_name': fullName,
      'cedula': cedula,
      'phone': phone,
      'service': service,
      'zone': zone,
      'license_number': licenseNumber,
      'payout_kind': payoutKind,
      'payout_key': (payoutKey ?? '').isEmpty ? null : payoutKey,
    });
    // Un vehículo por conductor en el MVP: se reemplaza el anterior.
    await _db.from('vehicles').delete().eq('driver_id', userId);
    await _db.from('vehicles').insert({
      'driver_id': userId,
      'kind': vehicleKindFor(service),
      'plate': plate,
      if ((brand ?? '').isNotEmpty) 'brand': brand,
      if ((color ?? '').isNotEmpty) 'color': color,
      'seats': seats,
    });
  }

  /// Sube la foto del documento al bucket privado y lo registra.
  Future<void> uploadDocument(String userId, String kind, XFile file) async {
    final path = '$userId/$kind.jpg';
    await _db.storage.from('driver-docs').uploadBinary(
          path,
          await file.readAsBytes(),
          fileOptions: const FileOptions(contentType: 'image/jpeg', upsert: true),
        );
    await _db.from('driver_documents').upsert(
      {'driver_id': userId, 'kind': kind, 'storage_path': path},
      onConflict: 'driver_id,kind',
    );
  }

  /// Ganancias de hoy y de los últimos 7 días (023).
  Future<DriverEarnings> earnings() async {
    final rows = await _db.rpc('driver_earnings') as List<dynamic>;
    return rows.isEmpty
        ? const DriverEarnings()
        : DriverEarnings.fromJson(Map<String, dynamic>.from(rows.first as Map));
  }

  Future<void> setAvailable(String userId, bool available) async {
    await _db
        .from('drivers')
        .update({'available': available}).eq('user_id', userId);
  }
}

final driverService = DriverService();
