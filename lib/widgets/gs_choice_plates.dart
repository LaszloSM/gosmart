// lib/widgets/gs_choice_plates.dart
// Elegir una opción entre pocas, como píldoras (los filtros de Google Maps):
// la elegida va en azul claro con borde azul. Sin animación (acción repetida).
// En varias filas: todo a la vista y cabe con texto grande.
import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

class GSChoicePlates<T> extends StatelessWidget {
  const GSChoicePlates({
    super.key,
    required this.options,
    required this.selected,
    required this.onChanged,
    this.icons,
  });

  /// Valor → etiqueta, en el orden en que se muestran.
  final Map<T, String> options;
  final T? selected;
  final ValueChanged<T> onChanged;
  final IconData? Function(T)? icons;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: GSSpacing.s2,
      runSpacing: GSSpacing.s2,
      children: [
        for (final e in options.entries)
          GSChoicePlate(
            label: e.value,
            icon: icons?.call(e.key),
            selected: e.key == selected,
            onTap: () => onChanged(e.key),
          ),
      ],
    );
  }
}

class GSChoicePlate extends StatelessWidget {
  const GSChoicePlate({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.stripe = true,
  });

  /// Se conserva por compatibilidad; ya no hay franja.
  final bool stripe;
  final String label;
  final IconData? icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? GSColors.brand : GSColors.text;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: selected ? GSColors.brandTint : GSColors.surface,
        shape: StadiumBorder(
          side: BorderSide(
              color: selected ? GSColors.brand : GSColors.line,
              width: selected ? 2 : 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            constraints: const BoxConstraints(minHeight: GSSize.touchTarget),
            padding: const EdgeInsets.symmetric(horizontal: GSSpacing.s4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 20, color: fg),
                  const SizedBox(width: GSSpacing.s2),
                ],
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      fontFamily: GSFonts.sans,
                      fontSize: 16,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                      color: fg,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
