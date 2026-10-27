// lib/widgets/gs_mode_visual.dart
// El vehículo de un modo: ilustración (assets/vehicles) o, para a pie y
// carro, el ícono. Mismo dibujo en el inicio, el planificador y la ruta.
import 'package:flutter/material.dart';

import '../providers/selected_mode_provider.dart';
import '../theme/design_tokens.dart';

class GSModeVisual extends StatelessWidget {
  const GSModeVisual({super.key, required this.mode, this.height = 40, this.iconColor});

  final String mode;

  /// Alto de la ilustración; el ícono usa el 70 %.
  final double height;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final asset = modeImageFor(mode);
    if (asset == null) {
      return Icon(modeIconFor(mode), size: height * 0.7, color: iconColor ?? GSColors.brand);
    }
    // 3:2 como las ilustraciones; sin semántica propia (la da la etiqueta).
    return ExcludeSemantics(
      child: Image.asset(asset, height: height, width: height * 1.5, fit: BoxFit.contain),
    );
  }
}
