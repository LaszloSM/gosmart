// lib/services/safety_service.dart
// Contactos de emergencia, registro de SOS y compartir viaje (migración 011).
// El aviso real sale del teléfono (WhatsApp/SMS/123); esto solo deja constancia.
import 'package:latlong2/latlong.dart';

import '../core/supabase_client.dart';
import '../models/emergency_contact.dart';

class TripShare {
  const TripShare({required this.token, required this.expiresAt});
  final String token;
  final DateTime expiresAt;

  bool get isActive => DateTime.now().isBefore(expiresAt);
}

class SafetyService {
  Future<List<EmergencyContact>> listContacts() async {
    final rows = await GoSmartSupabase.client
        .from('emergency_contacts')
        .select('id, name, phone, relation')
        .order('created_at');
    return (rows as List)
        .map((r) => EmergencyContact.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// [phone] ya normalizado a +57XXXXXXXXXX.
  Future<void> addContact({
    required String userId,
    required String name,
    required String phone,
    String? relation,
  }) async {
    await GoSmartSupabase.client.from('emergency_contacts').insert({
      'user_id': userId,
      'name': name,
      'phone': phone,
      if ((relation ?? '').isNotEmpty) 'relation': relation,
    });
  }

  Future<void> deleteContact(String id) async {
    await GoSmartSupabase.client.from('emergency_contacts').delete().eq('id', id);
  }

  /// Deja constancia del SOS. Mismo [idempotencyKey] = un solo registro,
  /// aunque se reintente sin señal. Devuelve false si no se pudo guardar.
  Future<bool> recordSos({
    required String userId,
    required String idempotencyKey,
    LatLng? at,
    List<String> channels = const [],
  }) async {
    try {
      await GoSmartSupabase.client.from('sos_events').upsert(
        {
          'user_id': userId,
          'idempotency_key': idempotencyKey,
          'lat': at?.latitude,
          'lng': at?.longitude,
          'channels': channels,
        },
        onConflict: 'user_id,idempotency_key',
        ignoreDuplicates: true,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<TripShare> startShare({
    required String destination,
    String? mode,
    int hours = 4,
    LatLng? at,
  }) async {
    final res = await GoSmartSupabase.client.rpc('trip_share_start', params: {
      'p_destination': destination,
      'p_mode': mode,
      'p_hours': hours,
      'p_lat': at?.latitude,
      'p_lng': at?.longitude,
    });
    final row = (res as List).first as Map<String, dynamic>;
    return TripShare(
      token: row['token'] as String,
      expiresAt: DateTime.parse(row['expires_at'] as String).toLocal(),
    );
  }

  Future<bool> updateShare(String token, LatLng at) async {
    final res = await GoSmartSupabase.client.rpc('trip_share_update', params: {
      'p_token': token,
      'p_lat': at.latitude,
      'p_lng': at.longitude,
    });
    return res == true;
  }

  Future<void> stopShare(String token) async {
    await GoSmartSupabase.client
        .rpc('trip_share_stop', params: {'p_token': token});
  }
}

final safetyService = SafetyService();
