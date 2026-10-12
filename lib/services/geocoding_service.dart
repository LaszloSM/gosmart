// lib/services/geocoding_service.dart
// Búsqueda de direcciones con Google Places (Autocomplete New + Place Details)
// a través de la Edge Function `maps`: la clave de Google no va en el APK.
// Una sesión = escribir + elegir; Google cobra la sesión, no cada letra.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../core/supabase_client.dart';
import '../models/geocode_suggestion.dart';

typedef MapsInvoke = Future<Map<String, dynamic>> Function(
    Map<String, dynamic> body);

/// Llama la función `maps`. Errores → [GeocodingException] con el código.
Future<Map<String, dynamic>> invokeMaps(Map<String, dynamic> body) async {
  try {
    final res = await GoSmartSupabase.client.functions
        .invoke('maps', body: body)
        .timeout(const Duration(seconds: 12));
    final data = res.data;
    final map = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
    final err = map['error'];
    if (err != null) throw GeocodingException('$err');
    return map;
  } on FunctionException catch (e) {
    throw GeocodingException('http_${e.status}');
  } on TimeoutException {
    throw const GeocodingException('timeout');
  }
}

const _types = {
  'street_address': 'address',
  'route': 'address',
  'premise': 'address',
  'neighborhood': 'neighborhood',
  'sublocality': 'neighborhood',
  'locality': 'locality',
};

class GeocodingService {
  GeocodingService({MapsInvoke? invoke, String Function()? newSession})
      : _invoke = invoke ?? invokeMaps,
        _newSession = newSession ?? (() => const Uuid().v4());
  final MapsInvoke _invoke;
  final String Function() _newSession;
  String? _session;

  /// Igual que [searchStrict], pero nunca falla: devuelve [] ante cualquier error.
  Future<List<GeocodeSuggestion>> search(String query, {LatLng? proximity}) async {
    try {
      return await searchStrict(query, proximity: proximity);
    } catch (e) {
      debugPrint('[GeocodingService] search error: $e');
      return [];
    }
  }

  /// Sugerencias SIN coordenadas (se piden al elegir con [resolve]).
  /// Lanza [GeocodingException] si Google o la función fallan (D8).
  Future<List<GeocodeSuggestion>> searchStrict(String query,
      {LatLng? proximity}) async {
    final q = query.trim();
    if (q.length < 2) return [];
    _session ??= _newSession();
    final data = await _invoke({
      'action': 'autocomplete',
      'input': q,
      'session': _session,
      if (proximity != null)
        'near': {'lat': proximity.latitude, 'lng': proximity.longitude},
    });
    return [
      for (final it in data['items'] as List? ?? const [])
        if (it is Map)
          GeocodeSuggestion(
            placeName: '${it['name'] ?? ''}',
            fullAddress: '${it['address'] ?? ''}',
            latLng: null,
            placeId: it['placeId'] as String?,
            featureType: _featureType(it['types']),
          ),
    ];
  }

  /// Coordenadas de una sugerencia elegida. Cierra la sesión de Google.
  Future<GeocodeSuggestion> resolve(GeocodeSuggestion s) async {
    if (s.latLng != null) return s;
    final id = s.placeId;
    if (id == null) throw const GeocodingException('no_place');
    final session = _session;
    _session = null; // la próxima búsqueda abre otra sesión
    final data = await _invoke({
      'action': 'details',
      'place_id': id,
      if (session != null) 'session': session,
    });
    final p = data['place'] as Map? ?? const {};
    return s.withLocation(
      LatLng((p['lat'] as num).toDouble(), (p['lng'] as num).toDouble()),
      address: p['address'] as String?,
    );
  }

  static String _featureType(Object? types) {
    for (final t in types is List ? types : const []) {
      final k = _types['$t'];
      if (k != null) return k;
    }
    return 'poi';
  }
}

final geocodingService = GeocodingService();

class GeocodingException implements Exception {
  const GeocodingException(this.code);
  final String code;
  @override
  String toString() => 'GeocodingException($code)';
}
