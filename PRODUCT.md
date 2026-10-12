# Product

<!-- impeccable:product-schema 1 -->

## Platform

android

## Users

- **Viajero del corredor:** va entre Riohacha y Maicao por la Troncal del Caribe (unos 75 km), en
  colectivo, intermunicipal o carro. Antes de salir necesita saber si la vía está abierta, cuánto
  cuesta y cuándo sale el próximo cupo.
- **Usuario urbano:** se mueve dentro de Riohacha o Maicao en mototaxi, taxi o TransPadilla. Necesita
  llegar de cualquier punto a cualquier punto (una dirección, una referencia como "frente al Éxito",
  un punto en el mapa) y saber cuánto debería pagar.
- **Conductor:** mototaxista, taxista o conductor de colectivo dentro de la misma app. Recibe
  solicitudes, acepta o contraoferta, cobra y cierra el viaje, con una mano y mientras maneja.

## Product Purpose

GoSmart convierte la información dispersa del corredor (bloqueos, retenes, inundaciones, tarifas
informales, salidas de colectivos) en una decisión de viaje: por dónde ir, en qué, cuánto pagar y
cuándo salir. El éxito es que el usuario sepa el estado de la vía antes de salir y que complete el
viaje puerta a puerta, aunque mezcle modos de transporte.

## Positioning

Ningún producto vecino junta en un solo lugar el estado de la Troncal reportado por la gente,
los modos informales locales (mototaxi, colectivo, TransPadilla) con su tarifa justa, y el viaje
encadenado de tramos con pago y un recibo único. Waze tiene reportes de vía, pero no colectivos,
ni tarifas informales, ni seguridad del pasajero.

## Operating Context

- Uso en la calle y en la moto, a pleno sol, con una mano; a menudo con señal débil o sin señal en
  la Troncal.
- Teléfonos Android de gama media.
- La información viaja por WhatsApp: los reportes y el estado del corredor se comparten como
  links que se abren sin la app.
- Se puede usar sin cuenta (modo invitado); la cuenta se pide al reportar, pedir mototaxi,
  reservar un cupo o pagar.

## Capabilities and Constraints

- Flutter + Supabase (plan gratis). Mapa: Google Maps en la Fase 3; hoy flutter_map.
- Hoy existen: inicio con Línea del corredor y "¿A dónde vas?", planificador, asistente de IA
  (Groq vía Edge Function), billetera con recarga simulada, perfil, login.
- Aún no existen: reportes viales (Fase 4), planificador puerta a puerta con grafo (Fase 5),
  conductor y viaje encadenado (Fase 6), pago real con Wompi (Fase 7), panel admin (Fase 8).
- NFC pospuesto; queda como visión para validadores de transporte público.
- Las recargas son simuladas hasta Wompi: nunca presentarlas como dinero real.
- Terminología local: "la Troncal", "el terminal", "mototaxi", "colectivo", "cupo", "TransPadilla".

## Brand Commitments

- Nombre: GoSmart. Visión de largo plazo: tarjeta universal de transporte del país.
- El rediseño de 2026-10 empieza visualmente desde cero (decisión del usuario): ningún color,
  fuente o componente actual es obligatorio.
- Voz: tuteo, corto, palabras locales, sin alarmismo.
- No usar iconografía ni patrones wayuu como decoración.
- Los reportes de seguridad nunca nombran ni señalan personas o comunidades.

## Evidence on Hand

- Diagnóstico de 17 problemáticas y propuesta "GUAJIRA MOVILIDAD" (resumidos en
  `docs/PLAN_MVP_GUAJIRA.md`).
- No hay todavía: datos reales de reportes viales, tarifas levantadas en campo, rutas de
  TransPadilla, usuarios piloto ni testimonios. No inventarlos; los datos de ejemplo se marcan
  como sintéticos.

## Product Principles

1. Antes de salir, ya sé cómo está la vía: el estado del corredor se ve en un segundo.
2. Honestidad sobre los datos: si no hay dato, se dice "sin datos" con la hora; nunca un estado inventado.
3. Funciona en la calle real: una mano, sol directo, señal débil.
4. Lo local primero: modos, nombres y precios de La Guajira, no de Bogotá.
5. La cuenta se pide al actuar, no para mirar.

## Accessibility & Inclusion

- Legibilidad a pleno sol: texto principal con contraste de al menos 7:1.
- Áreas táctiles de 48 dp mínimo; 72 dp en modo conductor.
- Soportar texto del sistema hasta 200% sin cortar.
- El estado nunca depende solo del color.
- Usuarios mayores y con poca experiencia digital.
