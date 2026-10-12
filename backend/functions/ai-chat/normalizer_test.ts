// backend/functions/ai-chat/normalizer_test.ts
import { assertEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import { normalize } from './normalizer.ts'

Deno.test('expand Cra. to Carrera', () => {
  const r = normalize('Cra. 7 con Cl. 15')
  assertEquals(r.normalized, 'Carrera 7 con Calle 15')
})

Deno.test('detect city from TransPadilla', () => {
  const r = normalize('¿cuánto vale el TransPadilla?')
  assertEquals(r.city, 'Riohacha')
  assertEquals(r.city_confidence, 'high')
})

Deno.test('detect Maicao from Paraguachón', () => {
  const r = normalize('¿cómo llego a Paraguachon?')
  assertEquals(r.city, 'Maicao')
})

Deno.test('explicit city mention', () => {
  const r = normalize('colectivo de rio hacha al terminal')
  assertEquals(r.city, 'Riohacha')
})

Deno.test('city_hint overrides auto-detect', () => {
  const r = normalize('¿cuánto cuesta el mototaxi?', 'Maicao')
  assertEquals(r.city, 'Maicao')
  assertEquals(r.city_confidence, 'high')
})

Deno.test('no city returns none confidence', () => {
  const r = normalize('¿cuánto cuesta el colectivo?')
  assertEquals(r.city_confidence, 'none')
})

Deno.test('intent address detected', () => {
  const r = normalize('Calle 15 con Carrera 7 Riohacha')
  assertEquals(r.intent, 'address')
})

Deno.test('intent fare detected', () => {
  const r = normalize('¿cuánto cuesta el pasaje?')
  assertEquals(r.intent, 'fare')
})
