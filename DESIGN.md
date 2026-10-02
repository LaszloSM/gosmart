---
name: GoSmart Guajira
description: Sunlit street-object mobility app for Riohacha, Maicao and the Troncal del Caribe; limewashed walls of color announce the state of the road.
colors:
  cal: "#F1F5F3"
  cal-2: "#E3EBE7"
  muro: "#FFFFFF"
  tinta: "#172033"
  tinta-2: "#4A5568"
  tinta-3: "#6B7385"
  linea: "#CBD6D1"
  turquesa: "#1FB0A6"
  turquesa-fg: "#10202A"
  turquesa-tx: "#0A6F6B"
  turquesa-suave: "#D3EAE6"
  ocre: "#E9A825"
  ocre-fg: "#172033"
  ocre-suave: "#FBEBC6"
  coral: "#C8412F"
  coral-fg: "#FFFFFF"
  coral-suave: "#F7D9D2"
  mar: "#2B5DA8"
  mar-suave: "#DCE6F5"
  mapa-mar: "#D6E7EE"
  mapa-tierra: "#ECE6D3"
  marco: "#172033"
  cal-dark: "#10161F"
  cal-2-dark: "#18212D"
  muro-dark: "#1E2836"
  tinta-dark: "#E8EEF0"
  tinta-2-dark: "#B3BDC8"
  tinta-3-dark: "#8D97A5"
  linea-dark: "#2C3847"
  turquesa-dark: "#1A9E95"
  turquesa-fg-dark: "#0C1A20"
  turquesa-tx-dark: "#47C9BE"
  turquesa-suave-dark: "#143936"
  ocre-dark: "#E3A223"
  ocre-fg-dark: "#14191F"
  ocre-suave-dark: "#3A2E12"
  coral-dark: "#C4402E"
  coral-fg-dark: "#FFFFFF"
  coral-suave-dark: "#40201B"
  mar-dark: "#5B8DD8"
  mar-suave-dark: "#1C2B45"
  mapa-mar-dark: "#14303B"
  mapa-tierra-dark: "#262A26"
  marco-dark: "#05080C"
typography:
  display:
    fontFamily: "Archivo, Arial Narrow, ui-sans-serif, system-ui, sans-serif"
    fontSize: "clamp(40px, 17cqi, 60px)"
    fontWeight: 850
    lineHeight: 0.95
    letterSpacing: "0.01em"
    fontVariation: "'wdth' 68"
  headline:
    fontFamily: "Archivo, Arial Narrow, ui-sans-serif, system-ui, sans-serif"
    fontSize: "30px"
    fontWeight: 850
    lineHeight: 0.95
    letterSpacing: "0.01em"
    fontVariation: "'wdth' 68"
  fare:
    fontFamily: "Archivo, Arial Narrow, ui-sans-serif, system-ui, sans-serif"
    fontSize: "22px"
    fontWeight: 850
    lineHeight: 1
    fontVariation: "'wdth' 68"
    fontFeature: "'tnum' 1"
  title:
    fontFamily: "Archivo, ui-sans-serif, system-ui, -apple-system, Segoe UI, Roboto, sans-serif"
    fontSize: "17px"
    fontWeight: 750
    lineHeight: 1.3
  body:
    fontFamily: "Archivo, ui-sans-serif, system-ui, -apple-system, Segoe UI, Roboto, sans-serif"
    fontSize: "15px"
    fontWeight: 400
    lineHeight: 1.45
  body-sm:
    fontFamily: "Archivo, ui-sans-serif, system-ui, -apple-system, Segoe UI, Roboto, sans-serif"
    fontSize: "14px"
    fontWeight: 400
    lineHeight: 1.45
  label:
    fontFamily: "Archivo, ui-sans-serif, system-ui, -apple-system, Segoe UI, Roboto, sans-serif"
    fontSize: "13px"
    fontWeight: 600
    lineHeight: 1.3
  caption:
    fontFamily: "Archivo, ui-sans-serif, system-ui, -apple-system, Segoe UI, Roboto, sans-serif"
    fontSize: "12px"
    fontWeight: 400
    lineHeight: 1.4
rounded:
  plate: "6px"
  sm: "10px"
  badge: "12px"
  md: "14px"
  bubble: "18px"
  sheet: "24px"
  pill: "999px"
spacing:
  xs: "4px"
  sm: "8px"
  md: "10px"
  stack: "14px"
  panel: "16px"
  gutter: "20px"
  wall-top: "58px"
