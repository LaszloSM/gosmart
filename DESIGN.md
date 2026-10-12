---
# gstack: design-md-format=spec
name: GoSmart
description: Señalización vial bien hecha para Riohacha, Maicao y la Troncal; cálida, clara al sol, sin adornos.
colors:
  primary: "#0B4A57"        # mar profundo: marca y acciones
  on-primary: "#FFFFFF"
  background: "#F6F1E7"     # arena
  surface: "#FFFDF8"        # sal
  text: "#1B1915"           # tinta
  text-muted: "#4A453C"     # tinta suave
  line: "#CFC4B1"
  road-open: "#17602F"
  road-caution: "#6A3F00"
  road-caution-tint: "#FBE7C2"
  road-closed: "#9E1F18"
  road-unknown: "#55514A"
  dark-background: "#14130F"
  dark-surface: "#1E1C17"
  dark-text: "#F3EEE4"
  dark-text-muted: "#BDB5A6"
  dark-primary: "#7FC7D3"
typography:
  display:
    fontFamily: Atkinson Hyperlegible Next
    fontWeight: 800
    fontSize: 28px
    letterSpacing: -0.01em
  title:
    fontFamily: Atkinson Hyperlegible Next
    fontWeight: 700
    fontSize: 20px
  body:
    fontFamily: Atkinson Hyperlegible Next
    fontWeight: 400
    fontSize: 17px
    lineHeight: 1.45
  label:
    fontFamily: Atkinson Hyperlegible Next
    fontWeight: 600
    fontSize: 14px
    letterSpacing: 0.01em
  mono:
    fontFamily: Atkinson Hyperlegible Mono
    fontWeight: 600
    fontSize: 17px
  mono-display:
    fontFamily: Atkinson Hyperlegible Mono
    fontWeight: 700
    fontSize: 32px
rounded:
  sm: 6px
  md: 10px
  lg: 16px
  full: 9999px
spacing:
  xs: 4px
  sm: 8px
  md: 16px
  lg: 24px
  xl: 32px
  2xl: 48px
  touch: 48px
  touch-driver: 72px
components:
  button-primary:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.on-primary}"
    rounded: "{rounded.md}"
    height: "{spacing.touch}"
  button-driver:
    backgroundColor: "{colors.primary}"
    textColor: "{colors.on-primary}"
    rounded: "{rounded.lg}"
    height: "{spacing.touch-driver}"
  input:
    backgroundColor: "{colors.surface}"
    borderColor: "{colors.text-muted}"
    rounded: "{rounded.sm}"
  sheet:
    backgroundColor: "{colors.surface}"
    rounded: "{rounded.lg}"
  corridor-line:
    height: 56px
    backgroundColor: "{colors.surface}"
---

# GoSmart

## Overview

**Creative North Star:** señalización vial bien hecha. Informa de un vistazo, al sol y con una mano; nada decora.
**Frase guía:** "Antes de salir, ya sé cómo está la vía."
**Product context:** app Android (Flutter) de movilidad para Riohacha, Maicao y la Troncal del Caribe. Usuarios: viajeros del corredor, usuarios de mototaxi y TransPadilla, y conductores. Pares: Moovit, Citymapper, Waze, Uber/InDrive.
**Mode per surface:** pasajero = Operate; conductor = Operate con atención mínima; página pública de WhatsApp = Read; admin web = Operate denso.
**Reference sites:** solo búsqueda web, sin capturas. Moovit agrupa alertas de servicio junto al estado de cada línea; Citymapper prioriza filtros de un toque.
**Key characteristics:**
- La Línea del corredor arriba: el estado de la vía en 1 segundo.
- Un solo color de marca. Rojo, ámbar y verde existen solo para la vía.
- Números en monoespaciada, como un tablero de carretera.
- Superficies planas sobre arena; el mapa es el fondo.

## Colors

