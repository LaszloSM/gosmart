import { assert, assertEquals } from '../ai-chat/test_assert.ts'
import {
  autocompleteBody,
  forwardGeocodeUrl,
  parseForwardGeocode,
  decodePolyline,
  detailsUrl,
  inColombia,
  parseAutocomplete,
  parseDetails,
  parseGeocode,
  parseNearby,
  parseRoute,
  routeBody,
  shortAddress,
} from './google.ts'

Deno.test('polilínea: el ejemplo de la documentación de Google', () => {
  assertEquals(decodePolyline('_p~iF~ps|U_ulLnnqC_mqNvxq`@'), [
    [38.5, -120.2],
    [40.7, -120.95],
    [43.252, -126.453],
  ])
  assertEquals(decodePolyline(''), [])
})

Deno.test('autocompletar: solo La Guajira, en español, ordenado desde la persona', () => {
  const b = autocompleteBody('muelle', null, 'tok-1')
  assertEquals(b.includedRegionCodes, ['co'])
  assertEquals(b.languageCode, 'es')
  assertEquals(b.sessionToken, 'tok-1')
  assertEquals(b.locationRestriction?.rectangle.low, { latitude: 10.3, longitude: -73.7 })
  const near = autocompleteBody('muelle', { lat: 11.54, lng: -72.9 })
  assertEquals(near.origin, { latitude: 11.54, longitude: -72.9 })
  assert(!('sessionToken' in near))
})

Deno.test('autocompletar: con ubicación prioriza la ciudad de la persona', () => {
  const near = autocompleteBody('calle 15', { lat: 11.54, lng: -72.9 })
  assertEquals(near.locationBias?.circle.center, { latitude: 11.54, longitude: -72.9 })
  assertEquals(near.locationBias?.circle.radius, 15000)
  assert(!('locationRestriction' in near))
  // Nombra otro municipio: toda La Guajira.
  const wide = autocompleteBody('hospital manaure', { lat: 11.54, lng: -72.9 }, undefined, true)
  assert(!('locationBias' in wide))
  assertEquals(wide.locationRestriction?.rectangle.high, { latitude: 12.6, longitude: -71.0 })
})

Deno.test('autocompletar: lee nombre y dirección, descarta lo incompleto', () => {
  const items = parseAutocomplete({
    suggestions: [
      {
        placePrediction: {
          placeId: 'abc',
          text: { text: 'Muelle Turístico, Riohacha, La Guajira' },
          structuredFormat: {
            mainText: { text: 'Muelle Turístico' },
            secondaryText: { text: 'Riohacha, La Guajira' },
          },
          types: ['tourist_attraction'],
        },
      },
      { queryPrediction: { text: { text: 'muelle' } } },
      { placePrediction: { text: { text: 'sin id' } } },
    ],
  })
  assertEquals(items, [{
    placeId: 'abc',
    name: 'Muelle Turístico',
    address: 'Riohacha, La Guajira',
    types: ['tourist_attraction'],
  }])
  assertEquals(parseAutocomplete({}), [])
})

Deno.test('detalle: coordenadas y dirección corta', () => {
  assertEquals(
    parseDetails({ location: { latitude: 11.5, longitude: -72.9 }, shortFormattedAddress: 'Cl. 1, Riohacha', formattedAddress: 'largo' }),
    { lat: 11.5, lng: -72.9, address: 'Cl. 1, Riohacha' },
  )
  assertEquals(parseDetails({ formattedAddress: 'x' }), null)
  assert(detailsUrl('a b', 's1').includes('/places/a%20b?'))
  assert(detailsUrl('id', 's1').includes('sessionToken=s1'))
})

Deno.test('ruta: a pie sin preferencia de tráfico; por la vía sin tráfico en vivo', () => {
  const a = { lat: 11.54, lng: -72.9 }, b = { lat: 11.38, lng: -72.24 }
  const walk = routeBody(a, b, 'walk')
  assertEquals(walk.travelMode, 'WALK')
  assert(!('routingPreference' in walk))
  const drive = routeBody(a, b, 'drive')
  assertEquals(drive.travelMode, 'DRIVE')
  assertEquals(drive.routingPreference, 'TRAFFIC_UNAWARE')
  assertEquals(drive.origin.location.latLng, { latitude: 11.54, longitude: -72.9 })
})

Deno.test('ruta: duración "123s", distancia y puntos', () => {
  const r = parseRoute({ routes: [{ duration: '754s', distanceMeters: 4200, polyline: { encodedPolyline: '_p~iF~ps|U' } }] })!
  assertEquals(r.duration_s, 754)
  assertEquals(r.distance_m, 4200)
  assertEquals(r.points, [[38.5, -120.2]])
  assertEquals(parseRoute({ routes: [] }), null)
  assertEquals(parseRoute({}), null)
})

Deno.test('solo puntos dentro de Colombia', () => {
  assert(inColombia({ lat: 11.54, lng: -72.9 }))
  assert(!inColombia({ lat: 40.4, lng: -3.7 }))
  assert(!inColombia({ lat: NaN, lng: -72 }))
})

Deno.test('dirección de un punto: calle corta o lugar cercano', () => {
  assertEquals(shortAddress('Cl. 2 #7-30, Riohacha, La Guajira, Colombia'), 'Cl. 2 #7-30, Riohacha')
  assertEquals(parseGeocode({ status: 'OK', results: [{ formatted_address: 'Cra. 7 #1-10, Riohacha, La Guajira, Colombia' }] }),
    'Cra. 7 #1-10, Riohacha')
  assertEquals(parseGeocode({ status: 'REQUEST_DENIED', results: [] }), null)
  assertEquals(parseNearby({ places: [{ displayName: { text: 'Parque Almirante Padilla' } }] }),
    'Cerca de Parque Almirante Padilla')
  assertEquals(parseNearby({ places: [{ displayName: { text: 'Tienda' }, shortFormattedAddress: 'Cl. 2 #7-08, Riohacha' }] }),
    'Cl. 2 #7-08, Riohacha')
  assertEquals(parseNearby({}), null)
})

Deno.test('dirección escrita: busca en Colombia y dice si es exacta', () => {
  const u = new URL(forwardGeocodeUrl('Calle 14 # 10-20, Riohacha', 'k'))
  assertEquals(u.searchParams.get('address'), 'Calle 14 # 10-20, Riohacha')
  assertEquals(u.searchParams.get('components'), 'country:CO')
  const ok = parseForwardGeocode({
    status: 'OK',
    results: [{
      formatted_address: 'Cl. 14 #10-20, Riohacha, La Guajira, Colombia',
      geometry: { location: { lat: 11.54, lng: -72.91 }, location_type: 'RANGE_INTERPOLATED' },
    }],
  })
  assertEquals(ok, { lat: 11.54, lng: -72.91, address: 'Cl. 14 #10-20, Riohacha', exact: true })
  const street = parseForwardGeocode({
    status: 'OK',
    results: [{ formatted_address: 'Cl. 14, Riohacha', geometry: { location: { lat: 11.54, lng: -72.91 }, location_type: 'GEOMETRIC_CENTER' } }],
  })
  assertEquals(street?.exact, false)
  // Fuera de La Guajira no sirve.
  assertEquals(parseForwardGeocode({
    status: 'OK',
    results: [{ formatted_address: 'Bogotá', geometry: { location: { lat: 4.6, lng: -74.08 }, location_type: 'ROOFTOP' } }],
  }), null)
  assertEquals(parseForwardGeocode({ status: 'ZERO_RESULTS', results: [] }), null)
})
