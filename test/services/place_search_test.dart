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
    expect(s.fullAddress, 'Maicao');
    expect(s.fromDirectory, isTrue);
  });

  group('sugerencias de Google (sin coordenadas hasta elegirlas)', () {
    const g = GeocodeSuggestion(
        placeName: 'Muelle Turístico de Riohacha',
        fullAddress: 'Riohacha, La Guajira',
        latLng: null,
        placeId: 'abc');

    test('el mismo nombre que el directorio no se repite', () async {
      final r = await LayeredPlaceSearch(
        directory: _Fake([muelleDir]),
        provider: _Fake([g, const GeocodeSuggestion(
            placeName: 'Calle 15', fullAddress: '', latLng: null, placeId: 'x')]),
      ).search('muelle');
      expect(r.items.map((s) => s.placeName),
          ['Muelle Turístico de Riohacha', 'Calle 15']);
    });

    test('resolver: lo verificado no llama a Google; Google trae el punto',
        () async {
      var calls = 0;
      final search = LayeredPlaceSearch(
        directory: _Fake([]),
        provider: _Fake([]),
        resolver: (s) async {
          calls++;
          return s.withLocation(const LatLng(11.5449, -72.9075));
        },
      );
      expect(await search.resolve(muelleDir), muelleDir);
      expect(calls, 0);
      final r = await search.resolve(g);
      expect(r!.latLng, const LatLng(11.5449, -72.9075));
      expect(r.placeName, g.placeName);
      expect(calls, 1);
    });

    test('resolver: si Google falla, null (la pantalla avisa)', () async {
      final search = LayeredPlaceSearch(
        directory: _Fake([]),
        provider: _Fake([]),
        resolver: (_) async => throw const GeocodingException('http_403'),
      );
      expect(await search.resolve(g), isNull);
    });
  });
  group('lugar del directorio sin verificar (la plaza Almirante Padilla)', () {
    // Punto de la semilla, a unos 100 m del real.
    const plazaDir = GeocodeSuggestion(
        placeName: 'Parque Almirante Padilla',
        fullAddress: 'Riohacha',
        latLng: LatLng(11.5441, -72.9071),
        featureType: 'poi',
        fromDirectory: true,
        approximate: true);
    const plazaGoogle = GeocodeSuggestion(
        placeName: 'Parque José Prudencio Padilla',
        fullAddress: 'Cl. 2, Riohacha, La Guajira',
        latLng: null,
        placeId: 'g-plaza');
    const real = LatLng(11.5448, -72.9079);

    test('al elegirlo, el punto sale de Google y conserva el nombre conocido',
        () async {
      String? asked;
      final search = LayeredPlaceSearch(
        directory: _Fake([]),
        provider: _Recorder([plazaGoogle], (q) => asked = q),
        resolver: (s) async => s.withLocation(real, address: 'Cl. 2 #7, Riohacha'),
      );
      final r = await search.resolve(plazaDir);
      expect(asked, 'Parque Almirante Padilla, Riohacha');
      expect(r!.latLng, real);
      expect(r.placeName, 'Parque Almirante Padilla');
      expect(r.approximate, isFalse);
      expect(r.fullAddress, 'Cl. 2 #7, Riohacha');
    });

    test('sin Google, queda el punto aproximado marcado como tal', () async {
      final search = LayeredPlaceSearch(
        directory: _Fake([]),
        provider: _Fake([], error: const GeocodingException('no_key')),
      );
      final r = await search.resolve(plazaDir);
      expect(r!.latLng, plazaDir.latLng);
      expect(r.approximate, isTrue);
    });

    test('si Google no encuentra nada, queda el aproximado', () async {
      final search = LayeredPlaceSearch(
        directory: _Fake([]),
        provider: _Fake([]),
        resolver: (_) async => throw StateError('no debe resolver'),
      );
      expect((await search.resolve(plazaDir))!.approximate, isTrue);
    });

    test('un homónimo lejano de Google no reemplaza el punto', () async {
      final search = LayeredPlaceSearch(
        directory: _Fake([]),
        provider: _Fake([plazaGoogle]),
        // Maicao: a ~73 km
        resolver: (s) async => s.withLocation(const LatLng(11.3780, -72.2405)),
      );
      final r = await search.resolve(plazaDir);
      expect(r!.latLng, plazaDir.latLng);
      expect(r.approximate, isTrue);
    });

    test('el mismo nombre de Google (sin coordenadas) no sale repetido',
        () async {
      final r = await LayeredPlaceSearch(
        directory: _Fake([plazaDir]),
        provider: _Fake([
          const GeocodeSuggestion(
              placeName: 'Parque Almirante Padilla',
              fullAddress: 'Riohacha',
              latLng: null,
              placeId: 'g1'),
          plazaGoogle,
        ]),
      ).search('almirante padilla');
      expect(r.items.map((s) => s.placeName),
          ['Parque Almirante Padilla', 'Parque José Prudencio Padilla']);
    });
  });
}

class _Recorder implements PlaceSearch {
  _Recorder(this.items, this.onQuery);
  final List<GeocodeSuggestion> items;
  final void Function(String) onQuery;
  @override
  Future<List<GeocodeSuggestion>> search(String q, {LatLng? near}) async {
    onQuery(q);
    return items;
  }
}
