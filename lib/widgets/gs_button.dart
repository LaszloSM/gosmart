import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

enum GSButtonVariant { primary, secondary, outline, ghost, eco, danger }
/// `driver`: 72 dp, para el modo conductor (DS6, una mano).
enum GSButtonSize { sm, md, lg, driver }

/// Botón GoSmart (mundo "rótulo de colectivo"): plano, radio md, etiqueta en
/// letra condensada de rótulo. Al presionar baja a 0.97 en 120 ms ease-out
/// (Emil Kowalski); con "quitar animaciones" del sistema no escala.
/// Toda talla mide al menos 48 dp de alto (área táctil de Android).
class GSButton extends StatefulWidget {
  const GSButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.variant = GSButtonVariant.primary,
    this.size = GSButtonSize.md,
    this.leadingIcon,
    this.trailingIcon,
    this.isLoading = false,
    this.isFullWidth = true,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final GSButtonVariant variant;
  final GSButtonSize size;
  final IconData? leadingIcon;
  final IconData? trailingIcon;
  final bool isLoading;
  final bool isFullWidth;
  final String? semanticLabel;

  @override
  State<GSButton> createState() => _GSButtonState();
}

class _GSButtonState extends State<GSButton> {
  bool _pressed = false;

  void _setPressed(bool v) {
    if (_pressed != v && mounted) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    final c = _variantColors;
    final d = _sizeDims;
    final isDisabled = widget.isLoading || widget.onPressed == null;
    final reduceMotion = MediaQuery.of(context).disableAnimations;
    // Píldora, como los botones de las apps de referencia.
    final button = Material(
      color: c.bg,
      shape: StadiumBorder(
        side: c.border == null
            ? BorderSide.none
            : BorderSide(color: c.border!, width: 1.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: isDisabled ? null : widget.onPressed,
        // La escala es la respuesta; sin salpicadura encima.
        splashFactory: NoSplash.splashFactory,
        highlightColor: c.fg.withValues(alpha: 0.08),
        child: Container(
          // Alto mínimo, no fijo: con texto al 200 % la etiqueta baja a una
          // segunda línea en vez de cortarse (Regla de los Doscientos).
          constraints: BoxConstraints(minHeight: d.height),
          width: widget.isFullWidth ? double.infinity : null,
          padding: EdgeInsets.symmetric(
              horizontal: d.hPad, vertical: GSSpacing.s1),
          // Center con heightFactor 1: centra sin estirarse a todo el alto
          // disponible (un Container con alignment sí se estiraría).
          child: Center(
            heightFactor: 1,
            widthFactor: widget.isFullWidth ? null : 1,
            child: _content(c.fg, d),
          ),
        ),
      ),
    );

    return Semantics(
      label: widget.semanticLabel ?? widget.label,
      button: true,
      enabled: !isDisabled,
      excludeSemantics: true,
      child: Opacity(
        opacity: isDisabled && !widget.isLoading ? 0.38 : 1,
        // Listener: la respuesta llega al tocar, sin esperar al arbitraje
        // de gestos de las listas con scroll.
        child: Listener(
          onPointerDown: isDisabled ? null : (_) => _setPressed(true),
          onPointerUp: (_) => _setPressed(false),
          onPointerCancel: (_) => _setPressed(false),
          child: AnimatedScale(
            scale: _pressed && !reduceMotion ? 0.97 : 1,
            duration: GSDuration.press,
            curve: GSCurve.enter,
            child: button,
          ),
        ),
      ),
    );
  }

  Widget _content(Color fg, _SizeDims d) {
    if (widget.isLoading) {
      return SizedBox(
        width: d.iconSize,
        height: d.iconSize,
        child: CircularProgressIndicator(strokeWidth: 2.5, color: fg),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (widget.leadingIcon != null) ...[
          Icon(widget.leadingIcon, size: d.iconSize, color: fg),
          const SizedBox(width: GSSpacing.s2),
        ],
        Flexible(
          child: Text(
            widget.label,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: GSFonts.sans,
              fontSize: d.fontSize,
              fontWeight: FontWeight.w700,
              height: 1.15,
              color: fg,
            ),
          ),
        ),
        if (widget.trailingIcon != null) ...[
          const SizedBox(width: GSSpacing.s2),
          Icon(widget.trailingIcon, size: d.iconSize, color: fg),
        ],
      ],
    );
  }

  _VariantColors get _variantColors {
    switch (widget.variant) {
      case GSButtonVariant.primary:
      case GSButtonVariant.eco:
        return _VariantColors(GSColors.brand, GSColors.onBrand);
      case GSButtonVariant.secondary:
        return _VariantColors(GSColors.brandTint, GSColors.brand);
      case GSButtonVariant.outline:
        return _VariantColors(GSColors.surface, GSColors.text, GSColors.line);
      case GSButtonVariant.ghost:
        return _VariantColors(Colors.transparent, GSColors.brand);
      case GSButtonVariant.danger:
        return _VariantColors(
            GSColors.roadClosedTint, GSColors.roadClosed);
    }
  }

  _SizeDims get _sizeDims {
    switch (widget.size) {
      case GSButtonSize.sm:
        return const _SizeDims(height: 48, hPad: 18, fontSize: 15, iconSize: 18);
      case GSButtonSize.md:
        return const _SizeDims(height: 52, hPad: 22, fontSize: 17, iconSize: 20);
      case GSButtonSize.lg:
        return const _SizeDims(height: 56, hPad: 24, fontSize: 18, iconSize: 22);
      case GSButtonSize.driver:
        return const _SizeDims(
            height: GSSize.touchTargetDriver, hPad: 24, fontSize: 20, iconSize: 26);
    }
  }
}

class _VariantColors {
  final Color bg;
  final Color fg;
  final Color? border;
  const _VariantColors(this.bg, this.fg, [this.border]);
}

class _SizeDims {
  final double height;
  final double hPad;
  final double fontSize;
  final double iconSize;
  const _SizeDims({
    required this.height,
    required this.hPad,
    required this.fontSize,
    required this.iconSize,
  });
}

// ─── Icon-only circular button ───────────────────────────────────────────────

class GSIconButton extends StatelessWidget {
  const GSIconButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.backgroundColor,
    this.iconColor,
    this.size = GSSize.touchTarget,
    this.tooltip,
    this.hasShadow = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final Color? backgroundColor;
  final Color? iconColor;
  final double size;
  final String? tooltip;
  final bool hasShadow;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: tooltip,
      button: true,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(GSRadius.full),
        child: Tooltip(
          message: tooltip ?? '',
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              color: backgroundColor ?? GSColors.surface,
              shape: BoxShape.circle,
              boxShadow: hasShadow ? GSShadow.float : [],
            ),
            child: Icon(icon,
                color: iconColor ?? GSColors.text, size: size * 0.45),
          ),
        ),
      ),
    );
  }
}
