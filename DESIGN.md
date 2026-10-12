---
# gstack: design-md-format=spec
name: GoSmart
description: Rótulo de colectivo para la Troncal del Caribe; cada destino, tramo y viaje es una placa de ruta que se lee a cinco metros, al sol y con una mano.
colors:
  brand: "#1B3A8C"
  brand-pressed: "#142C6B"
  on-brand: "#FFFFFF"
  on-brand-muted: "#CCD7F2"
  brand-tint: "#E3E9F6"
  stripe: "#C2185B"
  background: "#EEF1F5"
  surface: "#FFFFFF"
  surface-sunken: "#E2E7EE"
  text: "#111827"
  text-muted: "#465066"
  text-disabled: "#8A93A6"
  line: "#C9D0DC"
  road-open: "#17602F"
  road-caution: "#6A3F00"
  road-caution-tint: "#FBE7C2"
  road-closed: "#9E1F18"
  road-closed-tint: "#F6DAD6"
  road-unknown: "#545B69"
  mode-taxi: "#7A4E2D"
  mode-bike: "#3D6B8C"
  card-gold: "#B08A3E"
typography:
  display:
    fontFamily: "Barlow Condensed"
    fontSize: "28px"
    fontWeight: 800
    lineHeight: 1.1
  headline:
    fontFamily: "Barlow Condensed"
    fontSize: "24px"
    fontWeight: 700
    lineHeight: 1.15
  title:
    fontFamily: "Barlow Condensed"
    fontSize: "24px"
    fontWeight: 700
    lineHeight: 1.15
  app-bar:
    fontFamily: "Barlow Condensed"
    fontSize: "26px"
    fontWeight: 800
    letterSpacing: "0.2px"
  plate:
    fontFamily: "Barlow Condensed"
    fontSize: "22px"
    fontWeight: 800
    lineHeight: 1.05
    letterSpacing: "0.4px"
  plate-lg:
    fontFamily: "Barlow Condensed"
    fontSize: "30px"
    fontWeight: 800
    lineHeight: 1.05
    letterSpacing: "0.4px"
  button:
    fontFamily: "Barlow Condensed"
    fontSize: "20px"
    fontWeight: 700
    lineHeight: 1.1
    letterSpacing: "0.3px"
  row-title:
    fontFamily: "Barlow"
    fontSize: "17px"
    fontWeight: 600
    lineHeight: 1.3
  body:
    fontFamily: "Barlow"
    fontSize: "17px"
    fontWeight: 400
    lineHeight: 1.45
  body-small:
    fontFamily: "Barlow"
    fontSize: "15px"
    fontWeight: 400
    lineHeight: 1.4
  label:
    fontFamily: "Barlow"
    fontSize: "15px"
    fontWeight: 600
    letterSpacing: "0.15px"
  label-small:
    fontFamily: "Barlow"
    fontSize: "13px"
    fontWeight: 600
    letterSpacing: "0.2px"
  figures:
    fontFamily: "Barlow"
    fontSize: "17px"
    fontWeight: 600
    fontFeature: "tnum"
  figures-display:
    fontFamily: "Barlow"
    fontSize: "32px"
    fontWeight: 700
    fontFeature: "tnum"
rounded:
  sm: "4px"
  md: "8px"
  lg: "12px"
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
  corridor-line: "56px"
  stripe: "4px"
