# RAG Colombia Mobility — Design Spec
**Fecha:** 2026-03-16
**Proyecto:** GoSmart — Asistente de Movilidad Urbana Colombia
**Estado:** Aprobado para implementación

---

## Objetivo

Aumentar la precisión del asistente GoSmart AI para el dominio de movilidad urbana colombiana mediante un pipeline RAG (Retrieval-Augmented Generation) ligero sobre infraestructura Supabase existente. Resuelve tres problemas actuales:

1. **Alucinación de datos** — el LLM inventa estaciones, rutas y tarifas
2. **Ambigüedad geográfica** — "Carrera 7" puede ser Bogotá o Cali sin distinción
3. **Alias locales no reconocidos** — "La Séptima", "Portal Norte", "Cra." ignorados

**Métrica de aceptación:** ≥ 90% precision@1 en set de validación de 100 queries colombianas reales.

---

## Alcance

- **Geográfico:** Colombia completa (todos los municipios y departamentos)
- **Entidades:** ~51.500 registros (estaciones, paraderos, barrios, calles, municipios, departamentos, terminales, landmarks)
- **Fuentes de datos:** OpenStreetMap (OSM) + DANE datos.gov.co
- **Stack:** Supabase (pgvector) + Supabase Edge Function (Deno) + Groq (llama-3.1-8b-instant) + OpenAI embeddings (text-embedding-3-small)
- **Tipo:** Prototipo — no producción
- **Prerrequisito:** pgvector disponible en todos los planes Supabase (Free, Pro, Team) desde 2024

---

## Arquitectura

### Flujo completo

```
Flutter (ai_service.dart)
    │  POST /functions/v1/ai-chat
    │  { query, city_hint?, history[] }
    ▼
┌─────────────────────────────────────────────────┐
│        Edge Function: ai-chat (Deno)            │
│                                                 │
│  1. NORMALIZER          ~2ms                    │
│     · Expand abreviaturas viales               │
│     · Unicode NFC                               │
│     · Typos conocidos de topónimos              │
│     → { normalized, abbreviations_expanded[] } │
│                                                 │
│  2. CITY DETECTOR       ~1ms                    │
│     · Sistemas de transporte → ciudad           │
│     · Barrios/estaciones únicos → ciudad        │
│     · Contexto de sesión                        │
│     SI confidence='none' → "¿En qué ciudad?"   │
│                                                 │
│  3. EXACT MATCH        ~15ms                    │
│     · FTS tsvector en colombia_kg_aliases       │
│     · Filtrado por city detectada               │
│     GATE: si match ≥ 1 → saltar paso 4         │
│                                                 │
│  4. SEMANTIC SEARCH    ~200ms (condicional)     │
│     · embed(query) → OpenAI                     │
│     · pgvector cosine, threshold ≥ 0.65        │
│     · Filtrado por city + type[]               │
│     SI top_similarity < 0.65 → fallback        │
│                                                 │
│  5. DEDUP + MERGE       ~1ms                    │
│     · Combinar exact + semantic                 │
│     · Eliminar entity_id duplicados             │
│     · Etiquetar: [VERIFICADO] vs [APROXIMADO]  │
│                                                 │
│  6. CONTEXT BUILDER     ~1ms                    │
│     · Formato descripción densa                 │
│     · Budget: ≤ 600 tokens                      │
│                                                 │
│  7. GROQ                ~600ms                  │
│     · System prompt 4 bloques                   │
│     · Streaming habilitado                      │
└─────────────────────────────────────────────────┘
    │
    ▼
{ content, source, entities_used[], latency_ms, fallback }
```

### Latencia esperada

| Escenario | Tiempo estimado |
|-----------|----------------|
| Alias exact match (60% de queries) | ~650ms warm |
| FTS match (20% de queries) | ~660ms warm |
| Semantic search (20% de queries) | ~850ms warm |
| Cold start primera llamada del día | +200–500ms adicionales |