components:
  button-primary:
    backgroundColor: "{colors.tinta}"
    textColor: "{colors.cal}"
    typography: "{typography.title}"
    rounded: "{rounded.md}"
    padding: "0 20px"
    height: "52px"
  button-turquesa:
    backgroundColor: "{colors.turquesa}"
    textColor: "{colors.turquesa-fg}"
    rounded: "{rounded.md}"
    padding: "0 20px"
    height: "52px"
  button-coral:
    backgroundColor: "{colors.coral}"
    textColor: "{colors.coral-fg}"
    rounded: "{rounded.md}"
    padding: "0 20px"
    height: "52px"
  button-ghost:
    backgroundColor: "{colors.cal-2}"
    textColor: "{colors.tinta}"
    rounded: "{rounded.md}"
    padding: "0 20px"
    height: "52px"
  wall-abierta:
    backgroundColor: "{colors.turquesa}"
    textColor: "{colors.turquesa-fg}"
    typography: "{typography.display}"
    padding: "58px 20px 22px"
  wall-precaucion:
    backgroundColor: "{colors.ocre}"
    textColor: "{colors.ocre-fg}"
    typography: "{typography.display}"
    padding: "58px 20px 22px"
  wall-bloqueo:
    backgroundColor: "{colors.coral}"
    textColor: "{colors.coral-fg}"
    typography: "{typography.display}"
    padding: "58px 20px 22px"
  ask-card:
    backgroundColor: "{colors.muro}"
    textColor: "{colors.tinta}"
    rounded: "{rounded.md}"
    padding: "16px"
  chip:
    backgroundColor: "{colors.muro}"
    textColor: "{colors.tinta}"
    typography: "{typography.body-sm}"
    rounded: "{rounded.pill}"
    padding: "10px 14px"
    height: "44px"
  tag-ok:
    backgroundColor: "{colors.turquesa-suave}"
    textColor: "{colors.turquesa-tx}"
    rounded: "{rounded.pill}"
    padding: "3px 8px"
  tag-bad:
    backgroundColor: "{colors.coral-suave}"
    textColor: "{colors.coral}"
    rounded: "{rounded.pill}"
    padding: "3px 8px"
  panel:
    backgroundColor: "{colors.muro}"
    rounded: "{rounded.md}"
    padding: "16px"
  input-composer:
    backgroundColor: "{colors.muro}"
    textColor: "{colors.tinta}"
    rounded: "{rounded.pill}"
    padding: "10px 16px"
  nav:
    backgroundColor: "{colors.cal}"
    textColor: "{colors.tinta-3}"
    padding: "8px 8px 22px"
  nav-active:
    textColor: "{colors.tinta}"
  sheet:
    backgroundColor: "{colors.cal}"
    rounded: "{rounded.sheet}"
    padding: "10px 20px 28px"
  toast:
    backgroundColor: "{colors.tinta}"
    textColor: "{colors.cal}"
    rounded: "{rounded.md}"
    padding: "13px 16px"
---

# Design System: GoSmart Guajira

## Overview

**Creative North Star: "Muros de Cal" (the limewashed wall of Riohacha centro)**

GoSmart is a sunlit street object, not a dark map dashboard. The ground is cool limewash, the ink is deep indigo, and the state of the Troncal del Caribe is announced by whole painted fields of color: Caribbean turquoise when the road is open, ochre for caution or detour, coral for a blockade. The color is the message. It is laid down as a wall, the way a facade on the malecón is painted, never sprinkled as a glowing accent.

Type behaves like hand-painted sign lettering. Destinations, road states, arrival times and fares are set in Archivo squeezed to a condensed heavy cap (68% width, weight 850); everything else is Archivo at regular width, plain and readable under strong sun. Surfaces are flat and tonal; the only shadows are soft, ink-tinted, and reserved for things that float. Motion has one signature: the wall repaint, a left-to-right clip-path wipe in the new state color.

The world is light-first because it is used outdoors under Caribbean sun, on mid and low-end Android phones. A full dark token set exists and mirrors every role. This replaces the incumbent "Kinetic Flow" look (dark navy with a neon teal accent, still in `lib/theme/design_tokens.dart`); the Flutter tokens have not yet been migrated.

**Key Characteristics:**
- Cool lime-white ground, indigo ink, three state colors applied as full fields.
- Condensed heavy caps (rótulos) only for states, destinations, arrival times and money.
- One radius family: 14px panels and buttons, pill chips and tags.
- Flat by default; tinted soft shadows only on floating layers.
- Signature motion: the clip-path wall repaint.
- Phosphor icons (fill style, 256 grid) inlined from an SVG sprite.