components:
  button-primary:
    backgroundColor: "{colors.brand}"
    textColor: "{colors.on-brand}"
    typography: "{typography.button}"
    rounded: "{rounded.md}"
    height: "52px"
    padding: "0 20px"
  button-primary-pressed:
    backgroundColor: "{colors.brand}"
    textColor: "{colors.on-brand}"
  button-secondary:
    backgroundColor: "{colors.brand-tint}"
    textColor: "{colors.brand}"
    typography: "{typography.button}"
    rounded: "{rounded.md}"
    height: "52px"
  button-outline:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.brand}"
    typography: "{typography.button}"
    rounded: "{rounded.md}"
    height: "52px"
  button-ghost:
    backgroundColor: "transparent"
    textColor: "{colors.brand}"
    typography: "{typography.button}"
    rounded: "{rounded.md}"
    height: "{spacing.touch}"
  button-danger:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.road-closed}"
    typography: "{typography.button}"
    rounded: "{rounded.md}"
    height: "52px"
  route-plate:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.brand}"
    typography: "{typography.plate}"
    rounded: "{rounded.md}"
    height: "56px"
    padding: "8px 16px"
  route-plate-placeholder:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.text-muted}"
    typography: "{typography.plate}"
    rounded: "{rounded.md}"
  route-plate-sm:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.brand}"
    rounded: "{rounded.md}"
    height: "{spacing.touch}"
    padding: "8px 12px"
  top-bar:
    backgroundColor: "{colors.brand}"
    textColor: "{colors.on-brand}"
    typography: "{typography.app-bar}"
    height: "{spacing.top-bar}"
  bottom-nav:
    backgroundColor: "{colors.brand}"
    textColor: "{colors.on-brand-muted}"
    typography: "{typography.label-small}"
    height: "{spacing.bottom-nav}"
  bottom-nav-active:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.brand}"
    rounded: "{rounded.sm}"
  input:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.text}"
    typography: "{typography.body}"
    rounded: "{rounded.md}"
    padding: "12px 16px"
  list-row:
    backgroundColor: "transparent"
    textColor: "{colors.text}"
    typography: "{typography.row-title}"
    height: "64px"
    padding: "12px 16px"
  chip:
    backgroundColor: "{colors.surface-sunken}"
    textColor: "{colors.text}"
    rounded: "{rounded.sm}"
    padding: "4px 12px"
  chip-selected:
    backgroundColor: "{colors.brand-tint}"
    textColor: "{colors.brand}"
    rounded: "{rounded.sm}"
  segmented-selected:
    backgroundColor: "{colors.brand}"
    textColor: "{colors.on-brand}"
    rounded: "{rounded.md}"
    height: "{spacing.touch}"
  sheet:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.text}"
    rounded: "{rounded.lg}"
  corridor-line:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.text-muted}"
    height: "{spacing.corridor-line}"
    padding: "0 16px"
  toast:
    backgroundColor: "{colors.text}"
    textColor: "{colors.on-brand}"
    rounded: "{rounded.md}"
---

# Design System: GoSmart

## Overview

**Creative North Star: "El rótulo de colectivo"**

GoSmart se lee como los rótulos de ruta pintados en el parabrisas de los colectivos y busetas de la costa. Cada destino, tramo, viaje o nombre importante es una **placa de ruta**: blanca, con borde fino, letras condensadas gruesas en ultramar y, cuando está elegida o en curso, una franja fucsia debajo. La carrocería es el shell: la barra superior, la barra inferior y el botón primario son azul ultramar macizo; entre ellas, la pantalla es lámina blanca fría y las filas son planas, separadas por divisores.

La densidad es de señalización, no de tablero: pocos elementos por pantalla, letras grandes, cifras tabulares, contraste pensado para pleno sol y una mano. La profundidad casi no existe; el sistema se sostiene con color plano, bordes de 1,5 dp y la franja. El movimiento es breve y funcional: la placa responde al dedo y su rótulo se "pinta" al cambiar; nada se anima por adorno.

El mundo rechaza explícitamente el mapa blanco con hoja negra y un solo acento de las apps de transporte globales, y el arena-con-un-azul del diseño anterior de GoSmart.

**Key Characteristics:**
- Shell en ultramar de carrocería; contenido en lámina fría y placas blancas.
- Placas de ruta con letras Barlow Condensed 800 en mayúsculas como gesto distintivo.
- Franja fucsia de 4 dp solo bajo lo seleccionado o activo.
- Rojo, ámbar y verde reservados al estado de la vía, siempre con ícono y palabra.
- Radios 4 / 8 / 12; sin degradados, sin vidrio, sin tarjetas por defecto.
- Presión a 0,97 en 120 ms; cambio de placa con fundido y 8 dp en 200 ms.