> El streaming de Groq hace que el usuario vea texto en ~200ms aunque el total sea 650ms.

---

## Esquema de Base de Datos

```sql
-- Prerrequisito: pgvector ya disponible en Supabase
CREATE EXTENSION IF NOT EXISTS vector;

-- ── Entidades canónicas ───────────────────────────────────────────────────────
CREATE TABLE colombia_kg (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  canonical_name  TEXT NOT NULL,
  type            TEXT NOT NULL CHECK (type IN (
                    'station','stop','terminal','neighborhood',
                    'locality','municipality','department',
                    'street','landmark','poi')),
  city            TEXT,
  department      TEXT,
  lat             DOUBLE PRECISION,
  lon             DOUBLE PRECISION,
  embed_text      TEXT NOT NULL,       -- "descripción densa" usada para embedding
  metadata        JSONB DEFAULT '{}',  -- tarifas, operador, línea, horarios
  source          TEXT CHECK (source IN ('osm','dane','manual')),
  canonical_score SMALLINT DEFAULT 100,
  created_at      TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX idx_kg_city ON colombia_kg(city);
CREATE INDEX idx_kg_type ON colombia_kg(type);

-- ── Aliases ───────────────────────────────────────────────────────────────────
CREATE TABLE colombia_kg_aliases (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entity_id   UUID REFERENCES colombia_kg(id) ON DELETE CASCADE,
  alias       TEXT NOT NULL,
  alias_type  TEXT NOT NULL CHECK (alias_type IN (
                'abbreviation','popular','official','typo')),
  UNIQUE (entity_id, alias)
);

CREATE INDEX idx_aliases_fts ON colombia_kg_aliases
  USING gin(to_tsvector('spanish', alias));

-- ── Embeddings ────────────────────────────────────────────────────────────────
CREATE TABLE colombia_kg_embeddings (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entity_id   UUID REFERENCES colombia_kg(id) ON DELETE CASCADE UNIQUE,
  embedding   vector(1536),
  created_at  TIMESTAMPTZ DEFAULT now()
);

-- Crear índice DESPUÉS del bulk load (no antes)
-- HNSW: mejor recall, no requiere re-entrenamiento tras inserciones
CREATE INDEX idx_embeddings_hnsw
  ON colombia_kg_embeddings
  USING hnsw (embedding vector_cosine_ops)
  WITH (m = 16, ef_construction = 64);

-- ── RLS (tablas públicas de solo lectura) ─────────────────────────────────────
ALTER TABLE colombia_kg            ENABLE ROW LEVEL SECURITY;
ALTER TABLE colombia_kg_aliases    ENABLE ROW LEVEL SECURITY;
ALTER TABLE colombia_kg_embeddings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "public_read" ON colombia_kg            FOR SELECT USING (true);
CREATE POLICY "public_read" ON colombia_kg_aliases    FOR SELECT USING (true);
CREATE POLICY "public_read" ON colombia_kg_embeddings FOR SELECT USING (true);

-- ── Función RPC de retrieval semántico ────────────────────────────────────────
CREATE OR REPLACE FUNCTION match_colombia_kg(
  query_embedding vector(1536),
  match_count     INT     DEFAULT 5,
  city_filter     TEXT    DEFAULT NULL,
  type_filter     TEXT[]  DEFAULT NULL,
  similarity_threshold FLOAT DEFAULT 0.65
)
RETURNS TABLE (
  id             UUID,
  canonical_name TEXT,
  type           TEXT,
  city           TEXT,
  department     TEXT,
  lat            DOUBLE PRECISION,
  lon            DOUBLE PRECISION,
  embed_text     TEXT,
  metadata       JSONB,
  similarity     FLOAT
)
LANGUAGE plpgsql SECURITY DEFINER AS $$
BEGIN
  RETURN QUERY
  SELECT
    k.id, k.canonical_name, k.type, k.city, k.department,
    k.lat, k.lon, k.embed_text, k.metadata,
    1 - (e.embedding <=> query_embedding) AS similarity
  FROM colombia_kg_embeddings e
  JOIN colombia_kg k ON k.id = e.entity_id
  WHERE
    (city_filter IS NULL OR LOWER(k.city) = LOWER(city_filter))
    AND (type_filter IS NULL OR k.type = ANY(type_filter))
    AND (1 - (e.embedding <=> query_embedding)) >= similarity_threshold
  ORDER BY e.embedding <=> query_embedding
  LIMIT LEAST(match_count, 20);  -- límite de seguridad
END;
$$;

-- ── Logging de fallbacks (retroalimentación continua) ─────────────────────────
CREATE TABLE rag_fallback_log (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  query_original   TEXT NOT NULL,
  query_normalized TEXT,
  city_detected    TEXT,
  top_similarity   FLOAT,
  fallback_reason  TEXT CHECK (fallback_reason IN (
                     'no_match','low_similarity','city_unknown','timeout')),
  created_at       TIMESTAMPTZ DEFAULT now()
);

-- RLS: solo la Edge Function (service role) puede insertar; anon no puede leer
ALTER TABLE rag_fallback_log ENABLE ROW LEVEL SECURITY;
-- No se crea policy SELECT para anon — datos de telemetría internos

-- Grant de ejecución de la RPC al rol anon (usado por la Edge Function con anon key)
GRANT EXECUTE ON FUNCTION match_colombia_kg(vector, int, text, text[], float) TO anon;
```

