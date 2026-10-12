// lib/widgets/gs_list_row.dart
// Fila plana con divisor (sin tarjetas por defecto). Ícono, título, detalle
// y un final opcional (valor, interruptor o chevron). Mín. 64 dp de alto.
import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

class GSListRow extends StatelessWidget {
  const GSListRow({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.value,
    this.onTap,
    this.iconColor,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  /// Widget al final; si es null y hay [onTap], va un chevron.
  final Widget? trailing;

  /// Valor corto a la derecha en cifras tabulares (p. ej. "120").
  final String? value;
  final VoidCallback? onTap;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final end = trailing ??
        (value != null
            ? Text(
                value!,
                style: const TextStyle(
                  fontFamily: GSFonts.mono,
                  fontFeatures: GSFonts.tabular,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: GSColors.text,
                ),
              )
            : onTap != null
                ? const Icon(Icons.chevron_right_rounded,
                    color: GSColors.textMuted)
                : null);

    return Semantics(
      button: onTap != null,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 64),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: GSSpacing.s4, vertical: GSSpacing.s3),
            child: Row(
              children: [
                Icon(icon, color: iconColor ?? GSColors.brand),
                const SizedBox(width: GSSpacing.s4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(title, style: text.titleMedium),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          style: text.bodySmall,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                if (end != null) ...[
                  const SizedBox(width: GSSpacing.s3),
                  end,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Título de sección en letra de rótulo (no una etiqueta pequeña en
/// mayúsculas: impeccable las prohíbe).
class GSSectionTitle extends StatelessWidget {
  const GSSectionTitle(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          GSSpacing.s4, GSSpacing.s6, GSSpacing.s4, GSSpacing.s1),
      child: Text(label, style: Theme.of(context).textTheme.titleLarge),
    );
  }
}