## Colors

Un ultramar saturado de carrocería sobre neutros fríos de lámina, con un fucsia de señal que nunca rellena y una paleta vial que solo habla del estado de la Troncal.

### Primary
- **Ultramar de carrocería** (brand): barra superior, barra inferior, botón primario, letras de las placas, íconos de filas y foco de campos. Blanco encima alcanza 10,3:1. Su versión presionada (brand-pressed) solo para estados de presión.
- **Blanco sobre carrocería** (on-brand) y **Azul neblina** (on-brand-muted): texto e íconos sobre ultramar; el neblina para pestañas inactivas y textos secundarios dentro del shell (7:1).
- **Tinte de ultramar** (brand-tint): fondos de lo seleccionado (chips, botón secundario, resaltado al tocar una placa); el ultramar encima da 8,5:1.

### Secondary
- **Fucsia de franja** (stripe): la franja de 4 dp bajo la placa activa, la placa del perfil, la Línea del corredor en el shell y el borde inferior de la pestaña activa. Nunca relleno, nunca texto, nunca fondo.

### Tertiary
- **Paleta vial** (road-open, road-caution, road-closed, road-unknown, con sus tintes): exclusiva del estado de la vía en la Línea del corredor y sus detalles. Los rojos de error de formulario reutilizan road-closed porque Material los exige, pero siempre con ícono y texto.
- **Modos de transporte**: TransPadilla, colectivo e intermunicipal usan el ultramar; mototaxi/taxi el café (mode-taxi); bicicleta el azul acero (mode-bike); a pie la tinta suave; carro la tinta. Ninguno coincide con la paleta vial.
- **Oro de tarjeta** (card-gold): solo el chip de la tarjeta GoSmart.

### Neutral
- **Lámina** (background): fondo de pantalla, frío y claro.
- **Placa** (surface): placas, hojas, campos, la Línea del corredor.
- **Lámina hundida** (surface-sunken): agrupar y chips sin seleccionar.
- **Tinta** (text): texto principal, 15,7:1 sobre lámina; también fondo de los avisos.
- **Tinta suave** (text-muted): texto secundario, 7,1:1 sobre lámina; bordes de campos y de botón contorno.
- **Tinta apagada** (text-disabled): solo pistas y deshabilitados, exenta del mínimo.
- **Línea** (line): divisores y bordes de placa; nunca lleva texto encima.

### Named Rules
**The Carrocería Rule.** El ultramar es el shell (barras arriba y abajo, botón primario) y la tinta de las placas. No se usa como fondo de bloques de contenido ni de tarjetas.

**The Franja Rule.** El fucsia aparece solo como franja bajo un elemento seleccionado o en curso, una por grupo. Si nada está activo, no hay fucsia en pantalla.

**The Semáforo Rule.** Rojo, ámbar y verde existen solo para el estado de la vía y siempre van con ícono y palabra ("Cerrada", "Precaución", "Abierta", "Sin datos"). El éxito usa el ultramar; los eco-puntos no son verdes; el dinero no lleva rojo ni verde, el signo lo dice.

**The Siete a Uno Rule.** Todo texto principal y secundario cumple al menos 7:1 contra su fondo; solo deshabilitados y pistas quedan exentos.

## Typography

**Display Font:** Barlow Condensed 600 / 700 / 800 (empaquetada, OFL)
**Body Font:** Barlow 400 / 500 / 600 / 700 (empaquetada, OFL)
**Label/Mono Font:** Barlow con cifras tabulares (no hay monoespaciada aparte)

**Character:** Letra de rótulo pintado, condensada y gruesa, para lo que se lee de lejos (placas, títulos, botones); Barlow abierta y tranquila para el cuerpo. Las dos son de la misma familia, así que conviven sin fricción.