---

## Normalizador de Abreviaturas Colombianas

Corre en Edge Function antes de cualquier búsqueda. Determinista, sin LLM, < 5ms.

### Diccionario vial

| Abreviatura(s) | Expansión |
|---|---|
| `Cra.` `Cra` `Kr.` `Kr` `Cr.` | `Carrera` |
| `Cl.` `Cl` `Cll.` `Cll` | `Calle` |
| `Av.` `Av` `Avda.` | `Avenida` |
| `Dg.` `Dg` `Diag.` | `Diagonal` |
| `Tv.` `Tv` `Trv.` `Trans.` | `Transversal` |
| `Ac.` `AC` | `Autopista Central` |
| `Ak.` `AK` | `Autopista Kennedy` |
| `Bv.` `Bvr.` | `Bulevar` |
| `No.` `Nro.` `#` | `Número` |

### Corrección de topónimos

| Input | Canónico |
|---|---|
| `Medellin` | `Medellín` |
| `Bogota` | `Bogotá` |
| `Barranquila` | `Barranquilla` |
| `Cartagena de Indias` | `Cartagena` |

### Inferencia de ciudad desde sistema de transporte

| Término detectado | Ciudad inferida |
|---|---|
| `TransMilenio` `SITP` `TM` `Portal` | `Bogotá` |
| `Metro de Medellín` `Metroplús` `Metrocable` | `Medellín` |
| `MIO` `Masivo Integrado de Occidente` | `Cali` |
| `Transmetro` | `Barranquilla` |
| `Transcaribe` | `Cartagena` |
| `Metrolínea` | `Bucaramanga` |
| `Megabús` | `Pereira` |

### Precedencia de `city_hint` vs. detección automática

Si Flutter envía `city_hint` (ciudad detectada en conversación previa), la Edge Function aplica esta regla **antes** de correr el city detector:

```
SI city_hint != null AND city_hint.trim() != ""
  → city = city_hint, city_confidence = 'high'
  → SALTAR city detector
SINO
  → correr city detector sobre normalized_query
```

Esto evita que una query ambigua sobreescriba una ciudad ya establecida en la sesión.

### Objeto de salida del normalizador

```typescript
interface NormalizedQuery {
  original: string;
  normalized: string;
  city: string | null;
  city_confidence: 'high' | 'medium' | 'none';
  intent: 'address' | 'station' | 'neighborhood' | 'route' | 'fare' | 'general';
  entities_mentioned: string[];
  abbreviations_expanded: string[];
  is_ambiguous: boolean;
}
```

