// lib/core/city_rank.dart
// "Tu ciudad primero": las sugerencias de lugares se ordenan por la ciudad
// donde está la persona (Riohacha o Maicao), luego la otra ciudad del MVP y el
// corredor. Los demás municipios (Manaure, Uribia…) solo salen si la persona
// escribe su nombre. Dart puro: se prueba sin red.
import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

import '../models/geocode_suggestion.dart';
import 'region.dart';

/// Qué tan cerca está un lugar de la persona, en ciudades.
enum CityTier {
  /// En la ciudad donde estás.
  here,

  /// En la otra ciudad del MVP (Riohacha / Maicao) o en la Troncal.
  mvp,

  /// En otro municipio (Manaure, Uribia, Santa Marta…).
  other,
}

/// Radio de cada ciudad desde su centro (incluye los barrios de la periferia).
const _cityRadiusKm = {'riohacha': 12.0, 'maicao': 10.0};

const _cityCenters = {
  'riohacha': GSRegion.riohacha,
  'maicao': GSRegion.maicao,
};

/// Municipios y pueblos fuera del MVP. Solo aparecen si se nombran.
const otherTowns = [
  'manaure', 'uribia', 'albania', 'dibulla', 'fonseca', 'barrancas',
  'hatonuevo', 'distraccion', 'villanueva', 'urumita', 'el molino',
  'la jagua del pilar', 'san juan del cesar', 'palomino', 'mingueo',
  'cabo de la vela', 'santa marta', 'valledupar', 'barranquilla',
  'nazareth', 'puerto bolivar', 'el pajaro', 'musichi', 'carrizal',
  'puerto estrella', 'la punta de los remedios', 'conejo',
];

String normPlace(String s) => s
    .toLowerCase()
    .replaceAll(RegExp('[áä]'), 'a')
    .replaceAll(RegExp('[éë]'), 'e')
    .replaceAll(RegExp('[íï]'), 'i')
    .replaceAll(RegExp('[óö]'), 'o')
    .replaceAll(RegExp('[úü]'), 'u')
    .replaceAll(RegExp(r'[^a-zñ0-9 ]'), ' ')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim();

bool _hasWord(String text, String word) =>
    RegExp('(^| )${RegExp.escape(word)}( |\$)').hasMatch(text);

double _km(LatLng a, LatLng b) {
  const r = 6371.0;
  final dLat = (b.latitude - a.latitude) * math.pi / 180;
  final dLng = (b.longitude - a.longitude) * math.pi / 180;
  final x = dLng * math.cos((a.latitude + b.latitude) * math.pi / 360);
  return r * math.sqrt(dLat * dLat + x * x);
}

/// 'riohacha' o 'maicao' si el punto está en esa ciudad; null si no.
String? cityAt(LatLng? p) {
  if (p == null) return null;
  for (final e in _cityCenters.entries) {
    if (_km(p, e.value) <= _cityRadiusKm[e.key]!) return e.key;
  }
  return null;
}

/// El otro municipio que nombra la búsqueda ("hospital manaure" → 'manaure').
String? namedOtherTown(String query) {
  final q = normPlace(query);
  for (final t in otherTowns) {
    if (_hasWord(q, t)) return t;
  }
  return null;
}

/// El municipio que nombra un texto ('riohacha', 'maicao', 'manaure'…), o null.
String? townIn(String text) {
  final t = normPlace(text);
  for (final c in [..._cityCenters.keys, ...otherTowns]) {
    if (_hasWord(t, c)) return c;
  }
  return null;
}

/// En qué "anillo" cae una sugerencia respecto de la ciudad [here].
CityTier tierOf(GeocodeSuggestion s, {String? here}) {
  final text = normPlace('${s.placeName} ${s.fullAddress}');
  // 1. Lo que dice la dirección manda (Google y el directorio la traen).
  for (final city in _cityCenters.keys) {
    if (_hasWord(text, city)) {
      return city == here ? CityTier.here : CityTier.mvp;
    }
  }
  if (otherTowns.any((t) => _hasWord(text, t))) return CityTier.other;
  // 2. Si hay coordenadas, dónde cae el punto.
  final at = cityAt(s.latLng);
  if (at != null) return at == here ? CityTier.here : CityTier.mvp;
  // 3. Corredor y La Guajira sin municipio: dentro del MVP.
  if (_hasWord(text, 'troncal') || _hasWord(text, 'guajira') ||
      s.fullAddress.trim().isEmpty) {
    return CityTier.mvp;
  }
  return CityTier.other;
}

/// Ordena (estable) por anillo y, dentro de cada uno, por [relevance].
/// Sin nombrar otro municipio, los de [CityTier.other] se quitan (salvo que
/// no quede nada). Si la búsqueda nombra un municipio, primero lo de ese
/// municipio y después lo demás por parecido.
List<GeocodeSuggestion> rankByCity(
  String query,
  List<GeocodeSuggestion> items, {
  LatLng? near,
  required double Function(GeocodeSuggestion) relevance,
}) {
  final here = cityAt(near);
  final named = namedOtherTown(query);
  final tier = {for (final s in items) s: tierOf(s, here: here)};
  final score = {for (final s in items) s: relevance(s)};
  final indexed = [for (var i = 0; i < items.length; i++) (i, items[i])];

  int key(GeocodeSuggestion s) {
    if (named != null) {
      return _hasWord(normPlace('${s.placeName} ${s.fullAddress}'), named) ? 0 : 1;
    }
    return tier[s]!.index;
  }

  var list = indexed;
  if (named == null) {
    final kept = [for (final e in indexed) if (tier[e.$2] != CityTier.other) e];
    if (kept.isNotEmpty) list = kept;
  }
  list.sort((a, b) {
    final t = key(a.$2).compareTo(key(b.$2));
    if (t != 0) return t;
    final r = score[b.$2]!.compareTo(score[a.$2]!);
    return r != 0 ? r : a.$1.compareTo(b.$1);
  });
  return [for (final e in list) e.$2];
}

/// Nombre para mostrar de una ciudad del MVP ('riohacha' → 'Riohacha').
String cityLabel(String key) => switch (key) {
      'riohacha' => 'Riohacha',
      'maicao' => 'Maicao',
      _ => key,
    };

/// Lo que se le manda a Google: si la búsqueda no nombra ningún municipio y
/// la persona está en Riohacha o Maicao, se le agrega la ciudad ("Calle 14"
/// → "Calle 14, Riohacha"). Así Google trae las calles de esa ciudad y no las
/// de toda La Guajira.
String withCity(String query, LatLng? near) {
  final q = query.trim();
  if (townIn(q) != null) return q;
  final city = cityAt(near);
  return city == null ? q : '$q, ${cityLabel(city)}';
}