### Hierarchy
- **Display** (Barlow Condensed 800, 28–40 sp, 1,05–1,1): pantallas de bienvenida y cifras de portada; poco uso.
- **Headline / Title** (Barlow Condensed 700, 22–28 sp, 1,1–1,15): títulos de sección dentro de una pantalla ("Tu cuenta", "Seguridad") y títulos de hoja (26 sp, 800).
- **Barra superior** (Barlow Condensed 800, 26 sp): el nombre de la pantalla en blanco sobre ultramar.
- **Placa** (Barlow Condensed 800, 18 / 22 / 30 sp según talla, 1,05, +0,4 de tracking, mayúsculas): el rótulo de cada placa de ruta y el campo "¿A DÓNDE VAS?".
- **Botón** (Barlow Condensed 700, 17 / 20 / 22 sp según talla): etiquetas de botón en caja normal.
- **Título de fila** (Barlow 600, 17 sp, 1,3): el título de cada fila y de las listas.
- **Body** (Barlow 400, 17 sp, 1,45; 16 y 15 sp en tinta suave para lo secundario): texto corrido y subtítulos.
- **Label** (Barlow 600, 13–15 sp, +0,15–0,2 de tracking): etiquetas de campos, pestañas, extremos de la Línea del corredor.
- **Cifras** (Barlow 600 con tnum, 17 sp; 32 sp / 700 para el saldo): precios, saldo, km, horas y todo número que se compara.

### Named Rules
**The Rótulo Rule.** Las mayúsculas condensadas son de las placas: destinos, tramos, nombres. El resto del texto va en caja normal; no se inventan etiquetas pequeñas en mayúsculas sobre los títulos.

**The Cifra Tabular Rule.** Todo número que el usuario compara (pesos, km, minutos, horas) lleva cifras tabulares y se formatea con `formatCop()` cuando es dinero.

**The Doscientos Rule.** Ningún texto se corta con el texto del sistema al 200 %: las placas crecen en alto, admiten 2 líneas en nombres largos, y la barra inferior crece desde 72 dp.

## Layout

Columna única de teléfono con margen lateral de 16 dp y escala de espaciado de 4 dp (4, 8, 12, 16, 20, 24, 32, 40, 48, 64). La estructura fija es: barra ultramar de 56 dp arriba (en Inicio, la Línea del corredor de 56 dp sobre una placa blanca dentro del shell), contenido en lámina, barra inferior ultramar de 72 dp mínimo con tres pestañas (Inicio, Billetera, Perfil).

En Inicio el mapa ocupa el centro y una hoja blanca abajo lleva la placa "¿A DÓNDE VAS?" a todo el ancho (56 dp) con Casa y Trabajo como placas pequeñas debajo. En las demás pantallas el contenido son filas planas de 64 dp mínimo con divisor, agrupadas bajo títulos de sección condensados; una placa grande encabeza cuando hay un nombre o destino que mostrar (el nombre del usuario en Perfil).

Áreas táctiles de 48 dp mínimo; 72 dp en modo conductor. Todo contenido con scroll deja debajo el alto de la barra inferior más el área segura más 16 dp.

### Named Rules
**The Fila Plana Rule.** Las listas son filas planas con divisor, no tarjetas. Una tarjeta solo aparece si agrupa algo que se mueve junto, y entonces es plana con borde de línea y radio 12.

## Elevation & Depth

Plano por defecto. La jerarquía la dan el color del shell, el borde de 1,5 dp de las placas y la franja. Hay un vocabulario corto de sombras teñidas de tinta ultramar (no negro puro) que se reserva para lo que flota sobre el mapa: la hoja inferior y los botones circulares de mapa. Placas, filas, botones y tarjetas no llevan sombra.

### Shadow Vocabulary
- **Hoja** (`0 -2px 12px rgba(14,26,58,0.12)`): hoja inferior sobre el mapa y hojas modales.
- **Flotante de mapa** (`0 2px 10px rgba(14,26,58,0.10)`): controles circulares sobre el mapa (ubicarme).
- **Baja** (`0 1px 4px rgba(14,26,58,0.08)`): disponible para un botón de ícono que necesite separarse de un fondo variable.

