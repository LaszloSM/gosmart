// backend/functions/maps/google.ts
// Armado y lectura de las llamadas a Google (Places API New y Routes API).
// Sin red ni imports remotos: se prueba con `deno test google_test.ts`.
//
// Búsqueda = Autocomplete (New) + Place Details al elegir, con el mismo
// sessionToken: Google cobra la sesión, no cada letra escrita.

export type LatLng = { lat: number; lng: number }

export type Suggestion = {
  placeId: string
  name: string
  address: string
  types: string[]
}

export type Place = { lat: number; lng: number; address: string }

export type Route = {
  distance_m: number
  duration_s: number
  points: [number, number][]
}

/// Centro aproximado entre Riohacha y Maicao: sesgo cuando no hay GPS.
export const GUAJIRA_CENTER: LatLng = { lat: 11.46, lng: -72.57 }

/// Solo Colombia (con margen): evita gastar cuota en búsquedas de otro lado.
export function inColombia(p: LatLng): boolean {
  return Number.isFinite(p.lat) && Number.isFinite(p.lng) &&
    p.lat >= -4.5 && p.lat <= 13.5 && p.lng >= -82 && p.lng <= -66.5
}

export const AUTOCOMPLETE_URL = 'https://places.googleapis.com/v1/places:autocomplete'
export const DETAILS_FIELDS = 'id,location,formattedAddress,shortFormattedAddress'
export const ROUTES_URL = 'https://routes.googleapis.com/directions/v2:computeRoutes'
export const ROUTE_FIELDS =
  'routes.duration,routes.distanceMeters,routes.polyline.encodedPolyline'

export function detailsUrl(placeId: string, session?: string): string {
  const q = new URLSearchParams({ languageCode: 'es', regionCode: 'co' })
  if (session) q.set('sessionToken', session)
  return `https://places.googleapis.com/v1/places/${encodeURIComponent(placeId)}?${q}`
}

export function autocompleteBody(input: string, near?: LatLng | null, session?: string) {
  const c = near ?? GUAJIRA_CENTER
  return {
    input,
    languageCode: 'es',
    regionCode: 'co',
    includedRegionCodes: ['co'],
    // Con GPS, cerca de la persona; sin GPS, todo el corredor (máx. 50 km).
    locationBias: {
      circle: {
        center: { latitude: c.lat, longitude: c.lng },
        radius: near ? 30000 : 50000,
      },
    },
    ...(session ? { sessionToken: session } : {}),
  }
}

// deno-lint-ignore no-explicit-any
export function parseAutocomplete(json: any): Suggestion[] {
  const out: Suggestion[] = []
  for (const s of json?.suggestions ?? []) {
    const p = s?.placePrediction
    if (!p?.placeId) continue
    const name = p.structuredFormat?.mainText?.text ?? p.text?.text ?? ''
    if (!name) continue
    out.push({
      placeId: String(p.placeId),
      name: String(name),
      address: String(p.structuredFormat?.secondaryText?.text ?? ''),
      types: Array.isArray(p.types) ? p.types.map(String) : [],
    })
  }
  return out.slice(0, 6)
}

// deno-lint-ignore no-explicit-any
export function parseDetails(json: any): Place | null {
  const lat = json?.location?.latitude, lng = json?.location?.longitude
  if (typeof lat !== 'number' || typeof lng !== 'number') return null
  return { lat, lng, address: String(json.shortFormattedAddress ?? json.formattedAddress ?? '') }
}

export type RouteMode = 'walk' | 'drive'

export function routeBody(from: LatLng, to: LatLng, mode: RouteMode) {
  const point = (p: LatLng) => ({ location: { latLng: { latitude: p.lat, longitude: p.lng } } })
  return {
    origin: point(from),
    destination: point(to),
    // Mototaxi, taxi y carro van por la vía. TWO_WHEELER no está en todos
    // los países; DRIVE sí.
    travelMode: mode === 'walk' ? 'WALK' : 'DRIVE',
    // Sin tráfico en vivo: es el nivel más barato de Routes.
    ...(mode === 'drive' ? { routingPreference: 'TRAFFIC_UNAWARE' } : {}),
    languageCode: 'es-419',
    units: 'METRIC',
  }
}

// deno-lint-ignore no-explicit-any
export function parseRoute(json: any): Route | null {
  const r = json?.routes?.[0]
  const enc = r?.polyline?.encodedPolyline
  if (!r || typeof enc !== 'string') return null
  const dur = parseFloat(String(r.duration ?? '0').replace(/s$/, ''))
  return {
    distance_m: Number(r.distanceMeters ?? 0),
    duration_s: Number.isFinite(dur) ? dur : 0,
    points: decodePolyline(enc),
  }
}

/// Polilínea codificada de Google → [lat, lng] (precisión 1e-5).
export function decodePolyline(s: string): [number, number][] {
  const pts: [number, number][] = []
  let i = 0, lat = 0, lng = 0
  const next = () => {
    let result = 0, shift = 0, b: number
    do {
      b = s.charCodeAt(i++) - 63
      result |= (b & 0x1f) << shift
      shift += 5
    } while (b >= 0x20 && i < s.length)
    return result & 1 ? ~(result >> 1) : result >> 1
  }
  while (i < s.length) {
    lat += next()
    lng += next()
    pts.push([lat / 1e5, lng / 1e5])
  }
  return pts
}

// ── Dirección de un punto (geocodificación inversa) ─────────────────────────
// Primero Geocoding API (calle y número); si no está habilitada o no hay
// resultado, el lugar conocido más cercano con Places API (New), que ya se usa.

export const GEOCODE_URL = 'https://maps.googleapis.com/maps/api/geocode/json'

export function geocodeUrl(p: LatLng, key: string): string {
  const q = new URLSearchParams({
    latlng: `${p.lat},${p.lng}`,
    language: 'es',
    result_type: 'street_address|premise|route|intersection',
    key,
  })
  return `${GEOCODE_URL}?${q}`
}

/// "Cl. 2 #7-30, Riohacha, La Guajira, Colombia" → "Cl. 2 #7-30, Riohacha".
export function shortAddress(a: string): string {
  return a.replace(/,?\s*(La Guajira|Colombia)\b/g, '').replace(/,\s*\d{5,6}\b/g, '').trim()
}

// deno-lint-ignore no-explicit-any
export function parseGeocode(json: any): string | null {
  if (json?.status !== 'OK') return null
  const a = json.results?.[0]?.formatted_address
  return typeof a === 'string' && a ? shortAddress(a) : null
}

export const NEARBY_URL = 'https://places.googleapis.com/v1/places:searchNearby'
export const NEARBY_FIELDS = 'places.displayName,places.shortFormattedAddress'

export function nearbyBody(p: LatLng) {
  return {
    maxResultCount: 1,
    rankPreference: 'DISTANCE',
    languageCode: 'es',
    regionCode: 'co',
    locationRestriction: {
      circle: { center: { latitude: p.lat, longitude: p.lng }, radius: 120 },
    },
  }
}

/// "Parque Almirante Padilla" (o su dirección corta si no tiene nombre).
// deno-lint-ignore no-explicit-any
export function parseNearby(json: any): string | null {
  const pl = json?.places?.[0]
  const name = pl?.displayName?.text
  if (typeof name === 'string' && name) return `Cerca de ${name}`
  const a = pl?.shortFormattedAddress
  return typeof a === 'string' && a ? shortAddress(a) : null
}
