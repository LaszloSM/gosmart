// lib/services/place_search.dart
// Buscador de lugares en capas (Fase 3, decisión D8):
//   1. Directorio propio (`places`): como la gente nombra los sitios.
//   2. Proveedor externo (hoy Mapbox; Google Places cuando haya clave).
//   3. Si nada sirve, el usuario marca el punto en el mapa.
// Si el proveedor falla o no está configurado, se sigue con el directorio y
// la pantalla lo avisa (`PlaceSearchResult.limited`).
import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../core/supabase_client.dart';
import '../core/telemetry.dart';
import '../models/geocode_suggestion.dart';
import 'geocoding_service.dart';

abstract class PlaceSearch {
  Future<List<GeocodeSuggestion>> search(String query, {LatLng? near});
}

class PlaceSearchResult {
  const PlaceSearchResult(this.items, {this.limited = false});
  final List<GeocodeSuggestion> items;

  /// true = solo se buscó en parte (el proveedor externo no respondió).
  final bool limited;
}

const _cityLabel = {
  'riohacha': 'Riohacha',
  'maicao': 'Maicao',
  'corredor': 'Troncal del Caribe',
  'otro': 'La Guajira',
};

const _kindType = {
  'barrio': 'neighborhood',
  'via': 'address',
};

class DirectoryPlaceSearch implements PlaceSearch {
  @override
  Future<List<GeocodeSuggestion>> search(String query, {LatLng? near}) async {
    final rows = await GoSmartSupabase.client.rpc('search_places', params: {
      'p_query': query,
      'p_lat': near?.latitude,
      'p_lng': near?.longitude,
      'p_limit': 6,
    });
    return [
      for (final r in rows as List) fromDirectoryRow(r as Map<String, dynamic>),
    ];
  }

  static GeocodeSuggestion fromDirectoryRow(Map<String, dynamic> r) {
    final verified = r['verified'] as bool? ?? false;
    final city = _cityLabel[r['city']] ?? 'La Guajira';
    return GeocodeSuggestion(
      placeName: r['name'] as String,
      fullAddress: verified ? city : '$city · ubicación aprox.',
      latLng: LatLng((r['lat'] as num).toDouble(), (r['lng'] as num).toDouble()),
      featureType: _kindType[r['kind']] ?? 'poi',
      fromDirectory: true,
      approximate: !verified,
    );
  }
}

class ProviderPlaceSearch implements PlaceSearch {
  ProviderPlaceSearch([GeocodingService? service])
      : _service = service ?? geocodingService;
  final GeocodingService _service;

  @override
  Future<List<GeocodeSuggestion>> search(String query, {LatLng? near}) =>
      _service.searchStrict(query, proximity: near);
}

/// Une las capas: directorio primero, luego el proveedor sin repetidos.
class LayeredPlaceSearch {
  LayeredPlaceSearch({required this.directory, required this.provider});
  final PlaceSearch directory;
  final PlaceSearch provider;

  static const maxResults = 8;

  Future<PlaceSearchResult> search(String query, {LatLng? near}) async {
    if (query.trim().length < 2) return const PlaceSearchResult([]);

    final results = await Future.wait([
      _safe(() => directory.search(query, near: near), 'places_directory'),
      _safe(() => provider.search(query, near: near), 'geocoding'),
    ]);
    final dir = results[0];
    final ext = results[1];

    final merged = <GeocodeSuggestion>[...?dir];
    for (final s in ext ?? const <GeocodeSuggestion>[]) {
      if (!merged.any((m) => isSamePlace(m, s))) merged.add(s);
    }
    return PlaceSearchResult(
      merged.take(maxResults).toList(),
      limited: dir == null || ext == null,
    );
  }

  Future<List<GeocodeSuggestion>?> _safe(
      Future<List<GeocodeSuggestion>> Function() run, String service) async {
    try {
      return await run();
    } on GeocodingException catch (e) {
      // Sin clave no es una falla que reportar; igual se avisa en pantalla.
      if (e.code != 'no_key') Telemetry.degraded(service, e.code);
      return null;
    } catch (e) {
      Telemetry.degraded(service, e.runtimeType.toString());
      return null;
    }
  }
}

/// Mismo lugar: nombre parecido y a menos de 150 m.
bool isSamePlace(GeocodeSuggestion a, GeocodeSuggestion b) {
  String norm(String s) => s
      .toLowerCase()
      .replaceAll(RegExp('[áä]'), 'a')
      .replaceAll(RegExp('[éë]'), 'e')
      .replaceAll(RegExp('[íï]'), 'i')
      .replaceAll(RegExp('[óö]'), 'o')
      .replaceAll(RegExp('[úü]'), 'u')
      .replaceAll(RegExp(r'[^a-zñ0-9 ]'), '')
      .trim();
  final na = norm(a.placeName), nb = norm(b.placeName);
  final similarName = na == nb || na.contains(nb) || nb.contains(na);
  return similarName && _meters(a.latLng, b.latLng) < 150;
}

double _meters(LatLng a, LatLng b) {
  const r = 6371000.0;
  final dLat = (b.latitude - a.latitude) * math.pi / 180;
  final dLng = (b.longitude - a.longitude) * math.pi / 180;
  final x = dLng * math.cos((a.latitude + b.latitude) * math.pi / 360);
  return r * math.sqrt(dLat * dLat + x * x);
}

final placeSearch = LayeredPlaceSearch(
  directory: DirectoryPlaceSearch(),
  provider: ProviderPlaceSearch(),
);
