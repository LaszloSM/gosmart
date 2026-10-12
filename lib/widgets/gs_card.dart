import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

/// Superficie plana con borde fino (sin sombra). Úsala solo cuando la tarjeta
/// ES la interacción; por defecto, filas planas con divisor (GSListRow).
class GSCard extends StatelessWidget {
  const GSCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.radius,
    this.color = GSColors.surface,
    this.shadow,
    this.border,
    this.onTap,
    this.clip = Clip.antiAlias,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double? radius;
  final Color color;
  final List<BoxShadow>? shadow;
  final Border? border;
  final VoidCallback? onTap;
  final Clip clip;

  @override
  Widget build(BuildContext context) {
    final r = radius ?? GSRadius.lg;
    final content = Container(
      margin: margin,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(r),
        boxShadow: shadow,
        border: border ?? Border.all(color: GSColors.line),
      ),
      clipBehavior: clip,
      // Material transparente: los ListTile internos pintan su ripple sobre
      // la tarjeta y no detrás del fondo de color.
      child: Material(
        type: MaterialType.transparency,
        child:
            padding != null ? Padding(padding: padding!, child: child) : child,
      ),
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: content);
    }
    return content;
  }
}
