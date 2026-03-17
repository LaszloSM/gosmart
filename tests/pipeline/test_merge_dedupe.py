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
