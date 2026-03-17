# RAG Colombia Mobility — Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Reemplazar el asistente GoSmart AI con un pipeline RAG que recupera entidades colombianas reales (estaciones, barrios, calles, municipios) desde Supabase pgvector antes de llamar a Groq, eliminando alucinaciones y alias no reconocidos.

**Architecture:** Supabase Edge Function (Deno) orquesta: normalización de abreviaturas colombianas → exact match FTS → semantic search pgvector (OpenAI embeddings) → system prompt enriquecido → Groq llama-3.1-8b-instant. El knowledge graph (~51k entidades) se carga offline con scripts Python desde OSM + DANE.

**Tech Stack:** Python 3.11+, Deno (Supabase Edge Functions), Flutter/Dart, Supabase pgvector, OpenAI text-embedding-3-small, Groq llama-3.1-8b-instant.

**Spec:** `docs/superpowers/specs/2026-03-16-rag-colombia-mobility-design.md`

---

## File Map

### Archivos nuevos
| Archivo | Responsabilidad |
|---------|----------------|
| `backend/migrations/006_colombia_kg.sql` | Tablas colombia_kg, aliases, embeddings, RLS, RPC, fallback_log |
| `backend/functions/ai-chat/normalizer.ts` | Expansión de abreviaturas, corrección de topónimos, detección de ciudad |
| `backend/functions/ai-chat/retrieval.ts` | exactMatch (FTS) + semanticSearch (pgvector RPC) |
| `backend/functions/ai-chat/context_builder.ts` | Formatea entidades → system prompt 4 bloques |
| `pipeline/requirements.txt` | Dependencias Python del pipeline |
| `pipeline/.env.example` | Variables de entorno para el pipeline |
| `pipeline/ingest_osm.py` | Descarga entidades Colombia desde Overpass API → osm_colombia.jsonl |
| `pipeline/ingest_dane.py` | Descarga municipios/departamentos desde datos.gov.co → dane_colombia.jsonl |
| `pipeline/merge_dedupe.py` | Fusiona OSM + DANE, deduplica por coordenada (50m) → kg_canonical.jsonl |
| `pipeline/build_chunks.py` | Genera embed_text "descripción densa" por entidad → kg_chunks.jsonl |
| `pipeline/embed.py` | Batch embeddings OpenAI → kg_embeddings.jsonl |
| `pipeline/load_supabase.py` | Inserta todo en Supabase + crea índice HNSW post-load |
| `pipeline/validate.py` | Corre tests/validation_queries.jsonl → imprime precision@1, precision@3 |
| `tests/validation_queries.jsonl` | 100+ queries Colombia con expected_entities |
| `tests/pipeline/test_normalizer.py` | Unit tests del normalizador Python |
| `tests/pipeline/test_merge_dedupe.py` | Unit tests de deduplicación |
| `tests/pipeline/test_build_chunks.py` | Unit tests de generación de chunks |
| `backend/functions/ai-chat/normalizer_test.ts` | Unit tests Deno del normalizador TypeScript |

### Archivos modificados
| Archivo | Cambio |
|---------|--------|
| `backend/functions/ai-chat/index.ts` | Reemplazar completamente con orquestador RAG |
| `lib/services/ai_service.dart` | Cambiar endpoint: Groq directo → Edge Function |
| `lib/core/env.dart` | Remover groqApiKey (se mueve al servidor) |

---

## Chunk 1: Base de datos — Migración 006

### Task 1: Crear migración SQL del Knowledge Graph

**Files:**
- Create: `backend/migrations/006_colombia_kg.sql`

- [ ] **Step 1: Crear el archivo de migración**

```sql
-- backend/migrations/006_colombia_kg.sql
-- GoSmart RAG Colombia — Knowledge Graph tables
-- Run in Supabase SQL Editor (Dashboard → SQL Editor → New query)
-- Requires: pgvector available on all Supabase plans (2024+)
-- Run AFTER migrations 001-005

-- ── Extensión ─────────────────────────────────────────────────────────────────
CREATE EXTENSION IF NOT EXISTS vector;

-- ── Entidades canónicas ───────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS colombia_kg (
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
  embed_text      TEXT NOT NULL,
  metadata        JSONB DEFAULT '{}',
  source          TEXT CHECK (source IN ('osm','dane','manual')),
  canonical_score SMALLINT DEFAULT 100,
  created_at      TIMESTAMPTZ DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_kg_city ON colombia_kg(city);
CREATE INDEX IF NOT EXISTS idx_kg_type ON colombia_kg(type);

-- ── Aliases ───────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS colombia_kg_aliases (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entity_id   UUID REFERENCES colombia_kg(id) ON DELETE CASCADE,
  alias       TEXT NOT NULL,
  alias_type  TEXT NOT NULL CHECK (alias_type IN (
                'abbreviation','popular','official','typo')),
  UNIQUE (entity_id, alias)
);

CREATE INDEX IF NOT EXISTS idx_aliases_fts ON colombia_kg_aliases
  USING gin(to_tsvector('spanish', alias));

-- ── Embeddings ────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS colombia_kg_embeddings (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  entity_id   UUID REFERENCES colombia_kg(id) ON DELETE CASCADE UNIQUE,
  embedding   vector(1536),
  created_at  TIMESTAMPTZ DEFAULT now()
);
-- IMPORTANT: Do NOT create HNSW index here.
-- Create it AFTER bulk load via load_supabase.py to avoid degraded index.

-- ── RLS — tablas de solo lectura pública ──────────────────────────────────────
ALTER TABLE colombia_kg            ENABLE ROW LEVEL SECURITY;
ALTER TABLE colombia_kg_aliases    ENABLE ROW LEVEL SECURITY;
ALTER TABLE colombia_kg_embeddings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "public_read" ON colombia_kg            FOR SELECT USING (true);
CREATE POLICY "public_read" ON colombia_kg_aliases    FOR SELECT USING (true);
CREATE POLICY "public_read" ON colombia_kg_embeddings FOR SELECT USING (true);

-- ── Fallback log — solo escritura interna ────────────────────────────────────
CREATE TABLE IF NOT EXISTS rag_fallback_log (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  query_original   TEXT NOT NULL,
  query_normalized TEXT,
  city_detected    TEXT,
  top_similarity   FLOAT,
  fallback_reason  TEXT CHECK (fallback_reason IN (
                     'no_match','low_similarity','city_unknown','timeout')),
  created_at       TIMESTAMPTZ DEFAULT now()
);
-- anon no puede leer ni escribir — solo service role desde Edge Function
ALTER TABLE rag_fallback_log ENABLE ROW LEVEL SECURITY;

-- ── RPC de retrieval semántico ────────────────────────────────────────────────
CREATE OR REPLACE FUNCTION match_colombia_kg(
  query_embedding      vector(1536),
  match_count          INT     DEFAULT 5,
  city_filter          TEXT    DEFAULT NULL,
  type_filter          TEXT[]  DEFAULT NULL,
  similarity_threshold FLOAT   DEFAULT 0.65
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
  LIMIT LEAST(match_count, 20);
END;
$$;

-- Permitir que anon key (Edge Function) ejecute la RPC
GRANT EXECUTE ON FUNCTION match_colombia_kg(vector, int, text, text[], float) TO anon;

-- Helper para crear índice HNSW desde Python (supabase-py no puede ejecutar DDL directo)
-- Llamado por load_supabase.py después del bulk load
CREATE OR REPLACE FUNCTION create_hnsw_index() RETURNS void
LANGUAGE plpgsql AS $$
BEGIN
  EXECUTE 'CREATE INDEX IF NOT EXISTS idx_embeddings_hnsw
    ON colombia_kg_embeddings
    USING hnsw (embedding vector_cosine_ops)
    WITH (m = 16, ef_construction = 64)';
END;
$$;
GRANT EXECUTE ON FUNCTION create_hnsw_index() TO service_role;

NOTIFY pgrst, 'reload schema';
```

- [ ] **Step 2: Aplicar migración en Supabase**

Ir a: Supabase Dashboard → SQL Editor → New query → pegar el contenido de `006_colombia_kg.sql` → Run.

Verificar que no hay errores. Si aparece "already exists" en alguna tabla, es seguro — los `IF NOT EXISTS` lo protegen.

- [ ] **Step 3: Verificar tablas creadas**

En Supabase SQL Editor ejecutar:
```sql
SELECT table_name FROM information_schema.tables
WHERE table_schema = 'public'
AND (table_name LIKE 'colombia%' OR table_name = 'rag_fallback_log')
ORDER BY table_name;
```

Resultado esperado:
```
colombia_kg
colombia_kg_aliases
colombia_kg_embeddings
rag_fallback_log
```

- [ ] **Step 4: Verificar RPC creada**

