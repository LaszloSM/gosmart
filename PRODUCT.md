# Product

<!-- impeccable:product-schema 1 -->

## Platform

web

## Stack

Prototype: a single self-contained static HTML/CSS/JS file (no build step), published as a private claude.ai artifact and committed under `prototype/`. It simulates the mobile app inside a phone frame. The production app remains Flutter (Android-first) + Supabase; the prototype does not replace it.

## Users

- **Passenger (primary):** residents of Riohacha and Maicao (La Guajira, Colombia) who move inside each city and along the ~75 km Troncal del Caribe corridor between them, often for work, university, or legal/administrative errands (e.g. Palacio de Justicia Riohacha → Palacio de Justicia Maicao). They combine walking, TransPadilla buses, mototaxis, and intermunicipal colectivos, and today leave home without knowing if the road is open, if it is safe, how long they will wait, or what a fair fare is.
- **Driver (secondary):** mototaxistas, colectivo drivers, and other informal/formal operators who need demand, a payment key (Bre-B, Nequi, Daviplata), ride closing, occupancy reporting, and — for the first time — a verifiable history of trips and income.

## Product Purpose

GoSmart is an information and coordination layer over the transport that already exists in Riohacha and Maicao — public, private, and informal — that also unifies payment and traceability. Core thesis: the central problem is not payment, it is information. Success means a passenger can say one sentence to the assistant and get a monitored, chained, door-to-door trip with one price, one payment, and one receipt, and knows the corridor state before leaving home.

## Positioning

"InDrive, Maxim y Uber te llevan. GoSmart te dice cómo moverte." No other platform covers informal transport, integrates TransPadilla, covers the intermunicipal leg, reports whether the road is blocked, or builds a trip by conversation. GoSmart is an integrator of all transport guilds, not a transport company and not a competitor that displaces taxis.

## Operating Context

- Corridor: Troncal del Caribe Riohacha–Maicao, with recurring blockades at identified km points, illegal checkpoints and road piracy, seasonal flooding, deteriorated road surface; real detour via Albania–Cuestecitas.
- Colectivos to Maicao depart when full, not by schedule.
- Information today lives in scattered WhatsApp groups and local radio.
- Intermittent connectivity along the corridor: offline-first is a hard requirement.
- Payment habit: driver holds the QR (Bre-B / Nequi / Daviplata), passenger pays by in-app balance, direct transfer, or cash.

## Capabilities and Constraints

Five modules:
1. **Estado del Corredor en tiempo real** — live road-state map (open, blocked, detour, flooded), geo-referenced crowd reports with cross-confirmation, preventive alerts before leaving home, history/patterns, real alternate routes.
2. **Asistente IA + planificador multimodal** — natural-language trip requests that transform into a map itinerary; multimodal chaining; context-aware weighting (blockades, time of day, rain season, road condition); fair-fare range for informal legs (intermunicipal shows the authorized fare, never negotiated); dispatch prediction by occupancy ("7 de 12 puestos · salida estimada en 14 min") with backward calculation of when to take the first leg; habit learning.
3. **Viaje encadenado y trazabilidad** — trip state machine (planificado → tramo 1 → espera de despacho → tramo 2 → tramo 3 → finalizado), dynamic replanning, share live trip, emergency button, identified driver per leg.
4. **Pago unificado** — driver-held QR, in-app balance / transfer / cash, single payment split across providers released per leg, refund of unexecuted legs, one receipt with breakdown.
5. **Confianza y reputación** — two-way ratings, driver document validation (cédula, licencia, tarjeta de propiedad, SOAT), non-payment reports (two confirmed block the passenger), cross-validated road reports.

Prototype scope: passenger app and driver app. Admin web panel is out of scope for the prototype.

Declared out of scope for the product: eliminating armed violence, fixing roads/flooding, resolving the formal/informal conflict.

## Brand Commitments

- Name: **GoSmart** (the regional proposal is presented as GoSmart's evolution, not a new brand).
- Language: Colombian Spanish, local vocabulary (mototaxi, colectivo, TransPadilla, Troncal, Bre-B, Nequi, Daviplata).
- Ethical rule: road reports say "vía cerrada" or "reporte de inseguridad en el sector"; never identify people or communities.
- Honesty: dispatch predictions are shown as estimated ranges, not exact data.

## Evidence on Hand

- Proposal document: "Guajira Movilidad — Propuesta de solución" (17 diagnosed problems, problem→solution matrix, reference case).
- Existing Flutter app code in `lib/` (AI assistant via Groq + Colombia KG, Mapbox map, wallet mock, favorites, history).
- No real field data yet (route graph, real fares, fill times are Phase 1 deliverables). All prototype data is synthetic and must be labeled as such; no invented users, testimonials, partnerships, or official endorsements.

## Product Principles

1. Information first: knowing the corridor state is the entry door; it must deliver value even if nobody else uses the app.
2. One trip, one price, one payment, one receipt — hide multi-leg complexity, never hide the facts.
3. Inclusive integrator: every transport actor (TransPadilla, mototaxi, colectivo, taxi) is a first-class participant.
4. Honest by design: ranges over false precision, explicit scope limits, no stigmatization.
5. Works with bad signal: offline state is a normal condition, not an error.

## Accessibility & Inclusion

Used outdoors under strong Caribbean sun, on mid/low-end Android phones, often with intermittent data. Users range in digital literacy; drivers may be on a moving motorcycle. Large touch targets, high contrast, plain Spanish copy.
