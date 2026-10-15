---
# gstack: design-md-format=spec
name: GoSmart
description: Movilidad para Riohacha, Maicao y la Troncal del Caribe, con el acabado familiar de InDrive, Google Maps, Nequi y Uber/DiDi.
colors:
  # Día (GSPalette.light)
  brand: "#0B4FC4"
  brand-pressed: "#093F9D"
  on-brand: "#FFFFFF"
  on-brand-muted: "#D6E2FA"
  brand-tint: "#E8F0FE"
  shell: "#FFFFFF"
  on-shell: "#14161B"
  on-shell-muted: "#4A5162"
  background: "#F4F6FA"
  surface: "#FFFFFF"
  surface-sunken: "#EBEEF3"
  text: "#14161B"
  text-muted: "#4A5162"
  text-disabled: "#9AA0AC"
  line: "#DDE1E8"
  road-open: "#0F5F30"
  road-caution: "#734600"
  road-caution-tint: "#FFF1D6"
  road-closed: "#9C1E17"
  road-closed-tint: "#FDE7E5"
  road-unknown: "#4A5162"
  mode-taxi: "#6941C6"
  mode-bike: "#0E7490"
  card-gold: "#FFC93C"
  shadow-ink: "#1A2440"
  # Noche (GSPalette.dark): esquema propio, no una inversión
  brand-dark: "#A8C7FA"
  brand-pressed-dark: "#C2D7FB"
  on-brand-dark: "#0B1D3A"
  on-brand-muted-dark: "#1E3560"
  brand-tint-dark: "#1F2E4D"
  shell-dark: "#1B1E25"
  on-shell-dark: "#E6E8EE"
  on-shell-muted-dark: "#A9AEBA"
  background-dark: "#111318"
  surface-dark: "#1B1E25"
  surface-sunken-dark: "#262A33"
  text-dark: "#E6E8EE"
  text-muted-dark: "#A9AEBA"
  text-disabled-dark: "#6E7482"
  line-dark: "#2E333D"
  road-open-dark: "#73D69C"
  road-caution-dark: "#F2B65A"
  road-caution-tint-dark: "#3A2A10"
  road-closed-dark: "#FF8F85"
  road-closed-tint-dark: "#3F1916"
  road-unknown-dark: "#A3ABBA"
  mode-taxi-dark: "#C4B1F4"
  mode-bike-dark: "#7DD3E8"
  card-gold-dark: "#FFD66B"
  shadow-ink-dark: "#000000"
typography:
  display:
    fontFamily: "Figtree"
    fontSize: "34px"
    fontWeight: 800
    lineHeight: 1.1
    letterSpacing: "-0.6px"
  headline:
    fontFamily: "Figtree"
    fontSize: "24px"
    fontWeight: 800
    lineHeight: 1.2
    letterSpacing: "-0.3px"
  headline-small:
    fontFamily: "Figtree"
    fontSize: "22px"
    fontWeight: 700
    lineHeight: 1.2
    letterSpacing: "-0.2px"
  title:
    fontFamily: "Figtree"
    fontSize: "20px"
    fontWeight: 700
    lineHeight: 1.25
    letterSpacing: "-0.1px"
  title-medium:
    fontFamily: "Figtree"
    fontSize: "17px"
    fontWeight: 600
    lineHeight: 1.3
  body:
    fontFamily: "Figtree"
    fontSize: "17px"
    fontWeight: 400
    lineHeight: 1.45
  body-medium:
    fontFamily: "Figtree"
    fontSize: "16px"
    fontWeight: 400
    lineHeight: 1.45
  body-small:
    fontFamily: "Figtree"
    fontSize: "14px"
    fontWeight: 400
    lineHeight: 1.4
  label:
    fontFamily: "Figtree"
    fontSize: "16px"
    fontWeight: 600
  label-small:
    fontFamily: "Figtree"
    fontSize: "12px"
    fontWeight: 600
    letterSpacing: "0.1px"
  button:
    fontFamily: "Figtree"
    fontSize: "17px"
    fontWeight: 700
  amount:
    fontFamily: "Figtree"
    fontSize: "38px"
    fontWeight: 800
    fontFeature: "tnum"
