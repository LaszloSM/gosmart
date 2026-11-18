// Búsqueda y rutas con Google a través de la función `maps` (sin red: la
// llamada se reemplaza). Una sesión de Google = escribir + elegir.
import 'package:flutter_test/flutter_test.dart';
import 'package:gosmart/models/route_result.dart';
import 'package:gosmart/services/directions_service.dart';
import 'package:gosmart/services/geocoding_service.dart';
import 'package:gosmart/services/place_search.dart';
import 'package:latlong2/latlong.dart';

void main() {
  test('autocompletar manda la sesión y el punto cercano; detalle la cierra',
      () async {
    final sent = <Map<String, dynamic>>[];
    var n = 0;
    final svc = GeocodingService(
      newSession: () => 'sesion-${++n}',
      invoke: (body) async {
        sent.add(body);
        if (body['action'] == 'autocomplete') {
          return {
            'items': [
              {'placeId': 'p1', 'name': 'Muelle', 'address': 'Riohacha',
               'types': ['route']},
            ]
          };
        }
        return {'place': {'lat': 11.5, 'lng': -72.9, 'address': 'Cl. 1'}};
      },
    );

    final items = await svc.searchStrict('mue',
        proximity: const LatLng(11.54, -72.9));
    await svc.searchStrict('muel');
    expect(items.single.latLng, isNull);
    expect(items.single.placeId, 'p1');
    expect(items.single.featureType, 'address');
    expect(sent[0]['session'], 'sesion-1');
    expect(sent[0]['near'], {'lat': 11.54, 'lng': -72.9});
    // En Riohacha, Google recibe la ciudad: trae las calles de aquí.
    expect(sent[0]['input'], 'mue, Riohacha');
    expect(sent[1]['input'], 'muel', reason: 'sin ubicación no se inventa ciudad');
    expect(sent[1]['session'], 'sesion-1', reason: 'misma sesión al seguir escribiendo');

    final r = await svc.resolve(items.single);
    expect(r.latLng, const LatLng(11.5, -72.9));
    expect(r.fullAddress, 'Cl. 1');
    expect(sent[2], {'action': 'details', 'place_id': 'p1', 'session': 'sesion-1'});

    await svc.searchStrict('terminal');
    expect(sent[3]['session'], 'sesion-2', reason: 'después de elegir, sesión nueva');
  });

  test('la misma búsqueda otra vez no gasta otra petición (cuota diaria)',
      () async {
    var calls = 0;
    final svc = GeocodingService(invoke: (body) async {
      calls++;
      return {
        'items': [
          {'placeId': 'p1', 'name': 'Parque Padilla', 'address': 'Riohacha'},
        ]
      };
    });
    await svc.searchStrict('parque pad');
    await svc.searchStrict('Parque Pad ');
    expect(calls, 1);
    await svc.searchStrict('parque padi');
    expect(calls, 2);
  });

  test('un error de la función llega como GeocodingException (aviso D8)',
      () async {
    final svc = GeocodingService(
        invoke: (_) async => throw const GeocodingException('no_key'));
    expect(() => svc.searchStrict('muelle'),
        throwsA(isA<GeocodingException>().having((e) => e.code, 'code', 'no_key')));
    expect(await svc.search('muelle'), isEmpty);
  });

  test('ruta: a pie va como walk; puntos, km y minutos', () async {
    Map<String, dynamic>? sent;
    final r = await DirectionsService(invoke: (body) async {
      sent = body;
      return {
        'route': {
          'distance_m': 4200, 'duration_s': 754,
          'points': [[11.54, -72.9], [11.53, -72.91]],
        }
      };
    }).getRoute(
        origin: const LatLng(11.54, -72.9),
        destination: const LatLng(11.53, -72.91),
        profile: RouteProfile.walking);
    expect(sent!['mode'], 'walk');
    expect(r!.distanceKm, 4.2);
    expect(r.durationMin, 13);
    expect(r.legs.single.points.length, 2);
  });

  test('ruta: sin respuesta útil, null', () async {
    final r = await DirectionsService(
            invoke: (_) async => throw const GeocodingException('http_403'))
        .getRoute(
            origin: const LatLng(11.54, -72.9),
            destination: const LatLng(11.53, -72.91),
            profile: RouteProfile.driving);
    expect(r, isNull);
  });

  test('una dirección escrita se ubica con geocode y dice si es exacta', () async {
    final sent = <Map<String, dynamic>>[];
    final svc = GeocodingService(invoke: (body) async {
      sent.add(body);
      return {'place': {'lat': 11.54, 'lng': -72.91, 'address': 'Cl. 14 #10-20', 'exact': false}};
    });
    final g = await svc.geocodeAddress('Calle 14 # 10-20', near: const LatLng(11.54, -72.9));
    expect(sent.single['action'], 'geocode');
    expect(sent.single['input'], 'Calle 14 # 10-20, Riohacha');
    expect(g.placeName, 'Calle 14 # 10-20');
    expect(g.approximate, isTrue);
    expect(g.typedAddress, isTrue);
  });

  test('Text Search trae lugares con punto y la ciudad en la búsqueda', () async {
    final sent = <Map<String, dynamic>>[];
    final svc = GeocodingService(invoke: (body) async {
      sent.add(body);
      return {'items': [
        {'placeId': 'x', 'name': 'Cl. 24 #14-20', 'address': 'Riohacha',
         'types': ['street_address'], 'lat': 11.548, 'lng': -72.904},
      ]};
    });
    final items = await svc.textSearch('calle 24 # 14', proximity: const LatLng(11.54, -72.9));
    expect(sent.single['action'], 'textsearch');
    expect(sent.single['input'], 'calle 24 # 14, Riohacha');
    expect(items.single.latLng, const LatLng(11.548, -72.904));
    expect(items.single.featureType, 'address');
  });

  test('autocompletado + Text Search juntos, sin repetidos; si Text Search falla, queda el otro', () async {
    final svc = GeocodingService(invoke: (body) async {
      if (body['action'] == 'autocomplete') {
        return {'items': [
          {'placeId': 'p1', 'name': 'Muelle Turístico', 'address': 'Riohacha', 'types': ['tourist_attraction']},
        ]};
      }
      return {'items': [
        {'placeId': 'p2', 'name': 'Muelle Turístico', 'address': 'Riohacha', 'types': [], 'lat': 11.5449, 'lng': -72.9075},
        {'placeId': 'p3', 'name': 'Parque Padilla', 'address': 'Riohacha', 'types': [], 'lat': 11.5444, 'lng': -72.9072},
      ]};
    });
    final both = await ProviderPlaceSearch(svc).search('muelle', near: const LatLng(11.54, -72.9));
    expect(both.map((s) => s.placeName), ['Muelle Turístico', 'Parque Padilla']);

    final oldServer = GeocodingService(invoke: (body) async {
      if (body['action'] == 'autocomplete') {
        return {'items': [
          {'placeId': 'p1', 'name': 'Muelle Turístico', 'address': 'Riohacha', 'types': []},
        ]};
      }
      throw const GeocodingException('bad_request');
    });
    final onlyAuto = await ProviderPlaceSearch(oldServer).search('muelle');
    expect(onlyAuto.single.placeName, 'Muelle Turístico');
  });
}