---

## System Prompt Estructurado (4 bloques)

**Budget total:** ~780 tokens input

```
[BLOQUE 1 — IDENTIDAD Y RESTRICCIONES — ~80 tokens — fijo]
Eres GoSmart AI, asistente de movilidad urbana para Colombia.
SIEMPRE responde en español. NUNCA inventes datos ni horarios.
Si la información no está en DATOS VERIFICADOS, responde exactamente:
"No tengo datos verificados sobre eso. Consulta la app GoSmart para
información en tiempo real."

[BLOQUE 2 — COBERTURA — ~40 tokens — fijo]
Ciudades cubiertas: Bogotá, Medellín, Cali, Barranquilla, Cartagena,
Bucaramanga, Pereira, Manizales y todos los municipios de Colombia.

[BLOQUE 3 — DATOS VERIFICADOS — ≤600 tokens — dinámico]
--- DATOS VERIFICADOS ---
• [VERIFICADO] {canonical_name} [{type}] — {city}
  {embed_text resumido}
• [APROXIMADO] {canonical_name} [{type}] — {city}
  {embed_text resumido}
--- FIN DATOS VERIFICADOS ---

[BLOQUE 4 — FORMATO DE RESPUESTA — ~60 tokens — fijo]
Máximo 3 párrafos. Para rutas:
OPCIÓN [N]: [modo] → [tiempo estimado] → [tarifa COP]
Nunca uses horarios exactos salvo que estén en DATOS VERIFICADOS.
Sé conciso, amigable y práctico.
```

---

## Formato de Chunks para Embeddings

Cada entidad se convierte en texto de descripción densa (100-200 palabras) antes de embeber. El alias y variantes se incluyen EN el texto, no solo en metadata, para mejorar recall semántico.

**Ejemplo — Estación:**
```
Estación Niza de TransMilenio, ubicada en la Carrera 58 con Calle 127
en Bogotá, barrio Niza, localidad Suba. También conocida como Portal Niza
y Estación Niza-127. Sirve a los barrios Niza, Andes Norte y Palermo.
Conecta con alimentadores hacia Suba Compartir. Tarifa 2.950 COP.
Línea troncal NQS. Operada por TransMilenio S.A.
```

**Ejemplo — Barrio:**
```
Barrio Chapinero Alto en Bogotá, localidad Chapinero. También conocido
como Chapinero Central o simplemente Chapinero. Límites aproximados:
Calle 57 a Calle 72, Carrera 5 a Carrera 13. Cuenta con servicio SITP
rutas 1, 2, 14. Cerca al Parque de Lourdes y la Carrera 13.
```

---

## Pipeline de Datos (Python, corre offline una vez)

```
pipeline/
├── ingest_osm.py      # Overpass API → osm_colombia.jsonl
├── ingest_dane.py     # datos.gov.co API → dane_colombia.jsonl
├── merge_dedupe.py    # Merge + dedup por coordenada → kg_canonical.jsonl
├── build_chunks.py    # Genera embed_text denso por entidad → kg_chunks.jsonl
├── embed.py           # OpenAI batch embeddings → kg_embeddings.jsonl
├── load_supabase.py   # Inserta en Supabase (kg + aliases + embeddings)
└── validate.py        # Corre 100+ queries → imprime precision@1, precision@3
```

**Variables de entorno requeridas para pipeline:**
```
SUPABASE_URL=...
SUPABASE_SERVICE_ROLE_KEY=...   # service role (no anon) para inserciones
OPENAI_API_KEY=...
```

**`pipeline/requirements.txt`:**
```
supabase==2.4.0
openai==1.30.0
requests==2.32.0
tqdm==4.66.0
python-dotenv==1.0.1
unidecode==1.3.8
shapely==2.0.4
```

