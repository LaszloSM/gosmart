// backend/functions/ai-chat/index.ts
// GoSmart AI — proxy de Groq para Riohacha, Maicao y el corredor.
// La key de Groq vive solo aquí (secret GROQ_API_KEY), nunca en el APK.
// Flujo: lugares del KG (FTS sobre alias) → prompt corto → Groq 8b → (respaldo 70b)
// Con herramientas (Fase 5): el modelo puede pedir el estado del corredor, buscar
// lugares o tarifas (se resuelven aquí) o plan_trip, que se devuelve al celular:
//   → { source: 'tool_call', tool_call, tool_messages }
// y el celular vuelve a llamar con tool_messages + el resultado.

import { serve }        from 'https://deno.land/std@0.208.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { normalize }    from './normalizer.ts'
import { exactMatch, KgEntity } from './retrieval.ts'
import { buildContext, buildSystemPrompt } from './context_builder.ts'
import {
  ChatMessage, CLIENT_TOOLS, estimateFare, MAX_TOOL_ROUNDS, parseArgs,
  sanitizeToolMessages, summarizeCorridor, ToolCall, TOOLS,
} from './tools.ts'

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
    const { query, history = [], client_context = '', tool_messages = [] } = await req.json()
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

    // Conversación: sistema + historial + pregunta + (vuelta de una herramienta).
    const messages: ChatMessage[] = [
      { role: 'system', content: systemPrompt },
      ...turns as ChatMessage[],
      { role: 'user', content: query },
      ...sanitizeToolMessages(tool_messages),
    ]
    // true = esta llamada trae el resultado de una herramienta del celular.
    const continuing = messages.some((m) => m.role === 'tool')

    let result: GroqResult = { ok: false, content: UNAVAILABLE, model: PRIMARY_MODEL, error: 'no_rounds' }
    const added: ChatMessage[] = []
    for (let round = 0; round < MAX_TOOL_ROUNDS; round++) {
      result = await callGroqWithFallback([...messages, ...added], groqKey)
      if (!result.ok || !result.toolCalls?.length) break

      const assistant: ChatMessage = { role: 'assistant', content: null, tool_calls: result.toolCalls }
      const clientCall = result.toolCalls.find((c) => CLIENT_TOOLS.has(c.function.name))
      if (clientCall) {
        // plan_trip corre en el celular (D6). Si ya trajo un resultado y el
        // modelo lo vuelve a pedir, se corta: no hay vueltas infinitas.
        if (continuing) {
          return json({
            content: 'Te dejé la ruta lista: tócala para verla en el mapa.',
            source: 'groq',
            model: result.model,
            latency_ms: Date.now() - t0,
          })
        }
        return json({
          content: '',
          source: 'tool_call',
          model: result.model,
          tool_call: { id: clientCall.id, name: clientCall.function.name, args: parseArgs(clientCall.function.arguments) },
          // Lo que el celular debe devolver tal cual, más su respuesta 'tool'.
          tool_messages: [...sanitizeToolMessages(tool_messages), ...added, assistant],
          latency_ms: Date.now() - t0,
        })
      }
      added.push(assistant)
      for (const call of result.toolCalls) {
        added.push({ role: 'tool', tool_call_id: call.id,
                     content: JSON.stringify(await runServerTool(supabase, call)) })
      }
    }

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

// ── Herramientas del servidor ────────────────────────────────────────────────

// deno-lint-ignore no-explicit-any
async function runServerTool(supabase: any, call: ToolCall): Promise<unknown> {
  const args = parseArgs(call.function.arguments)
  try {
    switch (call.function.name) {
      case 'get_corridor_status': {
        const { data, error } = await supabase.rpc('road_status')
        if (error) return { error: 'sin_conexion' }
        return summarizeCorridor(data ?? [])
      }
      case 'search_place': {
        const { data, error } = await supabase.rpc('search_places', {
          p_query: String(args.query ?? '').slice(0, 80), p_limit: 3 })
        if (error) return { error: 'sin_conexion' }
        return { lugares: (data ?? []).map((p: Record<string, unknown>) => ({
          nombre: p.name, ciudad: p.city, aproximado: !p.verified })) }
      }
      case 'estimate_fare': {
        const hour = Number(new Intl.DateTimeFormat('en-US', {
          hour: 'numeric', hour12: false, timeZone: 'America/Bogota' }).format(new Date()))
        return estimateFare(String(args.mode ?? ''), Number(args.km), hour)
      }
      default:
        return { error: 'herramienta_desconocida' }
    }
  } catch {
    return { error: 'fallo_herramienta' }
  }
}

// ── Helpers ───────────────────────────────────────────────────────────────────

function json(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), { headers: CORS, status })
}

type GroqResult = {
  ok: boolean; content: string; model: string; error?: string; toolCalls?: ToolCall[]
}

const UNAVAILABLE =
  'El asistente no está disponible ahora. Puedes planear tu viaje desde el mapa.'

// Intenta el modelo principal; si Groq responde 429 (cuota) o 5xx, usa el 70b una vez.
async function callGroqWithFallback(messages: ChatMessage[], key: string): Promise<GroqResult> {
  const first = await callGroq(PRIMARY_MODEL, messages, key)
  if (first.ok) return first
  if (first.error === 'rate_limited' || first.error === 'server_error') {
    return await callGroq(FALLBACK_MODEL, messages, key)
  }
  return first
}

async function callGroq(model: string, messages: ChatMessage[], key: string): Promise<GroqResult> {
  const controller = new AbortController()
  const timer = setTimeout(() => controller.abort(), GROQ_TIMEOUT)
  try {
    const res = await fetch(GROQ_URL, {
      method: 'POST',
      headers: { 'Authorization': `Bearer ${key}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({
        model,
        messages,
        tools: TOOLS,
        tool_choice: 'auto',
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
    const msg = data.choices?.[0]?.message
    const toolCalls = Array.isArray(msg?.tool_calls) ? msg.tool_calls as ToolCall[] : undefined
    if (toolCalls?.length) return { ok: true, content: '', model, toolCalls }
    const content = msg?.content
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