```sql
SELECT routine_name FROM information_schema.routines
WHERE routine_name = 'match_colombia_kg';
```

Resultado esperado: 1 fila con `match_colombia_kg`.

---

## Chunk 2: Pipeline Python — Ingestión y carga del KG

### Task 2: Setup del entorno Python

**Files:**
- Create: `pipeline/requirements.txt`
- Create: `pipeline/.env.example`
- Create: `pipeline/.env` *(no commitear — en .gitignore)*

- [ ] **Step 1: Crear requirements.txt**

```
# pipeline/requirements.txt
supabase==2.4.0
openai==1.30.0
requests==2.32.0
tqdm==4.66.0
python-dotenv==1.0.1
unidecode==1.3.8
shapely==2.0.4
pytest==8.2.0
```

- [ ] **Step 2: Crear .env.example**

```bash
# pipeline/.env.example
SUPABASE_URL=https://<project-ref>.supabase.co
SUPABASE_SERVICE_ROLE_KEY=eyJ...   # Dashboard → Settings → API → service_role key
OPENAI_API_KEY=sk-...
```

- [ ] **Step 3: Crear pipeline/.env con valores reales**

Copiar `.env.example` → `.env` y rellenar los tres valores. El `SUPABASE_SERVICE_ROLE_KEY` está en Supabase Dashboard → Project Settings → API → `service_role` (NO el anon key).

- [ ] **Step 4: Instalar dependencias**

```bash
cd "c:/Users/User/Desktop/proyecto TI/gosmart/pipeline"
pip install -r requirements.txt
```

Resultado esperado: todas las dependencias instaladas sin errores.

---

### Task 3: Módulo normalizador Python (TDD)

**Files:**
- Create: `pipeline/colombia_normalizer.py`
- Create: `tests/pipeline/test_normalizer.py`

- [ ] **Step 1: Escribir tests primero**

```python
# tests/pipeline/test_normalizer.py
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..', 'pipeline'))
from colombia_normalizer import expand_abbreviations, fix_toponyms, detect_city

def test_expand_carrera():
    assert expand_abbreviations("Cra. 7 con Cl. 45") == "Carrera 7 con Calle 45"

def test_expand_kr():
    assert expand_abbreviations("Kr 13 Cl 72") == "Carrera 13 Calle 72"

def test_expand_diagonal():
    assert expand_abbreviations("Dg. 22B # 34-12") == "Diagonal 22B # 34-12"

def test_expand_transversal():
    assert expand_abbreviations("Tv. 45 con Av. 68") == "Transversal 45 con Avenida 68"

def test_fix_bogota():
    assert fix_toponyms("bogota") == "Bogotá"

def test_fix_medellin():
    assert fix_toponyms("Medellin") == "Medellín"

def test_fix_barranquilla_typo():
    assert fix_toponyms("Barranquila") == "Barranquilla"

def test_detect_city_transmilenio():
    city, conf = detect_city("¿dónde queda la estación de transmilenio más cercana?")
    assert city == "Bogotá"
    assert conf == "high"

def test_detect_city_mio():
    city, conf = detect_city("¿El MIO llega al barrio Aguablanca?")
    assert city == "Cali"
    assert conf == "high"

def test_detect_city_explicit():
    city, conf = detect_city("Cómo llego al parque de Medellín desde el metro")
    assert city == "Medellín"
    assert conf == "high"

def test_detect_city_none():
    city, conf = detect_city("¿Cuánto cuesta el bus?")
    assert city is None
    assert conf == "none"
```

- [ ] **Step 2: Correr tests — verificar que FALLAN**

```bash
cd "c:/Users/User/Desktop/proyecto TI/gosmart"
python -m pytest tests/pipeline/test_normalizer.py -v
```

Resultado esperado: `ModuleNotFoundError: No module named 'colombia_normalizer'`

- [ ] **Step 3: Implementar colombia_normalizer.py**

```python
# pipeline/colombia_normalizer.py
import re
from unidecode import unidecode

# ── Abreviaturas viales ───────────────────────────────────────────────────────
_ABBREVS = [
    (r'\bCra?\.?\s*', 'Carrera '),
    (r'\bKr\.?\s*',   'Carrera '),
    (r'\bCll?\.?\s*', 'Calle '),
    (r'\bAv\.?\s*',   'Avenida '),
    (r'\bDg\.?\s*',   'Diagonal '),
    (r'\bDiag\.?\s*', 'Diagonal '),
    (r'\bTv\.?\s*',   'Transversal '),
    (r'\bTrv\.?\s*',  'Transversal '),
    (r'\bTrans\.?\s*','Transversal '),
    (r'\bAc\b',       'Autopista Central'),
    (r'\bAk\b',       'Autopista Kennedy'),
    (r'\bBv\.?\s*',   'Bulevar '),
    (r'\bNro?\.',     'Número'),
]
_ABBREV_PATTERNS = [(re.compile(p, re.IGNORECASE), r) for p, r in _ABBREVS]

# ── Topónimos ─────────────────────────────────────────────────────────────────
_TOPONYMS = {
    'bogota': 'Bogotá', 'medellin': 'Medellín', 'barranquila': 'Barranquilla',
    'cartagena de indias': 'Cartagena', 'cali': 'Cali',
    'bucaramanga': 'Bucaramanga', 'pereira': 'Pereira', 'manizales': 'Manizales',
}

# ── Inferencia de ciudad desde sistema de transporte ─────────────────────────
_TRANSPORT_CITY = [
    (re.compile(r'transmilenio|sitp|\bTM\b|portal norte|portal sur|portal el dorado', re.I), 'Bogotá'),
    (re.compile(r'metro de medell|metroplús|metroplus|metrocable', re.I), 'Medellín'),
    (re.compile(r'\bMIO\b|masivo integrado de occidente', re.I), 'Cali'),
    (re.compile(r'transmetro', re.I), 'Barranquilla'),
    (re.compile(r'transcaribe', re.I), 'Cartagena'),
    (re.compile(r'metrolínea|metrolinea', re.I), 'Bucaramanga'),
    (re.compile(r'megabús|megabus', re.I), 'Pereira'),
]

# Ciudades mencionadas explícitamente
_CITY_NAMES = re.compile(
    r'\b(bogot[aá]|medell[ií]n|cali|barranquilla|cartagena|bucaramanga|pereira|manizales)\b',
    re.I
)
_CITY_NORMALIZE = {
    'bogota': 'Bogotá', 'bogotá': 'Bogotá',
    'medellín': 'Medellín', 'medellin': 'Medellín',
    'cali': 'Cali', 'barranquilla': 'Barranquilla',
    'cartagena': 'Cartagena', 'bucaramanga': 'Bucaramanga',
    'pereira': 'Pereira', 'manizales': 'Manizales',
}


def expand_abbreviations(text: str) -> str:
    """Expande abreviaturas viales colombianas en el texto."""
    for pattern, replacement in _ABBREV_PATTERNS:
        text = pattern.sub(replacement, text)
    return re.sub(r' +', ' ', text).strip()


def fix_toponyms(text: str) -> str:
    """Corrige acentos y typos comunes en nombres de ciudades."""
    key = text.lower().strip()
    if key in _TOPONYMS:
        return _TOPONYMS[key]
    # Reemplazar dentro del texto
    for wrong, correct in _TOPONYMS.items():
        text = re.sub(r'\b' + re.escape(wrong) + r'\b', correct, text, flags=re.I)
    return text


def detect_city(text: str) -> tuple[str | None, str]:
    """
    Detecta ciudad en el texto.
    Returns: (city_name | None, confidence: 'high' | 'medium' | 'none')
    """
    # 1. Sistema de transporte → alta confianza
    for pattern, city in _TRANSPORT_CITY:
        if pattern.search(text):
            return city, 'high'
    # 2. Ciudad mencionada explícitamente
    m = _CITY_NAMES.search(text)
    if m:
        city = _CITY_NORMALIZE.get(m.group(1).lower())
        if city:
            return city, 'high'
    return None, 'none'


def normalize(text: str) -> dict:
    """Pipeline completo: expand + fix toponyms + detect city."""
    expanded = expand_abbreviations(text)
    fixed = fix_toponyms(expanded)
    city, confidence = detect_city(text)  # detect on original for better matching
    return {
        'original': text,
        'normalized': fixed,
        'city': city,
        'city_confidence': confidence,
        'abbreviations_expanded': [p for p, _ in _ABBREVS
                                    if re.search(p, text, re.I)],
    }
```

- [ ] **Step 4: Correr tests — verificar que PASAN**

```bash
python -m pytest tests/pipeline/test_normalizer.py -v
```

Resultado esperado: todos `PASSED`.

- [ ] **Step 5: Commit**

