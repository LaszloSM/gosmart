// backend/functions/wompi/signing.ts
// Firmas de Wompi (sin imports remotos, para probarlas donde deno.land está bloqueado).
//   Integridad del checkout: SHA256(referencia + monto_en_centavos + moneda + secreto_integridad)
//   Evento (webhook): SHA256(valores de signature.properties en orden + timestamp + secreto_eventos)
// Referencia: docs.wompi.co (Widget & Checkout Web, Eventos). NO verificado contra
// el sandbox real desde este entorno: probar con llaves de prueba antes del piloto.

export async function sha256Hex(s: string): Promise<string> {
  const buf = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(s))
  return [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, '0')).join('')
}

export function integrityPayload(reference: string, amountInCents: number,
                                 currency: string, secret: string): string {
  return `${reference}${amountInCents}${currency}${secret}`
}

export async function integritySignature(reference: string, amountInCents: number,
                                         currency: string, secret: string): Promise<string> {
  return sha256Hex(integrityPayload(reference, amountInCents, currency, secret))
}

/** Lee un camino 'transaction.amount_in_cents' dentro de event.data. */
export function pick(data: unknown, path: string): unknown {
  return path.split('.').reduce<unknown>(
    (o, k) => (o && typeof o === 'object' ? (o as Record<string, unknown>)[k] : undefined),
    data)
}

export type WompiEvent = {
  event?: string
  data?: { transaction?: Record<string, unknown> }
  signature?: { properties?: string[]; checksum?: string }
  timestamp?: number
}

/** true si el checksum del evento coincide (comparación en tiempo constante). */
export async function verifyEvent(ev: WompiEvent, eventsSecret: string): Promise<boolean> {
  const props = ev.signature?.properties
  const checksum = ev.signature?.checksum
  if (!Array.isArray(props) || props.length === 0 || typeof checksum !== 'string' ||
      typeof ev.timestamp !== 'number') return false
  const values = props.map((p) => String(pick(ev.data, p) ?? '')).join('')
  const expected = await sha256Hex(`${values}${ev.timestamp}${eventsSecret}`)
  return timingSafeEqual(expected, checksum.toLowerCase())
}

function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false
  let diff = 0
  for (let i = 0; i < a.length; i++) diff |= a.charCodeAt(i) ^ b.charCodeAt(i)
  return diff === 0
}

/** URL del Web Checkout de Wompi. */
export function checkoutUrl(o: {
  publicKey: string; reference: string; amountInCents: number; signature: string
  redirectUrl?: string
}): string {
  const q = new URLSearchParams({
    'public-key': o.publicKey,
    currency: 'COP',
    'amount-in-cents': String(o.amountInCents),
    reference: o.reference,
    'signature:integrity': o.signature,
  })
  if (o.redirectUrl) q.set('redirect-url', o.redirectUrl)
  return `https://checkout.wompi.co/p/?${q.toString()}`
}
