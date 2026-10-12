import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme/design_tokens.dart';

class GSTextField extends StatelessWidget {
  const GSTextField({
    super.key,
    required this.hint,
    this.label,
    this.controller,
    this.keyboardType,
    this.obscureText = false,
    this.prefixIcon,
    this.suffixIcon,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.inputFormatters,
    this.maxLength,
    this.maxLines = 1,
    this.enabled = true,
    this.autofocus = false,
    this.textCapitalization = TextCapitalization.none,
    this.semanticLabel,
  });

  final String hint;
  final String? label;
  final TextEditingController? controller;
  final TextInputType? keyboardType;
  final bool obscureText;
  final IconData? prefixIcon;
  final Widget? suffixIcon;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final String? Function(String?)? validator;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final int maxLines;
  final bool enabled;
  final bool autofocus;
  final TextCapitalization textCapitalization;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticLabel ?? label ?? hint,
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        obscureText: obscureText,
        onChanged: onChanged,
        onFieldSubmitted: onSubmitted,
        validator: validator,
        inputFormatters: inputFormatters,
        maxLength: maxLength,
        maxLines: maxLines,
        enabled: enabled,
        autofocus: autofocus,
        textCapitalization: textCapitalization,
        style: const TextStyle(
          fontSize: 15,
          color: GSColors.textPrimary,
          fontWeight: FontWeight.w400,
        ),
        decoration: InputDecoration(
          hintText: hint,
          labelText: label,
          counterText: '',
          prefixIcon: prefixIcon != null
              ? Icon(prefixIcon, size: 20, color: GSColors.textSecondary)
              : null,
          suffixIcon: suffixIcon,
        ),
      ),
    );
  }
}

// ─── Search bar ───────────────────────────────────────────────────────────────

class GSSearchBar extends StatelessWidget {
  const GSSearchBar({
    super.key,
    required this.hint,
    this.controller,
    this.onChanged,
    this.onTap,
    this.readOnly = false,
    this.trailing,
  });

  final String hint;
  final TextEditingController? controller;
  final ValueChanged<String>? onChanged;
  final VoidCallback? onTap;
  final bool readOnly;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: readOnly ? onTap : null,
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: GSSpacing.s4),
        decoration: BoxDecoration(
          color: GSColors.surface,
          // DESIGN.md: los campos usan radio sm; las píldoras son solo filtros.
          borderRadius: BorderRadius.circular(GSRadius.sm),
          border: Border.all(color: GSColors.textMuted, width: 1.5),
        ),
        child: Row(
          children: [
            const Icon(Icons.search_rounded,
                size: 22, color: GSColors.accent),
            const SizedBox(width: GSSpacing.s3),
            Expanded(
              child: readOnly
                  ? Text(hint,
                      style: const TextStyle(
                          fontFamily: GSFonts.sans,
                          color: GSColors.textMuted,
                          fontSize: 17,
                          fontWeight: FontWeight.w600))
                  : TextField(
                      controller: controller,
                      onChanged: onChanged,
                      decoration: InputDecoration(
                        hintText: hint,
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        filled: false,
                        contentPadding: EdgeInsets.zero,
                        isDense: true,
                      ),
                      style: const TextStyle(
                          fontSize: 15, color: GSColors.textPrimary),
                    ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
      ),
    );
  }
}
