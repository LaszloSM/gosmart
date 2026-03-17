# pipeline/colombia_normalizer.py
import re
from unidecode import unidecode

# ── Abreviaturas viales ───────────────────────────────────────────────────────
_ABBREVS = [
    (r'\bCra?\.?\s*', 'Carrera '),
    (r'\bKr\.?\s*',   'Carrera '),
    (r'\bCll?\.?\s*', 'Calle '),
    (r'\bAv(?!enida)\.?\s*',   'Avenida '),
    (r'\bDg\.?\s*',   'Diagonal '),
    (r'\bDiag(?!onal)\.?\s*', 'Diagonal '),
    (r'\bTv\.?\s*',   'Transversal '),
    (r'\bTrv\.?\s*',  'Transversal '),
    (r'\bTrans(?!versal)\.?\s*','Transversal '),
    (r'\bAc\b',       'Autopista Central'),
    (r'\bAk\b',       'Autopista Kennedy'),
    (r'\bBv\.?\s*',   'Bulevar '),
    (r'\bNro?\.',     'Número'),
]
_ABBREV_PATTERNS = [(re.compile(p, re.IGNORECASE), r) for p, r in _ABBREVS]

# ── Topónimos ─────────────────────────────────────────────────────────────────
_TOPONYMS = {
    'bogota': 'Bogotá', 'medellin': 'Medellín', 'barranquila': 'Barranquilla',
    'cartagena de indias': 'Cartagena', 'cali': 'Cali',
    'bucaramanga': 'Bucaramanga', 'pereira': 'Pereira', 'manizales': 'Manizales',
}

# ── Inferencia de ciudad desde sistema de transporte ─────────────────────────
_TRANSPORT_CITY = [
    (re.compile(r'transmilenio|sitp|\bTM\b|portal norte|portal sur|portal el dorado', re.I), 'Bogotá'),
    (re.compile(r'metro de medell|metroplús|metroplus|metrocable', re.I), 'Medellín'),
    (re.compile(r'\bMIO\b|masivo integrado de occidente', re.I), 'Cali'),
    (re.compile(r'transmetro', re.I), 'Barranquilla'),
    (re.compile(r'transcaribe', re.I), 'Cartagena'),
    (re.compile(r'metrolínea|metrolinea', re.I), 'Bucaramanga'),
    (re.compile(r'megabús|megabus', re.I), 'Pereira'),
]

# Ciudades mencionadas explícitamente
_CITY_NAMES = re.compile(
    r'\b(bogot[aá]|medell[ií]n|cali|barranquilla|cartagena|bucaramanga|pereira|manizales)\b',
    re.I
)
_CITY_NORMALIZE = {
    'bogota': 'Bogotá', 'bogotá': 'Bogotá',
    'medellín': 'Medellín', 'medellin': 'Medellín',
    'cali': 'Cali', 'barranquilla': 'Barranquilla',
    'cartagena': 'Cartagena', 'bucaramanga': 'Bucaramanga',
    'pereira': 'Pereira', 'manizales': 'Manizales',
}


def expand_abbreviations(text: str) -> str:
    """Expande abreviaturas viales colombianas en el texto."""
    for pattern, replacement in _ABBREV_PATTERNS:
        text = pattern.sub(replacement, text)
    return re.sub(r' +', ' ', text).strip()


def fix_toponyms(text: str) -> str:
    """Corrige acentos y typos comunes en nombres de ciudades."""
    key = text.lower().strip()
    if key in _TOPONYMS:
        return _TOPONYMS[key]
    # Reemplazar dentro del texto
    for wrong, correct in _TOPONYMS.items():
        text = re.sub(r'\b' + re.escape(wrong) + r'\b', correct, text, flags=re.I)
    return text


def detect_city(text: str) -> tuple:
    """
    Detecta ciudad en el texto.
    Returns: (city_name | None, confidence: 'high' | 'medium' | 'none')
    """
    # 1. Sistema de transporte -> alta confianza
    for pattern, city in _TRANSPORT_CITY:
        if pattern.search(text):
            return city, 'high'
    # 2. Ciudad mencionada explícitamente
    m = _CITY_NAMES.search(text)
    if m:
        city = _CITY_NORMALIZE.get(m.group(1).lower())
        if city:
            return city, 'high'
    return None, 'none'


def normalize(text: str) -> dict:
    """Pipeline completo: expand + fix toponyms + detect city."""
    expanded = expand_abbreviations(text)
    fixed = fix_toponyms(expanded)
    city, confidence = detect_city(text)  # detect on original for better matching
    return {
        'original': text,
        'normalized': fixed,
        'city': city,
        'city_confidence': confidence,
        'abbreviations_expanded': [p for p, _ in _ABBREVS
                                    if re.search(p, text, re.I)],
    }
