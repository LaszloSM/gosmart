// backend/functions/ai-chat/normalizer.ts

export interface NormalizedQuery {
  original: string
  normalized: string
  city: string | null
  city_confidence: 'high' | 'medium' | 'none'
  intent: 'address' | 'station' | 'neighborhood' | 'route' | 'fare' | 'general'
  entities_mentioned: string[]
  abbreviations_expanded: string[]
}

// ── Abreviaturas viales ───────────────────────────────────────────────────────
const ABBREVS: [RegExp, string][] = [
  [/\bCra?\.?\s*/gi,           'Carrera '],
  [/\bKr\.?\s*/gi,             'Carrera '],
  [/\bCll?\.?\s*/gi,           'Calle '],
  [/\bAv(?!enida)\.?\s*/gi,    'Avenida '],
  [/\bDg\.?\s*/gi,             'Diagonal '],
  [/\bDiag(?!onal)\.?\s*/gi,   'Diagonal '],
  [/\bTv\.?\s*/gi,             'Transversal '],
  [/\bTrv\.?\s*/gi,            'Transversal '],
  [/\bTrans(?!versal)\.?\s*/gi, 'Transversal '],
  [/\bAc\b/gi,                 'Autopista Central'],
  [/\bAk\b/gi,                 'Autopista Kennedy'],
  [/\bBv(?!ulevar)\.?\s*/gi,   'Bulevar '],
  [/\bNro?\./gi,               'Número'],
]

// ── Topónimos con typos frecuentes ────────────────────────────────────────────
const TOPONYMS: [RegExp, string][] = [
  [/\bbogota\b/gi,             'Bogotá'],
  [/\bmedellin\b/gi,           'Medellín'],
  [/\bbarranquila\b/gi,        'Barranquilla'],
  [/\bcartagena de indias\b/gi, 'Cartagena'],
]

// ── Inferencia de ciudad desde sistema de transporte ─────────────────────────
const TRANSPORT_CITY: [RegExp, string][] = [
  [/transmilenio|sitp|\bTM\b|portal norte|portal sur|portal el dorado/i, 'Bogotá'],
  [/metro de medell|metroplús|metroplus|metrocable/i,                     'Medellín'],
  [/\bMIO\b|masivo integrado de occidente/i,                              'Cali'],
  [/transmetro/i,                                                         'Barranquilla'],
  [/transcaribe/i,                                                        'Cartagena'],
  [/metrolínea|metrolinea/i,                                              'Bucaramanga'],
  [/megabús|megabus/i,                                                    'Pereira'],
]

// Ciudades mencionadas explícitamente
const CITY_RE = /\b(bogot[aá]|medell[ií]n|cali|barranquilla|cartagena|bucaramanga|pereira|manizales)\b/i
const CITY_NORMALIZE: Record<string, string> = {
  'bogota': 'Bogotá', 'bogotá': 'Bogotá',
  'medellin': 'Medellín', 'medellín': 'Medellín',
  'cali': 'Cali', 'barranquilla': 'Barranquilla',
  'cartagena': 'Cartagena', 'bucaramanga': 'Bucaramanga',
  'pereira': 'Pereira', 'manizales': 'Manizales',
}

// ── Intent detection ──────────────────────────────────────────────────────────
function detectIntent(text: string): NormalizedQuery['intent'] {
  const q = text.toLowerCase()
  if (/direcci[oó]n|calle|carrera|avenida|diagonal|transversal|cra|cl\b|av\b/.test(q)) return 'address'
  if (/estaci[oó]n|parada|paradero|portal|terminal/.test(q)) return 'station'
  if (/barrio|localidad|comuna|sector|zona/.test(q)) return 'neighborhood'
  if (/ruta|llegar|como ir|bus|metro|transporte|línea/.test(q)) return 'route'
  if (/tarifa|costo|precio|cuanto cuesta|valor|pesos/.test(q)) return 'fare'
  return 'general'
}

export function normalize(query: string, cityHint?: string): NormalizedQuery {
  let text = query.trim()

  // Expandir abreviaturas
  const expanded: string[] = []
  for (const [pattern, replacement] of ABBREVS) {
    const before = text
    text = text.replace(pattern, replacement)
    if (text !== before) expanded.push(replacement.trim())
  }

  // Corregir topónimos
  for (const [pattern, replacement] of TOPONYMS) {
    text = text.replace(pattern, replacement)
  }

  // Detectar ciudad — city_hint tiene prioridad sobre detección automática
  let city: string | null = null
  let confidence: NormalizedQuery['city_confidence'] = 'none'

  if (cityHint?.trim()) {
    city = cityHint.trim()
    confidence = 'high'
  } else {
    for (const [pattern, inferredCity] of TRANSPORT_CITY) {
      if (pattern.test(query)) { city = inferredCity; confidence = 'high'; break }
    }
    if (!city) {
      const m = query.match(CITY_RE)
      if (m) {
        city = CITY_NORMALIZE[m[1].toLowerCase()] ?? null
        if (city) confidence = 'high'
      }
    }
  }

  return {
    original: query,
    normalized: text.replace(/\s+/g, ' ').trim(),
    city,
    city_confidence: confidence,
    intent: detectIntent(query),
    entities_mentioned: [],
    abbreviations_expanded: expanded,
  }
}
