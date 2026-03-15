# GoSmart UI Quick Wins — Design Spec
**Date:** 2026-03-14
**Style direction:** Glassmorphism sutil (Linear/Raycast aplicado a fintech móvil)
**Scope:** 6 mejoras visuales de alto impacto, sin cambios de arquitectura ni lógica de negocio
**Deliverable:** `design/quickwins/` con assets + `design-tokens.json` actualizado + Flutter widget stubs

---

## Context

La app GoSmart existe y funciona. Las pantallas (wallet, history, profile, home) usan un sistema de design tokens establecido (`GSColors`, `GSSpacing`, `GSRadius`, `GSShadow`, `GSDuration`) con fondo claro `#F5F6FA`, acento teal `#00D4AA`, y acento violet `#6C63FF`. El problema es que la UI se siente funcional pero no premium: la bottom nav es plana y opaca, la wallet card carece de profundidad física, las quick actions son tiles genéricos, los skeletons no coinciden en shape con el contenido, el header de home usa un avatar placeholder, y el estado de pago exitoso es estático.

El polish no requiere rediseño — requiere capa de refinamiento sobre lo existente.

---

## Design Tokens a agregar / modificar

Archivo: `lib/theme/design_tokens.dart`
Archivo espejo: `design/quickwins/design-tokens.json`

### Nuevas clases de tokens (añadir al final de `design_tokens.dart`)

```dart
abstract class GSGlass {
  static const double blur = 20;
  static const double backgroundOpacity = 0.72;
  static const double borderOpacity = 0.18;
  static const double borderWidth = 1.0;
}

abstract class GSGradient {
  // Colores base vienen de GSColors — no duplicar valores
  static List<Color> get accentPill => [GSColors.accent, GSColors.accentAlt];
  static List<Color> get cardGloss =>
      [Colors.white.withOpacity(0.08), Colors.transparent];
  static List<Color> get avatarRing => [GSColors.accent, GSColors.accentAlt];
}

abstract class GSAnimDuration {
  static const countUp = Duration(milliseconds: 800);
  static const checkmarkStroke = Duration(milliseconds: 600);
  static const particleBurst = Duration(milliseconds: 700);
  static const skeletonStagger = 80; // ms por ítem (int, no Duration)
  static const pillSlide = Duration(milliseconds: 200);
}
```

### Nueva entrada de color (añadir a `GSColors`)

```dart
// En GSColors, junto a los otros colores:
static const Color cardGold = Color(0xFFC9A84C); // chip de la wallet card
```

### Design Tokens JSON espejo

```json
{
  "glass": {
    "blur": 20,
    "backgroundOpacity": 0.72,
    "borderOpacity": 0.18,
    "borderWidth": 1.0
  },
  "gradient": {
    "accentPill": ["#00D4AA", "#6C63FF"],
    "cardGloss": ["rgba(255,255,255,0.08)", "rgba(255,255,255,0.00)"],
    "avatarRing": ["#00D4AA", "#6C63FF"]
  },
  "colors": {
    "cardGold": "#C9A84C"
  },
  "animDuration": {
    "countUp": 800,
    "checkmarkStroke": 600,
    "particleBurst": 700,
    "skeletonStaggerPerItem": 80,
    "pillSlide": 200
  },
  "shadow": {
    "glassNav": "0 -4px 24px rgba(0,212,170,0.08)",
    "cardGlow": "0 8px 32px rgba(108,99,255,0.24)"
  }
}
```

---

## QW-1 · Bottom Nav — Glass flotante con labels persistentes

### Problema
- `Container` opaco con `color: GSColors.surface` — sin blur, sin profundidad
- Labels solo visibles en tab activo; inactivos muestran solo ícono
- Pill activo: `GSColors.accentLight` sólido, color plano