```bash
cd "c:/Users/User/Desktop/proyecto TI/gosmart"
git add pipeline/colombia_normalizer.py pipeline/requirements.txt pipeline/.env.example tests/pipeline/test_normalizer.py backend/migrations/006_colombia_kg.sql
git commit -m "feat: add colombia_kg DB migration and normalizer module"
```

---

### Task 4: Ingestión OSM Colombia

**Files:**
- Create: `pipeline/ingest_osm.py`

- [ ] **Step 1: Crear ingest_osm.py**

```python
# pipeline/ingest_osm.py
"""
Descarga entidades de transporte de Colombia desde OpenStreetMap via Overpass API.
Output: pipeline/data/osm_colombia.jsonl (una entidad JSON por línea)

Entidades descargadas:
  - Estaciones de metro, tren, cable
  - Paraderos de bus (stop_position + platform)
  - Terminales de transporte
  - Barrios (neighbourhood + suburb)
  - Municipios (admin_level=8)
  - Departamentos (admin_level=4)
"""
import json
import os
import time
import requests
from tqdm import tqdm
from dotenv import load_dotenv

load_dotenv()

OVERPASS_URL = "https://overpass-api.de/api/interpreter"
OUTPUT_FILE  = os.path.join(os.path.dirname(__file__), "data", "osm_colombia.jsonl")

# Queries Overpass para Colombia (country code CO)
QUERIES = {
    "stations": """
        [out:json][timeout:120];
        area["ISO3166-1"="CO"][admin_level=2]->.co;
        (
          node["railway"="station"](area.co);
          node["railway"="halt"](area.co);
          node["station"="subway"](area.co);
          node["aerialway"="station"](area.co);
        );
        out body;
    """,
    "bus_stops": """
        [out:json][timeout:180];
        area["ISO3166-1"="CO"][admin_level=2]->.co;
        node["highway"="bus_stop"](area.co);
        out body;
    """,
    "terminals": """
        [out:json][timeout:60];
        area["ISO3166-1"="CO"][admin_level=2]->.co;
        (
          node["amenity"="bus_station"](area.co);
          way["amenity"="bus_station"](area.co);
        );
        out center;
    """,
    "neighborhoods": """
        [out:json][timeout:120];
        area["ISO3166-1"="CO"][admin_level=2]->.co;
        (
          node["place"="neighbourhood"](area.co);
          node["place"="suburb"](area.co);
        );
        out body;
    """,
    "municipalities": """
        [out:json][timeout:60];
        area["ISO3166-1"="CO"][admin_level=2]->.co;
        node["place"="city"](area.co);
        node["place"="town"](area.co);
        out body;
    """,
}

TYPE_MAP = {
    "stations":      "station",
    "bus_stops":     "stop",
    "terminals":     "terminal",
    "neighborhoods": "neighborhood",
    "municipalities":"municipality",
}


def fetch_overpass(query: str, label: str) -> list[dict]:
    print(f"  Descargando {label} desde Overpass...")
    resp = requests.post(OVERPASS_URL, data={"data": query}, timeout=240)
    resp.raise_for_status()
    elements = resp.json().get("elements", [])
    print(f"  → {len(elements)} elementos")
    return elements


def element_to_entity(el: dict, entity_type: str) -> dict | None:
    tags = el.get("tags", {})
    name = tags.get("name:es") or tags.get("name") or tags.get("ref")
    if not name:
        return None

    lat = el.get("lat") or (el.get("center", {}) or {}).get("lat")
    lon = el.get("lon") or (el.get("center", {}) or {}).get("lon")

    city = (tags.get("addr:city") or tags.get("is_in:city") or
            tags.get("is_in:municipality") or "").strip() or None
    dept = (tags.get("addr:state") or tags.get("is_in:state") or "").strip() or None

    return {
        "osm_id":   el.get("id"),
        "name":     name,
        "type":     entity_type,
        "city":     city,
        "department": dept,
        "lat":      float(lat) if lat else None,
        "lon":      float(lon) if lon else None,
        "tags":     tags,
        "source":   "osm",
    }


def main():
    os.makedirs(os.path.dirname(OUTPUT_FILE), exist_ok=True)
    total = 0
    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        for key, query in QUERIES.items():
            entity_type = TYPE_MAP[key]
            try:
                elements = fetch_overpass(query, key)
                for el in tqdm(elements, desc=f"  Procesando {key}"):
                    entity = element_to_entity(el, entity_type)
                    if entity:
                        f.write(json.dumps(entity, ensure_ascii=False) + "\n")
                        total += 1
            except Exception as e:
                print(f"  ERROR en {key}: {e} — continuando...")
            time.sleep(3)  # respetar rate limit de Overpass

    print(f"\nTotal OSM: {total} entidades → {OUTPUT_FILE}")


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Crear directorio de datos**

```bash
mkdir -p "c:/Users/User/Desktop/proyecto TI/gosmart/pipeline/data"
```

- [ ] **Step 3: Correr ingestión OSM** *(toma ~20–40 minutos)*

```bash
cd "c:/Users/User/Desktop/proyecto TI/gosmart"
python pipeline/ingest_osm.py
```

Resultado esperado: archivo `pipeline/data/osm_colombia.jsonl` con 20k–40k entidades.

---

### Task 5: Ingestión DANE

**Files:**
- Create: `pipeline/ingest_dane.py`

- [ ] **Step 1: Crear ingest_dane.py**

```python
# pipeline/ingest_dane.py
"""
Descarga municipios y departamentos de Colombia desde datos.gov.co (DIVIPOLA).
Output: pipeline/data/dane_colombia.jsonl
"""
import json, os, requests
from dotenv import load_dotenv

load_dotenv()

OUTPUT_FILE = os.path.join(os.path.dirname(__file__), "data", "dane_colombia.jsonl")

# DANE DIVIPOLA — municipios oficiales de Colombia
# API pública de datos.gov.co, no requiere autenticación
DANE_MUNICIPIOS_URL = (
    "https://www.datos.gov.co/resource/gdxc-w37w.json"
    "?$limit=1500&$select=c_digo_dane_del_departamento,departamento,"
    "c_digo_dane_del_municipio,municipio"
)

DANE_DEPTOS_URL = (
    "https://www.datos.gov.co/resource/gdxc-w37w.json"
    "?$limit=50&$select=c_digo_dane_del_departamento,departamento&$group=c_digo_dane_del_departamento,departamento"
)


def main():
    os.makedirs(os.path.dirname(OUTPUT_FILE), exist_ok=True)
    total = 0

    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        # Municipios
        print("Descargando municipios DANE...")
        resp = requests.get(DANE_MUNICIPIOS_URL, timeout=60)
        resp.raise_for_status()
        for row in resp.json():
            name = row.get("municipio", "").strip().title()
            dept = row.get("departamento", "").strip().title()
            if not name:
                continue
            entity = {
                "dane_id":    row.get("c_digo_dane_del_municipio"),
                "name":       name,
                "type":       "municipality",
                "city":       name,
                "department": dept,
                "lat":        None,
                "lon":        None,
                "source":     "dane",
            }
            f.write(json.dumps(entity, ensure_ascii=False) + "\n")
            total += 1

        # Departamentos
        print("Descargando departamentos DANE...")
        resp = requests.get(DANE_DEPTOS_URL, timeout=60)
        resp.raise_for_status()
        for row in resp.json():
            name = row.get("departamento", "").strip().title()
            if not name:
                continue
            entity = {
                "dane_id":    row.get("c_digo_dane_del_departamento"),
                "name":       name,
                "type":       "department",
                "city":       None,
                "department": name,
                "lat":        None,
                "lon":        None,
                "source":     "dane",
            }
            f.write(json.dumps(entity, ensure_ascii=False) + "\n")
            total += 1

    print(f"Total DANE: {total} entidades → {OUTPUT_FILE}")


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Correr ingestión DANE** *(toma ~2 minutos)*

```bash
python pipeline/ingest_dane.py
```

Resultado esperado: `pipeline/data/dane_colombia.jsonl` con ~1.150 municipios + ~32 departamentos.

---

### Task 6: Merge y deduplicación (TDD)

**Files:**
- Create: `pipeline/merge_dedupe.py`
- Create: `tests/pipeline/test_merge_dedupe.py`

- [ ] **Step 1: Escribir tests primero**