rounded:
  sm: "8px"
  md: "12px"
  lg: "16px"
  xl: "24px"
  full: "9999px"
spacing:
  s1: "4px"
  s2: "8px"
  s3: "12px"
  s4: "16px"
  s5: "20px"
  s6: "24px"
  s8: "32px"
  s10: "40px"
  s12: "48px"
  s16: "64px"
  touch: "48px"
  touch-driver: "72px"
  top-bar: "56px"
  bottom-nav: "72px"
  button: "52px"
components:
  button-primary:
    backgroundColor: "{colors.brand}"
    textColor: "{colors.on-brand}"
    typography: "{typography.button}"
    rounded: "{rounded.full}"
    height: "52px"
    padding: "4px 22px"
  button-secondary:
    backgroundColor: "{colors.brand-tint}"
    textColor: "{colors.brand}"
    typography: "{typography.button}"
    rounded: "{rounded.full}"
    height: "52px"
  button-outline:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.text}"
    typography: "{typography.button}"
    rounded: "{rounded.full}"
    height: "52px"
  button-ghost:
    textColor: "{colors.brand}"
    typography: "{typography.button}"
    rounded: "{rounded.full}"
    height: "52px"
  button-danger:
    backgroundColor: "{colors.road-closed-tint}"
    textColor: "{colors.road-closed}"
    rounded: "{rounded.full}"
    height: "52px"
  button-driver:
    backgroundColor: "{colors.brand}"
    textColor: "{colors.on-brand}"
    rounded: "{rounded.full}"
    height: "72px"
    padding: "4px 24px"
  search-pill:
    backgroundColor: "{colors.surface-sunken}"
    textColor: "{colors.text}"
    rounded: "{rounded.full}"
  input-field:
    backgroundColor: "{colors.surface-sunken}"
    textColor: "{colors.text}"
    rounded: "{rounded.md}"
    padding: "16px"
  choice-pill:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.text}"
    rounded: "{rounded.full}"
    height: "48px"
    padding: "0 16px"
  choice-pill-selected:
    backgroundColor: "{colors.brand-tint}"
    textColor: "{colors.brand}"
    rounded: "{rounded.full}"
  option-card:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.text}"
    rounded: "{rounded.lg}"
    padding: "12px 16px"
  option-card-selected:
    backgroundColor: "{colors.brand-tint}"
    textColor: "{colors.text}"
    rounded: "{rounded.lg}"
  list-row:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.text}"
    height: "64px"
    padding: "12px 16px"
  group-card:
    backgroundColor: "{colors.surface}"
    rounded: "{rounded.lg}"
  balance-card:
    backgroundColor: "{colors.brand}"
    textColor: "{colors.on-brand}"
    typography: "{typography.amount}"
    rounded: "{rounded.xl}"
  fare-badge:
    backgroundColor: "{colors.brand-tint}"
    textColor: "{colors.brand}"
    rounded: "{rounded.full}"
  bottom-nav:
    backgroundColor: "{colors.shell}"
    textColor: "{colors.on-shell-muted}"
    height: "72px"
  bottom-nav-indicator:
    backgroundColor: "{colors.brand-tint}"
    rounded: "{rounded.full}"
    width: "56px"
    height: "32px"
  bottom-sheet:
    backgroundColor: "{colors.surface}"
    rounded: "{rounded.xl}"
  corridor-pill:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.text}"
    rounded: "{rounded.lg}"
    height: "56px"
---

# Design System: GoSmart

## Overview

**Creative North Star: "Lo que ya sabes usar"**

GoSmart se ve y se toca como las apps que la gente de la costa ya domina: mapa a pantalla completa como Google Maps, opciones de viaje con tiempo y precio como Uber/DiDi e InDrive, billetera de saldo grande como Nequi. Nada que aprender. Superficies blancas sobre un gris frío, un solo azul de marca, Figtree en caja normal, botones en píldora y tarjetas redondeadas con sombra suave.

