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


def load_jsonl(path: str) -> list:
    entities = []
    with open(path, encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if line:
                entities.append(json.loads(line))
    return entities


def merge_and_dedupe() -> list:
    osm_path  = os.path.join(DATA_DIR, "osm_colombia.jsonl")
    dane_path = os.path.join(DATA_DIR, "dane_colombia.jsonl")

    osm_entities  = load_jsonl(osm_path)  if os.path.exists(osm_path)  else []
    dane_entities = load_jsonl(dane_path) if os.path.exists(dane_path) else []

    all_entities = osm_entities + dane_entities

    print(f"Total antes de dedup: {len(all_entities)} (OSM={len(osm_entities)}, DANE={len(dane_entities)})")

    canonical = []
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
    print(f"KG canónico -> {OUTPUT}")


if __name__ == "__main__":
    main()
