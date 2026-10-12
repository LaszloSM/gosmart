import { assert, assertEquals } from '../ai-chat/test_assert.ts'
import { fcmMessage, noticeFor, signJwt } from './fcm.ts'

Deno.test('aviso de viaje para conductores, con tarifa y origen', () => {
  const n = noticeFor('ride_requests', { id: 'r1', status: 'open', offered_fare: 5000, origin_label: 'Parque Padilla' })!
  assert(n.title.includes('5.000'))
  assert(n.body.includes('Parque Padilla'))
  assertEquals(n.data, { type: 'ride_request', id: 'r1' })
})

Deno.test('reportes: solo los que complican la vía; nunca nombres', () => {
  assertEquals(noticeFor('road_reports', { id: 'x', kind: 'hueco', segment_id: 's' }), null)
  assertEquals(noticeFor('road_reports', { id: 'x', kind: 'despejado', segment_id: 's' }), null)
  const n = noticeFor('road_reports', { id: 'x', kind: 'bloqueo', segment_id: 'troncal-30-40' })!
  assert(n.body.includes('Sin confirmar'))
  assertEquals(noticeFor('ride_requests', { status: 'accepted' }), null)
})

Deno.test('mensaje FCM v1 con prioridad alta', () => {
  const m = fcmMessage('tok', { title: 't', body: 'b', data: { a: '1' } })
  assertEquals(m.message.android.priority, 'HIGH')
  assertEquals(m.message.token, 'tok')
})

Deno.test('el JWT se firma con RS256 y verifica con la llave pública', async () => {
  const kp = await crypto.subtle.generateKey(
    { name: 'RSASSA-PKCS1-v1_5', modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: 'SHA-256' },
    true, ['sign', 'verify'])
  const pk8 = new Uint8Array(await crypto.subtle.exportKey('pkcs8', kp.privateKey))
  const pem = `-----BEGIN PRIVATE KEY-----\n${btoa(String.fromCharCode(...pk8))}\n-----END PRIVATE KEY-----\n`
  const jwt = await signJwt({ client_email: 'a@b.iam', private_key: pem, project_id: 'p' }, 1700000000)
  const [h, c, s] = jwt.split('.')
  const claims = JSON.parse(atob(c.replace(/-/g, '+').replace(/_/g, '/')))
  assertEquals(claims.iss, 'a@b.iam')
  assertEquals(claims.exp - claims.iat, 3600)
  const pad = (x: string) => x.replace(/-/g, '+').replace(/_/g, '/') + '='.repeat((4 - x.length % 4) % 4)
  const sig = Uint8Array.from(atob(pad(s)), (ch) => ch.charCodeAt(0))
  assert(await crypto.subtle.verify('RSASSA-PKCS1-v1_5', kp.publicKey, sig,
    new TextEncoder().encode(`${h}.${c}`)))
})
