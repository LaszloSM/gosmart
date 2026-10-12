// backend/functions/ai-chat/index.ts
// GoSmart AI — proxy de Groq para Riohacha, Maicao y el corredor.
// La key de Groq vive solo aquí (secret GROQ_API_KEY), nunca en el APK.
// Flujo: lugares del KG (FTS sobre alias) → prompt corto → Groq 8b → (respaldo 70b)

import { serve }        from 'https://deno.land/std@0.208.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { normalize }    from './normalizer.ts'
import { exactMatch, KgEntity } from './retrieval.ts'
import { buildContext, buildSystemPrompt } from './context_builder.ts'

const GROQ_URL      = 'https://api.groq.com/openai/v1/chat/completions'
// El 8b tiene cuota diaria mucho mayor que el 70b en el plan gratis (E1).
const PRIMARY_MODEL  = 'llama-3.1-8b-instant'
const FALLBACK_MODEL = 'llama-3.3-70b-versatile'
const GROQ_TIMEOUT   = 12_000
const MAX_HISTORY    = 6
const MAX_CLIENT_CONTEXT_CHARS = 1500

const CORS = {
  'Access-Control-Allow-Origin':  '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Content-Type': 'application/json',
}

type Turn = { role: string; content: string }

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })

  const t0 = Date.now()

  try {
    const { query, history = [], client_context = '' } = await req.json()
    if (typeof query !== 'string' || !query.trim()) {
      return json({ content: '¿En qué te ayudo?', source: 'system', latency_ms: 0 })
    }

    const groqKey = Deno.env.get('GROQ_API_KEY')
    if (!groqKey) {
      return json({
        content: 'El asistente no está configurado todavía. Usa el planificador mientras tanto.',
        source: 'system',
        error: 'missing_key',
        latency_ms: Date.now() - t0,
      })
    }

    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_ANON_KEY')!,
    )

    const nq = normalize(query)
    const entities: KgEntity[] = await exactMatch(supabase, nq.normalized, nq.city)

    const systemPrompt = buildSystemPrompt(
      buildContext(entities),
      String(client_context).slice(0, MAX_CLIENT_CONTEXT_CHARS),
    )
    const turns: Turn[] = (Array.isArray(history) ? history : [])
      .filter((t: Turn) => (t?.role === 'user' || t?.role === 'assistant') && typeof t.content === 'string')
      .slice(-MAX_HISTORY)

    const result = await callGroqWithFallback(systemPrompt, turns, query, groqKey)

    return json({
      content:       result.content,
      source:        result.ok ? 'groq' : 'error',
      model:         result.model,
      error:         result.ok ? undefined : result.error,
      entities_used: entities.map(e => e.canonical_name),
      latency_ms:    Date.now() - t0,
    })
  } catch (err) {
    console.error('[ai-chat] unhandled error:', err)
    return json({
      content: 'El asistente no está disponible ahora. Puedes planear tu viaje desde el mapa.',
      source: 'error',
      error: 'unhandled',
      latency_ms: Date.now() - t0,
    }, 500)
  }
})

// ── Helpers ───────────────────────────────────────────────────────────────────

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { headers: CORS, status })
}

type GroqResult = { ok: boolean; content: string; model: string; error?: string }

const UNAVAILABLE =
  'El asistente no está disponible ahora. Puedes planear tu viaje desde el mapa.'

// Intenta el modelo principal; si Groq responde 429 (cuota) o 5xx, usa el 70b una vez.
async function callGroqWithFallback(
  systemPrompt: string,
  history: Turn[],
  query: string,
  key: string,
): Promise<GroqResult> {
  const first = await callGroq(PRIMARY_MODEL, systemPrompt, history, query, key)
  if (first.ok) return first
  if (first.error === 'rate_limited' || first.error === 'server_error') {
    return await callGroq(FALLBACK_MODEL, systemPrompt, history, query, key)
  }
  return first
}

async function callGroq(
  model: string,
  systemPrompt: string,
  history: Turn[],
  query: string,
  key: string,
): Promise<GroqResult> {
  const controller = new AbortController()
  const timer = setTimeout(() => controller.abort(), GROQ_TIMEOUT)
  try {
    const res = await fetch(GROQ_URL, {
      method: 'POST',
      headers: { 'Authorization': `Bearer ${key}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model,
        messages: [
          { role: 'system', content: systemPrompt },
          ...history,
          { role: 'user', content: query },
        ],
        max_tokens: 450,
        temperature: 0.5,
      }),
      signal: controller.signal,
    })
    if (!res.ok) {
      console.error('[Groq]', model, res.status, await res.text())
      const error = res.status === 429 ? 'rate_limited'
        : res.status >= 500 ? 'server_error' : 'bad_request'
      return { ok: false, content: UNAVAILABLE, model, error }
    }
    const data = await res.json()
    const content = data.choices?.[0]?.message?.content
    if (typeof content !== 'string' || !content.trim()) {
      return { ok: false, content: UNAVAILABLE, model, error: 'empty_response' }
    }
    return { ok: true, content, model }
  } catch (err) {
    const error = err instanceof DOMException && err.name === 'AbortError' ? 'timeout' : 'network'
    console.error('[Groq]', model, error)
    return { ok: false, content: UNAVAILABLE, model, error }
  } finally {
    clearTimeout(timer)
  }
}
