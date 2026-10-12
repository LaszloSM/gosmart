// backend/functions/ai-chat/context_builder.ts
import { KgEntity } from './retrieval.ts'

const MAX_CONTEXT_CHARS = 1600

// Prompt corto a propósito (E1): cada token cuenta contra la cuota gratis de Groq.
const SYSTEM_FIXED = `Eres GoSmart, asistente de movilidad para Riohacha, Maicao y la vía entre ellas (Troncal del Caribe), en La Guajira.
Hablas en español, tuteas, frases cortas, palabras locales (mototaxi, colectivo, la Troncal, el terminal). Máximo 3 párrafos cortos, texto plano, sin Markdown.
Solo hablas de transporte y movilidad. Si te preguntan otra cosa: "Solo te ayudo con transporte. ¿A dónde necesitas ir?"
Nunca inventes horarios, rutas ni tarifas exactas. Si no sabes, dilo y sugiere el planificador de la app.
Nunca señales a personas ni comunidades. Habla de "bloqueo en el km X" o "reporte de inseguridad en el sector", sin culpables.

Referencias generales (aproximadas, pueden cambiar):
• TransPadilla (Riohacha): microbuses urbanos desde mayo de 2026, 2 rutas desde el Terminal de Riohacha, pasaje $3.000.
• Mototaxi: el precio se negocia; varía por distancia, hora y zona.
• Riohacha–Maicao: buses de empresas desde los terminales, alrededor de $14.000–$16.000; colectivos y vans salen cuando se llenan.
• Terminal de Maicao: atiende aprox. 4:00 a. m.–7:00 p. m. De noche casi no hay servicio formal.
• La Troncal puede tener bloqueos, a menudo desde temprano en la mañana. Si está cerrada, el desvío usual es por Albania–Cuestecitas.
Si recibes [CONTEXTO DE LA APP], úsalo como dato principal.`

export function buildContext(entities: KgEntity[]): string {
  if (entities.length === 0) return ''

  const lines: string[] = ['LUGARES CONOCIDOS:']
  let totalChars = 0
  for (const e of entities) {
    const line = `• ${e.canonical_name} (${e.type}, ${e.city ?? e.department ?? 'La Guajira'}): ${e.embed_text.slice(0, 200)}`
    if (totalChars + line.length > MAX_CONTEXT_CHARS) break
    lines.push(line)
    totalChars += line.length
  }
  return lines.join('\n')
}

export function buildSystemPrompt(contextBlock: string, clientContext: string): string {
  const parts = [SYSTEM_FIXED]
  if (contextBlock) parts.push(contextBlock)
  if (clientContext.trim()) parts.push(`[CONTEXTO DE LA APP]\n${clientContext.trim()}`)
  return parts.join('\n\n')
}