### Solución
- `ClipRRect` + `BackdropFilter(filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20))`
- Background: `GSColors.surface.withOpacity(GSGlass.backgroundOpacity)`
- Borde superior: `Border(top: BorderSide(color: Colors.white.withOpacity(GSGlass.borderOpacity), width: GSGlass.borderWidth))`
- Todos los tabs muestran label: activo 11sp medium white, inactivo 9sp regular `textDisabled`
- Pill activo: `LinearGradient(GSGradient.accentPill)` con `borderRadius: BorderRadius.circular(20)`
- Transición del pill: `AnimatedContainer` 200ms curve `easeInOut`

### Prerequisito en Scaffolds consumidores
`BackdropFilter` solo produce blur visible si el `Scaffold` tiene `extendBody: true`.
`home_screen.dart` ya lo tiene (línea 170). **Verificar y añadir `extendBody: true` en:**
- `lib/features/wallet/wallet_screen.dart`
- `lib/features/history/history_screen.dart`
- `lib/features/profile/profile_screen.dart`

### Archivo a modificar
`lib/widgets/gs_bottom_nav.dart`

### Widget stub

```dart
import 'dart:ui'; // ImageFilter

// Reemplazar el Container exterior del nav por:
ClipRRect(
  child: BackdropFilter(
    filter: ImageFilter.blur(
      sigmaX: GSGlass.blur,
      sigmaY: GSGlass.blur,
    ),
    child: Container(
      decoration: BoxDecoration(
        color: GSColors.surface.withOpacity(GSGlass.backgroundOpacity),
        border: Border(
          top: BorderSide(
            color: Colors.white.withOpacity(GSGlass.borderOpacity),
            width: GSGlass.borderWidth,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: List.generate(items.length, (i) => _buildItem(i)),
        ),
      ),
    ),
  ),
)

// _buildItem — pill activo con gradiente:
Widget _buildItem(int index) {
  final isActive = index == currentIndex;
  return Expanded(
    child: GestureDetector(
      onTap: () => onTap(index),
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: GSAnimDuration.pillSlide,
        curve: Curves.easeInOut,
        margin: const EdgeInsets.symmetric(
          horizontal: GSSpacing.s2,
          vertical: GSSpacing.s2,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: isActive ? GSSpacing.s3 : 0,
          vertical: GSSpacing.s2,
        ),
        decoration: isActive
            ? BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: LinearGradient(colors: GSGradient.accentPill),
              )
            : null,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              items[index].icon,
              size: GSSize.iconLg,
              color: isActive ? Colors.white : GSColors.textDisabled,
            ),
            const SizedBox(height: 2),
            Text(
              items[index].label,
              style: TextStyle(
                fontSize: isActive ? 11 : 9,
                fontWeight:
                    isActive ? FontWeight.w500 : FontWeight.w400,
                color: isActive ? Colors.white : GSColors.textDisabled,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
```

---

## QW-2 · Wallet Card — Profundidad premium + balance animado

### Problema
- Gradiente plano sin capa de gloss
- Balance en ~24sp — pequeño para elemento principal de la pantalla
- Sin chip visual, sin outer glow
- Sin animación al cargar el balance

### Solución
1. **Remover el `boxShadow` existente** de la `BoxDecoration` interna del card en `_buildCardSection` (actualmente en las líneas con `GSShadow.card`) — reemplazarlo con el nuevo outer glow wrapper.
2. **Stack con 3 capas:** gradiente base (existente) → gloss overlay → contenido
3. **Gloss:** `LinearGradient` diagonal `GSGradient.cardGloss` en 45°
4. **Chip:** `Container` 38×28px con `GSRadius.sm`, borde `GSColors.cardGold` 1px, gradiente interior (dorado claro)
5. **Balance:** 32sp `w700`, `TweenAnimationBuilder<double>` desde 0 al valor real en `GSAnimDuration.countUp`
6. **Outer glow:** `boxShadow: [BoxShadow(color: GSColors.accentAlt.withOpacity(0.24), blurRadius: 32, offset: Offset(0, 8))]`

### Archivo a modificar
`lib/features/wallet/wallet_screen.dart`

### Widget stub

