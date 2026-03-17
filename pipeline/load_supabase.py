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


def insert_batch_kg(batch: list) -> list:
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


def insert_aliases_batch(alias_rows: list):
    if not alias_rows:
        return
    supabase.table("colombia_kg_aliases").insert(alias_rows).execute()


def insert_embeddings_batch(embedding_rows: list):
    if not embedding_rows:
        return
    supabase.table("colombia_kg_embeddings").insert(embedding_rows).execute()


def main():
    entities = load_entities()
    print(f"Cargando {len(entities)} entidades en Supabase...")

    for i in tqdm(range(0, len(entities), BATCH_SIZE), desc="Insertando KG"):
        batch = entities[i:i+BATCH_SIZE]
        inserted = insert_batch_kg(batch)

        alias_rows = []
        embedding_rows = []
        for entity, row in zip(batch, inserted):
            entity_id = row["id"]
            for a in (entity.get("aliases") or []):
                if a:
                    alias_rows.append({"entity_id": entity_id, "alias": a, "alias_type": "popular"})
            if entity.get("embedding"):
                embedding_rows.append({"entity_id": entity_id, "embedding": entity["embedding"]})

        insert_aliases_batch(alias_rows)
        insert_embeddings_batch(embedding_rows)

    # Crear índice HNSW DESPUÉS del bulk load vía función RPC registrada en 006_colombia_kg.sql
    # (supabase-py 2.x no puede ejecutar DDL directo — usamos la función helper)
    print("\nCreando índice HNSW en embeddings (puede tomar varios minutos)...")
    supabase.rpc("create_hnsw_index", {}).execute()
    print("Carga completa.")


if __name__ == "__main__":
    main()
