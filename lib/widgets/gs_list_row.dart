// lib/widgets/gs_list_row.dart
// Fila de lista como en Nequi o los ajustes de Google: ícono en un círculo
// gris, título, detalle y un final opcional (valor, interruptor o chevron).
// Mín. 64 dp. Se agrupan en tarjetas blancas con GSGroup.
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
                style: TextStyle(
                  fontFamily: GSFonts.mono,
                  fontFeatures: GSFonts.tabular,
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: GSColors.text,
                ),
              )
            : onTap != null
                ? Icon(Icons.chevron_right_rounded,
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
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: GSColors.surfaceSunken,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, size: 22, color: iconColor ?? GSColors.text),
                ),
                const SizedBox(width: GSSpacing.s3),
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

/// Grupo de filas en una tarjeta blanca de radio 16, con divisores que
/// empiezan después del ícono (Nequi, ajustes de Android).
class GSGroup extends StatelessWidget {
  const GSGroup({super.key, required this.children, this.margin});
  final List<Widget> children;
  final EdgeInsetsGeometry? margin;

  @override
  Widget build(BuildContext context) {
    final items = <Widget>[];
    for (var i = 0; i < children.length; i++) {
      if (i > 0) items.add(const Divider(indent: 68));
      items.add(children[i]);
    }
    return Padding(
      padding: margin ??
          const EdgeInsets.symmetric(horizontal: GSSpacing.s4),
      child: Material(
        color: GSColors.surface,
        borderRadius: BorderRadius.circular(GSRadius.lg),
        clipBehavior: Clip.antiAlias,
        child: Column(mainAxisSize: MainAxisSize.min, children: items),
      ),
    );
  }
}

/// Título de sección: en caja normal y peso 700 (sin etiquetas pequeñas en
/// mayúsculas: impeccable las prohíbe).
class GSSectionTitle extends StatelessWidget {
  const GSSectionTitle(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          GSSpacing.s4, GSSpacing.s6, GSSpacing.s4, GSSpacing.s3),
      child: Text(label, style: Theme.of(context).textTheme.titleLarge),
    );
  }
}