### Named Rules
**The Sin Vidrio Rule.** Superficies sólidas y opacas, legibles al sol: sin desenfoque de fondo, sin degradados, sin brillos de color.

## Shapes

Esquinas apenas suavizadas, como una lámina cortada: 4 dp para chips, placas pequeñas y la pastilla de la pestaña activa; 8 dp para botones, campos y placas; 12 dp para hojas (solo arriba) y tarjetas. El sistema no pasa de 12. El círculo completo queda para los filtros de modo de transporte, los botones de ícono sobre el mapa, el asa de la hoja y los avatares. Los bordes son de 1,5 dp (placas, campos en reposo) o 2 dp (foco, botón contorno); la franja activa mide 4 dp y se pega al borde inferior de la placa, que se recorta con ella.

## Components

### Placa de ruta (GSRoutePlate, gesto distintivo)
La placa es la unidad del mundo: destino, tramo, viaje o nombre.
- **Forma:** placa blanca, radio 8, borde de línea de 1,5 dp; tallas de 48, 56 y 72 dp de alto mínimo con rótulo de 18, 22 y 30 sp.
- **Rótulo:** Barlow Condensed 800 en mayúsculas, en ultramar; en tinta suave cuando es una placa en blanco ("¿A DÓNDE VAS?"). Origen y destino se unen con un ícono de flecha, no con un glifo. Una línea pequeña opcional debajo (hora, precio, correo) en Barlow 500 tabular, 15 sp, tinta suave.
- **Activa:** el borde pasa a ultramar y aparece la franja fucsia de 4 dp debajo. Anuncia "seleccionado" a TalkBack.
- **Presión:** escala a 0,97 en 120 ms con GSCurve.enter, disparada al tocar (no al confirmar el gesto); resaltado con tinte de ultramar, sin salpicadura.
- **Cambio de rótulo:** el nuevo entra con fundido y desplazamiento de 8 dp en 200 ms (cubic 0.23, 1, 0.32, 1); el anterior solo se desvanece. Con "quitar animaciones" queda un fundido de 150 ms sin desplazamiento ni escala.
- **Destino pintado:** en el planificador, el campo de destino es una placa en blanco; al elegir una sugerencia se convierte en placa activa con la misma transición de 200 ms. Tocarla la borra para escribir otro.

### Buttons
- **Shape:** radio 8 (rounded.md), sin elevación; 48 / 52 / 60 dp de alto según talla, ancho completo por defecto.
- **Primary:** ultramar con texto blanco, etiqueta Barlow Condensed 700.
- **Secondary:** tinte de ultramar con texto ultramar. **Outline:** placa blanca con borde ultramar de 2 dp. **Ghost:** transparente con texto ultramar. **Danger:** placa blanca con borde y texto rojo de vía cerrada (acciones destructivas, siempre con palabra explícita).
- **Presión:** 0,97 en 120 ms GSCurve.enter, sin salpicadura; sin escala con "quitar animaciones". Deshabilitado a 38 % de opacidad; cargando muestra un indicador del color del texto.

### Chips
- **Style:** lámina hundida, borde de línea, radio 4, Barlow 600 14 sp.
- **State:** seleccionado en tinte de ultramar. El selector segmentado nativo marca lo elegido en ultramar macizo con texto blanco en Barlow Condensed 700, sin animación de deslizamiento.

### Cards / Containers
- **Corner Style:** 12 dp.
- **Background:** placa blanca.
- **Shadow Strategy:** ninguna (ver Elevation & Depth).
- **Border:** línea de 1 dp.
- **Internal Padding:** 16 dp. Solo cuando agrupan algo; por defecto, filas planas.

### Inputs / Fields
- **Style:** placa blanca, borde de tinta suave de 1,5 dp, radio 8, padding 12 × 16, texto Barlow 17 sp; etiqueta encima en Barlow 600 15 sp.
- **Focus:** borde ultramar de 2 dp.
- **Error / Disabled:** borde de 2 dp en rojo de vía cerrada con mensaje de 14 sp; pistas en tinta apagada.

