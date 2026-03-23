import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

enum GSButtonVariant { primary, secondary, outline, ghost, eco, danger }
enum GSButtonSize { sm, md, lg }

/// GoSmart reusable button with AnimatedScale press feedback.
/// Primary variant uses a kinetic green → cyan gradient.
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

  void _onTapDown(TapDownDetails _) => setState(() => _pressed = true);
  void _onTapUp(TapUpDetails _) => setState(() => _pressed = false);
  void _onTapCancel() => setState(() => _pressed = false);

  @override
  Widget build(BuildContext context) {
    final colors = _variantColors;
    final dims = _sizeDims;
    final isDisabled = widget.isLoading || widget.onPressed == null;
    final isPrimary = widget.variant == GSButtonVariant.primary;
    final isEco = widget.variant == GSButtonVariant.eco;

    return Semantics(
      label: widget.semanticLabel ?? widget.label,
      button: true,
      child: AnimatedScale(
        scale: (_pressed && !isDisabled) ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeIn,
        child: GestureDetector(
          onTapDown: isDisabled ? null : _onTapDown,
          onTapUp: isDisabled ? null : _onTapUp,
          onTapCancel: isDisabled ? null : _onTapCancel,
          onTap: isDisabled ? null : widget.onPressed,
          child: SizedBox(
            width: widget.isFullWidth ? double.infinity : null,
            height: dims.height,
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(GSRadius.full),
                boxShadow: isDisabled
                    ? []
                    : isPrimary
                        ? GSShadow.accent
                        : isEco
                            ? GSShadow.eco
                            : [],
              ),
              child: Container(
                height: dims.height,
                padding: EdgeInsets.symmetric(horizontal: dims.hPad),
                decoration: BoxDecoration(
                  // Gradient for primary & eco; solid color for others
                  gradient: !isDisabled && (isPrimary || isEco)
                      ? LinearGradient(
                          colors: isPrimary
                              ? GSGradient.primaryButton
                              : [GSColors.eco, GSColors.ecoDark],
                          begin: Alignment.centerLeft,
                          end: Alignment.centerRight,
                        )
                      : null,
                  color: isDisabled
                      ? GSColors.surfaceContainerHigh
                      : (!isPrimary && !isEco) ? colors.bg : null,
                  borderRadius: BorderRadius.circular(GSRadius.full),
                  border: widget.variant == GSButtonVariant.outline
                      ? Border.all(
                          color: GSColors.accent.withValues(alpha: 0.40),
                          width: 1.5,
                        )
                      : widget.variant == GSButtonVariant.danger
                          ? Border.all(color: GSColors.error, width: 1.5)
                          : null,
                ),
                child: _buildChild(dims, colors, isDisabled),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChild(_SizeDims dims, _VariantColors colors, bool isDisabled) {
    final effectiveFg = isDisabled
        ? GSColors.textDisabled
        : (widget.variant == GSButtonVariant.primary ||
                widget.variant == GSButtonVariant.eco)
            ? GSColors.primary  // dark text on bright gradient
            : colors.fg;

    if (widget.isLoading) {
      return Center(
        child: SizedBox(
          width: dims.iconSize,
          height: dims.iconSize,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: effectiveFg,
          ),
        ),
      );
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.leadingIcon != null) ...[
          Icon(widget.leadingIcon, size: dims.iconSize, color: effectiveFg),
          const SizedBox(width: GSSpacing.s2),
        ],
        Text(
          widget.label,
          style: TextStyle(
            fontSize: dims.fontSize,
            fontWeight: FontWeight.w700,
            color: effectiveFg,
            letterSpacing: 0.2,
          ),
        ),
        if (widget.trailingIcon != null) ...[
          const SizedBox(width: GSSpacing.s2),
          Icon(widget.trailingIcon, size: dims.iconSize, color: effectiveFg),
        ],
      ],
    );
  }

  _VariantColors get _variantColors {
    switch (widget.variant) {
      case GSButtonVariant.primary:
        return const _VariantColors(GSColors.accent, GSColors.primary);
      case GSButtonVariant.secondary:
        return const _VariantColors(GSColors.accentLight, GSColors.accent);
      case GSButtonVariant.outline:
        return const _VariantColors(Colors.transparent, GSColors.accent);
      case GSButtonVariant.ghost:
        return const _VariantColors(Colors.transparent, GSColors.textSecondary);
      case GSButtonVariant.eco:
        return const _VariantColors(GSColors.eco, GSColors.primary);
      case GSButtonVariant.danger:
        return const _VariantColors(Colors.transparent, GSColors.error);
    }
  }

  _SizeDims get _sizeDims {
    switch (widget.size) {
      case GSButtonSize.sm:
        return const _SizeDims(height: 36, hPad: 16, fontSize: 13, iconSize: 16);
      case GSButtonSize.md:
        return const _SizeDims(height: 52, hPad: 24, fontSize: 15, iconSize: 20);
      case GSButtonSize.lg:
        return const _SizeDims(height: 60, hPad: 32, fontSize: 17, iconSize: 22);
    }
  }
}

class _VariantColors {
  final Color bg;
  final Color fg;
  const _VariantColors(this.bg, this.fg);
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
    this.backgroundColor = GSColors.surface,
    this.iconColor = GSColors.textPrimary,
    this.size = 44,
    this.tooltip,
    this.hasShadow = true,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final Color backgroundColor;
  final Color iconColor;
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
              color: backgroundColor,
              shape: BoxShape.circle,
              boxShadow: hasShadow ? GSShadow.card : [],
            ),
            child: Icon(icon, color: iconColor, size: size * 0.45),
          ),
        ),
      ),
    );
  }
}