**Lógica de deduplicación en `merge_dedupe.py`:**
- **Clave de dedup:** par de coordenadas con tolerancia de **50 metros** (radio). Dos entidades se consideran duplicados si su distancia haversine es ≤ 50m Y comparten el mismo `type`.
- **Preferencia de nombre canónico:** DANE gana sobre OSM para municipios y departamentos. OSM gana para estaciones, paraderos y calles.
- **Entidades sin coordenadas:** si solo una fuente tiene coordenadas, se usan esas. Si ninguna tiene coordenadas (ocurre en ~2% de municipios pequeños DANE), se insertan con `lat=NULL, lon=NULL` y `source='dane'`.
- **Aliases:** se fusionan los aliases de ambas fuentes en la misma entidad canónica.

**Costo estimado de embeddings:** ~$0.10 USD para 51k chunks con text-embedding-3-small.

---

## Cambios en Flutter

Cambio mínimo en `lib/services/ai_service.dart`:

```dart
// Antes: POST directo a Groq
// Después: POST a Edge Function de Supabase
final url = Uri.parse('${Env.supabaseUrl}/functions/v1/ai-chat');
final response = await http.post(url,
  headers: {
    'Authorization': 'Bearer ${Env.supabaseAnonKey}',
    'Content-Type': 'application/json',
  },
  body: jsonEncode({
    'query': query,
    'city_hint': context,   // ciudad detectada en sesión
    'history': safeHistory.map((t) => {
      'role': t.role,
      'content': t.content,
    }).toList(),
  }),
);
```

`Env.groqApiKey` deja de usarse desde Flutter (pasa al servidor).

---

## Manejo de Fallbacks

| Condición | Acción |
|-----------|--------|
| `city_confidence = 'none'` | Responder: "¿En qué ciudad estás?" — no hacer retrieval |
| `exact_match = 0` AND `top_similarity < 0.65` | Fallback estructurado por intent + log en `rag_fallback_log` |
| Intent `route_query` sin match | Dirigir a app GoSmart + sistema de la ciudad detectada |
| Intent `fare_query` sin match | "Las tarifas están disponibles en la app GoSmart" |
| OpenAI embed timeout (>3s) o error | Skip semántico → solo exact match + Groq sin contexto KG + log fallback |
| OpenAI embed: 1 reintento automático antes de activar fallback | — |
| Groq timeout (>12s) | "Intenta de nuevo en un momento" |
| Edge Function cold start | Inevitable primer request — no hay workaround para prototipo |

---

## Tests y Métricas

### Set de validación: `tests/validation_queries.jsonl`

**Fuente y distribución:** El set de 100+ queries es curado manualmente por el desarrollador + revisado por el agente `colombia-data-curator`. Distribución mínima requerida:

| Ciudad | Queries mínimas |
|--------|----------------|
| Bogotá | 30 |
| Medellín | 20 |
| Cali | 15 |
| Barranquilla | 10 |
| Cartagena | 10 |
| Otras ciudades | 15 |
| **Total** | **≥ 100** |

Distribución por intent: ≥ 25% `address`, ≥ 20% `station`, ≥ 20% `route`, ≥ 15% `fare`, resto `neighborhood`/`general`. El set debe aprobarse antes de correr métricas de aceptación — no puede ser generado y evaluado por la misma persona en la misma sesión.

100+ queries con estructura:
```jsonl
{"query": "¿Cómo llego de Chapinero al Portal Norte?", "city": "Bogotá", "expected_entities": ["Portal del Norte", "Carrera 7"], "intent": "route"}
{"query": "Cuanto cuesta el metro en Medellin", "city": "Medellín", "expected_entities": ["Metro de Medellín"], "intent": "fare"}
{"query": "Cra. 13 con Cl. 72 Bogotá", "city": "Bogotá", "expected_entities": ["Carrera 13", "Calle 72"], "intent": "address"}
{"query": "La Séptima hacia el norte", "city": "Bogotá", "expected_entities": ["Carrera 7"], "intent": "route"}
{"query": "Estacion museo metro", "city": "Medellín", "expected_entities": ["Estación Museo"], "intent": "station"}
```

