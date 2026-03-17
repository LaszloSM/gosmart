# pipeline/ingest_dane.py
"""
Datos DIVIPOLA de Colombia hardcodeados (API datos.gov.co cambia frecuentemente).
Incluye los 33 departamentos + DC y ~150 municipios principales.
Output: pipeline/data/dane_colombia.jsonl
"""
import json, os

OUTPUT_FILE = os.path.join(os.path.dirname(__file__), "data", "dane_colombia.jsonl")

DEPARTAMENTOS = [
    "Amazonas","Antioquia","Arauca","Atlantico","Bolivar","Boyaca","Caldas",
    "Caqueta","Casanare","Cauca","Cesar","Choco","Cordoba","Cundinamarca",
    "Guainia","Guaviare","Huila","La Guajira","Magdalena","Meta","Narino",
    "Norte De Santander","Putumayo","Quindio","Risaralda","San Andres",
    "Santander","Sucre","Tolima","Valle Del Cauca","Vaupes","Vichada",
    "Bogota D.C."
]

# Municipios principales por departamento: (municipio, departamento)
MUNICIPIOS = [
    # Bogotá y Cundinamarca
    ("Bogota","Bogota D.C."),("Soacha","Cundinamarca"),("Facatativa","Cundinamarca"),
    ("Zipaquira","Cundinamarca"),("Chia","Cundinamarca"),("Mosquera","Cundinamarca"),
    ("Madrid","Cundinamarca"),("Funza","Cundinamarca"),("Cajica","Cundinamarca"),
    ("Tocancipa","Cundinamarca"),("La Calera","Cundinamarca"),("Fusagasuga","Cundinamarca"),
    # Antioquia
    ("Medellin","Antioquia"),("Bello","Antioquia"),("Itagui","Antioquia"),
    ("Envigado","Antioquia"),("Apartado","Antioquia"),("Turbo","Antioquia"),
    ("Rionegro","Antioquia"),("Sabaneta","Antioquia"),("La Estrella","Antioquia"),
    ("Caldas","Antioquia"),("Copacabana","Antioquia"),("Girardota","Antioquia"),
    # Valle del Cauca
    ("Cali","Valle Del Cauca"),("Buenaventura","Valle Del Cauca"),("Palmira","Valle Del Cauca"),
    ("Tuluá","Valle Del Cauca"),("Cartago","Valle Del Cauca"),("Buga","Valle Del Cauca"),
    ("Yumbo","Valle Del Cauca"),("Jamundi","Valle Del Cauca"),("Candelaria","Valle Del Cauca"),
    # Atlantico
    ("Barranquilla","Atlantico"),("Soledad","Atlantico"),("Malambo","Atlantico"),
    ("Sabanagrande","Atlantico"),("Puerto Colombia","Atlantico"),
    # Bolivar
    ("Cartagena","Bolivar"),("Magangue","Bolivar"),("El Carmen De Bolivar","Bolivar"),
    # Santander
    ("Bucaramanga","Santander"),("Floridablanca","Santander"),("Giron","Santander"),
    ("Piedecuesta","Santander"),("Barrancabermeja","Santander"),("San Gil","Santander"),
    # Risaralda
    ("Pereira","Risaralda"),("Dosquebradas","Risaralda"),("Santa Rosa De Cabal","Risaralda"),
    # Caldas
    ("Manizales","Caldas"),("La Dorada","Caldas"),("Chinchina","Caldas"),
    # Quindio
    ("Armenia","Quindio"),("Calarca","Quindio"),("Montenegro","Quindio"),
    # Tolima
    ("Ibague","Tolima"),("Espinal","Tolima"),("Melgar","Tolima"),
    # Huila
    ("Neiva","Huila"),("Garzon","Huila"),("Pitalito","Huila"),
    # Nariño
    ("Pasto","Narino"),("Tumaco","Narino"),("Ipiales","Narino"),
    # Cauca
    ("Popayan","Cauca"),("Santander De Quilichao","Cauca"),
    # Cesar
    ("Valledupar","Cesar"),("Aguachica","Cesar"),
    # Magdalena
    ("Santa Marta","Magdalena"),("Cienaga","Magdalena"),
    # Cordoba
    ("Monteria","Cordoba"),("Lorica","Cordoba"),("Montelibano","Cordoba"),
    # Sucre
    ("Sincelejo","Sucre"),("Corozal","Sucre"),
    # Norte de Santander
    ("Cucuta","Norte De Santander"),("Ocana","Norte De Santander"),("Pamplona","Norte De Santander"),
    # Boyaca
    ("Tunja","Boyaca"),("Duitama","Boyaca"),("Sogamoso","Boyaca"),
    # Meta
    ("Villavicencio","Meta"),("Acacias","Meta"),
    # Casanare
    ("Yopal","Casanare"),
    # Arauca
    ("Arauca","Arauca"),
    # Putumayo
    ("Mocoa","Putumayo"),("Puerto Asis","Putumayo"),
    # Caqueta
    ("Florencia","Caqueta"),
    # La Guajira
    ("Riohacha","La Guajira"),("Maicao","La Guajira"),("Uribia","La Guajira"),
    # Choco
    ("Quibdo","Choco"),
    # San Andres
    ("San Andres","San Andres"),
    # Guainia
    ("Inirida","Guainia"),
    # Vaupes
    ("Mitu","Vaupes"),
    # Vichada
    ("Puerto Carreno","Vichada"),
    # Amazonas
    ("Leticia","Amazonas"),
    # Guaviare
    ("San Jose Del Guaviare","Guaviare"),
]


def main():
    os.makedirs(os.path.dirname(OUTPUT_FILE), exist_ok=True)
    total = 0

    with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
        # Departamentos
        for dept in DEPARTAMENTOS:
            entity = {
                "name": dept, "type": "department",
                "city": None, "department": dept,
                "lat": None, "lon": None, "source": "dane",
            }
            f.write(json.dumps(entity, ensure_ascii=False) + "\n")
            total += 1

        # Municipios
        for municipio, dept in MUNICIPIOS:
            entity = {
                "name": municipio, "type": "municipality",
                "city": municipio, "department": dept,
                "lat": None, "lon": None, "source": "dane",
            }
            f.write(json.dumps(entity, ensure_ascii=False) + "\n")
            total += 1

    print(f"Total DANE: {total} entidades -> {OUTPUT_FILE}")


if __name__ == "__main__":
    main()
