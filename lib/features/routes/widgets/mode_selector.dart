// lib/features/routes/widgets/mode_selector.dart
// "¿En qué vas?": los modos locales como placas pequeñas. La elegida va en
// ultramar con la franja fucsia. Sin animación: es una acción repetida.
import 'package:flutter/material.dart';

import '../../../providers/selected_mode_provider.dart';
import '../../../theme/design_tokens.dart';

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
        children: [
          for (final m in travelModes) ...[
            _ModeOption(
              label: m,
              icon: modeIconFor(m),
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

class _ModeOption extends StatelessWidget {
  const _ModeOption({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final fg = selected ? GSColors.onBrand : GSColors.text;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: selected ? GSColors.brand : GSColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GSRadius.sm),
          side: BorderSide(
              color: selected ? GSColors.brand : GSColors.line, width: 1.5),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            height: GSSize.touchTarget + 4,
            padding: const EdgeInsets.symmetric(horizontal: GSSpacing.s3),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: selected ? GSColors.stripe : Colors.transparent,
                  width: 4,
                ),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 22, color: fg),
                const SizedBox(width: GSSpacing.s2),
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: GSFonts.display,
                    fontSize: 19,
                    fontWeight: FontWeight.w700,
                    color: fg,
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
