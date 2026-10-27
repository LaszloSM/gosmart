// lib/widgets/gs_brand_hero.dart
// Cabecera honda de marca (Nequi/DiDi): banda azul profunda desde el borde
// superior, con el título y el contenido en blanco. El cuerpo de la pantalla
// monta encima con [GSHeroBody], que sube 24 dp y redondea sus esquinas.
// Lleva dos trazos de carretera muy tenues: la Troncal como firma, no adorno.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/design_tokens.dart';

class GSBrandHero extends StatelessWidget {
  const GSBrandHero({
    super.key,
    this.title,
    required this.child,
    this.trailing,
  });

  /// Título de la pantalla. Sin título cuando la barra inferior ya dice dónde
  /// estás y el dato principal habla solo (saldo, tu nombre).
  final String? title;
  final Widget child;

  /// Acción a la derecha del título (p. ej. ocultar saldo).
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.of(context).padding.top;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: GSColors.isDark
          ? SystemUiOverlayStyle.light
          : SystemUiOverlayStyle.light
              .copyWith(statusBarColor: Colors.transparent),
      child: Container(
        color: GSColors.brandDeep,
        child: CustomPaint(
          painter: _RoadMotif(GSColors.onBrandDeep),
          child: Padding(
            padding: EdgeInsets.fromLTRB(
                GSSpacing.s5, top + GSSpacing.s3, GSSpacing.s3, GSSpacing.s10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null || trailing != null) SizedBox(
                  height: 48,
                  child: Row(
                    children: [
                      Expanded(
                        child: title == null ? const SizedBox.shrink() : Semantics(
                          header: true,
                          child: Text(
                            title!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: GSFonts.sans,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -0.3,
                              color: GSColors.onBrandDeep,
                            ),
                          ),
                        ),
                      ),
                      if (trailing != null) trailing!,
                    ],
                  ),
                ),
                SizedBox(height: title == null && trailing == null ? GSSpacing.s6 : GSSpacing.s2),
                Padding(
                  padding: const EdgeInsets.only(right: GSSpacing.s2),
                  child: child,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Cuerpo que monta sobre la cabecera: fondo de pantalla con las esquinas de
/// arriba en 24, subido 24 dp para que la banda asome detrás.
class GSHeroBody extends StatelessWidget {
  const GSHeroBody({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Transform.translate(
      offset: const Offset(0, -GSRadius.xl),
      child: Container(
        decoration: BoxDecoration(
          color: GSColors.background,
          borderRadius:
              const BorderRadius.vertical(top: Radius.circular(GSRadius.xl)),
        ),
        padding: const EdgeInsets.only(top: GSSpacing.s2),
        child: child,
      ),
    );
  }
}

/// Acción redonda sobre la cabecera: círculo y etiqueta debajo. La primaria
/// va en blanco lleno con el ícono en la marca; las demás, translúcidas.
class GSHeroAction extends StatelessWidget {
  const GSHeroAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
    this.busy = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool primary;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    final on = GSColors.onBrandDeep;
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        radius: 40,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: GSSpacing.s1),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: primary ? on : on.withValues(alpha: 0.14),
                  shape: BoxShape.circle,
                ),
                child: busy
                    ? Padding(
                        padding: const EdgeInsets.all(16),
                        child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: primary ? GSColors.brandDeep : on),
                      )
                    : Icon(icon,
                        size: GSSize.iconLg, color: primary ? GSColors.brandDeep : on),
              ),
              const SizedBox(height: GSSpacing.s2),
              // Una línea que se reduce si no cabe: nunca "Recarga/r".
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  fontFamily: GSFonts.sans,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                  color: on,
                ),
              ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RoadMotif extends CustomPainter {
  _RoadMotif(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color.withValues(alpha: 0.07)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18
      ..strokeCap = StrokeCap.round;
    final w = size.width, h = size.height;
    final road = Path()
      ..moveTo(w * 0.42, -20)
      ..cubicTo(w * 0.70, h * 0.25, w * 0.55, h * 0.70, w * 1.10, h * 0.85);
    canvas.drawPath(road, p);
    // Línea de carril punteada sobre el trazo.
    final lane = Paint()
      ..color = color.withValues(alpha: 0.10)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final m in road.computeMetrics()) {
      for (double d = 0; d < m.length; d += 22) {
        canvas.drawPath(m.extractPath(d, d + 10), lane);
      }
    }
  }

  @override
  bool shouldRepaint(_RoadMotif old) => old.color != color;
}
