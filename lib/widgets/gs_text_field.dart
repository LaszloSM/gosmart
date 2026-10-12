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
    // Etiqueta ARRIBA del campo, nunca flotante ni como placeholder
    // (taste-skill 4.6); el error queda debajo.
    final field = TextFormField(
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
        fontFamily: GSFonts.sans,
        fontSize: 17,
        color: GSColors.text,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: hint,
        counterText: '',
        prefixIcon: prefixIcon != null
            ? Icon(prefixIcon, size: 22, color: GSColors.textMuted)
            : null,
        suffixIcon: suffixIcon,
      ),
    );

    return Semantics(
      label: semanticLabel ?? label ?? hint,
      child: label == null
          ? field
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label!,
                  style: const TextStyle(
                    fontFamily: GSFonts.sans,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: GSColors.text,
                  ),
                ),
                const SizedBox(height: GSSpacing.s2),
                field,
              ],
            ),
    );
  }
}