```dart
// 1. Wrapper de la tarjeta con outer glow (REEMPLAZA el shadow existente):
Container(
  margin: const EdgeInsets.all(GSSpacing.s4),
  decoration: BoxDecoration(
    borderRadius: BorderRadius.circular(GSRadius.xl),
    boxShadow: [
      BoxShadow(
        color: GSColors.accentAlt.withOpacity(0.24),
        blurRadius: 32,
        offset: const Offset(0, 8),
      ),
    ],
  ),
  child: ClipRRect(
    borderRadius: BorderRadius.circular(GSRadius.xl),
    child: Stack(
      children: [
        // Capa 1: gradiente base existente (sin cambios)
        _buildCardBase(),
        // Capa 2: gloss overlay
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: GSGradient.cardGloss,
                stops: const [0.0, 0.6],
              ),
            ),
          ),
        ),
        // Capa 3: chip + contenido
        Padding(
          padding: const EdgeInsets.all(GSSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _ChipWidget(),
                  const Text(
                    'GoSmart',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: GSSpacing.s6),
              // ... número enmascarado existente ...
              const SizedBox(height: GSSpacing.s4),
              Text(
                'Saldo disponible',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: GSSpacing.s1),
              _AnimatedBalance(amount: balance),
            ],
          ),
        ),
      ],
    ),
  ),
)

// _ChipWidget — chip de tarjeta:
class _ChipWidget extends StatelessWidget {
  const _ChipWidget();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 28,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(GSRadius.sm),
        border: Border.all(color: GSColors.cardGold, width: 1),
        gradient: LinearGradient(
          colors: [
            GSColors.cardGold.withOpacity(0.6),
            GSColors.cardGold.withOpacity(0.2),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
    );
  }
}

// _AnimatedBalance — count-up animation:
class _AnimatedBalance extends StatelessWidget {
  final double amount;
  const _AnimatedBalance({required this.amount});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: amount),
      duration: GSAnimDuration.countUp,
      curve: Curves.easeOut,
      builder: (_, value, __) => Text(
        '\$${value.toStringAsFixed(0)} COP',
        style: const TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          letterSpacing: -0.5,
        ),
      ),
    );
  }
}
```

---

## QW-3 · Quick Actions — Action rail unificado

### Problema
- Tres `Card` separadas en `Row` — sin relación visual entre sí
- Sin press feedback cohesivo

### Solución
- Una sola `GSCard` que contiene `IntrinsicHeight` + `Row` con `VerticalDivider` intercalado
- Cada acción: `InkWell` con `splashColor: accent.12` + icono circular 40px + label
- Divider: `VerticalDivider(width: 1, thickness: 1, color: GSColors.border)`
- El interleaving de dividers se hace con `List.generate` (índice par = acción, impar = divider)

### Archivo a modificar
`lib/features/wallet/wallet_screen.dart`

### Widget stub

```dart
GSCard(
  padding: EdgeInsets.zero,
  child: IntrinsicHeight(
    child: Row(
      // Intercalar dividers con List.generate (sin extensiones no nativas):
      children: List.generate(
        _actions.length * 2 - 1,
        (i) {
          if (i.isOdd) {
            return const VerticalDivider(
              width: 1,
              thickness: 1,
              indent: 12,
              endIndent: 12,
            );
          }
          final action = _actions[i ~/ 2];
          return Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: action.onTap,
                splashColor: GSColors.accent.withOpacity(0.12),
                borderRadius: BorderRadius.circular(GSRadius.md),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: GSSpacing.s4,
                    horizontal: GSSpacing.s2,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: action.color.withOpacity(0.12),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          action.icon,
                          color: action.color,
                          size: GSSize.iconLg,
                        ),
                      ),
                      const SizedBox(height: GSSpacing.s1),
                      Text(
                        action.label,
                        style: const TextStyle(
                          fontSize: 12,
                          color: GSColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    ),
  ),
)
```

---

## QW-4 · Home Header — Avatar ring + greeting dinámico

### Problema
- Avatar: `CircleAvatar` con ícono `person` placeholder, sin foto ni iniciales
- Greeting: función `_greeting()` **ya existe** en `home_screen.dart` pero usa cutoffs `< 12` / `< 18`
- Sin ring de gradiente

