import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

enum GSButtonVariant { primary, secondary, outline, ghost, eco, danger }
enum GSButtonSize { sm, md, lg }

/// GoSmart reusable button — covers all design system button variants.
class GSButton extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final colors = _variantColors;
    final dims = _sizeDims;

    return Semantics(
      label: semanticLabel ?? label,
      button: true,
      child: SizedBox(
        width: isFullWidth ? double.infinity : null,
        height: dims.height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(GSRadius.full),
            boxShadow: variant == GSButtonVariant.primary
                ? GSShadow.primary
                : variant == GSButtonVariant.eco
                    ? GSShadow.eco
                    : [],
          ),
          child: ElevatedButton(
            onPressed: isLoading ? null : onPressed,
            style: ElevatedButton.styleFrom(
              backgroundColor: colors.bg,
              foregroundColor: colors.fg,
              disabledBackgroundColor: GSColors.textDisabled,
              disabledForegroundColor: Colors.white,
              elevation: 0,
              minimumSize: Size(0, dims.height),
              padding: EdgeInsets.symmetric(horizontal: dims.hPad),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(GSRadius.full),
                side: variant == GSButtonVariant.outline
                    ? const BorderSide(color: GSColors.primary, width: 1.5)
                    : variant == GSButtonVariant.danger
                        ? const BorderSide(color: GSColors.error, width: 1.5)
                        : BorderSide.none,
              ),
            ),
            child: _buildChild(dims),
          ),
        ),
      ),
    );
  }

  Widget _buildChild(_SizeDims dims) {
    if (isLoading) {
      return SizedBox(
        width: dims.iconSize,
        height: dims.iconSize,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: _variantColors.fg,
        ),
      );
    }

    final children = <Widget>[
      if (leadingIcon != null) ...[
        Icon(leadingIcon, size: dims.iconSize),
        SizedBox(width: GSSpacing.s2),
      ],
      Text(
        label,
        style: TextStyle(
          
          fontSize: dims.fontSize,
          fontWeight: FontWeight.w600,
        ),
      ),
      if (trailingIcon != null) ...[
        SizedBox(width: GSSpacing.s2),
        Icon(trailingIcon, size: dims.iconSize),
      ],
    ];

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: children,
    );
  }

  _VariantColors get _variantColors {
    switch (variant) {
      case GSButtonVariant.primary:
        return _VariantColors(GSColors.primary, Colors.white);
      case GSButtonVariant.secondary:
        return _VariantColors(GSColors.primaryLight, GSColors.primary);
      case GSButtonVariant.outline:
        return _VariantColors(Colors.transparent, GSColors.primary);
      case GSButtonVariant.ghost:
        return _VariantColors(Colors.transparent, GSColors.textSecondary);
      case GSButtonVariant.eco:
        return _VariantColors(GSColors.eco, Colors.white);
      case GSButtonVariant.danger:
        return _VariantColors(Colors.transparent, GSColors.error);
    }
  }

  _SizeDims get _sizeDims {
    switch (size) {
      case GSButtonSize.sm:
        return _SizeDims(height: 36, hPad: 16, fontSize: 13, iconSize: 16);
      case GSButtonSize.md:
        return _SizeDims(height: 52, hPad: 24, fontSize: 15, iconSize: 20);
      case GSButtonSize.lg:
        return _SizeDims(height: 60, hPad: 32, fontSize: 17, iconSize: 22);
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
              boxShadow: hasShadow ? GSShadow.md : [],
            ),
            child: Icon(icon, color: iconColor, size: size * 0.45),
          ),
        ),
      ),
    );
  }
}
