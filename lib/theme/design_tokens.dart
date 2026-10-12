import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GoSmart Design Tokens — mundo "rótulo de colectivo" (rediseño 2026-10).
// Contrato: .impeccable/surfaces/lib-main-dart.md. Shell en ultramar de
// carrocería, placas blancas con letras condensadas, franja fucsia solo en lo
// seleccionado. Rojo / ámbar / verde existen SOLO para el estado de la vía.
// ─────────────────────────────────────────────────────────────────────────────

/// Paleta de un esquema (día o noche). Los valores salen de DESIGN.md; el
/// esquema nocturno es propio, no una inversión: las superficies suben de
/// luminosidad y la marca se aclara para leerse sobre ellas.
class GSPalette {
  const GSPalette({
    required this.brand,
    required this.brandPressed,
    required this.onBrand,
    required this.onBrandMuted,
    required this.brandTint,
    required this.shell,
    required this.onShell,
    required this.onShellMuted,
    required this.stripe,
    required this.background,
    required this.surface,
    required this.surfaceSunken,
    required this.text,
    required this.textMuted,
    required this.textDisabled,
    required this.line,
    required this.roadOpen,
    required this.roadCaution,
    required this.roadCautionTint,
    required this.roadClosed,
    required this.roadClosedTint,
    required this.roadUnknown,
    required this.taxi,
    required this.bike,
    required this.cardGold,
    required this.shadowInk,
  });

  final Color brand, brandPressed, onBrand, onBrandMuted, brandTint;
  final Color shell, onShell, onShellMuted, stripe;
  final Color background, surface, surfaceSunken;
  final Color text, textMuted, textDisabled, line;
  final Color roadOpen, roadCaution, roadCautionTint;
  final Color roadClosed, roadClosedTint, roadUnknown;
  final Color taxi, bike, cardGold, shadowInk;

  /// Día: claro primero, legible al sol.
  static const light = GSPalette(
    brand: Color(0xFF1B3A8C), // ultramar de carrocería; blanco encima 10.3:1
    brandPressed: Color(0xFF142C6B),
    onBrand: Color(0xFFFFFFFF),
    onBrandMuted: Color(0xFFCCD7F2), // 7:1 sobre ultramar
    brandTint: Color(0xFFE3E9F6), // ultramar encima 8.5:1
    shell: Color(0xFF1B3A8C),
    onShell: Color(0xFFFFFFFF),
    onShellMuted: Color(0xFFCCD7F2),
    stripe: Color(0xFFC2185B),
    background: Color(0xFFEEF1F5), // lámina
    surface: Color(0xFFFFFFFF), // placa
    surfaceSunken: Color(0xFFE2E7EE),
    text: Color(0xFF111827), // 15.7:1 sobre lámina
    textMuted: Color(0xFF465066), // 7.1:1 sobre lámina
    textDisabled: Color(0xFF8A93A6),
    line: Color(0xFFC9D0DC),
    roadOpen: Color(0xFF17602F),
    roadCaution: Color(0xFF6A3F00),
    roadCautionTint: Color(0xFFFBE7C2),
    roadClosed: Color(0xFF9E1F18),
    roadClosedTint: Color(0xFFF6DAD6),
    roadUnknown: Color(0xFF50576A),
    taxi: Color(0xFF7A4E2D),
    bike: Color(0xFF3D6B8C),
    cardGold: Color(0xFFB08A3E),
    shadowInk: Color(0xFF0E1A3A),
  );

  /// Noche: viajes nocturnos sin encandilar. Carrocería en ultramar profundo;
  /// marca clara para leerse sobre las placas oscuras. Todo texto ≥ 7:1.
  static const dark = GSPalette(
    brand: Color(0xFF9DB2F2), // 8:1 sobre la placa nocturna
    brandPressed: Color(0xFFB7C7F6),
    onBrand: Color(0xFF0E1320), // 8.9:1 sobre la marca
    onBrandMuted: Color(0xFF26345F),
    brandTint: Color(0xFF22305A),
    shell: Color(0xFF14295F),
    onShell: Color(0xFFFFFFFF), // 13.9:1
    onShellMuted: Color(0xFFC3CEEA), // 8.8:1
    stripe: Color(0xFFFF6FA3),
    background: Color(0xFF0E1320),
    surface: Color(0xFF171E2D),
    surfaceSunken: Color(0xFF0A0E17),
    text: Color(0xFFEEF1F5), // 14.7:1 sobre la placa
    textMuted: Color(0xFFAEB7CA), // 8.3:1
    textDisabled: Color(0xFF6E778B),
    line: Color(0xFF2C3649),
    roadOpen: Color(0xFF73D69C),
    roadCaution: Color(0xFFF2B65A),
    roadCautionTint: Color(0xFF3A2A10),
    roadClosed: Color(0xFFFF8F85),
    roadClosedTint: Color(0xFF3F1916),
    roadUnknown: Color(0xFFA3ABBA),
    taxi: Color(0xFFD2A27C),
    bike: Color(0xFF8FB6D6),
    cardGold: Color(0xFFD4B06A),
    shadowInk: Color(0xFF000000),
  );
}