Se usa en la calle, al sol, con una mano y a veces con texto grande. Por eso el contraste es alto (7:1 en texto), los toques miden 48 dp (72 en modo conductor) y nada se corta con el texto al 200 %. La noche tiene su propio esquema: superficies que suben de luminosidad y la marca aclarada, sin encandilar.

Reemplaza por completo el mundo anterior "Rótulo de colectivo" (placas condensadas en mayúsculas, ultramar macizo en barras, franja fucsia). Ninguno de esos recursos sigue vigente.

**Key Characteristics:**
- Mapa primero; encima, controles flotantes blancos con sombra.
- Un azul de marca para acción, selección, ruta y saldo.
- Píldoras para botones, buscador y chips; tarjetas de 16, hojas de 24.
- Verde, ámbar y rojo solo para el estado de la vía.
- Cifras tabulares para todo lo que el usuario compara.
- Movimiento corto y discreto; nada se anima al cambiar de pestaña.

## Colors

Neutros fríos y claros con un único azul; el color fuerte se reserva para lo que importa.

### Primary
- **Azul GoSmart** (brand): botón primario, selección, ruta en el mapa, tarjeta de saldo, ícono activo de la barra inferior. Blanco encima a 7.2:1. De noche se aclara (brand-dark) y el texto encima pasa a azul tinta.
- **Azul presionado** (brand-pressed): estado presionado.
- **Azul claro** (brand-tint): fondo de lo elegido (opción, chip, píldora de la pestaña activa, círculo de ícono, insignia de tarifa). La marca encima, en negrita.

### Secondary
- **Morado mototaxi** (mode-taxi) y **Cian bici** (mode-bike): colores de modo. El bus, colectivo e intermunicipal usan la marca; el carro, la tinta; a pie, el gris de texto secundario.
- **Oro de tarjeta** (card-gold): chip de la tarjeta GoSmart y eco-puntos.

### Tertiary
- **Vía abierta** (road-open), **Precaución** (road-caution + tint), **Cerrada** (road-closed + tint), **Sin datos** (road-unknown). Rojo también marca errores de campo y el botón de peligro.

### Neutral
- **Gris frío** (background): fondo de pantalla.
- **Blanco** (surface, shell): tarjetas, hojas, barras superior e inferior.
- **Gris hundido** (surface-sunken): buscador, campos, círculos de ícono en filas.
- **Tinta** (text): texto principal, 16.7:1 sobre el fondo.
- **Tinta suave** (text-muted): texto secundario, 7.3:1 sobre el fondo.
- **Línea** (line): divisores y bordes; nunca texto encima.

### Named Rules
**La Regla del Azul Único.** Hay un solo color de marca, #0B4FC4 (de día). Botones, selección, ruta y saldo lo usan; ningún segundo acento compite con él.

**La Regla de la Vía.** Verde, ámbar y rojo existen solo para el estado de la vía, y siempre van con ícono y palabra ("Cerrada", "Precaución"). El color nunca va solo. Entradas y salidas de dinero no usan verde ni rojo: las lleva el signo.

**La Regla del Modo.** Los colores de modo solo pintan tramos y marcadores (barra de tramos, línea de tiempo, polilínea del mapa), y se leen de la paleta activa en el momento de pintar (`liveColor`), nunca guardados.

**La Regla del 7:1.** Todo texto legible mide al menos 7:1 contra su fondo, de día y de noche. Solo el texto deshabilitado queda exento.

## Typography

**Display Font:** Figtree (empaquetada en assets/fonts, OFL; instancias estáticas 400, 500, 600, 700, 800)
**Body Font:** Figtree
**Label/Mono Font:** Figtree con cifras tabulares (`GSFonts.tabular`)

**Character:** Una sola familia geométrica y amable. Títulos en caja normal y peso 700–800 con interletrado levemente negativo; cuerpo en 400.