## Colors

Limewash and indigo carry the interface; turquoise, ochre and coral are road-state paint, used as walls or as soft tinted grounds.

### Primary
- **Caribbean Turquoise** (turquesa): the brand field and the "vía abierta" wall; also the filled state of seats, completed trip steps, toggles and the turquoise button. Ink on it is always Turquoise Ink (turquesa-fg), never white.
- **Deep Lagoon** (turquesa-tx): turquoise for text and icons on the limewash ground (links, active nav icon, chip icons, section actions). Raw turquoise is too light for text on cal; this darker step is mandatory there.
- **Sea Glass** (turquesa-suave): soft ground for "ok" badges and tags, the dispatch box, and the halo around the current trip step.

### Secondary
- **Guajira Ochre** (ocre): caution and detour walls, the mototaxi mode, the plate, the ride-request countdown bar, star ratings, icons on dark toasts and banners, and the focus ring and text selection. Ink on it is indigo (ocre-fg).
- **Ochre Wash** (ocre-suave): soft ground for warning badges, the fair-fare box and the detour explanation.

### Tertiary
- **Blockade Coral** (coral): the "bloqueo" wall, the full-screen emergency alert, the emergency hold button fill, active scenario switches, and blocked road lines on the map. White ink (coral-fg).
- **Coral Wash** (coral-suave): soft ground for bad-state badges and tags and the resting emergency hold button.
- **TransPadilla Sea** (mar) and **Sea Wash** (mar-suave): reserved for the TransPadilla bus system and the anticipatory suggestion card that recommends it.

### Neutral
- **Cal** (cal): the ground of every screen, the nav bar, the sheet and the status bar; also the text color on ink surfaces.
- **Cal Shade** (cal-2): sectioning layer, the page behind the phone, ghost buttons, neutral badges, pattern and ethics notes.
- **Muro** (muro): raised white surfaces: the ask card, panels, chips, inputs, payment methods, chat bubbles from the assistant.
- **Tinta** (tinta): the ink. Body text, primary buttons, the user's chat bubbles, the receipt head, the driver wall, toasts, the offline banner, the FAB.
- **Tinta 2 / Tinta 3** (tinta-2, tinta-3): secondary copy and captions, timestamps, inactive nav.
- **Línea** (linea): hairlines, row dividers, unselected borders, inactive switch track, timeline rails.
- **Map Sea / Map Land** (mapa-mar, mapa-tierra): the schematic corridor map only.

### Named Rules
**The Painted Wall Rule.** A road state is announced by a whole field of its color (the home wall, the itinerary wall, the full-screen alert), with the state written on it as a rótulo. Elsewhere state colors appear only as their soft wash behind a badge or tag. Never a neon accent on a dark ground.

**The Three-State Rule.** Turquoise means open and calm, ochre means caution or detour, coral means blockade or emergency. Do not reuse them decoratively. Sea blue belongs to TransPadilla only.

**The Ink Leads Rule.** The primary action on a screen is an ink button (tinta on cal). Turquoise and coral buttons are reserved for state-specific actions.

**The Paired Ink Rule.** Every paint color has a named foreground (turquesa-fg, ocre-fg, coral-fg). Text on a wall uses its pair; text on the ground uses turquesa-tx, never raw turquoise.

## Typography

**Display Font:** Archivo, variable width axis (with Arial Narrow fallback)
**Body Font:** Archivo at normal width (with ui-sans-serif, system-ui fallback)

**Character:** One family in two voices. The rótulo is Archivo squeezed to 68% width at weight 850, uppercase, tight 0.95 leading: hand-painted sign lettering for the facts that matter on the street. The UI voice is the same face at normal width, sturdy at 600 to 750 for labels and titles, 400 for reading.

