// backend/functions/ai-chat/tools.ts
// Herramientas que la IA puede pedir (function calling, Fase 5).
//   search_place, get_corridor_status, estimate_fare → se ejecutan aquí.
//   plan_trip → se ejecuta EN EL CELULAR (D6): el servidor devuelve la
//   llamada, el teléfono planea sobre su grafo y manda el resultado de vuelta.
// Sin imports remotos: se prueba con `deno test tools_test.ts`.

export const TOOLS = [
  {
    type: 'function',
    function: {
      name: 'plan_trip',
      description:
        'Planea un viaje puerta a puerta en Riohacha, Maicao o la Troncal. ' +
        'Úsala cuando la persona quiera ir de un lugar a otro.',
      parameters: {
        type: 'object',
        properties: {
          origin: { type: 'string', description: 'Lugar de salida. Vacío = ubicación actual.' },
          destination: { type: 'string', description: 'Lugar de llegada, como lo dijo la persona.' },
          mode: {
            type: 'string',
            enum: ['cualquiera', 'mototaxi', 'taxi', 'colectivo', 'transpadilla', 'intermunicipal', 'a_pie'],
          },
        },
        required: ['destination'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'get_corridor_status',
      description: 'Estado actual de la Troncal Riohacha–Maicao por tramos (bloqueos, retenes).',
      parameters: { type: 'object', properties: {} },
    },
  },
  {
    type: 'function',
    function: {
      name: 'search_place',
      description: 'Busca un lugar conocido de la región por su nombre popular.',
      parameters: {
        type: 'object',
        properties: { query: { type: 'string' } },
        required: ['query'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'estimate_fare',
      description: 'Rango de tarifa de referencia en mototaxi o taxi para una distancia.',
      parameters: {
        type: 'object',
        properties: {
          mode: { type: 'string', enum: ['mototaxi', 'taxi'] },
          km: { type: 'number' },
        },
        required: ['mode', 'km'],
      },
    },
  },
] as const

export const CLIENT_TOOLS = new Set(['plan_trip'])
export const MAX_TOOL_ROUNDS = 3

export type ToolCall = {
  id: string
  type: 'function'
  function: { name: string; arguments: string }
}

export type ChatMessage =
  | { role: 'system' | 'user'; content: string }
  | { role: 'assistant'; content: string | null; tool_calls?: ToolCall[] }
  | { role: 'tool'; tool_call_id: string; content: string }

/** Argumentos del modelo: JSON que puede venir mal formado. */
export function parseArgs(raw: string): Record<string, unknown> {
  try {
    const v = JSON.parse(raw || '{}')
    return v && typeof v === 'object' && !Array.isArray(v) ? v : {}
  } catch {
    return {}
  }
}

// Debe coincidir con lib/planner/fares.dart (defaultFareRules).
const FARES: Record<string, { base: number; perKm: number; minimum: number }> = {
  mototaxi: { base: 2000, perKm: 700, minimum: 3000 },
  taxi: { base: 4000, perKm: 1300, minimum: 7000 },
}

export function estimateFare(mode: string, km: number, hour: number) {
  const r = FARES[mode]
  if (!r || !(km > 0) || km > 60) return { error: 'sin_tarifa' }
  let mid = Math.max(r.base + r.perKm * km, r.minimum)
  if (hour >= 21 || hour < 5) mid *= 1.2
  const round = (v: number) => Math.max(500, Math.round(v / 500) * 500)
  return { mode, km, min: round(mid * 0.75), max: round(mid * 1.25), referencia: true }
}

/** Respuesta compacta del estado del corredor para el modelo. */
export function summarizeCorridor(rows: Array<Record<string, unknown>>) {
  const withData = rows.filter((r) => r.state !== 'unknown')
  if (withData.length === 0) {
    return { estado: 'sin_datos', nota: 'Nadie ha reportado nada vigente. No digas que está despejada.' }
  }
  return {
    tramos: withData.map((r) => ({
      tramo: r.name,
      estado: r.state,
      motivo: r.reason ?? null,
      actualizado: r.updated_at ?? null,
    })),
  }
}

/** El cliente devuelve el resultado de plan_trip junto con la llamada.
 *  Solo se aceptan mensajes 'assistant' con tool_calls y 'tool' de tamaño acotado:
 *  el cliente no puede colar un 'system' ni un 'user' falso. */
export function sanitizeToolMessages(input: unknown): ChatMessage[] {
  if (!Array.isArray(input)) return []
  const out: ChatMessage[] = []
  for (const m of input.slice(0, 8)) {
    if (!m || typeof m !== 'object') continue
    const msg = m as Record<string, unknown>
    if (msg.role === 'assistant' && Array.isArray(msg.tool_calls)) {
      const calls = (msg.tool_calls as ToolCall[])
        .filter((c) => c && typeof c.id === 'string' && c.function &&
          typeof c.function.name === 'string' && typeof c.function.arguments === 'string')
        .slice(0, 3)
        .map((c) => ({
          id: c.id.slice(0, 64),
          type: 'function' as const,
          function: { name: c.function.name.slice(0, 40), arguments: c.function.arguments.slice(0, 1000) },
        }))
      if (calls.length) out.push({ role: 'assistant', content: null, tool_calls: calls })
    } else if (msg.role === 'tool' && typeof msg.tool_call_id === 'string' &&
               typeof msg.content === 'string') {
      out.push({ role: 'tool', tool_call_id: msg.tool_call_id.slice(0, 64), content: msg.content.slice(0, 4000) })
    }
  }
  // Cada respuesta 'tool' debe tener su llamada antes.
  const asked = new Set(out.flatMap((m) => m.role === 'assistant' ? (m.tool_calls ?? []).map((c) => c.id) : []))
  return out.filter((m) => m.role !== 'tool' || asked.has(m.tool_call_id))
}