### Hierarchy
- **Display** (800, 30–40 px, 1.1): casi no se usa; saldo y pantallas de bienvenida.
- **Headline** (800, 24–28 px, 1.15–1.2): títulos de pantalla; la barra superior usa 22 px en 800.
- **Title** (700, 20 px, 1.25): títulos de sección (`GSSectionTitle`).
- **Title medium** (600, 17 px, 1.3): título de fila y de tarjeta.
- **Body** (400, 17 / 16 / 14 px, 1.45–1.4): texto corrido; 16 y 14 en tinta suave.
- **Label** (600, 16 / 14 / 12 px): etiquetas, chips y barra inferior (12.5 px; 700 activa).
- **Amount** (800, 38 px, tabular): saldo de la billetera. Precios, km y horas usan cifras tabulares a cualquier tamaño.

### Named Rules
**La Regla de los Doscientos.** El texto del sistema puede crecer hasta 200 % sin cortes a mitad de palabra: botones con alto mínimo (no fijo) que pasan a dos líneas, etiquetas de modo y de pestaña que se reducen para caber enteras (nunca "Colectiv/o" ni "Bille…").

**La Regla de la Cifra.** Todo número que el usuario compara (precio, saldo, minutos, km) va en cifras tabulares y se formatea con `formatCop()`.

## Layout

Pantalla de teléfono Android con margen lateral de 16 px (s4). Escala de espacio en múltiplos de 4: 4, 8, 12, 16, 20, 24, 32, 40, 48, 64.

El inicio es mapa a pantalla completa: arriba, la píldora flotante del corredor; abajo, una hoja blanca con el buscador "¿A dónde vas?", accesos Casa/Trabajo en círculos y una fila de servicios por modo. Las demás pantallas usan barra superior blanca con título grande a la izquierda (56 + 8 px) y contenido en grupos blancos sobre el fondo gris. La barra inferior Material 3 tiene cinco pestañas y mide al menos 72 px; crece con el texto grande.

Los toques miden al menos 48 dp; en modo conductor, 72 dp. Las filas de lista miden al menos 64 dp.

## Elevation & Depth

Sistema híbrido: plano por capas tonales (gris de fondo, blanco encima, gris hundido para campos) y sombras suaves teñidas de azul tinta solo para lo que flota sobre el mapa o el fondo. De noche la sombra es negra y la profundidad la da la superficie más clara.

### Shadow Vocabulary
- **sm** (0 1px 4px tinta 8 %): tarjetas que lo necesitan.
- **md** (0 2px 10px tinta 10 %).
- **lg** (0 4px 16px tinta 12 %).
- **sheet** (0 −4px 24px tinta 14 %): hoja inferior sobre el mapa.
- **float** (0 4px 16px tinta 16 % + 0 1px 2px tinta 6 %): píldora del corredor, buscador y botón de ubicarme sobre el mapa.

### Named Rules
**La Regla del Flotante.** La sombra marca lo que flota sobre el mapa. Las tarjetas sobre el fondo gris se separan por tono, no por sombra.

## Shapes

Formas suaves y conocidas. Radios 8 (chips pequeños, etiquetas, barra de tramos), 12 (campos, toasts, tarjetas pequeñas), 16 (tarjetas, grupos, opciones, píldora del corredor) y 24 (hojas inferiores arriba, diálogos, tarjeta de saldo). Botones, buscador, chips de filtro, insignias y avatares son píldoras. Íconos de fila y accesos van en círculos.

### Named Rules
**La Regla de la Píldora.** Todo lo que se toca para actuar o filtrar (botón, buscador, chip) es una píldora. Las tarjetas y hojas usan 16/24, nunca esquinas rectas.

## Components

### Buttons
- **Shape:** píldora (9999 px).
- **Primary:** azul de marca con texto blanco, Figtree 700 17 px; alto mínimo 52 px (sm 48, lg 56, conductor 72).
- **Press:** escala a 0.97 en 120 ms con ease-out fuerte, desde el toque; sin salpicadura. Con "quitar animaciones" no escala. Deshabilitado: opacidad 0.38.
- **Secondary / Outline / Ghost / Danger:** azul claro con texto azul; blanco con borde de línea 1.5 px; transparente con texto azul; rojo claro con texto rojo.

