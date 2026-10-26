// backend/functions/maps/index.ts
// Proxy de Google Maps Platform para la app: la clave nunca va en el APK.
//   { action: 'autocomplete', input, near?: {lat,lng}, session? } → { items }
//   { action: 'details', place_id, session? }                    → { place }
//   { action: 'route', from, to, mode: 'walk'|'drive' }           → { route }
//   { action: 'reverse', at: {lat,lng} }                          → { address }
// Errores como { error: 'no_key' | 'bad_request' | 'http_<n>' | 'not_found' }
// con 200, para que la app degrade con aviso (D8).
// Secret: GOOGLE_MAPS_SERVER_KEY (Places API New + Routes API habilitadas).
// Se despliega CON verificación de JWT: el anon key de la app basta.

import { serve } from 'https://deno.land/std@0.208.0/http/server.ts'
import {
  AUTOCOMPLETE_URL,
  autocompleteBody,
  DETAILS_FIELDS,
  detailsUrl,
  geocodeUrl,
  NEARBY_FIELDS,
  NEARBY_URL,
  nearbyBody,
  parseGeocode,
  parseNearby,
  inColombia,
  LatLng,
  parseAutocomplete,
  parseDetails,
  parseRoute,
  ROUTE_FIELDS,
  routeBody,
  ROUTES_URL,
} from './google.ts'

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}
const json = (b: unknown) =>
  new Response(JSON.stringify(b), { headers: { ...CORS, 'Content-Type': 'application/json' } })

// deno-lint-ignore no-explicit-any
const point = (v: any): LatLng | null => {
  const p = { lat: Number(v?.lat), lng: Number(v?.lng) }
  return inColombia(p) ? p : null
}
const token = (v: unknown) =>
  typeof v === 'string' && /^[A-Za-z0-9_-]{8,64}$/.test(v) ? v : undefined

async function google(url: string, key: string, fields: string, body?: unknown) {
  const res = await fetch(url, {
    method: body ? 'POST' : 'GET',
    headers: {
      'X-Goog-Api-Key': key,
      ...(fields ? { 'X-Goog-FieldMask': fields } : {}),
      ...(body ? { 'Content-Type': 'application/json' } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
    signal: AbortSignal.timeout(10000),
  })
  if (!res.ok) {
    console.error('google', res.status, (await res.text()).slice(0, 300))
    return { error: `http_${res.status}` }
  }
  return { data: await res.json() }
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })
  const key = Deno.env.get('GOOGLE_MAPS_SERVER_KEY')
  if (!key) return json({ error: 'no_key' })

  // deno-lint-ignore no-explicit-any
  const b: any = await req.json().catch(() => ({}))
  try {
    switch (b.action) {
      case 'autocomplete': {
        const input = String(b.input ?? '').trim()
        if (input.length < 2 || input.length > 120) return json({ items: [] })
        const near = b.near ? point(b.near) : null
        const r = await google(AUTOCOMPLETE_URL, key, '', autocompleteBody(input, near, token(b.session)))
        return json(r.error ? { error: r.error } : { items: parseAutocomplete(r.data) })
      }
      case 'details': {
        const id = String(b.place_id ?? '')
        if (!/^[A-Za-z0-9_-]{1,300}$/.test(id)) return json({ error: 'bad_request' })
        const r = await google(detailsUrl(id, token(b.session)), key, DETAILS_FIELDS)
        if (r.error) return json({ error: r.error })
        const place = parseDetails(r.data)
        return json(place ? { place } : { error: 'not_found' })
      }
      case 'route': {
        const from = point(b.from), to = point(b.to)
        if (!from || !to) return json({ error: 'bad_request' })
        const mode = b.mode === 'walk' ? 'walk' : 'drive'
        const r = await google(ROUTES_URL, key, ROUTE_FIELDS, routeBody(from, to, mode))
        if (r.error) return json({ error: r.error })
        const route = parseRoute(r.data)
        return json(route ? { route } : { error: 'not_found' })
      }
      case 'reverse': {
        const at = point(b.at)
        if (!at) return json({ error: 'bad_request' })
        try {
          const res = await fetch(geocodeUrl(at, key), { signal: AbortSignal.timeout(8000) })
          const address = res.ok ? parseGeocode(await res.json()) : null
          if (address) return json({ address })
        } catch (_) { /* sigue con Places */ }
        const r = await google(NEARBY_URL, key, NEARBY_FIELDS, nearbyBody(at))
        if (r.error) return json({ error: r.error })
        const address = parseNearby(r.data)
        return json(address ? { address } : { error: 'not_found' })
      }
      default:
        return json({ error: 'bad_request' })
    }
  } catch (e) {
    console.error('maps', e)
    return json({ error: e instanceof DOMException ? 'timeout' : 'internal' })
  }
})
