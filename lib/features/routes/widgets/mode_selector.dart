// lib/features/routes/widgets/mode_selector.dart
// "¿En qué vas?": los modos locales como placas pequeñas (GSChoicePlates).
import 'package:flutter/material.dart';

import '../../../providers/selected_mode_provider.dart';
import '../../../theme/design_tokens.dart';
import '../../../widgets/gs_choice_plates.dart';

class ModeSelector extends StatelessWidget {
  const ModeSelector({super.key, required this.selected, required this.onChanged});

  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: GSSpacing.s4),
      child: GSChoicePlates<String>(
        options: {for (final m in travelModes) m: m},
        icons: modeIconFor,
        selected: selected,
        onChanged: onChanged,
      ),
    );
  }
}
