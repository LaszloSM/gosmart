// backend/functions/ai-chat/normalizer_test.ts
import { assertEquals } from 'https://deno.land/std@0.208.0/assert/mod.ts'
import { normalize } from './normalizer.ts'

Deno.test('expand Cra. to Carrera', () => {
  const r = normalize('Cra. 7 con Cl. 45')
  assertEquals(r.normalized, 'Carrera 7 con Calle 45')
})

Deno.test('detect city from TransMilenio', () => {
  const r = normalize('¿dónde queda transmilenio calle 100?')
  assertEquals(r.city, 'Bogotá')
  assertEquals(r.city_confidence, 'high')
})

Deno.test('detect city from MIO', () => {
  const r = normalize('El MIO llega al barrio Aguablanca?')
  assertEquals(r.city, 'Cali')
})

Deno.test('city_hint overrides auto-detect', () => {
  const r = normalize('¿cuánto cuesta el bus?', 'Medellín')
  assertEquals(r.city, 'Medellín')
  assertEquals(r.city_confidence, 'high')
})

Deno.test('no city returns none confidence', () => {
  const r = normalize('¿cuánto cuesta el bus?')
  assertEquals(r.city_confidence, 'none')
})

Deno.test('intent address detected', () => {
  const r = normalize('Carrera 13 con Calle 72 Bogotá')
  assertEquals(r.intent, 'address')
})

Deno.test('intent fare detected', () => {
  const r = normalize('¿cuánto cuesta el metro?')
  assertEquals(r.intent, 'fare')
})