abstract class GSColors {
  static GSPalette _p = GSPalette.light;

  /// Esquema activo. Lo fija la app según el brillo del tema (main.dart).
  static GSPalette get palette => _p;
  static bool get isDark => identical(_p, GSPalette.dark);
  static void apply(Brightness b) =>
      _p = b == Brightness.dark ? GSPalette.dark : GSPalette.light;

  // ── Marca y carrocería ─────────────────────────────────────────────────────
  /// Marca: botón primario, letras de las placas, selección.
  static Color get brand => _p.brand;
  static Color get brandPressed => _p.brandPressed;

  /// Texto e íconos sobre [brand].
  static Color get onBrand => _p.onBrand;
  static Color get onBrandMuted => _p.onBrandMuted;

  /// Fondos seleccionados con [brand] encima.
  static Color get brandTint => _p.brandTint;

  /// Carrocería: barra superior, barra inferior, cabeceras. De día es la
  /// misma marca; de noche un ultramar profundo.
  static Color get shell => _p.shell;
  static Color get onShell => _p.onShell;
  static Color get onShellMuted => _p.onShellMuted;

  /// Franja fucsia: marca lo seleccionado y la placa activa. Nunca relleno.
  static Color get stripe => _p.stripe;

  // ── Neutros (lámina y placa) ───────────────────────────────────────────────
  static Color get background => _p.background;
  static Color get surface => _p.surface;
  static Color get surfaceSunken => _p.surfaceSunken;
  static Color get text => _p.text;
  static Color get textMuted => _p.textMuted;

  /// Texto deshabilitado (exento del mínimo de contraste).
  static Color get textDisabled => _p.textDisabled;

  /// Solo divisores y bordes de placa; nunca texto encima.
  static Color get line => _p.line;

  // ── Estado de la vía (siempre con ícono + texto) ───────────────────────────
  static Color get roadOpen => _p.roadOpen;
  static Color get roadCaution => _p.roadCaution;
  static Color get roadCautionTint => _p.roadCautionTint;
  static Color get roadClosed => _p.roadClosed;
  static Color get roadClosedTint => _p.roadClosedTint;
  static Color get roadUnknown => _p.roadUnknown;

  // ── Nombres anteriores (alias). Código nuevo: usar los de arriba. ──────────
  static Color get primary => background;
  static Color get bg => background;
  static Color get surfaceContainerLow => surfaceSunken;
  static Color get surfaceDark => surfaceSunken;
  static Color get surfaceContainerHigh => surface;
  static Color get surfaceContainerHighest => surface;
  static Color get surfaceBright => surfaceSunken;
  static Color get accent => brand;
  static Color get accentHover => brandPressed;
  static Color get accentContainer => brand;
  static Color get accentLight => brandTint;
  static Color get accentAlt => brand;
  static Color get accentAltLight => brandTint;
  static Color get tertiary => brand;
  static Color get tertiaryLight => brandTint;
  static Color get eco => brand;
  static Color get ecoLight => brandTint;
  static Color get ecoDark => brandPressed;
  static Color get border => line;
  static Color get textPrimary => text;
  static Color get textSecondary => textMuted;
  static Color get success => brand;
  static Color get successLight => brandTint;
  static Color get warning => roadCaution;
  static Color get warningLight => roadCautionTint;
  static Color get error => roadClosed;
  static Color get errorLight => roadClosedTint;
  static Color get info => brand;
  static Color get infoLight => brandTint;

  // ── Modos de transporte (distintos del rojo/ámbar/verde de la vía) ─────────
  static Color get bus => brand; // TransPadilla, colectivo, intermunicipal
  static Color get taxi => _p.taxi; // mototaxi / taxi
  static Color get car => text;
  static Color get walk => textMuted;
  static Color get bike => _p.bike;
  static Color get metro => _p.bike;

  // ── Tarjeta GoSmart ────────────────────────────────────────────────────────
  static Color get cardGold => _p.cardGold;
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
  // Sombras teñidas del ultramar de día; negras de noche.
  static Color get _ink => GSColors.palette.shadowInk;

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
  static List<Color> get accentPill => [GSColors.brand, GSColors.brand];
  static List<Color> get cardGloss => const [Colors.transparent, Colors.transparent];
  static List<Color> get avatarRing => [GSColors.brand, GSColors.brand];
  static List<Color> get primaryButton => [GSColors.brand, GSColors.brand];
  static List<Color> get smartCard => [GSColors.brand, GSColors.brand];
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
