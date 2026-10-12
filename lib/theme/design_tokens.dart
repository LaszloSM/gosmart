import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GoSmart Design Tokens — mundo "rótulo de colectivo" (rediseño 2026-10).
// Contrato: .impeccable/surfaces/lib-main-dart.md. Shell en ultramar de
// carrocería, placas blancas con letras condensadas, franja fucsia solo en lo
// seleccionado. Rojo / ámbar / verde existen SOLO para el estado de la vía.
// ─────────────────────────────────────────────────────────────────────────────

abstract class GSColors {
  // ── Marca y shell ──────────────────────────────────────────────────────────
  /// Ultramar de carrocería: barras, botón primario, letras de las placas.
  /// Blanco encima 10.3:1.
  static const brand = Color(0xFF1B3A8C);
  static const brandPressed = Color(0xFF142C6B);

  /// Texto e íconos sobre [brand].
  static const onBrand = Color(0xFFFFFFFF);

  /// Texto secundario sobre [brand] (7:1).
  static const onBrandMuted = Color(0xFFCCD7F2);

  /// Tinte de ultramar para fondos seleccionados (ultramar encima 8.5:1).
  static const brandTint = Color(0xFFE3E9F6);

  /// Franja fucsia: marca lo seleccionado y la placa activa. Nunca relleno.
  static const stripe = Color(0xFFC2185B);

  // ── Neutros fríos (lámina y placa) ─────────────────────────────────────────
  /// Lámina: fondo de pantalla.
  static const background = Color(0xFFEEF1F5);

  /// Placa: hojas, superficies, campos.
  static const surface = Color(0xFFFFFFFF);

  /// Lámina un tono más oscura: agrupar, chips sin seleccionar.
  static const surfaceSunken = Color(0xFFE2E7EE);

  /// Tinta: texto principal (15.7:1 sobre lámina).
  static const text = Color(0xFF111827);

  /// Tinta suave: texto secundario (7.1:1 sobre lámina).
  static const textMuted = Color(0xFF465066);

  /// Solo divisores y bordes de placa; nunca texto encima.
  static const line = Color(0xFFC9D0DC);

  // ── Estado de la vía (siempre con ícono + texto) ───────────────────────────
  static const roadOpen = Color(0xFF17602F);
  static const roadCaution = Color(0xFF6A3F00);
  static const roadCautionTint = Color(0xFFFBE7C2);
  static const roadClosed = Color(0xFF9E1F18);
  static const roadClosedTint = Color(0xFFF6DAD6);
  static const roadUnknown = Color(0xFF545B69);

  // ── Nombres anteriores (alias). Código nuevo: usar los de arriba. ──────────
  /// Antes "fondo más oscuro"; ahora el fondo arena.
  static const primary = background;
  static const bg = background;
  static const surfaceContainerLow = surfaceSunken;
  static const surfaceDark = surfaceSunken;
  static const surfaceContainerHigh = surface;
  static const surfaceContainerHighest = surface;
  static const surfaceBright = surfaceSunken;

  static const accent = brand;
  static const accentHover = brandPressed;
  static const accentContainer = brand;
  static const accentLight = brandTint;
  static const accentAlt = brand;
  static const accentAltLight = brandTint;
  static const tertiary = brand;
  static const tertiaryLight = brandTint;

  /// Los eco-puntos no usan verde: el verde es de la vía.
  static const eco = brand;
  static const ecoLight = brandTint;
  static const ecoDark = brandPressed;

  static const border = line;
  static const textPrimary = text;
  static const textSecondary = textMuted;

  /// Texto deshabilitado (exento del mínimo de contraste).
  static const textDisabled = Color(0xFF8A93A6);

  // Semánticos de formulario / avisos. El éxito usa la marca, no el verde.
  static const success = brand;
  static const successLight = brandTint;
  static const warning = roadCaution;
  static const warningLight = roadCautionTint;
  static const error = roadClosed;
  static const errorLight = roadClosedTint;
  static const info = brand;
  static const infoLight = brandTint;

  // ── Modos de transporte (distintos del rojo/ámbar/verde de la vía) ─────────
  static const bus = brand; // TransPadilla, colectivo, intermunicipal
  static const taxi = Color(0xFF7A4E2D); // mototaxi / taxi
  static const car = text;
  static const walk = textMuted;
  static const bike = Color(0xFF3D6B8C);
  static const metro = Color(0xFF3D6B8C);

  // ── Tarjeta GoSmart ────────────────────────────────────────────────────────
  static const cardGold = Color(0xFFB08A3E);
}

abstract class GSSpacing {
  static const double s1 = 4;
  static const double s2 = 8;
  static const double s3 = 12;
  static const double s4 = 16;
  static const double s5 = 20;
  static const double s6 = 24;
  static const double s8 = 32;
  static const double s10 = 40;
  static const double s12 = 48;
  static const double s16 = 64;
}

abstract class GSRadius {
  /// Chips y placas pequeñas.
  static const double sm = 4;

  /// Botones, campos y placas.
  static const double md = 8;

