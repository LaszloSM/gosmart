// lib/widgets/gs_meta_chip.dart
// Dato corto en píldora hundida: ícono + texto con cifras tabulares
// ("12 min", "3,4 km", "Tarifa oficial"). Para resúmenes de viaje.
import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

class GSMetaChip extends StatelessWidget {
  const GSMetaChip({super.key, required this.icon, required this.label, this.emphasis = false});

  final IconData icon;
  final String label;

  /// Fondo de selección y texto de marca, para el dato que más importa.
  final bool emphasis;

  @override
  Widget build(BuildContext context) {
    final fg = emphasis ? GSColors.brand : GSColors.text;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: emphasis ? GSColors.brandTint : GSColors.surfaceSunken,
        borderRadius: BorderRadius.circular(GSRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: GSSize.iconSm, color: fg),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: GSFonts.sans,
                fontFeatures: GSFonts.tabular,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