### Navigation
- **Barra superior:** ultramar, 56 dp, título Barlow Condensed 800 26 sp en blanco, íconos blancos, sin elevación.
- **Barra inferior:** ultramar, 72 dp mínimo que crece con el texto grande. Pestaña activa: ícono ultramar sobre una pastilla blanca de radio 4 con franja fucsia en su borde inferior, etiqueta blanca en Barlow 700. Inactivas: ícono y etiqueta en azul neblina, Barlow 500. Etiqueta siempre visible debajo. Cambiar de pestaña no se anima.

### Línea del corredor (GSCorridorLine)
Diagrama tipo metro de la Troncal, Riohacha a Maicao, de 56 dp sobre placa blanca. Línea de 6 dp coloreada por tramo con la paleta vial y estaciones de anillo de tinta en los extremos; a la derecha, ícono + palabra del estado en el color vial y la antigüedad del dato en cifras tabulares ("hace 12 min"). Sin datos o dato viejo: todo en gris de vía desconocida con "Sin datos". Nunca un estado inventado.

### Filas (GSListRow)
Fila plana de 64 dp mínimo: ícono ultramar, título Barlow 600 17 sp, detalle hasta 3 líneas en tinta suave, y al final un valor en cifras tabulares, un interruptor o un chevron. Divisor de línea entre filas.

### Hojas (GSBottomSheet)
Placa blanca con radio 12 arriba, asa de 40 × 4 dp en línea, título Barlow Condensed 800 26 sp y divisor. La hoja de Inicio se mueve en 250 ms al abrir y 200 ms al cerrar (GSDuration.sheetIn / sheetOut); las hojas modales usan la transición nativa. Con "quitar animaciones", ninguna se desliza.

### Avisos (GSToast)
Snackbar flotante de Material sobre tinta, radio 8, texto blanco Barlow 500 16 sp y un ícono que nombra el tipo. El error no rellena en rojo.

### Estado vacío (GSEmptyState)
Una placa en blanco (aún sin destino pintado), una frase que dice cómo llenarla y, si aplica, el botón que la llena.

## Do's and Don'ts

### Do:
- **Do** mostrar cada destino, tramo, viaje o nombre principal como placa de ruta: blanca, borde de 1,5 dp, Barlow Condensed 800 en mayúsculas y ultramar.
- **Do** poner la franja fucsia de 4 dp solo bajo la placa activa o la pestaña seleccionada.
- **Do** acompañar todo estado vial con ícono y palabra, y mostrar "Sin datos" con la hora cuando no hay dato.
- **Do** usar cifras tabulares para todo número que se compara.
- **Do** respetar 48 dp de área táctil (72 dp en modo conductor) y probar cada pantalla con texto al 200 %.
- **Do** usar la presión de 0,97 en 120 ms con GSCurve.enter, el cambio de placa de 200 ms con 8 dp, y hojas de 250 / 200 ms; con "quitar animaciones", solo fundidos cortos.
- **Do** usar los radios 4 / 8 / 12 y nada mayor salvo círculos completos.

### Don't:
- **Don't** usar rojo, ámbar o verde para nada que no sea el estado de la vía (ni éxito, ni eco-puntos, ni ingresos y gastos).
- **Don't** usar el fucsia como relleno, fondo, texto o decoración.
- **Don't** poner el ultramar como fondo de bloques de contenido; es la carrocería y la tinta de las placas.
- **Don't** usar degradados, vidrio esmerilado, brillos de color ni sombras en placas, filas y botones.
- **Don't** envolver listas en tarjetas por defecto.
- **Don't** animar el cambio de pestaña ni nada que el usuario repite muchas veces.
- **Don't** usar iconografía ni patrones wayuu como decoración.
- **Don't** escribir mayúsculas condensadas fuera de las placas, ni etiquetas pequeñas en mayúsculas sobre los títulos.
