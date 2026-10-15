// lib/features/home/widgets/home_sheet.dart
// Hoja inferior del inicio, como Uber/DiDi: buscador "¿A dónde vas?" en
// píldora, accesos Casa/Trabajo, servicios por modo y, más abajo, el
// asistente y (en modo invitado) la invitación a crear cuenta.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers/auth_provider.dart';
import '../../../providers/selected_mode_provider.dart';
import '../../../router/app_router.dart';
import '../../../theme/design_tokens.dart';
import '../../../widgets/gs_pressable.dart';
import 'quick_places_row.dart';

class HomeSheetContent extends ConsumerWidget {
  const HomeSheetContent({super.key, this.scrollController, this.peekKey});

  final ScrollController? scrollController;

  /// Marca la parte visible en reposo (asa → servicios) para medir su alto.
  final Key? peekKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGuest = ref.watch(isGuestProvider);
    final text = Theme.of(context).textTheme;

    void openPlanner([String? mode]) {
      if (mode != null) ref.read(selectedModeProvider.notifier).state = mode;
      context.push(AppRoutes.routePlanner);
    }

    return ListView(
      controller: scrollController,
      padding: EdgeInsets.zero,
      children: [
        // Parte visible en reposo: se mide para fijar la altura de la hoja.
        Column(
          key: peekKey,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(
                    top: GSSpacing.s3, bottom: GSSpacing.s4),
                decoration: BoxDecoration(
                  color: GSColors.line,
                  borderRadius: BorderRadius.circular(GSRadius.full),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: GSSpacing.s4),
              child: _SearchPill(onTap: openPlanner),
            ),
            const SizedBox(height: GSSpacing.s3),
            QuickPlacesRow(onPlaceSelected: (_) => openPlanner()),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  GSSpacing.s4, GSSpacing.s5, GSSpacing.s4, GSSpacing.s3),
              child: Text('¿En qué te mueves?', style: text.titleLarge),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: GSSpacing.s3),
              child: Row(
                children: [
                  for (final m in const [
                    ('Mototaxi', 'Mototaxi'),
                    ('Taxi', 'Taxi'),
                    ('Colectivo', 'Colectivo'),
                    ('Intermunicipal', 'Intermun.'),
                  ])
                    Expanded(
                      child: _ServiceTile(
                        icon: modeIconFor(m.$1),
                        label: m.$2,
                        semanticLabel: m.$1,
                        onTap: () => openPlanner(m.$1),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: GSSpacing.s4),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
              GSSpacing.s4, GSSpacing.s2, GSSpacing.s4, 0),
          child: Column(
            children: [
              _SheetAction(
                icon: Icons.auto_awesome_outlined,
                title: 'Pregúntale al asistente',
                subtitle: 'Cómo llegar, cuánto cuesta, cómo está la vía',
                onTap: () => context.push(AppRoutes.aiChat),
              ),
              if (isGuest) ...[
                const SizedBox(height: GSSpacing.s2),
                _SheetAction(
                  icon: Icons.person_add_alt_1_outlined,
                  title: 'Entra o crea tu cuenta',
                  subtitle: 'Para reportar la vía, pedir mototaxi o pagar',
                  onTap: () => context.push(AppRoutes.login),
                ),
              ],
              const SizedBox(height: GSSpacing.s3),
              Text(
                'También puedes mantener presionado el mapa para elegir un punto.',
                style: text.bodySmall,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        SizedBox(
          height: MediaQuery.of(context).padding.bottom + GSSpacing.s4,
        ),
      ],
    );
  }
}

/// Buscador en píldora gris (Google Maps / Uber): abre el planificador.
class _SearchPill extends StatelessWidget {
  const _SearchPill({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GSPressable(
      onTap: onTap,
      semanticLabel: '¿A dónde vas? Buscar destino',
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        padding: const EdgeInsets.symmetric(
            horizontal: GSSpacing.s4, vertical: GSSpacing.s3),
        decoration: BoxDecoration(
          color: GSColors.surfaceSunken,
          borderRadius: BorderRadius.circular(GSRadius.full),
        ),
        child: Row(
          children: [
            Icon(Icons.search_rounded, color: GSColors.text, size: 26),
            const SizedBox(width: GSSpacing.s3),
            Expanded(
              child: Text(
                '¿A dónde vas?',
                style: TextStyle(
                  fontFamily: GSFonts.sans,
                  fontSize: 19,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: GSColors.text,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: GSSpacing.s3, vertical: 6),
              decoration: BoxDecoration(
                color: GSColors.surface,
                borderRadius: BorderRadius.circular(GSRadius.full),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.schedule_rounded,
                      size: 18, color: GSColors.text),
                  const SizedBox(width: 4),
                  Text(
                    'Ahora',
                    style: TextStyle(
                      fontFamily: GSFonts.sans,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: GSColors.text,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Servicio por modo (DiDi/InDrive): ícono grande en un cuadro claro y la
/// etiqueta debajo. Elige el modo y abre el planificador.
class _ServiceTile extends StatelessWidget {
  const _ServiceTile({
    required this.icon,
    required this.label,
    required this.semanticLabel,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: GSSpacing.s1),
      child: GSPressable(
        onTap: onTap,
        semanticLabel: semanticLabel,
        child: Column(
          children: [
            Container(
              height: 64,
              width: double.infinity,
              decoration: BoxDecoration(
                color: GSColors.brandTint,
                borderRadius: BorderRadius.circular(GSRadius.lg),
              ),
              child: Icon(icon, size: 30, color: GSColors.brand),
            ),
            const SizedBox(height: 6),
            MediaQuery.withClampedTextScaling(
              maxScaleFactor: 1.4,
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: GSFonts.sans,
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: GSColors.text,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Acción secundaria de la hoja: tarjeta gris con ícono, título y detalle.
class _SheetAction extends StatelessWidget {
  const _SheetAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return GSPressable(
      onTap: onTap,
      semanticLabel: '$title. $subtitle',
      child: Container(
        padding: const EdgeInsets.all(GSSpacing.s4),
        decoration: BoxDecoration(
          color: GSColors.background,
          borderRadius: BorderRadius.circular(GSRadius.lg),
        ),
        child: Row(
          children: [
            Icon(icon, color: GSColors.brand, size: 26),
            const SizedBox(width: GSSpacing.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: text.titleMedium),
                  const SizedBox(height: 2),
                  Text(subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: text.bodySmall),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: GSColors.textMuted),
          ],
        ),
      ),
    );
  }
}