### Chips
- **Style:** `GSChoicePlates`: píldoras blancas con borde de línea 1 px, texto 16 px 600, alto 48.
- **State:** la elegida en azul claro con borde azul 2 px y texto 700. Sin animación al cambiar.

### Cards / Containers
- **Corner Style:** 16 px.
- **Background:** blanco sobre gris frío.
- **Shadow Strategy:** ninguna en reposo, salvo lo que flota sobre el mapa.
- **Border:** opción elegida con borde azul 2 px y fondo teñido; si no, línea 1 px.
- **Internal Padding:** 12–16 px.

### Inputs / Fields
- **Style:** relleno gris hundido, sin borde en reposo, radio 12, relleno 16.
- **Focus:** borde azul 2 px; etiqueta flotante en azul 600.
- **Error:** borde rojo 2 px y texto de error rojo 14 px.

### Navigation
- **Barra inferior:** blanca con línea fina arriba; píldora azul clara de 56 × 32 detrás del ícono activo; ícono activo azul, inactivo tinta suave; etiqueta siempre visible. Cambiar de pestaña no se anima.
- **Barra superior:** blanca, título 22 px 800 a la izquierda, sin elevación hasta que hay scroll.

### Opción de viaje (option card)
Tarjeta blanca de 16 con ícono en círculo, título, detalle y a la derecha tiempo y precio (como Uber/DiDi). La elegida lleva borde azul y fondo teñido. Si no hay regla de tarifa no se muestra precio.

### Billetera (balance card)
Tarjeta azul de 24 con el saldo en 38 px 800 tabular, un ojo para ocultarlo y la etiqueta "Saldo de prueba" mientras la recarga sea simulada. De noche usa el azul tenue nocturno (brand-tint-dark) con texto claro: un bloque de marca aclarada encandilaría.

### Línea del corredor
Píldora flotante sobre el mapa (radio 16, sombra float, alto 56): Riohacha → Maicao como línea gruesa con un color por tramo, el estado con ícono + palabra y la hora del dato.

### Detalle de ruta
Barra de tramos proporcional al tiempo (segmentos de 30 px, radio 8, color de modo; a pie en gris), línea de tiempo con el ícono del modo en un círculo de su color y la tarifa en una insignia píldora azul clara.

### Mapa
Google Maps con estilo propio de día (assets/map_styles/light.json: negocios ocultos, terreno gris claro, calles blancas) y de noche (night.json, azul noche). La ruta se pinta con el color de cada modo.

## Do's and Don'ts

### Do:
- **Do** usar el azul de marca (#0B4FC4) para la acción principal, la selección, la ruta y el saldo.
- **Do** acompañar todo estado de la vía con ícono y palabra.
- **Do** leer los colores de la paleta activa (getters de `GSColors`, `liveColor`); nunca guardarlos en un campo.
- **Do** usar píldoras para botones, buscador y chips; radios 8/12/16/24 para lo demás.
- **Do** medir los toques en 48 dp (72 en modo conductor).
- **Do** usar presión 0.97 en 120 ms ease-out; hojas 250 ms al entrar y 200 ms al salir; respetar "quitar animaciones".
- **Do** probar con texto al 130 % y 200 % sin cortes a mitad de palabra.
- **Do** mostrar precios solo cuando hay una regla de tarifa; si no, sin precio.

### Don't:
- **Don't** inventar un precio.
- **Don't** usar verde, ámbar o rojo fuera del estado de la vía (ni para entradas y salidas de dinero).
- **Don't** usar colores de modo fuera de tramos y marcadores.
- **Don't** animar el cambio de pestaña ni la selección de una opción.
- **Don't** volver al mundo anterior: placas condensadas en mayúsculas, barras ultramar, franja fucsia.
- **Don't** usar degradados ni vidrio; superficies sólidas y legibles al sol.
- **Don't** bajar el contraste del texto de 7:1.
- **Don't** presentar las recargas simuladas como dinero real.
