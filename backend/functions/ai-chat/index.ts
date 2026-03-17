// backend/functions/ai-chat/index.ts
// GoSmart AI — RAG Colombia v3
// Flujo: Normalizer → City detect → Exact match → Semantic search → Groq
// Keys: OPENAI_API_KEY + GROQ_API_KEY en Supabase Edge Functions secrets

import { serve }        from 'https://deno.land/std@0.208.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { normalize }    from './normalizer.ts'
import { exactMatch, semanticSearch, embedQuery, KgEntity } from './retrieval.ts'
import { buildContext, buildSystemPrompt, buildFallbackPrompt } from './context_builder.ts'

const GROQ_URL     = 'https://api.groq.com/openai/v1/chat/completions'
const GROQ_MODEL   = 'llama-3.1-8b-instant'
const GROQ_TIMEOUT = 12_000
const SIM_THRESHOLD = 0.35

const CORS = {
  'Access-Control-Allow-Origin':  '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Content-Type': 'application/json',
}

serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS })

  const t0 = Date.now()

  try {
    const { query, city_hint, history = [] } = await req.json()
    if (!query?.trim()) return json({ content: '¿En qué puedo ayudarte?', fallback: false })

    // SERVICE_ROLE_KEY (no anon): necesario para escribir en rag_fallback_log
    // que no tiene policy INSERT para anon. Las tablas colombia_kg tienen
    // policy SELECT pública — service_role también puede leerlas sin RLS.
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL')!,
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    )
    const groqKey = Deno.env.get('GROQ_API_KEY')!

    // 1 + 2. Normalize + detect city (city_hint overrides auto-detect)
    const nq = normalize(query, city_hint)

    // Only block address/station/neighborhood/route queries that need a city context.
    // General and fare queries can proceed without one.
    const needsCity = ['address', 'station', 'neighborhood', 'route'].includes(nq.intent)
    if (nq.city_confidence === 'none' && needsCity) {
      return json({
        content: '¿En qué ciudad estás? Necesito saberlo para darte información precisa sobre transporte.',
        source: 'system',
        fallback: true,
        latency_ms: Date.now() - t0,
      })
    }

    // 3. Exact match (siempre corre)
    const exactHits = await exactMatch(supabase, nq.normalized, nq.city)

    // 4. Semantic search (solo si exact match vacío)
    let semanticHits: KgEntity[] = []
    let usedFallback = false

    if (exactHits.length === 0) {
      try {
        const embedding = await embedQuery(nq.normalized)
        semanticHits = await semanticSearch(supabase, embedding, nq.city, SIM_THRESHOLD)
      } catch (err) {
        console.error('[RAG] embed/semantic failed:', err)
        usedFallback = true
        await logFallback(supabase, query, nq.normalized, nq.city, 0, 'no_match')
      }
    }

    // 5. Dedup + merge
    const exactIds = new Set(exactHits.map(e => e.id))
    const allEntities = dedup([...exactHits, ...semanticHits])

    if (allEntities.length === 0 && !usedFallback) {
      const topSim = semanticHits[0]?.similarity ?? 0
      await logFallback(supabase, query, nq.normalized, nq.city, topSim, 'low_similarity')
    }

    // 6 + 7. Build context + call Groq
    const contextBlock  = buildContext(allEntities, exactIds)
    const systemPrompt  = buildSystemPrompt(contextBlock)
    const groqContent   = allEntities.length === 0
      ? buildFallbackPrompt(nq.intent)
      : await callGroq(systemPrompt, history.slice(-5), nq.normalized, groqKey)

    return json({
      content:       groqContent,
      source:        'groq',
      entities_used: allEntities.map(e => e.canonical_name),
      fallback:      allEntities.length === 0,
      latency_ms:    Date.now() - t0,
    })

  } catch (err) {
    console.error('[ai-chat] unhandled error:', err)
    return json({
      content: 'Lo siento, el asistente no está disponible. Intenta de nuevo en un momento.',
      source: 'error',
      fallback: true,
      latency_ms: Date.now() - t0,
    }, 500)
  }
})

// ── Helpers ───────────────────────────────────────────────────────────────────

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { headers: CORS, status })
}

function dedup(entities: KgEntity[]): KgEntity[] {
  const seen = new Set<string>()
  return entities.filter(e => seen.has(e.id) ? false : (seen.add(e.id), true))
}

async function callGroq(
  systemPrompt: string,
  history: Array<{ role: string; content: string }>,
  query: string,
  key: string
): Promise<string> {
  const FALLBACK = 'Lo siento, el asistente no está disponible. Intenta de nuevo en un momento.'
  const controller = new AbortController()
  const timer = setTimeout(() => controller.abort(), GROQ_TIMEOUT)
  try {
    const res = await fetch(GROQ_URL, {
      method: 'POST',
      headers: { 'Authorization': `Bearer ${key}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model: GROQ_MODEL,
        messages: [
          { role: 'system', content: systemPrompt },
          ...history,
          { role: 'user', content: query },
        ],
        max_tokens: 512,
        temperature: 0.7,
      }),
      signal: controller.signal,
    })
    if (!res.ok) { console.error('[Groq]', res.status, await res.text()); return FALLBACK }
    const data = await res.json()
    return data.choices?.[0]?.message?.content ?? FALLBACK
  } catch {
    return FALLBACK
  } finally {
    clearTimeout(timer)
  }
}

async function logFallback(
  supabase: ReturnType<typeof createClient>,
  query: string,
  normalized: string,
  city: string | null,
  similarity: number,
  reason: string
) {
  await supabase.from('rag_fallback_log').insert({
    query_original: query, query_normalized: normalized,
    city_detected: city, top_similarity: similarity, fallback_reason: reason,
  }).then(() => {/* fire and forget */}).catch(() => {/* never block */})
}
