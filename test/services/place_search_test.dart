// test/services/place_search_test.dart
// Directorio primero, proveedor después, sin repetidos; si el proveedor
// falla, se sigue con el directorio y se marca como búsqueda limitada (D8).
import 'package:flutter_test/flutter_test.dart';
import 'package:gosmart/models/geocode_suggestion.dart';
import 'package:gosmart/services/geocoding_service.dart';
import 'package:gosmart/services/place_search.dart';
import 'package:latlong2/latlong.dart';

class _Fake implements PlaceSearch {
  _Fake(this.items, {this.error});
  final List<GeocodeSuggestion> items;
  final Object? error;
  @override
  Future<List<GeocodeSuggestion>> search(String q, {LatLng? near}) async {
    if (error != null) throw error!;
    return items;
  }
}

GeocodeSuggestion _s(String name, double lat, double lng, {bool dir = false}) =>
    GeocodeSuggestion(
        placeName: name,
        fullAddress: 'Riohacha',
        latLng: LatLng(lat, lng),
        fromDirectory: dir);

void main() {
  final muelleDir = _s('Muelle Turístico de Riohacha', 11.5449, -72.9075, dir: true);
  final muelleExt = _s('Muelle turistico', 11.5450, -72.9076);
  final otro = _s('Calle 15', 11.5400, -72.9100);

  test('el directorio va primero y el proveedor no repite el mismo lugar',
      () async {
    final r = await LayeredPlaceSearch(
      directory: _Fake([muelleDir]),
      provider: _Fake([muelleExt, otro]),
    ).search('muelle');
    expect(r.items.map((s) => s.placeName),
        ['Muelle Turístico de Riohacha', 'Calle 15']);
    expect(r.limited, isFalse);
  });

  test('si el proveedor falla, quedan los del directorio y se avisa', () async {
    final r = await LayeredPlaceSearch(
      directory: _Fake([muelleDir]),
      provider: _Fake([], error: const GeocodingException('http_429')),
    ).search('muelle');
    expect(r.items, [muelleDir]);
    expect(r.limited, isTrue);
  });

  test('si el directorio falla (sin red), queda el proveedor', () async {
    final r = await LayeredPlaceSearch(
      directory: _Fake([], error: Exception('offline')),
      provider: _Fake([otro]),
    ).search('calle 15');
    expect(r.items, [otro]);
    expect(r.limited, isTrue);
  });

  test('una letra no busca', () async {
    final r = await LayeredPlaceSearch(
      directory: _Fake([muelleDir]),
      provider: _Fake([otro]),
    ).search('m');
    expect(r.items, isEmpty);
  });

  test('mismo nombre pero lejos no se toma como repetido', () {
    final lejos = _s('Muelle turistico', 11.3780, -72.2405);
    expect(isSamePlace(muelleDir, muelleExt), isTrue);
    expect(isSamePlace(muelleDir, lejos), isFalse);
  });

  test('fila del directorio sin verificar se marca como aproximada', () {
    final s = DirectoryPlaceSearch.fromDirectoryRow({
      'name': 'Terminal de Maicao',
      'city': 'maicao',
      'kind': 'terminal',
      'lat': 11.379,
      'lng': -72.237,
      'verified': false,
    });
    expect(s.approximate, isTrue);
    expect(s.fullAddress, 'Maicao · ubicación aprox.');
    expect(s.fromDirectory, isTrue);
  });
}
