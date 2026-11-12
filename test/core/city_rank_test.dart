// test/core/city_rank_test.dart
// "Tu ciudad primero": estando en Riohacha salen primero los lugares de
// Riohacha, luego Maicao y el corredor; Manaure y demás solo si se nombran.
import 'package:flutter_test/flutter_test.dart';
import 'package:gosmart/core/city_rank.dart';
import 'package:gosmart/core/region.dart';
import 'package:gosmart/models/geocode_suggestion.dart';
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
}
