// backend/functions/wompi/index.ts
// Recargas de la billetera con Wompi (sandbox, Fase 7).
//   POST {action:'checkout', amount}  (con sesión)  → { url, reference }
//   POST (evento de Wompi, sin sesión)              → acredita si la firma es válida
// Secrets: WOMPI_PUBLIC_KEY, WOMPI_INTEGRITY_SECRET, WOMPI_EVENTS_SECRET,
//          SUPABASE_SERVICE_ROLE_KEY (para crear y liquidar recargas).
// Se despliega con --no-verify-jwt: el webhook de Wompi no trae JWT; el
// checkout valida la sesión a mano.

import { serve } from 'https://deno.land/std@0.208.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { checkoutUrl, integritySignature, verifyEvent, WompiEvent } from './signing.ts'

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Content-Type': 'application/json',
}
const json = (b: unknown, status = 200) => new Response(JSON.stringify(b), { status, headers: CORS })

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })
  if (req.method !== 'POST') return json({ error: 'method' }, 405)

  const url = Deno.env.get('SUPABASE_URL')!
  const service = createClient(url, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!)
  const body = await req.json().catch(() => ({}))

  // ── Webhook de Wompi ───────────────────────────────────────────────────────
  if (body && typeof body === 'object' && 'signature' in body) {
    const ev = body as WompiEvent
    const secret = Deno.env.get('WOMPI_EVENTS_SECRET')
    if (!secret || !(await verifyEvent(ev, secret))) return json({ error: 'bad_signature' }, 401)
    if (ev.event !== 'transaction.updated') return json({ ok: true, ignored: ev.event })
    const t = ev.data?.transaction ?? {}
    const cents = Number(t.amount_in_cents)
    const { data, error } = await service.rpc('wallet_topup_settle', {
      p_reference: String(t.reference ?? ''),
      p_status: String(t.status ?? ''),
      p_amount: Number.isFinite(cents) ? Math.round(cents / 100) : -1,
      p_provider_id: String(t.id ?? ''),
    })
    if (error) return json({ error: 'settle_failed' }, 500)
    // 200 aunque la referencia sea desconocida: Wompi no debe reintentar sin fin.
    return json({ ok: true, result: data })
  }

  // ── Crear checkout ─────────────────────────────────────────────────────────
  if (body?.action === 'checkout') {
    const pub = Deno.env.get('WOMPI_PUBLIC_KEY')
    const integrity = Deno.env.get('WOMPI_INTEGRITY_SECRET')
    if (!pub || !integrity) return json({ error: 'not_configured' }, 503)

    const auth = req.headers.get('Authorization') ?? ''
    const userClient = createClient(url, Deno.env.get('SUPABASE_ANON_KEY')!, {
      global: { headers: { Authorization: auth } },
    })
    const { data: { user } } = await userClient.auth.getUser()
    if (!user) return json({ error: 'unauthorized' }, 401)

    const amount = Math.round(Number(body.amount))
    if (!Number.isFinite(amount) || amount < 1000 || amount > 500000) {
      return json({ error: 'invalid_amount' }, 400)
    }
    const { data: reference, error } = await service.rpc('wallet_topup_create', {
      p_user: user.id, p_amount: amount,
    })
    if (error || typeof reference !== 'string') return json({ error: 'create_failed' }, 500)
    const cents = amount * 100
    const signature = await integritySignature(reference, cents, 'COP', integrity)
    return json({
      reference,
      url: checkoutUrl({ publicKey: pub, reference, amountInCents: cents, signature,
                         redirectUrl: typeof body.redirect_url === 'string' ? body.redirect_url : undefined }),
    })
  }

  return json({ error: 'unknown_action' }, 400)
})
