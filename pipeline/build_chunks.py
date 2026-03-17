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
    aliases = entity.get("aliases") or []
    meta  = entity.get("metadata") or {}

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

    print(f"Chunks generados: {total} -> {output_path}")


if __name__ == "__main__":
    main()