### Métricas a calcular

```python
# precision@1: la primera entidad recuperada es la correcta
# precision@3: al menos una de las 3 primeras es correcta
# recall@5:    la entidad esperada está entre las 5 primeras
# fallback_rate: % de queries que activan fallback (objetivo < 10%)
```

### Criterio de aceptación

| Métrica | Objetivo |
|---------|---------|
| precision@1 (address + station queries) | ≥ 90% |
| precision@3 (route + neighborhood queries) | ≥ 85% |
| fallback_rate | < 10% |
| latencia p95 warm | < 1.000ms |

---

## Plan de Despliegue

### Fase 1 — Base de datos y pipeline (offline)
1. Crear tablas en Supabase SQL Editor
2. Correr pipeline Python localmente (`ingest → merge → embed → load`)
3. Crear índice HNSW después del load
4. Verificar con `validate.py`

### Fase 2 — Edge Function
1. Reemplazar `backend/functions/ai-chat/index.ts` con nueva implementación
2. Setear secrets en Supabase Dashboard: `OPENAI_API_KEY`, `GROQ_API_KEY`
3. Deploy: `supabase functions deploy ai-chat`
4. Smoke test con curl

### Fase 3 — Flutter
1. Actualizar `lib/services/ai_service.dart` para llamar Edge Function
2. Remover `GROQ_API_KEY` del `.env` del cliente
3. Verificar en dispositivo físico con queries reales

### Fase 4 — Iteración con fallback logs
1. Revisar `rag_fallback_log` semanalmente
2. Agregar entidades faltantes al KG
3. Re-embed solo las nuevas entidades (no todo el KG)

---

## Estructura de Archivos Nueva

```
gosmart/
├── backend/
│   ├── functions/
│   │   └── ai-chat/
│   │       ├── index.ts          # REEMPLAZAR con Edge Function RAG
│   │       ├── normalizer.ts     # Módulo normalizador colombiano
│   │       ├── retrieval.ts      # Exact match + semantic search
│   │       ├── context_builder.ts # Formatea entidades → prompt
│   │       └── stops.json        # DEPRECAR (datos migrados al KG)
│   └── migrations/
│       └── 006_colombia_kg.sql   # Tablas colombia_kg + RLS + RPC
├── pipeline/
│   ├── ingest_osm.py
│   ├── ingest_dane.py
│   ├── merge_dedupe.py
│   ├── build_chunks.py
│   ├── embed.py
│   ├── load_supabase.py
│   ├── validate.py
│   └── requirements.txt
├── tests/
│   └── validation_queries.jsonl  # 100+ queries Colombia
└── lib/
    └── services/
        └── ai_service.dart       # Cambio mínimo: URL → Edge Function
```

---

## Skeleton de Edge Function (Deno)

Los cuatro archivos que componen `backend/functions/ai-chat/`.

### `index.ts` — Orquestador principal

