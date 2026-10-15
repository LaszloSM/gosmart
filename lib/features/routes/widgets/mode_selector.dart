// lib/features/routes/widgets/mode_selector.dart
// "¿En qué vas?": los modos locales como tarjetas en fila deslizable, igual
// que el selector de servicio de InDrive/DiDi: ícono grande, nombre y, en la
// elegida, borde azul y fondo teñido. Sin animación (acción repetida).
import 'package:flutter/material.dart';

import '../../../providers/selected_mode_provider.dart';
import '../../../theme/design_tokens.dart';
import '../../../widgets/gs_pressable.dart';

class ModeSelector extends StatelessWidget {
  const ModeSelector({super.key, required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: GSSpacing.s4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final m in travelModes) ...[
            _ModeTile(
              mode: m,
              selected: m == selected,
              onTap: () => onChanged(m),
            ),
            if (m != travelModes.last) const SizedBox(width: GSSpacing.s2),
          ],
        ],
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.mode,
    required this.selected,
    required this.onTap,
  });
  final String mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GSPressable(
      onTap: onTap,
      selected: selected,
      semanticLabel: mode,
      child: Container(
        width: 96,
        padding: const EdgeInsets.symmetric(
            horizontal: GSSpacing.s2, vertical: GSSpacing.s3),
        decoration: BoxDecoration(
          color: selected
              ? Color.alphaBlend(
                  GSColors.brandTint.withValues(alpha: 0.7), GSColors.surface)
              : GSColors.surface,
          borderRadius: BorderRadius.circular(GSRadius.lg),
          border: Border.all(
            color: selected ? GSColors.brand : GSColors.line,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(modeIconFor(mode),
                size: 30, color: selected ? GSColors.brand : GSColors.text),
            const SizedBox(height: 6),
            Text(
              mode,
              maxLines: 2,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: GSFonts.sans,
                fontSize: 14,
                height: 1.2,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: selected ? GSColors.brand : GSColors.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
