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

// Mismo modelo que el pipeline Python — vectores compatibles (384 dims)
// Llamada HTTP a HuggingFace Inference API (gratis, sin API key para bajo tráfico)
const HF_URL = 'https://api-inference.huggingface.co/pipeline/feature-extraction/sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2'

// ── Exact / FTS match en aliases ──────────────────────────────────────────────
export async function exactMatch(
  supabase: SupabaseClient,
  normalizedQuery: string,
  city: string | null
): Promise<KgEntity[]> {
  let query = supabase
    .from('colombia_kg_aliases')
    .select('entity_id, colombia_kg!inner(id, canonical_name, type, city, department, lat, lon, embed_text, metadata)')
    .textSearch('alias', normalizedQuery.split(' ').slice(0, 4).join(' & '), {
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

// ── Semantic search via pgvector RPC ─────────────────────────────────────────
export async function semanticSearch(
  supabase: SupabaseClient,
  embedding: number[],
  city: string | null,
  threshold = 0.35,
  matchCount = 5
): Promise<KgEntity[]> {
  const { data, error } = await supabase.rpc('match_colombia_kg', {
    query_embedding: embedding,
    match_count: matchCount,
    city_filter: city,
    type_filter: null,
    similarity_threshold: threshold,
  })
  if (error || !data) return []
  return data as KgEntity[]
}

// ── Embed query via HuggingFace API (mismo modelo que pipeline Python) ────────
export async function embedQuery(text: string): Promise<number[]> {
  const controller = new AbortController()
  const timer = setTimeout(() => controller.abort(), 8_000)
  try {
    const res = await fetch(HF_URL, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ inputs: text, options: { wait_for_model: true } }),
      signal: controller.signal,
    })
    if (!res.ok) throw new Error(`HF API ${res.status}`)
    const data = await res.json()
    // HF devuelve [[v1, v2, ...]] para un solo input
    return (Array.isArray(data[0]) ? data[0] : data) as number[]
  } finally {
    clearTimeout(timer)
  }
}