### Solución
- **Actualizar `_greeting()` existente** (no crear duplicado): cambiar `< 18` → `< 19`, añadir `>= 6` como límite inferior de "días"
- Avatar ring: `Container` circular con `gradient: LinearGradient(GSGradient.avatarRing)` → inner `CircleAvatar` con 2.5px inset
- Initials fallback: primeras letras de nombre + apellido en `GSColors.accentAlt` sobre `GSColors.accentLight`
- Jerarquía: greeting 13sp `textSecondary`, nombre 18sp `w600 textPrimary`

### Archivo a modificar
`lib/features/home/home_screen.dart`

### Widget stub

```dart
// 1. Reemplazar _greeting() existente (misma firma, lógica actualizada):
String _greeting() {
  final hour = DateTime.now().hour;
  if (hour >= 6 && hour < 12) return 'Buenos días';
  if (hour >= 12 && hour < 19) return 'Buenas tardes';
  return 'Buenas noches';
}
// Nota: cutoff "tardes" cambia de 18 → 19 (intencional).
// "días" ahora requiere hour >= 6 (antes era solo < 12).

// 2. Avatar con ring de gradiente:
Container(
  padding: const EdgeInsets.all(2.5),
  decoration: BoxDecoration(
    shape: BoxShape.circle,
    gradient: LinearGradient(
      colors: GSGradient.avatarRing,
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    ),
  ),
  child: CircleAvatar(
    radius: (GSSize.avatarMd / 2) - 2.5,
    backgroundColor: GSColors.accentLight,
    backgroundImage:
        photoUrl != null ? NetworkImage(photoUrl!) : null,
    child: photoUrl == null
        ? Text(
            _initials(name),
            style: const TextStyle(
              color: GSColors.accentAlt,
              fontWeight: FontWeight.w600,
              fontSize: 16,
            ),
          )
        : null,
  ),
)

// 3. Helper para iniciales:
String _initials(String? fullName) {
  if (fullName == null || fullName.isEmpty) return '?';
  final parts = fullName.trim().split(' ');
  if (parts.length == 1) return parts[0][0].toUpperCase();
  return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
}
```

---

## QW-5 · Skeleton Loaders — Shimmer staggered por ítem

### Problema
- `GSCardSkeleton` ya existe en `gs_skeleton_loader.dart` — se reutiliza, no se duplica
- `GSCardSkeleton` usa height del parámetro; la wallet card real mide **200px** — usar `GSCardSkeleton(height: 200)` en wallet
- Sin escalonado en listas — todos los skeletons animan en sincronía
- `GSTransactionSkeleton` existe pero no se usa en todas las pantallas que lo necesitan

### Solución
- **No crear `WalletCardSkeleton`** — usar `GSCardSkeleton(height: 200)` directamente
- Añadir `StaggeredSkeletonList` como nuevo widget en `gs_skeleton_loader.dart`
- Stagger: `AnimationController` con `Interval` por ítem `(i * staggerMs) / totalMs`
- Usar `TickerProviderStateMixin` (no `SingleTickerProviderStateMixin`) si la pantalla ya tiene otro controller

### Archivo a modificar
`lib/widgets/gs_skeleton_loader.dart`

### Widget stub

```dart
/// Lista de skeletons con aparición escalonada.
/// Usar en lugar de Column([GSTransactionSkeleton(), ...]) para mejor UX.
class StaggeredSkeletonList extends StatefulWidget {
  final int itemCount;
  final Widget Function(int index) itemBuilder;

  const StaggeredSkeletonList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
  });

  @override
  State<StaggeredSkeletonList> createState() => _StaggeredSkeletonListState();
}

class _StaggeredSkeletonListState extends State<StaggeredSkeletonList>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    final totalMs =
        400 + widget.itemCount * GSAnimDuration.skeletonStagger;
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: totalMs),
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalMs =
        400 + widget.itemCount * GSAnimDuration.skeletonStagger;
    return Column(
      children: List.generate(widget.itemCount, (i) {
        final startFraction =
            (i * GSAnimDuration.skeletonStagger) / totalMs;
        final endFraction =
            ((i * GSAnimDuration.skeletonStagger) + 400) / totalMs;
        return FadeTransition(
          opacity: CurvedAnimation(
            parent: _controller,
            curve: Interval(
              startFraction.clamp(0.0, 1.0),
              endFraction.clamp(0.0, 1.0),
              curve: Curves.easeOut,
            ),
          ),
          child: widget.itemBuilder(i),
        );
      }),
    );
  }
}
```

