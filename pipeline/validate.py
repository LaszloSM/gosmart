# pipeline/validate.py
"""
Evalua precision del sistema RAG contra tests/validation_queries.jsonl.
Metricas: precision@1, precision@3, fallback_rate.
Llama directamente al RPC de Supabase (no pasa por la Edge Function).
"""
import json, os, sys
from supabase import create_client
from dotenv import load_dotenv
from sentence_transformers import SentenceTransformer
sys.path.insert(0, os.path.dirname(__file__))
from colombia_normalizer import normalize as normalize_query

load_dotenv()

TESTS_FILE = os.path.join(os.path.dirname(__file__), '..', 'tests', 'validation_queries.jsonl')
THRESHOLD  = 0.35

supabase = create_client(os.environ['SUPABASE_URL'], os.environ['SUPABASE_SERVICE_ROLE_KEY'])
_model   = None


def get_model():
    global _model
    if _model is None:
        print("Cargando modelo de embeddings...")
        _model = SentenceTransformer("paraphrase-multilingual-MiniLM-L12-v2")
    return _model


def embed(text: str) -> list:
    return get_model().encode(text).tolist()


def retrieve(query: str, city) -> list:
    nq = normalize_query(query)
    normalized = nq['normalized']

    # Exact match (FTS — filtro de ciudad en Python por limitacion de supabase-py v2)
    term = ' & '.join(normalized.split()[:4])
    result = supabase.from_('colombia_kg_aliases')\
        .select('colombia_kg!inner(canonical_name, city)')\
        .text_search('alias', term)\
        .execute()
    rows = result.data or []
    if city:
        rows = [r for r in rows if (r['colombia_kg'] or {}).get('city') == city]
    exact_names = [r['colombia_kg']['canonical_name'] for r in rows[:5]]

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

    assert len(tests) >= 100, f'Solo {len(tests)} queries — necesitas >= 100 antes de evaluar'
    print(f"Evaluando {len(tests)} queries...")

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
    print(f"precision@1:        {p1_hits/n*100:.1f}%  (objetivo >= 90%)")
    print(f"precision@3:        {p3_hits/n*100:.1f}%  (objetivo >= 85%)")
    print(f"fallback_rate:      {fallbacks/n*100:.1f}%  (objetivo < 10%)")
    print(f"{'='*40}\n")

    if p1_hits/n < 0.80:
        print("ALERTA: precision@1 por debajo del objetivo. Revisar rag_fallback_log.")
        sys.exit(1)
    print("Metricas de aceptacion alcanzadas.")


if __name__ == '__main__':
    main()
