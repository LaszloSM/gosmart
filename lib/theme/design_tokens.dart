import 'package:flutter/material.dart';

// ─────────────────────────────────────────────────────────────────────────────
// GoSmart Design Tokens — rediseño 2026-10-15: familiar e intuitivo, al nivel
// de InDrive, Google Maps, Nequi y Uber/DiDi. Contrato:
// .impeccable/surfaces/lib-main-dart.md. Superficies blancas sobre gris frío,
// un solo azul de marca, Figtree, píldoras y radios suaves. Verde / ámbar /
// rojo existen SOLO para el estado de la vía, siempre con ícono y palabra.
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
    brand: Color(0xFF0B4FC4), // azul GoSmart; blanco encima 7.2:1
    brandPressed: Color(0xFF093F9D),
    onBrand: Color(0xFFFFFFFF),
    onBrandMuted: Color(0xFFD6E2FA), // texto secundario sobre la marca
    brandTint: Color(0xFFE8F0FE), // selección; la marca encima 6.3:1 (texto en negrita)
    shell: Color(0xFFFFFFFF), // barras blancas, como las apps de referencia
    onShell: Color(0xFF14161B),
    onShellMuted: Color(0xFF4A5162),
    stripe: Color(0xFF0B4FC4), // indicador de selección = la marca
    background: Color(0xFFF4F6FA), // gris frío claro
    surface: Color(0xFFFFFFFF),
    surfaceSunken: Color(0xFFEBEEF3), // campos de búsqueda y chips
    text: Color(0xFF14161B), // 16.7:1 sobre el fondo
    textMuted: Color(0xFF4A5162), // 7.3:1 sobre el fondo, 7.9:1 sobre blanco
    textDisabled: Color(0xFF9AA0AC),
    line: Color(0xFFDDE1E8),
    roadOpen: Color(0xFF0F5F30),
    roadCaution: Color(0xFF734600),
    roadCautionTint: Color(0xFFFFF1D6),
    roadClosed: Color(0xFF9C1E17),
    roadClosedTint: Color(0xFFFDE7E5),
    roadUnknown: Color(0xFF4A5162),
    taxi: Color(0xFF6941C6), // mototaxi / taxi en tramos y marcadores
    bike: Color(0xFF0E7490),
    cardGold: Color(0xFFFFC93C),
    shadowInk: Color(0xFF1A2440),
  );

  /// Noche: viajes nocturnos sin encandilar. Superficies que suben de
  /// luminosidad y marca aclarada. Todo texto principal ≥ 7:1.
  static const dark = GSPalette(
    brand: Color(0xFFA8C7FA), // 9.7:1 sobre la superficie nocturna
    brandPressed: Color(0xFFC2D7FB),
    onBrand: Color(0xFF0B1D3A), // 9.8:1 sobre la marca
    onBrandMuted: Color(0xFF1E3560),
    brandTint: Color(0xFF1F2E4D),
    shell: Color(0xFF1B1E25),
    onShell: Color(0xFFE6E8EE),
    onShellMuted: Color(0xFFA9AEBA),
    stripe: Color(0xFFA8C7FA),
    background: Color(0xFF111318),
    surface: Color(0xFF1B1E25),
    surfaceSunken: Color(0xFF262A33),
    text: Color(0xFFE6E8EE), // 15.2:1
    textMuted: Color(0xFFA9AEBA), // 7.5:1 sobre la superficie
    textDisabled: Color(0xFF6E7482),
    line: Color(0xFF2E333D),
    roadOpen: Color(0xFF73D69C),
    roadCaution: Color(0xFFF2B65A),
    roadCautionTint: Color(0xFF3A2A10),
    roadClosed: Color(0xFFFF8F85),
    roadClosedTint: Color(0xFF3F1916),
    roadUnknown: Color(0xFFA3ABBA),
    taxi: Color(0xFFC4B1F4),
    bike: Color(0xFF7DD3E8),
    cardGold: Color(0xFFFFD66B),
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

  // ── Marca y barras ─────────────────────────────────────────────────────
  /// Marca: botón primario, selección, ruta en el mapa, cabecera de saldo.
  static Color get brand => _p.brand;
  static Color get brandPressed => _p.brandPressed;

  /// Texto e íconos sobre [brand].
  static Color get onBrand => _p.onBrand;
  static Color get onBrandMuted => _p.onBrandMuted;

  /// Fondos seleccionados con [brand] encima.
  static Color get brandTint => _p.brandTint;

  /// Barras superior e inferior: blancas de día, superficie de noche.
  static Color get shell => _p.shell;
  static Color get onShell => _p.onShell;
  static Color get onShellMuted => _p.onShellMuted;

  /// Indicador de selección (pestaña activa, opción elegida). Es la marca.
  static Color get stripe => _p.stripe;

  // ── Neutros ───────────────────────────────────────────────
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

  // ── Tarjeta GoSmart: chip de la tarjeta y eco-puntos ───────────────────────
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
  /// Chips pequeños y etiquetas.
  static const double sm = 8;

  /// Campos, filas agrupadas y tarjetas pequeñas.
  static const double md = 12;

  /// Tarjetas.
  static const double lg = 16;

  /// Hojas inferiores (solo arriba) y la tarjeta de saldo.
  static const double xl = 24;
  static const double xxl = 28;

  /// Botones, buscador, chips de filtro y avatares: píldora.
  static const double full = 9999;

  static BorderRadius get cardRadius => BorderRadius.circular(lg);
  static BorderRadius get buttonRadius => BorderRadius.circular(full);
  static BorderRadius get chipRadius => BorderRadius.circular(full);
  static BorderRadius get sheetRadius =>
      const BorderRadius.vertical(top: Radius.circular(xl));
}

