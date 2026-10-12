// lib/features/onboarding/intro_screen.dart
// Primera vez: una sola pantalla que muestra el mecanismo en vez de
// prometerlo (impeccable onboard: llegar rápido al valor). La Línea del
// corredor de ejemplo está marcada como ejemplo: no es un dato real.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../models/corridor_status.dart';
import '../../router/app_router.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/gs_button.dart';
import '../../widgets/gs_corridor_line.dart';
import '../../widgets/gs_route_plate.dart';

class IntroScreen extends StatelessWidget {
  const IntroScreen({super.key});

  static final _example = CorridorStatus(
    segments: const [
      CorridorSegment(kmFrom: 0, kmTo: 40, state: RoadState.open),
      CorridorSegment(
          kmFrom: 40, kmTo: 44, state: RoadState.closed, reason: 'Bloqueo'),
      CorridorSegment(kmFrom: 44, kmTo: 75, state: RoadState.open),
    ],
    updatedAt: DateTime.now().subtract(const Duration(minutes: 8)),
  );

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: GSColors.background,
        body: Column(
          children: [
            // Carrocería: el nombre y la Línea de ejemplo.
            ColoredBox(
              color: GSColors.brand,
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(GSSpacing.s4,
                      GSSpacing.s6, GSSpacing.s4, GSSpacing.s5),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'GoSmart',
                        style: TextStyle(
                          fontFamily: GSFonts.display,
                          fontSize: 40,
                          fontWeight: FontWeight.w800,
                          height: 1,
                          color: GSColors.onBrand,
                        ),
                      ),
                      const SizedBox(height: GSSpacing.s2),
                      const Text(
                        'Antes de salir, ya sabes cómo está la vía.',
                        style: TextStyle(
                          fontFamily: GSFonts.sans,
                          fontSize: 19,
                          fontWeight: FontWeight.w500,
                          color: GSColors.onBrand,
                        ),
                      ),
                      const SizedBox(height: GSSpacing.s5),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(GSRadius.md),
                        child: ExcludeSemantics(
                          child: GSCorridorLine(status: _example),
                        ),
                      ),
                      const SizedBox(height: GSSpacing.s2),
                      const Text(
                        'Ejemplo: así se ve un bloqueo en la Troncal.',
                        style: TextStyle(
                          fontFamily: GSFonts.sans,
                          fontSize: 14,
                          color: GSColors.onBrandMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(GSSpacing.s4),
                children: [
                  const GSRoutePlate(
                    from: 'Riohacha',
                    text: 'Maicao',
                    leading: Icons.airport_shuttle_rounded,
                    detail: 'Escribe a dónde vas',
                  ),
                  const SizedBox(height: GSSpacing.s4),
                  _Point(
                    icon: Icons.two_wheeler_rounded,
                    text: 'Mototaxi, taxi, colectivo o TransPadilla, con '
                        'el tiempo y un precio de referencia.',
                    style: text.bodyLarge,
                  ),
                  _Point(
                    icon: Icons.person_outline_rounded,
                    text: 'Sin cuenta puedes mirar y planear. La cuenta se '
                        'pide para reportar, pedir o pagar.',
                    style: text.bodyLarge,
                  ),
                ],
              ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                    GSSpacing.s4, 0, GSSpacing.s4, GSSpacing.s4),
                child: GSButton(
                  label: 'Empezar',
                  onPressed: () => context.go(AppRoutes.locationPermission),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point({required this.icon, required this.text, this.style});
  final IconData icon;
  final String text;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: GSSpacing.s3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: GSColors.brand, size: 26),
          const SizedBox(width: GSSpacing.s3),
          Expanded(child: Text(text, style: style)),
        ],
      ),
    );
  }
}
