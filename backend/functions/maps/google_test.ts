import { assert, assertEquals } from '../ai-chat/test_assert.ts'
import {
  autocompleteBody,
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

Deno.test('autocompletar: solo Colombia, en español, sesgo al corredor sin GPS', () => {
  const b = autocompleteBody('muelle', null, 'tok-1')
  assertEquals(b.includedRegionCodes, ['co'])
  assertEquals(b.languageCode, 'es')
  assertEquals(b.sessionToken, 'tok-1')
  assertEquals(b.locationBias.circle.radius, 50000)
  const near = autocompleteBody('muelle', { lat: 11.54, lng: -72.9 })
  assertEquals(near.locationBias.circle.center, { latitude: 11.54, longitude: -72.9 })
  assert(!('sessionToken' in near))
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
  assertEquals(parseNearby({}), null)
})
