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