```typescript
import { serve } from 'https://deno.land/std@0.177.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { normalize } from './normalizer.ts'
import { exactMatch, semanticSearch } from './retrieval.ts'
import { buildContext, buildSystemPrompt } from './context_builder.ts'

const GROQ_URL  = 'https://api.groq.com/openai/v1/chat/completions'
const GROQ_MODEL = 'llama-3.1-8b-instant'
const GROQ_TIMEOUT_MS = 12_000
const EMBED_TIMEOUT_MS = 3_000
const SIMILARITY_THRESHOLD = 0.65

serve(async (req) => {
  const { query, city_hint, history = [] } = await req.json()
  const supabase = createClient(
    Deno.env.get('SUPABASE_URL')!,
    Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
  )

  // 1. Normalize
  const nq = normalize(query)

  // 2. City detection — city_hint overrides auto-detect
  const city = city_hint?.trim() || nq.city
  const cityConfidence = city_hint?.trim() ? 'high' : nq.city_confidence

  if (cityConfidence === 'none') {
    return json({ content: '¿En qué ciudad estás? Necesito saberlo para darte información precisa.', fallback: true })
  }

  // 3. Exact match (always runs)
  const exactHits = await exactMatch(supabase, nq.normalized, city)

  // 4. Semantic search (only if exact match returned nothing)
  let semanticHits: Entity[] = []
  if (exactHits.length === 0) {
    try {
      const embedding = await embedWithTimeout(nq.normalized, EMBED_TIMEOUT_MS)
      semanticHits = await semanticSearch(supabase, embedding, city, SIMILARITY_THRESHOLD)
    } catch {
      await logFallback(supabase, query, nq.normalized, city, 0, 'no_match')
    }
  }

  // 5. Dedup + merge
  const allEntities = dedup([...exactHits, ...semanticHits])

  if (allEntities.length === 0) {
    await logFallback(supabase, query, nq.normalized, city, semanticHits[0]?.similarity ?? 0, 'low_similarity')
  }

  // 6. Build context
  const context = buildContext(allEntities, exactHits.map(e => e.id))

  // 7. Call Groq
  const systemPrompt = buildSystemPrompt(context)
  const content = await callGroq(systemPrompt, history, nq.normalized, GROQ_TIMEOUT_MS)

  return json({
    content,
    source: 'groq',
    entities_used: allEntities.map(e => e.canonical_name),
    fallback: allEntities.length === 0,
  })
})

// ── Helpers ──────────────────────────────────────────────────────────────────

function json(body: unknown) {
  return new Response(JSON.stringify(body), {
    headers: { 'Content-Type': 'application/json' }
  })
}

function dedup(entities: Entity[]): Entity[] {
  const seen = new Set<string>()
  return entities.filter(e => seen.has(e.id) ? false : (seen.add(e.id), true))
}

async function embedWithTimeout(text: string, timeoutMs: number): Promise<number[]> {
  const controller = new AbortController()
  const timer = setTimeout(() => controller.abort(), timeoutMs)
  try {
    const res = await fetch('https://api.openai.com/v1/embeddings', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${Deno.env.get('OPENAI_API_KEY')}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({ model: 'text-embedding-3-small', input: text }),
      signal: controller.signal,
    })
    const data = await res.json()
    return data.data[0].embedding as number[]
  } finally {
    clearTimeout(timer)
  }
}

async function callGroq(systemPrompt: string, history: Turn[], query: string, timeoutMs: number): Promise<string> {
  const controller = new AbortController()
  const timer = setTimeout(() => controller.abort(), timeoutMs)
  const FALLBACK = 'Lo siento, el asistente no está disponible. Intenta de nuevo en un momento.'
  try {
    const res = await fetch(GROQ_URL, {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${Deno.env.get('GROQ_API_KEY')}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: GROQ_MODEL,
        messages: [
          { role: 'system', content: systemPrompt },
          ...history.slice(-5),
          { role: 'user', content: query },
        ],
        max_tokens: 512,
        temperature: 0.7,
      }),
      signal: controller.signal,
    })
    const data = await res.json()
    return data.choices?.[0]?.message?.content ?? FALLBACK
  } catch {
    return FALLBACK
  } finally {
    clearTimeout(timer)
  }
}

async function logFallback(
  supabase: SupabaseClient, query: string, normalized: string,
  city: string | null, similarity: number, reason: string
) {
  await supabase.from('rag_fallback_log').insert({
    query_original: query, query_normalized: normalized,
    city_detected: city, top_similarity: similarity, fallback_reason: reason,
  }).throwOnError().catch(() => {/* never block on telemetry */})
}

interface Entity { id: string; canonical_name: string; type: string; city: string; embed_text: string; similarity?: number }
interface Turn { role: 'user' | 'assistant'; content: string }
```

---

### `normalizer.ts` — Firma y responsabilidades

