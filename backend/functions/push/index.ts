// backend/functions/push/index.ts
// Envía push con FCM cuando entra una fila nueva (Database Webhook de Supabase
// en INSERT de ride_requests y road_reports, con el header x-webhook-secret).
// Secrets: FCM_SERVICE_ACCOUNT (JSON de la cuenta de servicio de Firebase),
//          PUSH_WEBHOOK_SECRET, SUPABASE_SERVICE_ROLE_KEY.
// Desplegar con --no-verify-jwt (el webhook trae su propio secreto).

import { serve } from 'https://deno.land/std@0.208.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { fcmMessage, noticeFor, ServiceAccount, signJwt } from './fcm.ts'

const json = (b: unknown, status = 200) =>
  new Response(JSON.stringify(b), { status, headers: { 'Content-Type': 'application/json' } })

let cachedToken: { value: string; exp: number } | null = null

async function accessToken(sa: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000)
  if (cachedToken && cachedToken.exp > now + 60) return cachedToken.value
  const res = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: await signJwt(sa, now),
    }),
  })
  const data = await res.json()
  cachedToken = { value: data.access_token, exp: now + (data.expires_in ?? 3600) }
  return cachedToken.value
}

serve(async (req) => {
  const secret = Deno.env.get('PUSH_WEBHOOK_SECRET')
  if (!secret || req.headers.get('x-webhook-secret') !== secret) return json({ error: 'unauthorized' }, 401)
  const saRaw = Deno.env.get('FCM_SERVICE_ACCOUNT')
  if (!saRaw) return json({ ok: true, skipped: 'not_configured' })

  const { type, table, record } = await req.json().catch(() => ({}))
  if (type !== 'INSERT' || !record) return json({ ok: true, skipped: 'ignored' })
  const notice = noticeFor(String(table), record)
  if (!notice) return json({ ok: true, skipped: 'no_notice' })

  const db = createClient(Deno.env.get('SUPABASE_URL')!, Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!)
  const fn = table === 'ride_requests' ? 'push_targets_for_request' : 'push_targets_for_report'
  const arg = table === 'ride_requests' ? { p_request_id: record.id } : { p_report_id: record.id }
  const { data: targets, error } = await db.rpc(fn, arg)
  if (error) return json({ error: 'targets_failed' }, 500)

  const sa = JSON.parse(saRaw) as ServiceAccount
  const token = await accessToken(sa)
  let sent = 0, stale = 0
  for (const t of (targets ?? []) as Array<{ token: string }>) {
    const res = await fetch(`https://fcm.googleapis.com/v1/projects/${sa.project_id}/messages:send`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}`, 'Content-Type': 'application/json' },
      body: JSON.stringify(fcmMessage(t.token, notice)),
    })
    if (res.ok) sent++
    else if (res.status === 404 || res.status === 400) {
      // Token vencido o desinstalado: se borra.
      stale++
      await db.from('push_tokens').delete().eq('token', t.token)
    }
  }
  return json({ ok: true, sent, stale })
})
