# pipeline/embed.py
"""
Genera embeddings locales (sentence-transformers) para cada entidad del KG.
Modelo: paraphrase-multilingual-MiniLM-L12-v2  — 384 dims, gratis, sin API key.
Output: pipeline/data/kg_embeddings.jsonl
"""
import hashlib
import json
import os
from sentence_transformers import SentenceTransformer
from tqdm import tqdm

DATA_DIR    = os.path.join(os.path.dirname(__file__), "data")
INPUT_FILE  = os.path.join(DATA_DIR, "kg_chunks.jsonl")
OUTPUT_FILE = os.path.join(DATA_DIR, "kg_embeddings.jsonl")
BATCH_SIZE  = 64
MODEL_NAME  = "paraphrase-multilingual-MiniLM-L12-v2"


def main():
    print(f"Cargando modelo {MODEL_NAME}...")
    model = SentenceTransformer(MODEL_NAME)

    entities = []
    with open(INPUT_FILE, encoding="utf-8") as f:
        for line in f:
            if line.strip():
                entities.append(json.loads(line))

    print(f"Total entidades a embeber: {len(entities)}")

    def _ckpt_key(e: dict) -> str:
        raw = f"{e['canonical_name']}|{e.get('city', '')}|{e['type']}"
        return hashlib.md5(raw.encode()).hexdigest()

    done_ids = set()
    if os.path.exists(OUTPUT_FILE):
        with open(OUTPUT_FILE, encoding="utf-8") as f:
            for line in f:
                if line.strip():
                    done_ids.add(_ckpt_key(json.loads(line)))
        print(f"  Ya procesados: {len(done_ids)} — continuando desde ahi")

    with open(OUTPUT_FILE, "a", encoding="utf-8") as fout:
        pending = [e for e in entities if _ckpt_key(e) not in done_ids]
        for i in tqdm(range(0, len(pending), BATCH_SIZE), desc="Embeddings"):
            batch = pending[i:i + BATCH_SIZE]
            texts = [e["embed_text"] for e in batch]
            vectors = model.encode(texts, show_progress_bar=False).tolist()
            for entity, vec in zip(batch, vectors):
                entity["embedding"] = vec
                fout.write(json.dumps(entity, ensure_ascii=False) + "\n")

    print(f"Embeddings -> {OUTPUT_FILE}")


if __name__ == "__main__":
    main()