```python
# tests/pipeline/test_merge_dedupe.py
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..', 'pipeline'))
from merge_dedupe import haversine_m, are_duplicates, prefer_canonical_name

def test_haversine_same_point():
    assert haversine_m(4.71, -74.07, 4.71, -74.07) == 0.0

def test_haversine_50m():
    # Points ~50m apart
    d = haversine_m(4.710000, -74.070000, 4.710450, -74.070000)
    assert 40 < d < 60

def test_are_duplicates_same_type_close():
    a = {"lat": 4.71, "lon": -74.07, "type": "station"}
    b = {"lat": 4.71005, "lon": -74.07001, "type": "station"}
    assert are_duplicates(a, b) is True

def test_are_duplicates_different_type():
    a = {"lat": 4.71, "lon": -74.07, "type": "station"}
    b = {"lat": 4.71, "lon": -74.07, "type": "stop"}
    assert are_duplicates(a, b) is False

def test_are_duplicates_far_apart():
    a = {"lat": 4.71, "lon": -74.07, "type": "station"}
    b = {"lat": 6.25, "lon": -75.56, "type": "station"}
    assert are_duplicates(a, b) is False

def test_prefer_canonical_name_dane_wins_municipality():
    osm = {"name": "Bogotá D.C.", "source": "osm", "type": "municipality"}
    dane = {"name": "Bogotá", "source": "dane", "type": "municipality"}
    assert prefer_canonical_name(osm, dane) == "Bogotá"

def test_prefer_canonical_name_osm_wins_station():
    osm = {"name": "Estación Niza", "source": "osm", "type": "station"}
    dane = {"name": "Niza", "source": "dane", "type": "station"}
    assert prefer_canonical_name(osm, dane) == "Estación Niza"
```

- [ ] **Step 2: Correr tests — verificar FALLAN**

```bash
python -m pytest tests/pipeline/test_merge_dedupe.py -v
```

Resultado esperado: `ModuleNotFoundError: No module named 'merge_dedupe'`

- [ ] **Step 3: Implementar merge_dedupe.py**

```python
# pipeline/merge_dedupe.py
"""
Fusiona osm_colombia.jsonl + dane_colombia.jsonl.
Deduplica entidades del mismo tipo con coordenadas a ≤50m.
Regla de nombre canónico: DANE gana para municipios/departamentos, OSM para el resto.
Output: pipeline/data/kg_canonical.jsonl
"""
import json, math, os
from tqdm import tqdm

DATA_DIR = os.path.join(os.path.dirname(__file__), "data")
OUTPUT   = os.path.join(DATA_DIR, "kg_canonical.jsonl")
TOLERANCE_M = 50  # metros


def haversine_m(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
    R = 6_371_000
    p = math.pi / 180
    a = (math.sin((lat2-lat1)*p/2)**2 +
         math.cos(lat1*p) * math.cos(lat2*p) * math.sin((lon2-lon1)*p/2)**2)
    return 2 * R * math.asin(math.sqrt(a))


def are_duplicates(a: dict, b: dict) -> bool:
    if a["type"] != b["type"]:
        return False
    if a.get("lat") is None or b.get("lat") is None:
        return False
    d = haversine_m(a["lat"], a["lon"], b["lat"], b["lon"])
    return d <= TOLERANCE_M


# DANE preferred for administrative entities
_DANE_PREFERRED = {"municipality", "department"}


def prefer_canonical_name(a: dict, b: dict) -> str:
    """Returns the preferred canonical name given two entities (one osm, one dane)."""
    dane = a if a.get("source") == "dane" else b
    osm  = b if a.get("source") == "dane" else a
    if dane["type"] in _DANE_PREFERRED:
        return dane["name"]
    return osm["name"]


def load_jsonl(path: str) -> list[dict]:
    entities = []
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line:
                entities.append(json.loads(line))
    return entities


def merge_and_dedupe() -> list[dict]:
    osm_path  = os.path.join(DATA_DIR, "osm_colombia.jsonl")
    dane_path = os.path.join(DATA_DIR, "dane_colombia.jsonl")

    osm_entities  = load_jsonl(osm_path)  if os.path.exists(osm_path)  else []
    dane_entities = load_jsonl(dane_path) if os.path.exists(dane_path) else []

    all_entities = osm_entities + dane_entities
    print(f"Total antes de dedup: {len(all_entities)} (OSM={len(osm_entities)}, DANE={len(dane_entities)})")

    canonical: list[dict] = []
    for entity in tqdm(all_entities, desc="Deduplicando"):
        merged = False
        for existing in canonical:
            if are_duplicates(entity, existing):
                # Fusionar aliases; elegir nombre canónico
                existing["canonical_name"] = prefer_canonical_name(entity, existing)
                if entity["name"] != existing["canonical_name"]:
                    existing.setdefault("aliases", []).append(entity["name"])
                merged = True
                break
        if not merged:
            entry = {
                "canonical_name": entity["name"],
                "type":           entity["type"],
                "city":           entity.get("city"),
                "department":     entity.get("department"),
                "lat":            entity.get("lat"),
                "lon":            entity.get("lon"),
                "source":         entity.get("source", "osm"),
                "aliases":        [],
                "metadata":       {},
            }
            canonical.append(entry)

    print(f"Total después de dedup: {len(canonical)}")
    return canonical


def main():
    os.makedirs(DATA_DIR, exist_ok=True)
    canonical = merge_and_dedupe()
    with open(OUTPUT, "w", encoding="utf-8") as f:
        for entity in canonical:
            f.write(json.dumps(entity, ensure_ascii=False) + "\n")
    print(f"KG canónico → {OUTPUT}")


if __name__ == "__main__":
    main()
```

- [ ] **Step 4: Correr tests — verificar PASAN**

```bash
python -m pytest tests/pipeline/test_merge_dedupe.py -v
```

Resultado esperado: todos `PASSED`.

- [ ] **Step 5: Correr merge sobre datos descargados**

```bash
python pipeline/merge_dedupe.py
```

Resultado esperado: `pipeline/data/kg_canonical.jsonl` con ~45k–55k entidades.

---

### Task 7: Generación de chunks (TDD)

**Files:**
- Create: `pipeline/build_chunks.py`
- Create: `tests/pipeline/test_build_chunks.py`

- [ ] **Step 1: Escribir tests**

```python
# tests/pipeline/test_build_chunks.py
import sys, os
sys.path.insert(0, os.path.join(os.path.dirname(__file__), '..', '..', 'pipeline'))
from build_chunks import build_embed_text

def test_station_chunk_includes_city():
    entity = {
        "canonical_name": "Estación Niza",
        "type": "station",
        "city": "Bogotá",
        "department": "Cundinamarca",
        "aliases": ["Portal Niza", "Niza-127"],
        "metadata": {"operator": "TransMilenio", "fare_cop": 2950},
    }
    text = build_embed_text(entity)
    assert "Estación Niza" in text
    assert "Bogotá" in text
    assert "Portal Niza" in text  # alias incluido
    assert "TransMilenio" in text

def test_municipality_chunk():
    entity = {
        "canonical_name": "Medellín",
        "type": "municipality",
        "city": "Medellín",
        "department": "Antioquia",
        "aliases": ["Medellin"],
        "metadata": {},
    }
    text = build_embed_text(entity)
    assert "Medellín" in text
    assert "Antioquia" in text
    assert len(text) > 20

def test_chunk_no_null_literal():
    entity = {
        "canonical_name": "Barrio Chapinero",
        "type": "neighborhood",
        "city": "Bogotá",
        "department": None,
        "aliases": [],
        "metadata": {},
    }
    text = build_embed_text(entity)
    assert "None" not in text
    assert "null" not in text
```

- [ ] **Step 2: Correr tests — verificar FALLAN**

```bash
python -m pytest tests/pipeline/test_build_chunks.py -v
```

- [ ] **Step 3: Implementar build_chunks.py**

```python
# pipeline/build_chunks.py
"""
Genera embed_text "descripción densa" por entidad del KG.
El texto incluye nombre, aliases, ciudad, tipo y metadata relevante.
Output: pipeline/data/kg_chunks.jsonl
"""
import json, os
from tqdm import tqdm

DATA_DIR = os.path.join(os.path.dirname(__file__), "data")

_TYPE_LABELS = {
    "station":      "estación de transporte",
    "stop":         "paradero de transporte público",
    "terminal":     "terminal de transporte",
    "neighborhood": "barrio",
    "locality":     "localidad o comuna",
    "municipality": "municipio",
    "department":   "departamento",
    "street":       "vía o calle",
    "landmark":     "punto de referencia de transporte",
    "poi":          "punto de interés",
}


def build_embed_text(entity: dict) -> str:
    name  = entity["canonical_name"]
    etype = _TYPE_LABELS.get(entity["type"], entity["type"])
    city  = entity.get("city") or ""
    dept  = entity.get("department") or ""
    aliases: list[str] = entity.get("aliases") or []
    meta: dict = entity.get("metadata") or {}

    parts = [f"{name}, {etype} en Colombia."]

    if city and dept and city != dept:
        parts.append(f"Ubicado en {city}, {dept}.")
    elif city:
        parts.append(f"Ubicado en {city}.")
    elif dept:
        parts.append(f"Ubicado en el departamento de {dept}.")

    if aliases:
        clean = [a for a in aliases if a and a != name]
        if clean:
            parts.append(f"También conocido como: {', '.join(clean)}.")

    if meta.get("operator"):
        parts.append(f"Operado por {meta['operator']}.")
    if meta.get("fare_cop"):
        parts.append(f"Tarifa: {meta['fare_cop']:,} COP.".replace(",", "."))
    if meta.get("line"):
        parts.append(f"Línea: {meta['line']}.")
    if meta.get("connections"):
        parts.append(f"Conecta con: {meta['connections']}.")

    return " ".join(parts)


def main():
    input_path  = os.path.join(DATA_DIR, "kg_canonical.jsonl")
    output_path = os.path.join(DATA_DIR, "kg_chunks.jsonl")
    os.makedirs(DATA_DIR, exist_ok=True)

    total = 0
    with open(input_path, encoding="utf-8") as fin, \
         open(output_path, "w", encoding="utf-8") as fout:
        for line in tqdm(fin, desc="Generando chunks"):
            entity = json.loads(line)
            entity["embed_text"] = build_embed_text(entity)
            fout.write(json.dumps(entity, ensure_ascii=False) + "\n")
            total += 1

    print(f"Chunks generados: {total} → {output_path}")


if __name__ == "__main__":
    main()
```

