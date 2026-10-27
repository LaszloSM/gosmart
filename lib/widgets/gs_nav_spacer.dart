// lib/widgets/gs_nav_spacer.dart
// Aire al final de una lista que corre bajo la barra inferior. Lee el padding
// con SU contexto (dentro del Scaffold con extendBody), que ya incluye la
// barra y lo que vaya encima; el contexto de la pantalla no la incluye.
import 'package:flutter/widgets.dart';

class GSNavSpacer extends StatelessWidget {
  const GSNavSpacer({super.key, this.extra = 16});
  final double extra;

  @override
  Widget build(BuildContext context) =>
      SizedBox(height: MediaQuery.of(context).padding.bottom + extra);
}
