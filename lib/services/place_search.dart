// lib/services/place_search.dart
// Buscador de lugares en capas (Fase 3, decisión D8):
//   1. Directorio propio (`places`): como la gente nombra los sitios.
//   2. Google Places (función `maps`); sus sugerencias traen coordenadas
//      solo al elegirlas (`resolve`).
//   3. Si Google no responde (cuota agotada, sin clave), Photon con datos de
//      OpenStreetMap: gratis y con coordenadas; solo de respaldo (uso justo).
//   4. Si nada sirve, el usuario marca el punto en el mapa.
// Coordenadas: un lugar verificado en campo usa la suya; uno sin verificar
// toma la de Google al elegirlo y solo usa la aproximada si Google no responde.
// Si el proveedor falla o no está configurado, se sigue con el directorio y
// la pantalla lo avisa (`PlaceSearchResult.limited`).
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
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
      // "aprox." se decide al elegirlo: casi siempre Google da el punto real.
      fullAddress: city,
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

/// Respaldo sin clave ni cuota: Photon (photon.komoot.io) sobre OpenStreetMap,
/// limitado a La Guajira. El servicio público pide uso justo: solo se llama
/// cuando Google falla, con la misma espera entre letras y caché propia.
class PhotonPlaceSearch implements PlaceSearch {
  PhotonPlaceSearch({http.Client? client}) : _client = client ?? http.Client();
  final http.Client _client;
  final _cache = <String, List<GeocodeSuggestion>>{};

  static const _bbox = '-73.7,10.3,-71.0,12.6'; // oeste,sur,este,norte

  @override
  Future<List<GeocodeSuggestion>> search(String query, {LatLng? near}) async {
    final q = query.trim();
    if (q.length < 2) return [];
    final key = q.toLowerCase();
    final cached = _cache[key];
    if (cached != null) return cached;
    final uri = Uri.https('photon.komoot.io', '/api/', {
      'q': q,
      'limit': '6',
      'bbox': _bbox,
      'lat': '${(near ?? const LatLng(11.5444, -72.9072)).latitude}',
      'lon': '${(near ?? const LatLng(11.5444, -72.9072)).longitude}',
    });
    final res = await _client
        .get(uri, headers: {'User-Agent': 'GoSmart/1.0 (MVP La Guajira)'})
        .timeout(const Duration(seconds: 8));
    if (res.statusCode != 200) throw GeocodingException('photon_${res.statusCode}');
    final items = parsePhoton(jsonDecode(utf8.decode(res.bodyBytes)));
    if (_cache.length > 40) _cache.clear();
    return _cache[key] = items;
  }

  /// GeoJSON de Photon → sugerencias con coordenadas (no hay que resolverlas).
  static List<GeocodeSuggestion> parsePhoton(Object? json) {
    final out = <GeocodeSuggestion>[];
    final features = json is Map ? json['features'] : null;
    for (final f in features is List ? features : const []) {
      if (f is! Map) continue;
      final c = (f['geometry'] as Map?)?['coordinates'];
      final p = f['properties'] is Map ? f['properties'] as Map : const {};
      if (c is! List || c.length < 2 || c[0] is! num || c[1] is! num) continue;
      final street = [p['street'], p['housenumber']].whereType<String>().join(' ');
      final name = (p['name'] as String?) ?? (street.isEmpty ? null : street);
      if (name == null || name.trim().isEmpty) continue;
      final place = [
        if (street.isNotEmpty && street != name) street,
        p['district'] ?? p['locality'],
        p['city'] ?? p['county'],
      ].whereType<String>().where((x) => x.isNotEmpty).toSet().join(', ');
      final kind = p['osm_key'] == 'highway' || p['type'] == 'street'
          ? 'address'
          : (p['type'] == 'city' || p['type'] == 'district' ? 'neighborhood' : 'poi');
      out.add(GeocodeSuggestion(
        placeName: name,
        fullAddress: place.isEmpty ? 'La Guajira' : place,
        latLng: LatLng((c[1] as num).toDouble(), (c[0] as num).toDouble()),
        featureType: kind,
      ));
    }
    return out;
  }
}