### Hierarchy
- **Display** (850, 68% width, clamp(40px, 17cqi, 60px) against the wall's inline size, 0.95, uppercase, balanced wrap): the road state on the home wall ("TRONCAL ABIERTA", "BLOQUEO EN EL KM 42"). Ochre caution uses a smaller clamp (36px, 13cqi, 52px) because its words are longer. The same voice sets the arrival on the itinerary wall (52px), balances and receipts (44 to 58px), the driver wall (56px) and the alert (60px).
- **Headline** (850, 68% width, 30px, 0.95, uppercase): screen titles beside the back button.
- **Fare** (850, 68% width, 21 to 22px, tabular): per-leg prices and fare rows. Money is always tabular.
- **Title** (750, 17px): section heads, the "¿Para dónde vas?" prompt, sheet titles (800, 20px).
- **Body** (400, 15px, 1.45): base copy, chat bubbles, row titles (650 when bolded). Body sm (14px) for hints, notes in panels, chips, toggles.
- **Label** (600 to 700, 11 to 13px): nav labels (11px, 600), tags (12px, 700), meta lines on the wall (13px, 600).
- **Caption** (400, 12 to 13px, tinta-3): timestamps, plates, disclaimers, demo notes.

### Named Rules
**The Rótulo Rule.** Condensed heavy caps are for the road state, destinations, arrival times, totals, fares and screen titles. Never for paragraphs, buttons or labels.

**The Tabular Money Rule.** Every number that changes or is compared (fares, balances, times, seat counts) uses tabular figures.

## Layout

Mobile canvas of 390 by 812 inside a phone frame. Screens use a 20px side gutter and a vertical stack with a 14px gap; panels pad 16px; inline gaps are 8 to 12px. Walls start at 58px top padding so the rótulo clears the status bar, and the ask card overlaps the wall by 22px, sitting half on the paint and half on the ground. Horizontal chip rows bleed to the screen edge and scroll. The bottom nav is a five-column grid with 44px minimum targets; the assistant is the center item as an ink pill.

The presenter page is a two-column grid (rail up to 320px, phone auto, 40px gap, max 1100px). At 860px and below the rail stacks under the phone. At 440px and below the page becomes the phone: frame, radius and status bar drop away and the screen fills 100dvh.

## Elevation & Depth

Flat and tonal at rest. Depth comes from three layers of the ground (cal-2 below, cal as ground, muro raised) and from painted walls. Shadows exist only for floating layers, and every shadow is tinted with the ink's RGB (`--sombra`, black in dark mode), never neutral gray.

### Shadow Vocabulary
- **Ask lift** (`box-shadow: 0 10px 24px -14px rgb(var(--sombra)/.35), 0 1px 0 rgb(var(--sombra)/.06)`): the assistant card overlapping the wall.
- **Request lift** (`box-shadow: 0 12px 24px -16px rgb(var(--sombra)/.45)`): the incoming ride request card for drivers.
- **FAB** (`box-shadow: 0 12px 24px -10px rgb(var(--sombra)/.55)`): the report button on the corridor map.
- **Sheet** (`box-shadow: 0 -12px 30px -12px rgb(var(--sombra)/.35)`): bottom sheets, over a scrim of `rgb(var(--sombra)/.42)`.
- **Toast** (`box-shadow: 0 14px 28px -12px rgb(var(--sombra)/.6)`): transient notices.
- **Thumb** (`box-shadow: 0 1px 2px rgb(var(--sombra)/.3)`): switch knobs.

### Named Rules
**The Floating-Only Shadow Rule.** Panels, rows, chips and walls never cast shadows. Only layers that float over content (ask card, sheet, toast, FAB, request card) get one, and it is ink-tinted.

## Shapes

One radius family. Panels, buttons, cards, the ask card, hints, methods and the map use 14px; small controls (segmented index items, toggles, amount buttons, ethics notes, fair box) use 10px; badges and the avatar use 12 to 14px; chips, tags, switches, the composer input and the FAB are full pills. Chat bubbles are 18px with the tail corner cut to 6px. Sheets round only their top corners at 24px. The license plate is the one sharp object: 6px radius with a 1.5px ink border, like a real plate. Selection is shown by an ink border plus a 1px inset ink ring, not by fill. Timelines (legs and trip steps) are drawn with a 2px hairline rail between circular dots.

## Components

### Buttons
Sturdy and blunt, like a painted shutter.
- **Shape:** gently rounded (14px), 52px minimum height, full width by default, 20px side padding, 750 weight at 16px.
- **Primary:** ink background with limewash text. Used for the main action of every screen ("Pagar ... una sola vez").
- **Turquoise / Coral / Ghost:** paint with their paired ink for state actions; ghost uses cal-2 with ink text.
- **Press:** scales to 0.97 over 140ms on the ease-out curve. On fine pointers the primary hover mixes 12% turquoise into the ink.
- **Disabled:** 45% opacity, no pointer events.
- **Focus:** a 3px ochre outline offset 2px, everywhere.

### Chips
- **Style:** white (muro) pill with a 1px hairline border, 44px tall, 14px 600 text, Deep Lagoon icon, secondary detail in tinta-3.
- **Hover (fine pointer):** border darkens to tinta-3.

### Tags and Badges
- **Tags:** small pills (12px, 700) on the soft wash of their state: ok on Sea Glass with Deep Lagoon text, warn on Ochre Wash, bad on Coral Wash with coral text, neutral on cal-2.
- **Badges:** 40px squares at 12px radius holding a 22px icon, same wash pairs, plus sea blue for TransPadilla.

### Cards / Containers
- **Corner Style:** 14px.
- **Background:** muro for panels, receipts, payment methods; cal-2 for pattern and ethics notes; mar-suave for the anticipatory hint; turquesa-suave for the dispatch box.
- **Shadow Strategy:** none, per the Floating-Only Shadow Rule.
- **Internal Padding:** 14 to 16px.
- **Receipt:** an ink head with a rótulo total, then dashed hairline rows.

### Inputs / Fields
- **Composer:** pill input on muro with a hairline border, 16px text (no zoom on mobile), flanked by 44px round buttons (ink send, cal-2 mic).
- **Payment methods and report types:** radio-style tiles; selected state is an ink border plus inset ink ring and an ink-dotted radio.
- **Focus:** the global ochre outline.

### Navigation
- **Bottom nav:** cal background, hairline top border, five items of 11px 600 labels with 24px icons in tinta-3. Active item turns ink with a Deep Lagoon icon. The assistant item is a 44 by 30 ink pill with a limewash icon.
- **Screen header:** a 40px round muro back button beside a 30px rótulo title.

### The Wall (signature)
The home screen's top half is a painted field in the corridor's current state color: route line with icon, the state as a display rótulo, one sentence of context, then meta (last confirmed time, number of reports). Variants: abierta (turquoise), precaución (ochre), bloqueo (coral). The itinerary repeats the wall in turquoise, or ochre when detoured, with the arrival time as its rótulo. The driver home uses an ink wall (cal-2 when offline).
- **Repaint:** on a state change and when the chat becomes the itinerary, a paint layer wipes in from the left with `clip-path: inset(0 100% 0 0)` to `inset(0 0 0 0)`, 520ms on the wall and 560ms on the itinerary, on `cubic-bezier(0.23, 1, 0.32, 1)`.

### Emergency Hold
A coral-wash button that fills with coral by the same clip-path wipe while held (1500ms linear), retracting in 200ms on release; the label flips to white as it fills. The full-screen alert is a coral wall with a 60px rótulo, fading in over 200ms.

### Sheets, Toasts and Banners
- **Sheet:** cal surface, 24px top radius, 40 by 5 grab handle, slides up in 380ms on `cubic-bezier(0.32, 0.72, 0, 1)` over a fading scrim (260ms).
- **Toast:** ink pill-ish card (14px radius) at the top, ochre icon, enters with opacity (220ms) and an upward 10px offset (260ms) on the ease-out curve.
- **Offline banner:** ink strip with an ochre icon and a pending-sync count; offline is shown as a normal state, never an error color.

### Motion
Two curves: ease-out `cubic-bezier(0.23, 1, 0.32, 1)` for entries, presses and the repaint; drawer `cubic-bezier(0.32, 0.72, 0, 1)` for sheets. Chat messages rise 6px and fade in over 260ms. Color changes on toggles and checks run 160 to 200ms. Under `prefers-reduced-motion: reduce`, every animation and transition collapses to 1ms.

## Do's and Don'ts

### Do:
- **Do** announce road state with a whole painted field and a rótulo, using the state's paired ink.
- **Do** use Deep Lagoon (turquesa-tx) for turquoise text and icons on the limewash ground.
- **Do** set road states, destinations, arrival times, totals and fares in the condensed rótulo (68% width, 850, uppercase, 0.95 leading), with tabular figures for money and times.
- **Do** keep radius to the one family: 14px panels and buttons, 10px small controls, pills for chips and tags.
- **Do** tint every shadow with the ink RGB and reserve shadows for floating layers.
- **Do** use the clip-path wall repaint (520 to 560ms, ease-out) when the corridor state changes or the chat becomes an itinerary.
- **Do** keep touch targets at 44px or more and the primary button at 52px.
- **Do** mark selection with an ink border plus inset ink ring.

### Don't:
- **Don't** return to the dark map dashboard with a neon accent; this world is light-first limewash.
- **Don't** use turquoise, ochre or coral as decoration; each means one road state.
- **Don't** use sea blue for anything other than TransPadilla.
- **Don't** put white text on turquoise or ochre, or raw turquoise text on the ground.
- **Don't** set paragraphs, buttons or labels in the condensed rótulo.
- **Don't** add shadows to panels, rows, chips or walls.
- **Don't** show offline as an error; it is an ink banner, not coral.