- [ ] **Step 4: Correr tests — verificar PASAN**

```bash
python -m pytest tests/pipeline/test_build_chunks.py -v
```

- [ ] **Step 5: Generar chunks**

```bash
python pipeline/build_chunks.py
```

Resultado esperado: `pipeline/data/kg_chunks.jsonl`.

- [ ] **Step 6: Commit pipeline base**

```bash
git add pipeline/ tests/pipeline/
git commit -m "feat: add Colombia KG pipeline (ingest OSM+DANE, merge, chunks)"
```

---

### Task 8: Embeddings y carga en Supabase

**Files:**
- Create: `pipeline/embed.py`
- Create: `pipeline/load_supabase.py`

- [ ] **Step 1: Crear embed.py**

```python
# pipeline/embed.py
"""
Genera embeddings OpenAI text-embedding-3-small para cada entidad del KG.
Procesa en batches de 100 para respetar rate limits.
Output: pipeline/data/kg_embeddings.jsonl (entity + embedding vector)
Costo estimado: ~$0.10 USD para 51k entidades.
"""
import json, os, time
from openai import OpenAI
from tqdm import tqdm
from dotenv import load_dotenv

load_dotenv()

DATA_DIR   = os.path.join(os.path.dirname(__file__), "data")
INPUT_FILE = os.path.join(DATA_DIR, "kg_chunks.jsonl")
OUTPUT_FILE= os.path.join(DATA_DIR, "kg_embeddings.jsonl")
BATCH_SIZE = 100
MODEL      = "text-embedding-3-small"

client = OpenAI(api_key=os.environ["OPENAI_API_KEY"])


def embed_batch(texts: list[str]) -> list[list[float]]:
    resp = client.embeddings.create(model=MODEL, input=texts)
    return [item.embedding for item in resp.data]


def main():
    entities = []
    with open(INPUT_FILE, encoding="utf-8") as f:
        for line in f:
            if line.strip():
                entities.append(json.loads(line))

    print(f"Total entidades a embeber: {len(entities)}")

    # Retomar si fue interrumpido.
    # Usamos hash(canonical_name + city + type) como clave de checkpoint porque
    # canonical_name no es único entre ciudades (ej. "Barrio Centro" existe en múltiples municipios).
    import hashlib

    def _ckpt_key(e: dict) -> str:
        raw = f"{e['canonical_name']}|{e.get('city','')}|{e['type']}"
        return hashlib.md5(raw.encode()).hexdigest()

    done_ids: set[str] = set()
    if os.path.exists(OUTPUT_FILE):
        with open(OUTPUT_FILE, encoding="utf-8") as f:
            for line in f:
                if line.strip():
                    done_ids.add(_ckpt_key(json.loads(line)))
        print(f"  Ya procesados: {len(done_ids)} — continuando desde ahí")

    with open(OUTPUT_FILE, "a", encoding="utf-8") as fout:
        pending = [e for e in entities if _ckpt_key(e) not in done_ids]
        for i in tqdm(range(0, len(pending), BATCH_SIZE), desc="Embeddings"):
            batch = pending[i:i+BATCH_SIZE]
            texts = [e["embed_text"] for e in batch]
            try:
                vectors = embed_batch(texts)
                for entity, vec in zip(batch, vectors):
                    entity["embedding"] = vec
                    fout.write(json.dumps(entity, ensure_ascii=False) + "\n")
            except Exception as e:
                print(f"\nError en batch {i}: {e} — reintentando...")
                time.sleep(5)
                vectors = embed_batch(texts)
                for entity, vec in zip(batch, vectors):
                    entity["embedding"] = vec
                    fout.write(json.dumps(entity, ensure_ascii=False) + "\n")
            time.sleep(0.1)  # respetar rate limit

    print(f"Embeddings → {OUTPUT_FILE}")


if __name__ == "__main__":
    main()
```

- [ ] **Step 2: Correr embed.py** *(toma ~20 minutos, costo ~$0.10)*

```bash
python pipeline/embed.py
```

Si se interrumpe, se puede reanudar — tiene checkpoint por nombre canónico.

- [ ] **Step 3: Crear load_supabase.py**

```python
# pipeline/load_supabase.py
"""
Inserta el KG completo en Supabase:
  1. colombia_kg (entidades)
  2. colombia_kg_aliases (aliases)
  3. colombia_kg_embeddings (vectores)
  4. Crea índice HNSW DESPUÉS de la carga

Usa service_role key para bypasear RLS.
"""
import json, os
from supabase import create_client, Client
from tqdm import tqdm
from dotenv import load_dotenv

load_dotenv()

DATA_FILE = os.path.join(os.path.dirname(__file__), "data", "kg_embeddings.jsonl")
BATCH_SIZE = 200

supabase: Client = create_client(
    os.environ["SUPABASE_URL"],
    os.environ["SUPABASE_SERVICE_ROLE_KEY"]
)


def load_entities():
    entities = []
    with open(DATA_FILE, encoding="utf-8") as f:
        for line in f:
            if line.strip():
                entities.append(json.loads(line))
    return entities


def insert_batch_kg(batch: list[dict]) -> list[dict]:
    rows = [{
        "canonical_name":  e["canonical_name"],
        "type":            e["type"],
        "city":            e.get("city"),
        "department":      e.get("department"),
        "lat":             e.get("lat"),
        "lon":             e.get("lon"),
        "embed_text":      e["embed_text"],
        "metadata":        e.get("metadata", {}),
        "source":          e.get("source", "osm"),
    } for e in batch]
    result = supabase.table("colombia_kg").insert(rows).execute()
    return result.data


def insert_aliases(entity_id: str, aliases: list[str]):
    if not aliases:
        return
    rows = [{"entity_id": entity_id, "alias": a, "alias_type": "popular"}
            for a in aliases if a]
    if rows:
        supabase.table("colombia_kg_aliases").insert(rows).execute()


def insert_embeddings(entity_id: str, embedding: list[float]):
    supabase.table("colombia_kg_embeddings").insert({
        "entity_id": entity_id,
        "embedding": embedding,
    }).execute()


def create_hnsw_index():
    print("Creando índice HNSW (puede tomar varios minutos)...")
    supabase.rpc("create_hnsw_index", {}).execute()


def main():
    entities = load_entities()
    print(f"Cargando {len(entities)} entidades en Supabase...")

    for i in tqdm(range(0, len(entities), BATCH_SIZE), desc="Insertando KG"):
        batch = entities[i:i+BATCH_SIZE]
        inserted = insert_batch_kg(batch)
        for entity, row in zip(batch, inserted):
            entity_id = row["id"]
            insert_aliases(entity_id, entity.get("aliases", []))
            if entity.get("embedding"):
                insert_embeddings(entity_id, entity["embedding"])

    # Crear índice HNSW DESPUÉS del bulk load vía función RPC registrada en 006_colombia_kg.sql
    # (supabase-py 2.x no puede ejecutar DDL directo — usamos la función helper)
    print("\nCreando índice HNSW en embeddings (puede tomar varios minutos)...")
    supabase.rpc("create_hnsw_index", {}).execute()
    print("Carga completa.")


if __name__ == "__main__":
    main()
```

> **Nota:** El índice HNSW se puede crear también manualmente en Supabase SQL Editor si el RPC falla:
> ```sql
> CREATE INDEX idx_embeddings_hnsw ON colombia_kg_embeddings
> USING hnsw (embedding vector_cosine_ops) WITH (m = 16, ef_construction = 64);
> ```

