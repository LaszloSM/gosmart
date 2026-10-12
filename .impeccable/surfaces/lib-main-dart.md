---
version: 1
slug: "lib-main-dart"
primary_target: "lib/main.dart"
related_targets: ["lib/features"]
---

# Surface brief: app de pasajero (shell + todas las pantallas)

Scope: toda la app Android (inicio, planificador, billetera, perfil, asistente, login). Visitor mode: Operate.
Audience: viajero del corredor, usuario urbano de mototaxi/TransPadilla, conductor (ver PRODUCT.md).
Task: saber cómo está la vía, decidir cómo llegar, pagar, gestionar su cuenta; con una mano, al sol.
Constraints: controles nativos Material 3; 48 dp (72 en conductor); contraste 7:1 en texto principal; fuentes empaquetadas; rojo/ámbar/verde solo para el estado de la vía.
Build path: code-led (Operate). Roll degradado (sin challengers; impeccable.style inalcanzable desde el contenedor).

## Direction contract

THESIS: GoSmart se lee como los rótulos de ruta pintados en el parabrisas de los colectivos y busetas de la costa: cada destino, tramo y viaje es una placa de ruta que se entiende a cinco metros. Rechaza el mapa blanco con hoja negra y un acento (Uber/Moovit) y el arena-con-un-azul del diseño anterior.

OWN-WORLD: shell en azul ultramar de carrocería (barra superior, barra inferior, botón primario); fondo blanco frío de lámina; placas blancas con borde fino y letras condensadas gruesas en ultramar (Barlow Condensed 700/800); cuerpo en Barlow 400–600 con cifras tabulares; una franja fucsia de 4 dp debajo de lo seleccionado y en la placa activa, nunca como relleno; estados de la vía en verde/ámbar/rojo con ícono y palabra. Radios 4/8/12; sin degradados, sin vidrio, sin tarjetas por defecto.

STORY: el usuario ve el estado de la Troncal, escribe su destino en una placa en blanco y la ve "pintada"; entiende tramos, precio y hora como placas encadenadas; paga y cierra con un recibo.

FIRST VIEWPORT: barra ultramar con la Línea del corredor sobre una placa blanca; mapa; hoja blanca con la placa "¿A DÓNDE VAS?" a todo el ancho (56 dp, letras condensadas 22 sp), Casa/Trabajo como placas pequeñas; barra inferior ultramar. En perfil: la placa con el nombre del usuario como rótulo de parabrisas, debajo filas planas.

FORM: candidato 3 de 7 (rótulo de colectivo) de la lista ordenada; seed key f3f70ca1. Gesto distintivo: GSRoutePlate. Movimiento: presión 0.97 en 120 ms ease-out; cambio de texto de placa con fundido + desplazamiento de 8 dp en 200 ms (cubic 0.23,1,0.32,1); nada animado al cambiar de pestaña; respeta "quitar animaciones".

FINISH: unreviewed and undocumented is unfinished; this build ends with the finish review, the verdict, DESIGN.md, and every shipping raster carrying its provenance
