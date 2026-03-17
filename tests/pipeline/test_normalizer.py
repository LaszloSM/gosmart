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
