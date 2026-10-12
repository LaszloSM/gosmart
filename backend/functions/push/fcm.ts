// backend/functions/push/fcm.ts
// FCM HTTP v1 sin imports remotos: token OAuth firmando un JWT RS256 con la
// cuenta de servicio, y mensajes de GoSmart. Probado en fcm_test.ts.

export type ServiceAccount = { client_email: string; private_key: string; project_id: string }

const b64url = (b: Uint8Array | string) => {
  const bytes = typeof b === 'string' ? new TextEncoder().encode(b) : b
  let s = ''
  for (const x of bytes) s += String.fromCharCode(x)
  return btoa(s).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/, '')
}

export async function signJwt(sa: ServiceAccount, nowSec: number): Promise<string> {
  const header = b64url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }))
  const claims = b64url(JSON.stringify({
    iss: sa.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: nowSec,
    exp: nowSec + 3600,
  }))
  const pem = sa.private_key.replace(/-----[^-]+-----/g, '').replace(/\s+/g, '')
  const der = Uint8Array.from(atob(pem), (c) => c.charCodeAt(0))
  const key = await crypto.subtle.importKey('pkcs8', der,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' }, false, ['sign'])
  const sig = new Uint8Array(await crypto.subtle.sign('RSASSA-PKCS1-v1_5', key,
    new TextEncoder().encode(`${header}.${claims}`)))
  return `${header}.${claims}.${b64url(sig)}`
}

export type Notice = { title: string; body: string; data: Record<string, string> }

const KIND_WORD: Record<string, string> = {
  bloqueo: 'Bloqueo', reten: 'Retén', accidente: 'Accidente', inundacion: 'Inundación',
}

/** Qué decir según la fila insertada. null = no se avisa. */
export function noticeFor(table: string, record: Record<string, unknown>): Notice | null {
  if (table === 'ride_requests' && record.status === 'open') {
    const fare = Number(record.offered_fare)
    return {
      title: `Viaje cerca por $${fare.toLocaleString('es-CO')}`,
      body: `Desde ${record.origin_label ?? 'un punto cercano'}. Abre GoSmart para aceptarlo.`,
      data: { type: 'ride_request', id: String(record.id) },
    }
  }
  if (table === 'road_reports' && KIND_WORD[String(record.kind)]) {
    return {
      title: `${KIND_WORD[String(record.kind)]} reportado en la Troncal`,
      body: 'Revisa el estado de la vía antes de seguir. Sin confirmar todavía.',
      data: { type: 'road_report', id: String(record.id), segment: String(record.segment_id) },
    }
  }
  return null
}

export function fcmMessage(token: string, n: Notice) {
  return {
    message: {
      token,
      notification: { title: n.title, body: n.body },
      data: n.data,
      android: { priority: 'HIGH' },
    },
  }
}
