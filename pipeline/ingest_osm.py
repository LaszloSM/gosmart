# pipeline/ingest_osm.py
"""
Descarga entidades de transporte de Colombia desde OpenStreetMap via Overpass API.
Output: pipeline/data/osm_colombia.jsonl (una entidad JSON por línea)

Entidades descargadas (lite — sin bus_stops para mayor velocidad):
  - Estaciones de metro, tren, cable
  - Terminales de transporte
  - Barrios (neighbourhood + suburb)
  - Municipios
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
        (
          node["place"="city"](area.co);
          node["place"="town"](area.co);
        );
        out body;
    """,
}

TYPE_MAP = {
    "stations":      "station",
    "terminals":     "terminal",
    "neighborhoods": "neighborhood",
    "municipalities":"municipality",
}


def fetch_overpass(query: str, label: str) -> list:
    print(f"  Descargando {label} desde Overpass...")
    resp = requests.post(OVERPASS_URL, data={"data": query}, timeout=240)
    resp.raise_for_status()
    elements = resp.json().get("elements", [])
    print(f"  -> {len(elements)} elementos")
    return elements


def element_to_entity(el: dict, entity_type: str):
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
            time.sleep(15)  # respetar rate limit de Overpass

    print(f"\nTotal OSM: {total} entidades -> {OUTPUT_FILE}")


if __name__ == "__main__":
    main()
