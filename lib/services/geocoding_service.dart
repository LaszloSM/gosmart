// lib/services/geocoding_service.dart
// Búsqueda de direcciones con Google Places (Autocomplete New + Place Details)
// a través de la Edge Function `maps`: la clave de Google no va en el APK.
// Una sesión = escribir + elegir; Google cobra la sesión, no cada letra.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../core/city_rank.dart';
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

  final _reverseCache = <String, String>{};

  /// Últimas búsquedas (texto normalizado → sugerencias): borrar y volver a
  /// escribir no gasta otra petición de la cuota diaria de Google.
  final _searchCache = <String, List<GeocodeSuggestion>>{};

  /// Dirección corta de un punto ("Cl. 2 #7-30, Riohacha" o "Cerca de
  /// Parque Padilla"); null si no se pudo. Guarda las últimas por ~50 m.
  Future<String?> reverse(LatLng p) async {
    final key = '${p.latitude.toStringAsFixed(4)},${p.longitude.toStringAsFixed(4)}';
    final cached = _reverseCache[key];
    if (cached != null) return cached;
    try {
      final data = await _invoke({
        'action': 'reverse',
        'at': {'lat': p.latitude, 'lng': p.longitude},
      });
      final a = (data['address'] as String?)?.trim();
      if (a == null || a.isEmpty) return null;
      if (_reverseCache.length > 50) _reverseCache.clear();
      return _reverseCache[key] = a;
    } catch (e) {
      debugPrint('[GeocodingService] reverse error: $e');
      return null;
    }
  }

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
    final cacheKey = '${q.toLowerCase()}|'
        '${proximity?.latitude.toStringAsFixed(2)},${proximity?.longitude.toStringAsFixed(2)}';
    final cached = _searchCache[cacheKey];
    if (cached != null) return cached;
    _session ??= _newSession();
    final data = await _invoke({
      'action': 'autocomplete',
      'input': withCity(q, proximity),
      'session': _session,
      if (proximity != null)
        'near': {'lat': proximity.latitude, 'lng': proximity.longitude},
      // Nombra otro municipio ("hospital de Manaure"): buscar en toda La
      // Guajira. Si no, Google prioriza los ~15 km alrededor de la persona.
      if (namedOtherTown(q) != null) 'wide': true,
    });
    final items = [
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
    if (_searchCache.length > 40) _searchCache.clear();
    return _searchCache[cacheKey] = items;
  }

  /// Ubica una dirección escrita ("Calle 14 # 10-20") con la Geocoding API
  /// (acción `geocode` de la función `maps`), en la ciudad de [near].
  /// `approximate` = Google no la encontró exacta (solo la calle o el barrio):
  /// la pantalla pide confirmar el pin. Lanza [GeocodingException].
  Future<GeocodeSuggestion> geocodeAddress(String address, {LatLng? near}) async {
    final data = await _invoke({
      'action': 'geocode',
      'input': withCity(address, near),
    });
    final p = data['place'] as Map? ?? const {};
    final lat = p['lat'], lng = p['lng'];
    if (lat is! num || lng is! num) throw const GeocodingException('not_found');
    return GeocodeSuggestion(
      placeName: address,
      fullAddress: (p['address'] as String?) ?? '',
      latLng: LatLng(lat.toDouble(), lng.toDouble()),
      featureType: 'address',
      approximate: p['exact'] != true,
      typedAddress: true,
    );
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
