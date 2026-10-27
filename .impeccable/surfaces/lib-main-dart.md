---
version: 1
slug: "lib-main-dart"
primary_target: "lib/main.dart"
related_targets: ["lib/features"]
---

# Surface brief: app de pasajero (shell + todas las pantallas)

Scope: toda la app Android (inicio y mapa, planificador y ruta, billetera, perfil y viaje; conductor y admin heredan). Visitor mode: Operate.
Audience: viajero del corredor, usuario urbano de mototaxi/TransPadilla, conductor (ver PRODUCT.md). Muchos con poca experiencia digital.
Task: saber cómo está la vía, decidir cómo llegar, pedir y pagar; con una mano, al sol.
Constraints: controles nativos Material 3; 48 dp (72 en conductor); contraste 7:1 en texto principal; fuentes empaquetadas; estado de la vía siempre con ícono y palabra.
Build path: code-led (Operate). Ronda degradada (sin retadores: impeccable.style inalcanzable). El usuario eligió la salida estándar en sus palabras: "amigable, que se sientan familiarizados, intuitivo". Vara de calidad: InDrive, Google Maps, Nequi, Uber/DiDi.

## Direction contract

THESIS: GoSmart se usa como las apps que la gente de la costa ya domina (InDrive, Google Maps, Nequi, Uber/DiDi), con su acabado: mapa a pantalla completa, buscador en píldora, hojas blancas, tarjetas de opciones de viaje con precio, billetera de saldo grande. Rechaza el rótulo de colectivo anterior (placas condensadas en mayúsculas, ultramar macizo en barras).

OWN-WORLD: superficies blancas sobre gris frío claro (#F4F6FA); un solo color de marca, azul GoSmart #0B4FC4 (botones, selección, ruta en el mapa, cabecera de saldo); tinta #14161B; Figtree 400–800 con cifras tabulares, títulos en caja normal; botones en píldora, tarjetas y hojas redondeadas 16/24; sombras suaves teñidas; verde/ámbar/rojo solo para la vía con ícono y palabra; colores por modo solo en tramos y marcadores.

STORY: abre la app y ve el mapa donde está y una píldora con el estado de la Troncal; toca "¿A dónde vas?", elige destino como en Google Maps, compara opciones (mototaxi, colectivo...) con tiempo y precio como en Uber, ve los tramos y pide; paga desde una billetera tipo Nequi.

FIRST VIEWPORT: mapa a pantalla completa; arriba, píldora flotante con el estado de la Troncal; abajo, hoja blanca redondeada con el buscador "¿A dónde vas?" en píldora gris, accesos Casa/Trabajo en círculos, y una fila de servicios (Mototaxi, Taxi, Colectivo, Intermunicipal) como tarjetas pequeñas; barra de navegación Material 3 blanca con indicador azul.

FORM: salida estándar de la categoría (canon), elegida por el usuario sobre la dirección asignada (candidato 4, Salinas de Manaure); seed key 0df96f91. Movimiento: presión 0.97 en 120 ms ease-out, hojas 250/200 ms, cambio de pestaña sin animación, respeta "quitar animaciones".

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