/// Une las capas: directorio primero, luego el proveedor sin repetidos.
class LayeredPlaceSearch {
  LayeredPlaceSearch({
    required this.directory,
    required this.provider,
    this.fallback,
    Future<GeocodeSuggestion> Function(GeocodeSuggestion)? resolver,
  }) : _resolver = resolver ?? geocodingService.resolve;
  final PlaceSearch directory;
  final PlaceSearch provider;

  /// Si [provider] falla: otro buscador con coordenadas (Photon).
  final PlaceSearch? fallback;
  final Future<GeocodeSuggestion> Function(GeocodeSuggestion) _resolver;

  /// Coordenadas de la sugerencia elegida (las de Google llegan aquí).
  /// null si no se pudo: la pantalla avisa y la persona puede elegir otra.
  /// Un lugar del directorio sin verificar se ubica con Google; si Google no
  /// responde, queda su punto aproximado (`approximate`, la pantalla lo dice).
  Future<GeocodeSuggestion?> resolve(GeocodeSuggestion s) async {
    if (s.fromDirectory) {
      if (!s.approximate) return s;
      return await _locateWithProvider(s) ?? s;
    }
    if (s.latLng != null) return s;
    try {
      return await _resolver(s);
    } on GeocodingException catch (e) {
      Telemetry.degraded('geocoding', e.code);
    } catch (e) {
      Telemetry.degraded('geocoding', e.runtimeType.toString());
    }
    return null;
  }

  /// Distancia máxima entre el punto aproximado y el de Google: más lejos es
  /// otro sitio con nombre parecido y no se toma.
  static const maxShiftMeters = 3000.0;

  /// Busca en Google el lugar del directorio por nombre y ciudad, cerca de su
  /// punto aproximado; si Google no responde, en el respaldo (Photon). Conserva
  /// el nombre que la gente conoce.
  Future<GeocodeSuggestion?> _locateWithProvider(GeocodeSuggestion s) async {
    final approx = s.latLng;
    final city = s.fullAddress.split(' · ').first;
    final query = '${s.placeName}, $city';
    GeocodeSuggestion? near(GeocodeSuggestion? g) {
      final at = g?.latLng;
      if (g == null || at == null) return null;
      if (approx != null && _meters(approx, at) > maxShiftMeters) return null;
      return GeocodeSuggestion(
        placeName: s.placeName,
        fullAddress: g.fullAddress.isEmpty ? city : g.fullAddress,
        latLng: at,
        placeId: g.placeId,
        featureType: s.featureType,
        fromDirectory: true,
      );
    }

    try {
      final found = await provider.search(query, near: approx);
      if (found.isEmpty) return null;
      return near(await _resolver(found.first));
    } on GeocodingException catch (e) {
      if (e.code != 'no_key') Telemetry.degraded('geocoding', e.code);
    } catch (e) {
      Telemetry.degraded('geocoding', e.runtimeType.toString());
    }
    final backup = fallback;
    if (backup == null) return null;
    try {
      // Los del respaldo ya traen coordenadas: el primero que caiga cerca.
      for (final g in await backup.search(query, near: approx)) {
        final ok = near(g);
        if (ok != null) return ok;
      }
    } catch (e) {
      Telemetry.degraded('photon', e.runtimeType.toString());
    }
    return null;
  }

  static const maxResults = 8;

  Future<PlaceSearchResult> search(String query, {LatLng? near}) async {
    if (query.trim().length < 2) return const PlaceSearchResult([]);

    final results = await Future.wait([
      _safe(() => directory.search(query, near: near), 'places_directory'),
      _safe(() => provider.search(query, near: near), 'geocoding'),
    ]);
    final dir = results[0];
    var ext = results[1];
    if (ext == null && fallback != null) {
      ext = await _safe(() => fallback!.search(query, near: near), 'photon');
    }

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

/// Mismo lugar: nombre parecido y a menos de 150 m. Si una sugerencia aún no
/// tiene coordenadas (Google sin resolver), basta con el nombre parecido.
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
  final la = a.latLng, lb = b.latLng;
  final similarName = na == nb || na.contains(nb) || nb.contains(na);
  if (la == null || lb == null) return similarName;
  return similarName && _meters(la, lb) < 150;
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
  fallback: PhotonPlaceSearch(),
);
