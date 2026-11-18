// test/core/city_rank_test.dart
// "Tu ciudad primero": estando en Riohacha salen primero los lugares de
// Riohacha, luego Maicao y el corredor; Manaure y demás solo si se nombran.
import 'package:flutter_test/flutter_test.dart';
import 'package:gosmart/core/city_rank.dart';
import 'package:gosmart/core/region.dart';
import 'package:gosmart/models/geocode_suggestion.dart';
import 'package:gosmart/services/geocoding_service.dart';
import 'package:gosmart/services/place_search.dart';
import 'package:latlong2/latlong.dart';

GeocodeSuggestion _g(String name, String address, {LatLng? at}) =>
    GeocodeSuggestion(placeName: name, fullAddress: address, latLng: at);

class _Fake implements PlaceSearch {
  _Fake(this.items);
  final List<GeocodeSuggestion> items;
  @override
  Future<List<GeocodeSuggestion>> search(String q, {LatLng? near}) async => items;
}

void main() {
  test('ubica la ciudad por el punto', () {
    expect(cityAt(GSRegion.riohacha), 'riohacha');
    expect(cityAt(const LatLng(11.53, -72.91)), 'riohacha');
    expect(cityAt(GSRegion.maicao), 'maicao');
    expect(cityAt(const LatLng(11.77, -72.44)), isNull); // Manaure
    expect(cityAt(null), isNull);
  });

  test('anillos: aquí, la otra ciudad / corredor, otro municipio', () {
    expect(tierOf(_g('Calle 15', 'Riohacha, La Guajira'), here: 'riohacha'), CityTier.here);
    expect(tierOf(_g('Calle 15', 'Maicao, La Guajira'), here: 'riohacha'), CityTier.mvp);
    expect(tierOf(_g('Calle 15', 'Manaure, La Guajira'), here: 'riohacha'), CityTier.other);
    expect(tierOf(_g('Calle 15', 'Uribia, La Guajira'), here: 'riohacha'), CityTier.other);
    expect(tierOf(_g('Peaje', 'Troncal del Caribe'), here: 'riohacha'), CityTier.mvp);
    expect(tierOf(_g('Playa', 'Santa Marta, Magdalena'), here: 'riohacha'), CityTier.other);
    // Sin ciudad en el texto, decide el punto.
    expect(tierOf(_g('Tienda', '', at: const LatLng(11.54, -72.91)), here: 'riohacha'),
        CityTier.here);
    // "de los Remedios" (hospital de Riohacha) no es "La Punta de los Remedios".
    expect(
        tierOf(_g('Hospital Nuestra Señora de los Remedios', 'Riohacha'), here: 'riohacha'),
        CityTier.here);
  });

  test('en Riohacha: Riohacha primero, Maicao después, Manaure fuera', () {
    final items = [
      _g('Calle 15', 'Manaure, La Guajira'),
      _g('Calle 15', 'Maicao, La Guajira'),
      _g('Calle 15', 'Riohacha, La Guajira'),
    ];
    final r = rankByCity('calle 15', items, near: GSRegion.riohacha, relevance: (_) => 1);
    expect(r.map((s) => s.fullAddress), ['Riohacha, La Guajira', 'Maicao, La Guajira']);
  });

  test('en Maicao: Maicao primero', () {
    final items = [
      _g('Terminal', 'Riohacha, La Guajira'),
      _g('Terminal', 'Maicao, La Guajira'),
    ];
    final r = rankByCity('terminal', items, near: GSRegion.maicao, relevance: (_) => 1);
    expect(r.first.fullAddress, 'Maicao, La Guajira');
  });

  test('si nombras otro municipio, sale y va primero', () {
    expect(namedOtherTown('Hospital de Manaure'), 'manaure');
    expect(namedOtherTown('Uribía centro'), 'uribia');
    expect(namedOtherTown('Calle 15'), isNull);
    final items = [
      _g('Hospital', 'Riohacha, La Guajira'),
      _g('Hospital', 'Manaure, La Guajira'),
    ];
    final r = rankByCity('hospital manaure', items, near: GSRegion.riohacha, relevance: (_) => 1);
    expect(r.first.fullAddress, 'Manaure, La Guajira');
    expect(r.length, 2);
  });

  test('si solo hay de otros municipios, se muestran (mejor que nada)', () {
    final items = [_g('Salinas', 'Manaure, La Guajira')];
    expect(rankByCity('salinas', items, near: GSRegion.riohacha, relevance: (_) => 1), items);
  });

  test('dentro de la misma ciudad manda el parecido', () {
    final items = [
      _g('Parque', 'Riohacha'),
      _g('Parque Padilla', 'Riohacha'),
    ];
    final r = rankByCity('parque padilla', items,
        near: GSRegion.riohacha, relevance: (s) => s.placeName == 'Parque Padilla' ? 1 : 0.5);
    expect(r.first.placeName, 'Parque Padilla');
  });

  test('el buscador en capas aplica la ciudad', () async {
    final r = await LayeredPlaceSearch(
      directory: _Fake([]),
      provider: _Fake([
        _g('Calle 1', 'Manaure, La Guajira'),
        _g('Calle 1', 'Maicao, La Guajira'),
        _g('Calle 1', 'Riohacha, La Guajira'),
      ]),
    ).search('calle 1', near: GSRegion.maicao);
    expect(r.items.map((s) => s.fullAddress),
        ['Maicao, La Guajira', 'Riohacha, La Guajira']);
  });

  test('una dirección escrita sale primero y se ubica sin perder su texto', () async {
    final search = LayeredPlaceSearch(
      directory: _Fake([]),
      provider: _Fake([_g('Calle 14', 'Riohacha, La Guajira')]),
      addressText: (a, {proximity}) async => [],
      addressLocator: (a, {near}) async => const GeocodeSuggestion(
          placeName: 'otro texto', fullAddress: 'Cl. 14 #10-20',
          latLng: LatLng(11.541, -72.905)),
    );
    final r = await search.search('cl 14 #10-20', near: GSRegion.riohacha);
    expect(r.items.first.placeName, 'Calle 14 # 10-20');
    expect(r.items.first.fullAddress, 'Dirección exacta · Riohacha');
    final placed = await search.resolve(r.items.first);
    expect(placed!.placeName, 'Calle 14 # 10-20');
    expect(placed.latLng, const LatLng(11.541, -72.905));
    expect(placed.approximate, isFalse);
  });

  test('sin la casa exacta usa la esquina; nunca el GPS como destino', () async {
    final asked = <String>[];
    final search = LayeredPlaceSearch(
      directory: _Fake([]),
      provider: _Fake([]),
      addressText: (a, {proximity}) async => [],
      addressLocator: (a, {near}) async {
        asked.add(a);
        if (a.contains('&')) {
          return const GeocodeSuggestion(
              placeName: 'esquina', fullAddress: '', latLng: LatLng(11.548, -72.905),
              approximate: true);
        }
        throw const GeocodingException('not_found');
      },
    );
    final r = await search.search('Calle 24 # 14', near: GSRegion.riohacha);
    final placed = await search.resolve(r.items.first);
    expect(asked, ['Calle 24 # 14', 'Calle 24 & Carrera 14']);
    expect(placed!.placeName, 'Calle 24 # 14');
    expect(placed.latLng, const LatLng(11.548, -72.905));
    expect(placed.approximate, isTrue, reason: 'se confirma el pin en la esquina');
  });

  test('si no aparece ni la esquina, null (se marca en el mapa)', () async {
    final search = LayeredPlaceSearch(
      directory: _Fake([]),
      provider: _Fake([]),
      addressText: (a, {proximity}) async => [],
      addressLocator: (a, {near}) async => throw const GeocodingException('not_found'),
    );
    final r = await search.search('Calle 24 # 7H-45', near: GSRegion.maicao);
    expect(await search.resolve(r.items.first), isNull);
  });

  test('Text Search ubica la casa cuando Geocoding no la tiene', () async {
    final search = LayeredPlaceSearch(
      directory: _Fake([]),
      provider: _Fake([]),
      addressLocator: (a, {near}) async => throw const GeocodingException('not_found'),
      addressText: (a, {proximity}) async => const [
        GeocodeSuggestion(placeName: 'Calle 24', fullAddress: 'Riohacha',
            latLng: LatLng(11.50, -72.90), featureType: 'address'),
        GeocodeSuggestion(placeName: 'Cl. 24 #14-20', fullAddress: 'Riohacha',
            latLng: LatLng(11.548, -72.904), featureType: 'address'),
      ],
    );
    final r = await search.search('Calle 24 # 14-20', near: GSRegion.riohacha);
    final placed = await search.resolve(r.items.first);
    expect(placed!.latLng, const LatLng(11.548, -72.904), reason: 'la casa, no la calle sola');
    expect(placed.placeName, 'Calle 24 # 14-20');
  });
}
