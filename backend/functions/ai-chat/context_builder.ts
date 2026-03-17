// backend/functions/ai-chat/context_builder.ts
import { KgEntity } from './retrieval.ts'

const MAX_CONTEXT_TOKENS_APPROX = 600  // ~2400 chars
const MAX_CHARS = MAX_CONTEXT_TOKENS_APPROX * 4

const SYSTEM_FIXED = `Eres GoSmart AI, asistente de movilidad urbana para Colombia.
SIEMPRE responde en español. NUNCA inventes datos ni horarios.
Si la información no está en DATOS VERIFICADOS, responde exactamente:
"No tengo datos verificados sobre eso. Consulta la app GoSmart para información en tiempo real."

Ciudades cubiertas: Bogotá, Medellín, Cali, Barranquilla, Cartagena, Bucaramanga, Pereira, Manizales y todos los municipios de Colombia.`

const FORMAT_FIXED = `Máximo 3 párrafos. Para rutas usa:
OPCIÓN [N]: [modo] → [tiempo estimado] → [tarifa COP]
Nunca uses horarios exactos salvo que estén en DATOS VERIFICADOS.
Sé conciso, amigable y práctico.`

export function buildContext(entities: KgEntity[], exactIds: Set<string>): string {
  if (entities.length === 0) return ''

  const lines: string[] = ['--- DATOS VERIFICADOS ---']
  let totalChars = 0

  for (const entity of entities) {
    const tag = exactIds.has(entity.id) ? '[VERIFICADO]' : '[APROXIMADO]'
    const summary = entity.embed_text.slice(0, 300)
    const line = `• ${tag} ${entity.canonical_name} [${entity.type}] — ${entity.city ?? entity.department ?? 'Colombia'}\n  ${summary}`

    if (totalChars + line.length > MAX_CHARS) break
    lines.push(line)
    totalChars += line.length
  }

  lines.push('--- FIN DATOS VERIFICADOS ---')
  return lines.join('\n')
}

export function buildSystemPrompt(contextBlock: string): string {
  const parts = [SYSTEM_FIXED]
  if (contextBlock) parts.push(contextBlock)
  parts.push(FORMAT_FIXED)
  return parts.join('\n\n')
}

export function buildFallbackPrompt(intent: string): string {
  const FALLBACK_BY_INTENT: Record<string, string> = {
    route:    'No encontré esa ruta específica en mi base de datos. Puedes buscarla en la app GoSmart o en el sitio oficial del sistema de transporte de tu ciudad.',
    fare:     'Las tarifas actualizadas están disponibles en la app GoSmart.',
    station:  'No tengo información verificada sobre esa estación. ¿Puedes describir mejor la ubicación o la ciudad?',
    address:  'No encontré esa dirección en mi base de datos. ¿Puedes indicar la ciudad?',
    general:  'No tengo datos verificados para esa consulta. Consulta la app GoSmart para información en tiempo real.',
  }
  return FALLBACK_BY_INTENT[intent] ?? FALLBACK_BY_INTENT['general']
}