---

## QW-6 · Payment Success — Burst de partículas + checkmark animado

### Problema
- Estado `PaymentStatus.authorized`: ícono estático con `ScaleTransition` básico
- Sin celebración visual en el momento de mayor relevancia emocional
- `payment_validation_screen.dart` usa `SingleTickerProviderStateMixin` para `_pulseCtrl`

### Solución
- **Cambiar `SingleTickerProviderStateMixin` → `TickerProviderStateMixin`** antes de añadir nuevos controllers
- `AnimatedCheckmark`: `CustomPainter` que dibuja el trazo del check via `PathMetrics` en 600ms
- `AnimatedParticleBurst`: `CustomPainter` con 12 partículas radiales en 700ms
- Ripple de fondo: `AnimatedContainer` que expande de 60px a 160px, opacity 0.12 → 0
- Secuencia con un solo `AnimationController` + 3 `Interval`s:
  - Ripple: `Interval(0.0, 0.5)`
  - Checkmark: `Interval(0.1, 0.7)`
  - Partículas: `Interval(0.2, 1.0)`

### Archivo a modificar
`lib/features/payment/payment_validation_screen.dart`

### Widget stub

```dart
import 'dart:math' show cos, sin, pi; // REQUERIDO para ParticleBurst

// 1. Cambiar mixin en la pantalla:
class _PaymentValidationScreenState extends State<PaymentValidationScreen>
    with TickerProviderStateMixin { // era SingleTickerProviderStateMixin
  late AnimationController _pulseCtrl;  // existente
  late AnimationController _successCtrl; // nuevo

  @override
  void initState() {
    super.initState();
    // _pulseCtrl existente sin cambios
    _pulseCtrl = AnimationController(/* existente */);
    _successCtrl = AnimationController(
      vsync: this,
      duration: GSAnimDuration.particleBurst,
    );
  }

  void _playSuccessAnimation() {
    _successCtrl.forward(from: 0);
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    _successCtrl.dispose();
    super.dispose();
  }
}

// 2. AnimatedCheckmark widget:
class AnimatedCheckmark extends StatelessWidget {
  final AnimationController controller;
  final double size;
  final Color color;

  const AnimatedCheckmark({
    super.key,
    required this.controller,
    this.size = 64,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: CurvedAnimation(
        parent: controller,
        curve: const Interval(0.1, 0.7, curve: Curves.easeOut),
      ),
      builder: (_, __) => CustomPaint(
        size: Size(size, size),
        painter: _CheckmarkPainter(
          progress: CurvedAnimation(
            parent: controller,
            curve: const Interval(0.1, 0.7),
          ).value,
          color: color,
        ),
      ),
    );
  }
}

class _CheckmarkPainter extends CustomPainter {
  final double progress;
  final Color color;

  const _CheckmarkPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.2, size.height * 0.5)
      ..lineTo(size.width * 0.42, size.height * 0.72)
      ..lineTo(size.width * 0.78, size.height * 0.3);

    final metrics = path.computeMetrics().first;
    final drawn = metrics.extractPath(0, metrics.length * progress);

    canvas.drawPath(
      drawn,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_CheckmarkPainter old) => old.progress != progress;
}

// 3. AnimatedParticleBurst widget:
class AnimatedParticleBurst extends StatelessWidget {
  final AnimationController controller;
  final double size;

  const AnimatedParticleBurst({
    super.key,
    required this.controller,
    this.size = 200,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: CurvedAnimation(
        parent: controller,
        curve: const Interval(0.2, 1.0, curve: Curves.easeOut),
      ),
      builder: (_, __) => CustomPaint(
        size: Size(size, size),
        painter: _ParticleBurstPainter(
          progress: CurvedAnimation(
            parent: controller,
            curve: const Interval(0.2, 1.0),
          ).value,
        ),
      ),
    );
  }
}

class _ParticleBurstPainter extends CustomPainter {
  final double progress;

  const _ParticleBurstPainter({required this.progress});

  static const _particleCount = 12;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final distance = 60 * Curves.easeOut.transform(progress);
    final opacity = (1 - progress).clamp(0.0, 1.0);

    for (int i = 0; i < _particleCount; i++) {
      final angle = (i / _particleCount) * 2 * pi;
      final color = i.isEven ? GSColors.success : GSColors.accent;

      canvas.save();
      canvas.translate(
        center.dx + cos(angle) * distance,
        center.dy + sin(angle) * distance,
      );
      canvas.rotate(angle);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: 4,
            height: 12,
          ),
          const Radius.circular(2),
        ),
        Paint()..color = color.withOpacity(opacity),
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ParticleBurstPainter old) => old.progress != progress;
}

// 4. Composición del estado Authorized (reemplaza el widget actual):
Widget _buildAuthorizedState() {
  return Stack(
    alignment: Alignment.center,
    children: [
      // Ripple de fondo
      AnimatedBuilder(
        animation: CurvedAnimation(
          parent: _successCtrl,
          curve: const Interval(0.0, 0.5),
        ),
        builder: (_, __) {
          final t = CurvedAnimation(
            parent: _successCtrl,
            curve: const Interval(0.0, 0.5),
          ).value;
          return Container(
            width: 60 + 100 * t,
            height: 60 + 100 * t,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: GSColors.success.withOpacity(0.12 * (1 - t)),
            ),
          );
        },
      ),
      // Partículas
      AnimatedParticleBurst(controller: _successCtrl),
      // Checkmark
      AnimatedCheckmark(
        controller: _successCtrl,
        color: GSColors.success,
      ),
    ],
  );
}
```