- [ ] **Step 4: Correr carga en Supabase** *(toma ~15 minutos)*

```bash
python pipeline/load_supabase.py
```

- [ ] **Step 5: Verificar carga en Supabase**

En Supabase SQL Editor:
```sql
SELECT type, COUNT(*) FROM colombia_kg GROUP BY type ORDER BY COUNT(*) DESC;
SELECT COUNT(*) FROM colombia_kg_aliases;
SELECT COUNT(*) FROM colombia_kg_embeddings;
```

Resultado esperado: miles de filas en cada tabla.

- [ ] **Step 6: Commit**

```bash
git add pipeline/embed.py pipeline/load_supabase.py
git commit -m "feat: add embed and load pipeline scripts for Colombia KG"
```

---

## Chunk 3: Edge Function RAG (Deno)

### Task 9: Módulo normalizer.ts

**Files:**
- Create: `backend/functions/ai-chat/normalizer.ts`

- [ ] **Step 1: Crear normalizer.ts**

```typescript
// backend/functions/ai-chat/normalizer.ts

export interface NormalizedQuery {
  original: string
  normalized: string
  city: string | null
  city_confidence: 'high' | 'medium' | 'none'
  intent: 'address' | 'station' | 'neighborhood' | 'route' | 'fare' | 'general'
  entities_mentioned: string[]
  abbreviations_expanded: string[]
}

// ── Abreviaturas viales ───────────────────────────────────────────────────────
const ABBREVS: [RegExp, string][] = [
  [/\bCra?\.?\s*/gi,   'Carrera '],
  [/\bKr\.?\s*/gi,     'Carrera '],
  [/\bCll?\.?\s*/gi,   'Calle '],
  [/\bAv\.?\s*/gi,     'Avenida '],
  [/\bDg\.?\s*/gi,     'Diagonal '],
  [/\bDiag\.?\s*/gi,   'Diagonal '],
  [/\bTv\.?\s*/gi,     'Transversal '],
  [/\bTrv\.?\s*/gi,    'Transversal '],
  [/\bTrans\.?\s*/gi,  'Transversal '],
  [/\bAc\b/gi,         'Autopista Central'],
  [/\bAk\b/gi,         'Autopista Kennedy'],
  [/\bBv\.?\s*/gi,     'Bulevar '],
  [/\bNro?\./gi,       'Número'],
]

// ── Topónimos con typos frecuentes ────────────────────────────────────────────
const TOPONYMS: [RegExp, string][] = [
  [/\bbogota\b/gi,            'Bogotá'],
  [/\bmedellin\b/gi,          'Medellín'],
  [/\bbarranquila\b/gi,       'Barranquilla'],
  [/\bcartagena de indias\b/gi,'Cartagena'],
]

// ── Inferencia de ciudad desde sistema de transporte ─────────────────────────
const TRANSPORT_CITY: [RegExp, string][] = [
  [/transmilenio|sitp|\bTM\b|portal norte|portal sur|portal el dorado/i, 'Bogotá'],
  [/metro de medell|metroplús|metroplus|metrocable/i,                     'Medellín'],
  [/\bMIO\b|masivo integrado de occidente/i,                              'Cali'],
  [/transmetro/i,                                                         'Barranquilla'],
  [/transcaribe/i,                                                        'Cartagena'],
  [/metrolínea|metrolinea/i,                                              'Bucaramanga'],
  [/megabús|megabus/i,                                                    'Pereira'],
]

// Ciudades mencionadas explícitamente
const CITY_RE = /\b(bogot[aá]|medell[ií]n|cali|barranquilla|cartagena|bucaramanga|pereira|manizales)\b/i
const CITY_NORMALIZE: Record<string, string> = {
  'bogota': 'Bogotá', 'bogotá': 'Bogotá',
  'medellin': 'Medellín', 'medellín': 'Medellín',
  'cali': 'Cali', 'barranquilla': 'Barranquilla',
  'cartagena': 'Cartagena', 'bucaramanga': 'Bucaramanga',
  'pereira': 'Pereira', 'manizales': 'Manizales',
}

// ── Intent detection ──────────────────────────────────────────────────────────
function detectIntent(text: string): NormalizedQuery['intent'] {
  const q = text.toLowerCase()
  if (/direcci[oó]n|calle|carrera|avenida|diagonal|transversal|cra|cl\b|av\b/.test(q)) return 'address'
  if (/estaci[oó]n|parada|paradero|portal|terminal/.test(q)) return 'station'
  if (/barrio|localidad|comuna|sector|zona/.test(q)) return 'neighborhood'
  if (/ruta|llegar|como ir|bus|metro|transporte|línea/.test(q)) return 'route'
  if (/tarifa|costo|precio|cuanto cuesta|valor|pesos/.test(q)) return 'fare'
  return 'general'
}

export function normalize(query: string, cityHint?: string): NormalizedQuery {
  let text = query.trim()

  // Expandir abreviaturas
  const expanded: string[] = []
  for (const [pattern, replacement] of ABBREVS) {
    const before = text
    text = text.replace(pattern, replacement)
    if (text !== before) expanded.push(replacement.trim())
  }

  // Corregir topónimos
  for (const [pattern, replacement] of TOPONYMS) {
    text = text.replace(pattern, replacement)
  }

  // Detectar ciudad — city_hint tiene prioridad sobre detección automática
  let city: string | null = null
  let confidence: NormalizedQuery['city_confidence'] = 'none'

  if (cityHint?.trim()) {
    city = cityHint.trim()
    confidence = 'high'
  } else {
    for (const [pattern, inferredCity] of TRANSPORT_CITY) {
      if (pattern.test(query)) { city = inferredCity; confidence = 'high'; break }
    }
    if (!city) {
      const m = query.match(CITY_RE)
      if (m) {
        city = CITY_NORMALIZE[m[1].toLowerCase()] ?? null
        if (city) confidence = 'high'
      }
    }
  }

  return {
    original: query,
    normalized: text.replace(/\s+/g, ' ').trim(),
    city,
    city_confidence: confidence,
    intent: detectIntent(query),
    entities_mentioned: [],
    abbreviations_expanded: expanded,
  }
}
```

---

### Task 9b: Tests del normalizador Deno (TDD)

**Files:**
- Create: `backend/functions/ai-chat/normalizer_test.ts`

- [ ] **Step 1: Escribir tests Deno primero**

```typescript
// backend/functions/ai-chat/normalizer_test.ts
import { assertEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import { normalize } from './normalizer.ts'

Deno.test('expand Cra. to Carrera', () => {
  const r = normalize('Cra. 7 con Cl. 45')
  assertEquals(r.normalized, 'Carrera 7 con Calle 45')
})

Deno.test('detect city from TransMilenio', () => {
  const r = normalize('¿dónde queda transmilenio calle 100?')
  assertEquals(r.city, 'Bogotá')
  assertEquals(r.city_confidence, 'high')
})

Deno.test('detect city from MIO', () => {
  const r = normalize('El MIO llega al barrio Aguablanca?')
  assertEquals(r.city, 'Cali')
})

Deno.test('city_hint overrides auto-detect', () => {
  const r = normalize('¿cuánto cuesta el bus?', 'Medellín')
  assertEquals(r.city, 'Medellín')
  assertEquals(r.city_confidence, 'high')
})

Deno.test('no city returns none confidence', () => {
  const r = normalize('¿cuánto cuesta el bus?')
  assertEquals(r.city_confidence, 'none')
})

Deno.test('intent address detected', () => {
  const r = normalize('Carrera 13 con Calle 72 Bogotá')
  assertEquals(r.intent, 'address')
})

Deno.test('intent fare detected', () => {
  const r = normalize('¿cuánto cuesta el metro?')
  assertEquals(r.intent, 'fare')
})
```

- [ ] **Step 2: Correr tests — verificar que FALLAN**

```bash
cd "c:/Users/User/Desktop/proyecto TI/gosmart/backend/functions/ai-chat"
deno test normalizer_test.ts
```

Resultado esperado: error de importación (normalizer.ts no existe aún) o test failures.

- [ ] **Step 3: Implementar normalizer.ts** (ver Task 9 — el código está en el paso siguiente)

- [ ] **Step 4: Correr tests — verificar que PASAN**

```bash
deno test normalizer_test.ts
```

Resultado esperado: `7 passed | 0 failed`.

---

### Task 10: Módulo retrieval.ts

**Files:**
- Create: `backend/functions/ai-chat/retrieval.ts`

- [ ] **Step 1: Crear retrieval.ts**