**Strategy:** restringido. `primary` (mar profundo) marca acciones y selección. Los colores `road-*` comunican solo el estado de un tramo o reporte y nunca se usan como acento de marca.
**Light or dark:** claro por defecto, porque la app se usa a pleno sol en la calle y en la moto. Oscuro solo cuando el sistema lo pide de noche: viajes nocturnos, sin encandilar al conductor.
- Todo texto principal llega a 7:1 o más. Medido: tinta/arena 15.6, tinta suave/arena 8.4, blanco/mar 9.8, blanco/abierta 7.6, blanco/cerrada 7.9, precaución/tinte 7.4.
- El estado nunca depende solo del color: siempre lleva ícono + texto ("Bloqueo km 42").
- Los neutros son cálidos, derivados de la arena; no se usa gris puro.
- `line` es solo para divisores; no lleva texto encima.
- En oscuro las superficies suben de luminosidad para dar jerarquía (fondo #14130F, superficie #1E1C17), en vez de simplemente invertir colores.

## Typography

- **Familia:** Atkinson Hyperlegible Next, del Braille Institute. Está hecha para que I, l y 1 no se confundan, que es justo el problema del sol y de las personas mayores.
- **Atkinson Hyperlegible Mono:** para km, tarifas, horas y placas; alinea los números en columnas.
- **Licencia y carga:** ambas OFL. Se empaquetan en `assets/fonts/` para que funcionen sin señal; no se usa `google_fonts` en tiempo de ejecución.
- **Pesos:** 400 cuerpo, 600 etiquetas y botones, 700 títulos, 800 display. Se retiran Plus Jakarta Sans e Inter.
- **Escala:** 28 / 20 / 17 / 14, con saltos de más de un peso entre niveles.
- **Texto grande:** se soporta hasta 200% sin cortar; los layouts usan `Expanded` + `maxLines`.

## Layout

- Móvil primero: el teléfono vertical es el único lienzo del MVP. El admin web usa una columna máxima de 1200 px.
- Márgenes laterales de 16 px y ritmo vertical en múltiplos de 8.
- Pantalla de inicio: Línea del corredor (56 px) → mapa a pantalla completa → hoja inferior con "¿A dónde vas?" y lugares frecuentes.
- **Modo conductor:** las acciones van en la mitad inferior (zona del pulgar), con 2 acciones por pantalla como máximo.
- Sin tarjetas por defecto: las listas son filas planas con divisor `line`. Una tarjeta solo existe cuando es la interacción completa, por ejemplo la solicitud entrante del conductor.

## Elevation & Depth

- Solo dos niveles: el mapa y las hojas encima.
- Sombra de hoja: desplazamiento 0 -2 px, desenfoque 12 px, tinta al 12%.
- Sin brillos ni halos; en modo oscuro la profundidad se da con superficies más claras, no con sombra.

## Shapes

- Radios: `sm` 6 para inputs y chips, `md` 10 para botones, `lg` 16 para hojas y la solicitud del conductor.
- Radio interior = radio exterior − separación.
- Nada redondeado por igual en todos lados; las píldoras (`full`) solo para filtros de modo de transporte.

## Components

- **Línea del corredor:** diagrama horizontal tipo metro de la Troncal, Riohacha (km 0) → Maicao (km ~75), con el desvío Albania–Cuestecitas como ramal.
  - Cada tramo se pinta con su color `road-*`, con un mínimo de 3:1 contra el fondo.
  - Los puntos con reporte llevan ícono.
  - Al tocarla se abre el detalle; al lado se muestra la hora de actualización en mono.
  - Sin señal, se muestra en gris con "hace X min".
- **Botón primario:** fondo mar y texto blanco 600. Al presionar, escala 0.97; foco visible con anillo de 2 px en mar a 2 px de distancia; deshabilitado al 38% de opacidad sobre arena.
- **Botón conductor:** 72 px de alto, ancho completo, texto de 20 px.
- **Fila de itinerario (tramo):** ícono de modo + nombre + tiempo y precio en mono a la derecha; el rango de precio con guion ("$4.000–6.000").
- **Chip de estado vial:** fondo del color `road-*` con texto blanco, o tinte de precaución con texto oscuro. Siempre con ícono y palabra (Abierta / Precaución / Cerrada / Sin datos).
- **Solicitud entrante del conductor:** hoja completa con precio en mono-display (32 px), distancia y origen, y dos botones de 72 px (Aceptar / Rechazar) más contador visible.

## Do's and Don'ts

- Do: mostrar la hora de actualización junto a todo dato vivo.
- Do: usar mono para cada número que el usuario compara (precios, minutos, km).
- Do: escribir en tuteo, corto y con palabras locales ("la Troncal", "el terminal", "mototaxi").
- Do: diseñar los estados cargando, vacío, error y sin señal de cada pantalla (tabla DS2 del plan).
- Don't: usar rojo, ámbar o verde fuera del estado de la vía; en error de formulario se usa el texto + ícono con `road-closed` solo dentro del mensaje.
- Don't: tarjetas dentro de tarjetas, íconos en círculos de color ni degradados.
- Don't: iconografía o patrones wayuu como decoración.
- Don't: lenguaje alarmista ni que señale comunidades en reportes de seguridad.

## Motion

- **Approach:** mínimo funcional.
- **Easing:** entrada ease-out (cubic-bezier 0.23, 1, 0.32, 1); salida ease-in; movimiento ease-in-out.
- **Duration:** presión 100–150 ms; chips 150–200 ms; hojas 250 ms al entrar y 200 ms al salir.
- **The one authored moment:** cuando cambia el estado de un tramo, la Línea del corredor funde el color en 200 ms y el tramo late una sola vez.
- Nada animado en acciones repetidas. Con "reducir movimiento" se quitan desplazamientos y se dejan los cambios de opacidad.

## Decisions Log
| Date | Decision | Rationale |
|------|----------|-----------|
| 2026-10-12 | Sistema de diseño inicial | /design-consultation sobre el plan MVP (DS1–DS8), búsqueda web de apps de tránsito y uso al sol |
| 2026-10-12 | Marca en mar profundo, no en verde | El verde queda reservado para "vía abierta" |
| 2026-10-12 | Línea del corredor como firma | Responde la frase guía en 1 segundo |
| 2026-10-12 | Fuentes empaquetadas, no `google_fonts` | Funcionan sin señal en el corredor |