---

## Deliverable structure

```
design/
└── quickwins/
    ├── design-tokens.json          ← tokens nuevos + existentes fusionados
    ├── qw1-bottom-nav.png          ← mockup before/after 1080×2340
    ├── qw2-wallet-card.png
    ├── qw3-quick-actions.png
    ├── qw4-home-header.png
    ├── qw5-skeleton-loaders.png
    └── qw6-payment-success.png
```

---

## Archivos a tocar

| Archivo | QWs | Cambio |
|---------|-----|--------|
| `lib/theme/design_tokens.dart` | todos | Añadir `GSGlass`, `GSGradient`, `GSAnimDuration`, `GSColors.cardGold` |
| `lib/widgets/gs_bottom_nav.dart` | QW-1 | Glass blur + gradient pill + labels siempre visibles |
| `lib/widgets/gs_skeleton_loader.dart` | QW-5 | Añadir `StaggeredSkeletonList` |
| `lib/features/wallet/wallet_screen.dart` | QW-2, QW-3 | Gloss + chip + glow + action rail + `extendBody: true` |
| `lib/features/history/history_screen.dart` | QW-1 prereq | `extendBody: true` |
| `lib/features/profile/profile_screen.dart` | QW-1 prereq | `extendBody: true` |
| `lib/features/home/home_screen.dart` | QW-4 | Avatar ring + initials + greeting updated |
| `lib/features/payment/payment_validation_screen.dart` | QW-6 | `TickerProviderStateMixin` + success animation |

**No se crean nuevas rutas, providers ni servicios.**
**No se modifica la lógica de negocio existente.**

---

## Success criteria

- `flutter analyze` pasa sin warnings nuevos tras cada QW
- Cada QW es un commit atómico y reversible
- Los nuevos tokens (`GSGlass`, `GSGradient`, `GSAnimDuration`, `GSColors.cardGold`) están definidos en `design_tokens.dart`
- `design/quickwins/design-tokens.json` refleja exactamente los valores Dart
- `BackdropFilter` produce blur visible en todas las pantallas (verificar `extendBody: true`)
- `flutter analyze` no reporta `dart:math` imports faltantes en el archivo de payment