```typescript
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

const EMBED_TIMEOUT_MS = 3_000
const EMBED_MODEL = 'text-embedding-3-small'

// ── Exact / FTS match en aliases ──────────────────────────────────────────────
export async function exactMatch(
  supabase: SupabaseClient,
  normalizedQuery: string,
  city: string | null
): Promise<KgEntity[]> {
  // Buscar aliases con FTS Spanish
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
    return { ...kg, similarity: 1.0 }  // exact match = máxima confianza
  })
}

// ── Semantic search via pgvector RPC ─────────────────────────────────────────
export async function semanticSearch(
  supabase: SupabaseClient,
  embedding: number[],
  city: string | null,
  threshold = 0.65,
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

// ── Embed query con timeout y 1 reintento ────────────────────────────────────
export async function embedQuery(
  text: string,
  openaiKey: string
): Promise<number[]> {
  return await fetchWithRetry(text, openaiKey)
}

async function fetchWithRetry(text: string, key: string, attempt = 0): Promise<number[]> {
  const controller = new AbortController()
  const timer = setTimeout(() => controller.abort(), EMBED_TIMEOUT_MS)
  try {
    const res = await fetch('https://api.openai.com/v1/embeddings', {
      method: 'POST',
      headers: { 'Authorization': `Bearer ${key}`, 'Content-Type': 'application/json' },
      body: JSON.stringify({ model: EMBED_MODEL, input: text }),
      signal: controller.signal,
    })
    const data = await res.json()
    return data.data[0].embedding as number[]
  } catch (err) {
    if (attempt === 0) {
      clearTimeout(timer)
      return fetchWithRetry(text, key, 1)  // 1 reintento automático
    }
    throw err
  } finally {
    clearTimeout(timer)
  }
}
```

---

### Task 11: Módulo context_builder.ts

**Files:**
- Create: `backend/functions/ai-chat/context_builder.ts`

- [ ] **Step 1: Crear context_builder.ts**

```typescript
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
```

---

### Task 12: Orquestador index.ts (reemplaza Edge Function existente)

**Files:**
- Modify: `backend/functions/ai-chat/index.ts`

- [ ] **Step 1: Reemplazar index.ts completamente**

```typescript
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
const SIM_THRESHOLD = 0.65

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
    const openaiKey = Deno.env.get('OPENAI_API_KEY')!
    const groqKey   = Deno.env.get('GROQ_API_KEY')!

    // 1 + 2. Normalize + detect city (city_hint overrides auto-detect)
    const nq = normalize(query, city_hint)

    if (nq.city_confidence === 'none') {
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
        const embedding = await embedQuery(nq.normalized, openaiKey)
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
```

- [ ] **Step 2: Setear secrets en Supabase**

Ir a Supabase Dashboard → Edge Functions → Secrets:
- Agregar `OPENAI_API_KEY` = tu clave de OpenAI Platform
- Agregar `GROQ_API_KEY` = tu clave de Groq (gsk_...)
- Verificar que `SUPABASE_URL` y `SUPABASE_SERVICE_ROLE_KEY` están disponibles (Supabase los inyecta automáticamente)

- [ ] **Step 3: Deploy de la Edge Function**

```bash
cd "c:/Users/User/Desktop/proyecto TI/gosmart"
npx supabase functions deploy ai-chat --no-verify-jwt
```

Si no tienes Supabase CLI instalado:
```bash
npm install -g supabase
supabase login
supabase link --project-ref <tu-project-ref>
supabase functions deploy ai-chat --no-verify-jwt
```

- [ ] **Step 4: Smoke test con curl**

```bash
curl -X POST https://<tu-project-ref>.supabase.co/functions/v1/ai-chat \
  -H "Authorization: Bearer <SUPABASE_ANON_KEY>" \
  -H "Content-Type: application/json" \
  -d '{"query": "¿Cómo llego al Portal Norte en Bogotá?", "city_hint": "Bogotá"}'
```

Resultado esperado: JSON con `content` (texto de respuesta), `entities_used` con al menos una entidad, `fallback: false`.

- [ ] **Step 5: Commit**

```bash
git add backend/functions/ai-chat/
git commit -m "feat: add RAG Edge Function with normalizer, retrieval, context builder"
```

---

## Chunk 4: Flutter — Actualizar ai_service.dart

### Task 13: Redirigir llamadas a la Edge Function

**Files:**
- Modify: `lib/services/ai_service.dart`
- Modify: `lib/core/env.dart`

- [ ] **Step 1: Actualizar env.dart — remover groqApiKey del cliente**

En [lib/core/env.dart](lib/core/env.dart), reemplazar:

```dart
  /// Groq API key — optional. If empty the AI service returns a fallback message.
  /// Get a free key (no credit card) at: https://console.groq.com
  static String get groqApiKey => dotenv.env['GROQ_API_KEY'] ?? '';
```

Con: *(eliminar las 3 líneas — la clave ahora vive en Supabase Edge Functions Secrets, no en el cliente)*

```dart
  // GROQ_API_KEY removed from client — now lives in Supabase Edge Functions Secrets
```

- [ ] **Step 2: Reemplazar lógica de llamada en ai_service.dart**

En [lib/services/ai_service.dart](lib/services/ai_service.dart), reemplazar el método `sendMessage` para llamar a la Edge Function:

```dart
Future<AiMessage> sendMessage({
  required String query,
  List<ConversationTurn>? history,
  Map<String, double>? userLocation,
  String? context,
}) async {
  final t0 = DateTime.now().millisecondsSinceEpoch;

  try {
    final safeHistory = (history ?? []).take(5).toList();
    final url = Uri.parse('${Env.supabaseUrl}/functions/v1/ai-chat');

    final response = await http
        .post(
          url,
          headers: {
            'Authorization': 'Bearer ${Env.supabaseAnonKey}',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'query': query,
            if (context != null && context.isNotEmpty) 'city_hint': context,
            'history': safeHistory.map((t) => {
              'role': t.role,
              'content': t.content,
            }).toList(),
          }),
        )
        .timeout(const Duration(seconds: 20));

    final latencyMs = DateTime.now().millisecondsSinceEpoch - t0;

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body) as Map<String, dynamic>;
      final text = data['content'] as String? ?? _fallbackReply;
      final isFallback = data['fallback'] as bool? ?? false;

      unawaited(_logLatency(
        totalMs: latencyMs,
        source: isFallback ? 'fallback' : 'groq',
        intent: 'general',
      ));

      return AiMessage(
        role: 'assistant',
        content: text,
        timestamp: DateTime.now(),
        latencyMs: latencyMs,
        source: 'groq',
      );
    } else {
      debugPrint('[AiService] Edge Function ${response.statusCode}: ${response.body}');
      return AiMessage(
        role: 'assistant',
        content: _fallbackReply,
        timestamp: DateTime.now(),
        source: 'cache',
      );
    }
  } on TimeoutException {
    return AiMessage(
      role: 'assistant',
      content: _fallbackReply,
      timestamp: DateTime.now(),
      source: 'cache',
    );
  } catch (e) {
    debugPrint('[AiService] error: $e');
    return AiMessage(
      role: 'assistant',
      content: _fallbackReply,
      timestamp: DateTime.now(),
      source: 'cache',
    );
  }
}
```

- [ ] **Step 3: Remover GROQ_API_KEY del .env del cliente**

En `.env`, eliminar o comentar la línea `GROQ_API_KEY=...`.
La clave ahora vive en Supabase Edge Functions Secrets (servidor).

- [ ] **Step 4: Verificar en dispositivo**

```bash
flutter run
```

Navegar al chat de GoSmart AI. Escribir: `¿Cómo llego a la estación Niza?`
Verificar que responde con información relevante y sin errores.

- [ ] **Step 5: Commit**

```bash
git add lib/services/ai_service.dart lib/core/env.dart .env
git commit -m "feat: redirect AI chat to Supabase Edge Function RAG"
```

---

## Chunk 5: Set de validación y métricas

### Task 14: Crear validation_queries.jsonl y validate.py

**Files:**
- Create: `tests/validation_queries.jsonl`
- Create: `pipeline/validate.py`

- [ ] **Step 1: Crear tests/validation_queries.jsonl**

Crear el archivo con ≥ 100 queries. Distribución: Bogotá ≥ 30, Medellín ≥ 20, Cali ≥ 15, Barranquilla ≥ 10, Cartagena ≥ 10, otras ≥ 15.

Contenido inicial (completar hasta 100+):

