// backend/functions/ai-chat/retrieval.ts
import { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'

export interface KgEntity {
  id: string
  canonical_name: string
  type: string
  city: string | null
  department: string | null
  lat: number | null
  lon: number | null
  embed_text: string
  metadata: Record<string, unknown>
  similarity?: number
}

// ── Exact / FTS match en aliases ──────────────────────────────────────────────
export async function exactMatch(
  supabase: SupabaseClient,
  normalizedQuery: string,
  city: string | null
): Promise<KgEntity[]> {
  // Palabras útiles, sin signos, unidas con OR: "¿cuánto vale el TransPadilla?" → "cuánto | vale | transpadilla"
  const terms = normalizedQuery
    .toLowerCase()
    .replace(/[^\p{L}\p{N}\s]/gu, ' ')
    .split(/\s+/)
    .filter(w => w.length > 3)
    .slice(0, 4)
  if (terms.length === 0) return []

  let query = supabase
    .from('colombia_kg_aliases')
    .select('entity_id, colombia_kg!inner(id, canonical_name, type, city, department, lat, lon, embed_text, metadata)')
    .textSearch('alias', terms.join(' | '), {
      config: 'spanish',
    })
    .limit(5)

  if (city) {
    query = query.eq('colombia_kg.city', city)
  }

  const { data, error } = await query
  if (error || !data) return []

  return data.map((row: Record<string, unknown>) => {
    const kg = row['colombia_kg'] as KgEntity
    return { ...kg, similarity: 1.0 }
  })
}
