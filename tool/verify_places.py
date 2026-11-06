#!/usr/bin/env python3
"""Compara la semilla del directorio (supabase/seed/places_seed.sql) con
Google Places (Text Search, API New) y escribe una tabla con la distancia
entre el punto aproximado y el de Google. Solo informa: nunca falla el job.
Así se decide qué filas corregir y marcar verified=true (a mano, con criterio:
Google también se equivoca).

Entorno: GOOGLE_MAPS_SERVER_KEY (o GOOGLE_MAPS_API_KEY). Sin clave, avisa y sale.
Uso: python3 tool/verify_places.py [ruta_semilla]
"""
import json
import math
import os
import re
import sys
import urllib.request

SEED = sys.argv[1] if len(sys.argv) > 1 else "supabase/seed/places_seed.sql"
CITY = {"riohacha": "Riohacha", "maicao": "Maicao", "corredor": "La Guajira", "otro": "La Guajira"}
ROW = re.compile(r"\(\s*'((?:[^']|'')+)'\s*,\s*'[^']*'\s*,\s*'(\w+)'\s*,\s*'\w+'\s*,\s*(-?[\d.]+)\s*,\s*(-?[\d.]+)")
out_path = os.environ.get("GITHUB_STEP_SUMMARY")


def say(line):
    print(line)
    if out_path:
        with open(out_path, "a", encoding="utf-8") as f:
            f.write(line + "\n")


def meters(a, b):
    r = 6371000.0
    dlat = math.radians(b[0] - a[0])
    dlng = math.radians(b[1] - a[1]) * math.cos(math.radians((a[0] + b[0]) / 2))
    return r * math.hypot(dlat, dlng)


def search(key, query, near):
    body = json.dumps({
        "textQuery": query,
        "regionCode": "co",
        "languageCode": "es",
        "maxResultCount": 1,
        "locationBias": {"circle": {"center": {"latitude": near[0], "longitude": near[1]}, "radius": 5000.0}},
    }).encode()
    req = urllib.request.Request(
        "https://places.googleapis.com/v1/places:searchText", data=body, method="POST",
        headers={"Content-Type": "application/json", "X-Goog-Api-Key": key,
                 "X-Goog-FieldMask": "places.displayName,places.formattedAddress,places.location"})
    with urllib.request.urlopen(req, timeout=15) as res:
        places = json.load(res).get("places") or []
    return places[0] if places else None


def main():
    key = os.environ.get("GOOGLE_MAPS_SERVER_KEY") or os.environ.get("GOOGLE_MAPS_API_KEY") or ""
    if not key:
        say("Sin GOOGLE_MAPS_SERVER_KEY ni GOOGLE_MAPS_API_KEY: no se verificó la semilla.")
        return
    rows = [(m[1].replace("''", "'"), m[2], float(m[3]), float(m[4]))
            for m in ROW.finditer(open(SEED, encoding="utf-8").read())]
    say("### Semilla del directorio vs Google Places")
    say("| Lugar | Google encontró | Distancia | Punto de Google |")
    say("|---|---|---:|---|")
    for name, city, lat, lng in rows:
        try:
            p = search(key, f"{name}, {CITY.get(city, 'La Guajira')}, La Guajira, Colombia", (lat, lng))
        except Exception as e:  # noqa: BLE001 — solo informa
            say(f"| {name} | error: {type(e).__name__} | | |")
            continue
        if not p:
            say(f"| {name} | (nada) | | |")
            continue
        loc = p["location"]
        g = (loc["latitude"], loc["longitude"])
        d = meters((lat, lng), g)
        flag = " ⚠" if d > 150 else ""
        gname = p.get("displayName", {}).get("text", "?")
        say(f"| {name} | {gname} — {p.get('formattedAddress', '')} | {d:,.0f} m{flag} | {g[0]:.5f}, {g[1]:.5f} |")
    say("")
    say("⚠ = más de 150 m. Revisa en el mapa antes de copiar el punto a la semilla y marcarla verified=true.")


if __name__ == "__main__":
    main()