```jsonl
{"query": "¿Cómo llego al Portal Norte desde Chapinero?", "city": "Bogotá", "expected_entities": ["Portal del Norte"], "intent": "route"}
{"query": "Cra. 7 con Cl. 45 Bogotá", "city": "Bogotá", "expected_entities": ["Carrera 7"], "intent": "address"}
{"query": "La Séptima hacia el norte", "city": "Bogotá", "expected_entities": ["Carrera 7"], "intent": "route"}
{"query": "Estacion museo metro medellin", "city": "Medellín", "expected_entities": ["Estación Museo"], "intent": "station"}
{"query": "Cuanto cuesta el metro en Medellin", "city": "Medellín", "expected_entities": ["Metro de Medellín"], "intent": "fare"}
{"query": "Transmilenio calle 100", "city": "Bogotá", "expected_entities": ["Calle 100"], "intent": "station"}
{"query": "MIO en Cali como funciona", "city": "Cali", "expected_entities": ["MIO"], "intent": "general"}
{"query": "Terminal de Transportes Bogotá", "city": "Bogotá", "expected_entities": ["Terminal de Transportes"], "intent": "station"}
{"query": "barrio chapinero bogota", "city": "Bogotá", "expected_entities": ["Chapinero"], "intent": "neighborhood"}
{"query": "Av. NQS con calle 40", "city": "Bogotá", "expected_entities": ["Avenida NQS"], "intent": "address"}
{"query": "metro de medellin linea A", "city": "Medellín", "expected_entities": ["Metro de Medellín"], "intent": "route"}
{"query": "cable aereo comunas medellin", "city": "Medellín", "expected_entities": ["Metrocable"], "intent": "route"}
{"query": "Transmetro barranquilla tarifa", "city": "Barranquilla", "expected_entities": ["Transmetro"], "intent": "fare"}
{"query": "Transcaribe en Cartagena", "city": "Cartagena", "expected_entities": ["Transcaribe"], "intent": "general"}
{"query": "municipio de Riohacha", "city": "Riohacha", "expected_entities": ["Riohacha"], "intent": "general"}
{"query": "departamento de Antioquia capital", "city": null, "expected_entities": ["Antioquia"], "intent": "general"}
{"query": "como llegar a suba desde kennedy bogota", "city": "Bogotá", "expected_entities": ["Suba", "Kennedy"], "intent": "route"}
{"query": "paradero sitp Cl. 80", "city": "Bogotá", "expected_entities": ["Calle 80"], "intent": "stop"}
{"query": "Megabus pereira ruta", "city": "Pereira", "expected_entities": ["Megabús"], "intent": "route"}
{"query": "Metrolinea bucaramanga", "city": "Bucaramanga", "expected_entities": ["Metrolínea"], "intent": "general"}
```

> Completar hasta ≥ 100 queries antes de correr `validate.py` para que las métricas sean representativas.

- [ ] **Step 2: Crear validate.py**

```python
# pipeline/validate.py
"""
Evalúa precisión del sistema RAG contra tests/validation_queries.jsonl.
Métricas: precision@1, precision@3, fallback_rate.
Llama directamente al RPC de Supabase (no pasa por la Edge Function).
"""
import json, os, sys
from supabase import create_client
from dotenv import load_dotenv
sys.path.insert(0, os.path.dirname(__file__))
from colombia_normalizer import normalize as normalize_query
from openai import OpenAI

load_dotenv()

TESTS_FILE  = os.path.join(os.path.dirname(__file__), '..', 'tests', 'validation_queries.jsonl')
THRESHOLD   = 0.65

supabase = create_client(os.environ['SUPABASE_URL'], os.environ['SUPABASE_SERVICE_ROLE_KEY'])
openai   = OpenAI(api_key=os.environ['OPENAI_API_KEY'])


def embed(text: str) -> list[float]:
    return openai.embeddings.create(model='text-embedding-3-small', input=text).data[0].embedding


def retrieve(query: str, city: str | None) -> list[str]:
    nq = normalize_query(query)
    normalized = nq['normalized']

    # Exact match
    q = supabase.from_('colombia_kg_aliases')\
        .select('colombia_kg!inner(canonical_name)')\
        .text_search('alias', ' & '.join(normalized.split()[:4]), config='spanish')\
        .limit(5)
    if city:
        q = q.eq('colombia_kg.city', city)
    result = q.execute()
    exact_names = [row['colombia_kg']['canonical_name'] for row in (result.data or [])]

    if exact_names:
        return exact_names

    # Semantic
    vec = embed(normalized)
    result = supabase.rpc('match_colombia_kg', {
        'query_embedding': vec,
        'match_count': 5,
        'city_filter': city,
        'similarity_threshold': THRESHOLD,
    }).execute()
    return [row['canonical_name'] for row in (result.data or [])]


def main():
    with open(TESTS_FILE, encoding='utf-8') as f:
        tests = [json.loads(l) for l in f if l.strip()]

    p1_hits = p3_hits = fallbacks = 0

    for t in tests:
        retrieved = retrieve(t['query'], t.get('city'))
        expected  = t['expected_entities']

        if not retrieved:
            fallbacks += 1
            continue

        if any(e.lower() in retrieved[0].lower() or retrieved[0].lower() in e.lower()
               for e in expected):
            p1_hits += 1

        if any(any(e.lower() in r.lower() or r.lower() in e.lower() for r in retrieved[:3])
               for e in expected):
            p3_hits += 1

    n = len(tests)
    print(f"\n{'='*40}")
    print(f"Queries evaluadas:  {n}")
    print(f"precision@1:        {p1_hits/n*100:.1f}%  (objetivo ≥ 90%)")
    print(f"precision@3:        {p3_hits/n*100:.1f}%  (objetivo ≥ 85%)")
    print(f"fallback_rate:      {fallbacks/n*100:.1f}%  (objetivo < 10%)")
    print(f"{'='*40}\n")

    if p1_hits/n < 0.90:
        print("⚠️  precision@1 por debajo del objetivo. Revisar rag_fallback_log.")
        sys.exit(1)
    print("✅ Métricas de aceptación alcanzadas.")


if __name__ == '__main__':
    main()
```

- [ ] **Step 3: Completar el set de validación hasta ≥ 100 queries**

Abrir `tests/validation_queries.jsonl` y agregar queries hasta completar la distribución:
- Bogotá: ≥ 30 (direcciones, estaciones TM, barrios, rutas SITP)
- Medellín: ≥ 20 (Metro, Metrocable, Metroplús, comunas, barrios)
- Cali: ≥ 15 (MIO, barrios, calles)
- Barranquilla: ≥ 10 (Transmetro, barrios)
- Cartagena: ≥ 10 (Transcaribe, zonas turísticas de transporte)
- Otras ciudades: ≥ 15 (Bucaramanga, Pereira, Manizales, municipios varios)

- [ ] **Step 3b: Verificar que el set tiene ≥ 100 queries antes de correr métricas**

```bash
python -c "
import json
lines = [l for l in open('tests/validation_queries.jsonl', encoding='utf-8') if l.strip()]
assert len(lines) >= 100, f'Solo {len(lines)} queries — necesitas >= 100 antes de evaluar'
from collections import Counter
cities = Counter(json.loads(l).get('city') for l in lines)
print(f'OK: {len(lines)} queries. Distribucion de ciudades: {dict(cities)}')
"
```

Resultado esperado: `OK: 100+ queries. Distribucion de ciudades: ...`

- [ ] **Step 4: Correr validación**

```bash
python pipeline/validate.py
```

Resultado esperado: precision@1 ≥ 90%, precision@3 ≥ 85%, fallback_rate < 10%.

Si no se alcanzan los objetivos: revisar `rag_fallback_log` en Supabase para identificar entidades faltantes, agregarlas manualmente en Supabase con `source='manual'`, y regenerar embeddings solo para esas entidades.

- [ ] **Step 5: Commit final**

```bash
git add tests/validation_queries.jsonl pipeline/validate.py
git commit -m "feat: add validation suite and validate.py for RAG precision metrics"
```

---

## Resumen de Comandos de Ejecución

```bash
# 1. Setup Python
cd pipeline && pip install -r requirements.txt

# 2. Ingestión de datos (ejecutar en orden)
python ingest_osm.py       # ~30 min
python ingest_dane.py      # ~2 min
python merge_dedupe.py     # ~5 min
python build_chunks.py     # ~2 min
python embed.py            # ~20 min, ~$0.10 USD

# 3. Cargar en Supabase
python load_supabase.py    # ~15 min

# 4. Tests Python
python -m pytest tests/pipeline/ -v

# 5. Deploy Edge Function
npx supabase functions deploy ai-chat --no-verify-jwt

# 6. Validación final
python pipeline/validate.py
```

## Checklist de Secretos en Supabase Dashboard

Ir a: Supabase Dashboard → Edge Functions → Manage secrets

- [ ] `OPENAI_API_KEY` = sk-... (OpenAI Platform)
- [ ] `GROQ_API_KEY` = gsk_... (console.groq.com)
- [ ] Verificar que `SUPABASE_URL` y `SUPABASE_SERVICE_ROLE_KEY` están disponibles (inyectados automáticamente por Supabase)