/// Profundidad = desplazamiento + desenfoque suave en tinta. Sin brillos.
abstract class GSShadow {
  // Sombras teñidas de azul tinta de día; negras de noche.
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

  /// Hoja inferior sobre el mapa.
  static List<BoxShadow> get sheet => [
        BoxShadow(
          color: _ink.withValues(alpha: 0.14),
          blurRadius: 24,
          offset: const Offset(0, -4),
        ),
      ];

  /// Controles flotantes sobre el mapa (buscador, píldora de la vía, ubicarme).
  static List<BoxShadow> get float => [
        BoxShadow(
          color: _ink.withValues(alpha: 0.16),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
        BoxShadow(
          color: _ink.withValues(alpha: 0.06),
          blurRadius: 2,
          offset: const Offset(0, 1),
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

  /// Cambio de título de una tarjeta (200 ms).
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
  static const double button = 52;
  static const double topBar = 56;

  /// Línea del corredor arriba del mapa.
  static const double corridorLine = 56;
}

/// Sin vidrio: superficies sólidas y legibles al sol.
abstract class GSGlass {
  static const double blur = 0;
  static const double backgroundOpacity = 1.0;
  static const double borderOpacity = 1.0;
  static const double borderWidth = 1.0;
}

/// Colores planos; se conservan los nombres para los usos existentes.
abstract class GSGradient {
  static List<Color> get accentPill => [GSColors.brand, GSColors.brand];
  static List<Color> get cardGloss => const [Colors.transparent, Colors.transparent];
  static List<Color> get avatarRing => [GSColors.brand, GSColors.brand];
  static List<Color> get primaryButton => [GSColors.brand, GSColors.brand];
  static List<Color> get smartCard => [GSColors.brand, GSColors.brand];
}

/// Figtree empaquetada en assets/fonts (OFL), sin red.
abstract class GSFonts {
  /// Todo el texto.
  static const sans = 'Figtree';

  /// Títulos: la misma familia en peso 700–800.
  static const display = 'Figtree';

  /// Números que el usuario compara (precios, km, horas): usar con [tabular].
  static const mono = 'Figtree';

  static const tabular = [FontFeature.tabularFigures()];
}