```typescript
export interface NormalizedQuery {
  original: string
  normalized: string
  city: string | null
  city_confidence: 'high' | 'medium' | 'none'
  intent: 'address' | 'station' | 'neighborhood' | 'route' | 'fare' | 'general'
  entities_mentioned: string[]
  abbreviations_expanded: string[]
}

// Expansión completa de abreviaturas viales colombianas
const ABBREVS: [RegExp, string][] = [
  [/\bCra?\.?\s*/gi, 'Carrera '], [/\bKr\.?\s*/gi, 'Carrera '],
  [/\bCll?\.?\s*/gi, 'Calle '],   [/\bAv\.?\s*/gi, 'Avenida '],
  [/\bDg\.?\s*/gi, 'Diagonal '], [/\bTv\.?\s*/gi, 'Transversal '],
  [/\bAc\b/gi, 'Autopista Central'], [/\bAk\b/gi, 'Autopista Kennedy'],
]

// Inferencia de ciudad desde sistema de transporte
const TRANSPORT_CITY: [RegExp, string][] = [
  [/transmilenio|sitp|\bTM\b|portal norte|portal sur/i, 'Bogotá'],
  [/metro de medell|metroplús|metrocable/i, 'Medellín'],
  [/\bMIO\b|masivo integrado/i, 'Cali'],
  [/transmetro/i, 'Barranquilla'],
  [/transcaribe/i, 'Cartagena'],
  [/metrolínea|metrolinea/i, 'Bucaramanga'],
  [/megabús|megabus/i, 'Pereira'],
]

export function normalize(query: string): NormalizedQuery { /* implementar */ }
```

---

### `retrieval.ts` — Firma y responsabilidades

```typescript
import { SupabaseClient } from 'https://esm.sh/@supabase/supabase-js@2'

// Exact/FTS match en colombia_kg_aliases filtrando por ciudad
export async function exactMatch(
  supabase: SupabaseClient,
  normalizedQuery: string,
  city: string | null
): Promise<Entity[]>

// Semantic search via RPC match_colombia_kg
export async function semanticSearch(
  supabase: SupabaseClient,
  embedding: number[],
  city: string | null,
  threshold: number
): Promise<Entity[]>
```

---

### `context_builder.ts` — Firma y responsabilidades

```typescript
// Construye el bloque DATOS VERIFICADOS con budget ≤ 600 tokens
// exactIds: set de entity_id recuperados por exact match → etiqueta [VERIFICADO]
// resto → etiqueta [APROXIMADO]
export function buildContext(entities: Entity[], exactIds: string[]): string

// Ensambla el system prompt completo de 4 bloques
export function buildSystemPrompt(contextBlock: string): string
```

---

## Agentes Coordinados

| Agente | Rol en este proyecto |
|--------|---------------------|
| **architecture-transformer** | Revisó esquema DB, corrigió IVFFlat→HNSW, detectó bug de filtros en RPC |
| **llm-integration-specialist** | Diseñó system prompt 4 bloques, estrategia de chunks, política de fallbacks |
| **prompt-engineer** | Refinar system prompt final y queries de validación |
| **workflow-automator** | Orchestrar pipeline Python (ingest→embed→load→validate) |
| **senior-code-reviewer** | Revisar Edge Function Deno antes de deploy |
| **colombia-data-curator** *(propuesto)* | Curar aliases locales no capturados por OSM/DANE |

### Agente propuesto: `colombia-data-curator`

**Scope:** Responsable de curar y mantener el knowledge graph colombiano. Tareas:
- Identificar aliases populares no documentados en OSM (jerga local, nombres históricos)
- Validar coordenadas de paraderos y estaciones contra fuentes oficiales
- Mantener diccionario de abreviaturas actualizado
- Priorizar entidades para el set de validación de 100+ queries
- Detectar entidades faltantes desde `rag_fallback_log`

---

*Spec generado con feedback de architecture-transformer y llm-integration-specialist.*