  /// Hojas y la solicitud del conductor.
  static const double lg = 12;

  // Alias anteriores: el sistema no pasa de 12.
  static const double xl = lg;
  static const double xxl = lg;

  /// Solo filtros de modo de transporte.
  static const double full = 9999;

  static BorderRadius get cardRadius => BorderRadius.circular(lg);
  static BorderRadius get buttonRadius => BorderRadius.circular(md);
  static BorderRadius get chipRadius => BorderRadius.circular(full);
  static BorderRadius get sheetRadius =>
      const BorderRadius.vertical(top: Radius.circular(lg));
}

/// Profundidad = desplazamiento + desenfoque suave en tinta. Sin brillos.
abstract class GSShadow {
  // Sombras teñidas del ultramar, no negro puro.
  static const _ink = Color(0xFF0E1A3A);

  static List<BoxShadow> get sm => [
        BoxShadow(
          color: _ink.withValues(alpha: 0.08),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ];

  static List<BoxShadow> get md => [
        BoxShadow(
          color: _ink.withValues(alpha: 0.10),
          blurRadius: 10,
          offset: const Offset(0, 2),
        ),
      ];

  static List<BoxShadow> get lg => [
        BoxShadow(
          color: _ink.withValues(alpha: 0.12),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];

  /// Hoja inferior sobre el mapa (DESIGN.md: 0 -2, blur 12, tinta 12%).
  static List<BoxShadow> get sheet => [
        BoxShadow(
          color: _ink.withValues(alpha: 0.12),
          blurRadius: 12,
          offset: const Offset(0, -2),
        ),
      ];

  static List<BoxShadow> get card => sm;

  // Alias anteriores (antes eran brillos de color; ahora sombras neutras).
  static List<BoxShadow> get accent => sm;
  static List<BoxShadow> get primary => sm;
  static List<BoxShadow> get eco => sm;
  static List<BoxShadow> get neumorphic => sm;
}

abstract class GSDuration {
  /// Presión de botón (DESIGN.md: 100–150 ms).
  static const press = Duration(milliseconds: 120);
  static const fast = Duration(milliseconds: 150);
  static const normal = Duration(milliseconds: 250);
  static const page = Duration(milliseconds: 250);

  /// Cambio de rótulo de una placa (contrato: 200 ms).
  static const plate = Duration(milliseconds: 200);

  /// Hojas: entrada 250 ms, salida 200 ms.
  static const sheetIn = Duration(milliseconds: 250);
  static const sheetOut = Duration(milliseconds: 200);
}

abstract class GSCurve {
  /// Entrada: ease-out fuerte, cubic-bezier(0.23, 1, 0.32, 1).
  static const enter = Cubic(0.23, 1, 0.32, 1);
  /// Salida: la misma curva invertida. Úsala solo como reverseCurve o
  /// switchOutCurve; un movimiento hacia adelante usa [enter].
  static const exit = FlippedCurve(enter);
  static const move = Curves.easeInOut;
}

abstract class GSSize {
  /// Pasajero (DESIGN.md `spacing.touch`).
  static const double touchTarget = 48;

  /// Modo conductor de una mano (DESIGN.md `spacing.touch-driver`).
  static const double touchTargetDriver = 72;
  static const double iconSm = 16;
  static const double iconMd = 20;
  static const double iconLg = 24;
  static const double iconXl = 32;
  static const double avatarSm = 32;
  static const double avatarMd = 44;
  static const double avatarLg = 64;
  static const double bottomNav = 72;
  static const double topBar = 56;

  /// Línea del corredor arriba del mapa.
  static const double corridorLine = 56;
}

/// Superficies translúcidas: DESIGN.md no usa vidrio esmerilado; la opacidad
/// queda en 1 para que las superficies sean sólidas y legibles al sol.
abstract class GSGlass {
  static const double blur = 0;
  static const double backgroundOpacity = 1.0;
  static const double borderOpacity = 1.0;
  static const double borderWidth = 1.0;
}

/// DESIGN.md: sin degradados. Se conservan los nombres con un color plano
/// (dos paradas iguales) para no romper los usos existentes.
abstract class GSGradient {
  static List<Color> get accentPill => const [GSColors.brand, GSColors.brand];
  static List<Color> get cardGloss => const [Colors.transparent, Colors.transparent];
  static List<Color> get avatarRing => const [GSColors.brand, GSColors.brand];
  static List<Color> get primaryButton => const [GSColors.brand, GSColors.brand];
  static List<Color> get smartCard => const [GSColors.brand, GSColors.brand];
}

/// Familias tipográficas empaquetadas en assets/fonts (OFL), sin red.
abstract class GSFonts {
  /// Cuerpo, etiquetas y controles.
  static const sans = 'Barlow';

  /// Placas de ruta y títulos: letra condensada de rótulo.
  static const display = 'BarlowCondensed';

  /// Números que el usuario compara (precios, km, horas). Barlow con cifras
  /// tabulares: usar siempre junto a [tabular].
  static const mono = 'Barlow';

  static const tabular = [FontFeature.tabularFigures()];
}
