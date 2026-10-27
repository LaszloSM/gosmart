// lib/features/home/widgets/home_sheet.dart
// Hoja inferior del inicio, como Uber/DiDi: saludo, buscador "¿A dónde vas?",
// accesos Casa/Trabajo, servicios en rejilla desigual y, más abajo, el
// asistente y (en modo invitado) la invitación a crear cuenta.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers/auth_provider.dart';
import '../../../providers/profile_provider.dart';
import '../../../providers/selected_mode_provider.dart';
import '../../../router/app_router.dart';
import '../../../theme/design_tokens.dart';
import '../../../widgets/gs_mode_visual.dart';
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

    final firstName = isGuest
        ? null
        : ref
            .watch(profileProvider)
            .valueOrNull
            ?.name
            .trim()
            .split(RegExp(r'\s+'))
            .first;

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
                    top: GSSpacing.s3, bottom: GSSpacing.s3),
                decoration: BoxDecoration(
                  color: GSColors.line,
                  borderRadius: BorderRadius.circular(GSRadius.full),
                ),
              ),
            ),
            // Solo el nombre: la pregunta ya la hace el buscador.
            if (firstName != null && firstName.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    GSSpacing.s5, 0, GSSpacing.s5, GSSpacing.s3),
                child: Text(
                  'Hola, $firstName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: text.headlineSmall,
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: GSSpacing.s4),
              child: _SearchPill(onTap: openPlanner),
            ),
            const SizedBox(height: GSSpacing.s3),
            QuickPlacesRow(onPlaceSelected: (_) => openPlanner()),
            const SizedBox(height: GSSpacing.s5),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: GSSpacing.s4),
              child: _ServiceBento(onPick: openPlanner),
            ),
            const SizedBox(height: GSSpacing.s2),
          ],
        ),
        // Lo de abajo empieza con aire: en reposo no asoma cortado sobre la barra.
        Padding(
          padding: const EdgeInsets.fromLTRB(
              GSSpacing.s4, GSSpacing.s8, GSSpacing.s4, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: _ServiceTile(
                      mode: 'Intermunicipal',
                      title: 'Intermunicipal',
                      detail: 'Riohacha – Maicao',
                      onTap: () => openPlanner('Intermunicipal'),
                    ),
                  ),
                  const SizedBox(width: GSSpacing.s2),
                  Expanded(
                    child: _ServiceTile(
                      mode: 'TransPadilla',
                      title: 'TransPadilla',
                      detail: 'Bus urbano',
                      onTap: () => openPlanner('TransPadilla'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: GSSpacing.s6),
              _AssistantCard(onTap: () => context.push(AppRoutes.aiChat)),
              if (isGuest) ...[
                const SizedBox(height: GSSpacing.s3),
                _SheetAction(
                  icon: Icons.person_add_alt_1_rounded,
                  title: 'Entra o crea tu cuenta',
                  subtitle: 'Para reportar la vía, pedir mototaxi o pagar',
                  onTap: () => context.push(AppRoutes.login),
                ),
              ],
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

/// Buscador (Uber/Google Maps): píldora hundida con la lupa en un círculo de
/// marca, que es la acción principal de la hoja. Abre el planificador.
class _SearchPill extends StatelessWidget {
  const _SearchPill({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GSPressable(
      onTap: onTap,
      semanticLabel: '¿A dónde vas? Buscar destino',
      child: Container(
        constraints: const BoxConstraints(minHeight: 60),
        padding: const EdgeInsets.fromLTRB(
            GSSpacing.s2, GSSpacing.s2, GSSpacing.s2, GSSpacing.s2),
        decoration: BoxDecoration(
          color: GSColors.surfaceSunken,
          borderRadius: BorderRadius.circular(GSRadius.full),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: GSColors.brand,
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.search_rounded,
                  color: GSColors.onBrand, size: 24),
            ),
            const SizedBox(width: GSSpacing.s3),
            Expanded(
              child: Text(
                '¿A dónde vas?',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: GSFonts.sans,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: GSColors.text,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: GSSpacing.s3, vertical: GSSpacing.s2),
              decoration: BoxDecoration(
                color: GSColors.surface,
                borderRadius: BorderRadius.circular(GSRadius.full),
                boxShadow: GSShadow.sm,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.schedule_rounded,
                      size: GSSize.iconMd, color: GSColors.text),
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

/// Servicios en rejilla desigual (DiDi/Uber): el mototaxi, que es lo que más
/// se pide en Riohacha, ocupa la tarjeta grande; taxi y colectivo, al lado.
class _ServiceBento extends StatelessWidget {
  const _ServiceBento({required this.onPick});
  final void Function(String mode) onPick;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 11,
            child: _HeroServiceTile(onTap: () => onPick('Mototaxi')),
          ),
          const SizedBox(width: GSSpacing.s2),
          Expanded(
            flex: 10,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: _ServiceTile(
                    mode: 'Taxi',
                    title: 'Taxi',
                    detail: 'Tarifa oficial',
                    onTap: () => onPick('Taxi'),
                  ),
                ),
                const SizedBox(height: GSSpacing.s2),
                Expanded(
                  child: _ServiceTile(
                    mode: 'Colectivo',
                    title: 'Colectivo',
                    detail: 'Por cupo',
                    onTap: () => onPick('Colectivo'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta grande del mototaxi: nombre, una línea y la moto grande abajo,
/// saliendo del borde como en las apps de referencia.
class _HeroServiceTile extends StatelessWidget {
  const _HeroServiceTile({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GSPressable(
      onTap: onTap,
      semanticLabel: 'Mototaxi. Pide uno ya',
      child: Container(
        constraints: const BoxConstraints(minHeight: 128),
        decoration: BoxDecoration(
          color: GSColors.brandTint,
          borderRadius: BorderRadius.circular(GSRadius.lg),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            const Positioned(
              right: -8,
              bottom: 4,
              child: GSModeVisual(mode: 'Mototaxi', height: 62),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  GSSpacing.s4, GSSpacing.s4, GSSpacing.s3, 64),
              child: MediaQuery.withClampedTextScaling(
                maxScaleFactor: 1.4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Mototaxi',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: GSFonts.sans,
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                        color: GSColors.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            'Pide uno ya',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: GSFonts.sans,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                              color: GSColors.brand,
                            ),
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(Icons.arrow_forward_rounded,
                            size: GSSize.iconSm, color: GSColors.brand),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Servicio pequeño: nombre y una línea a la izquierda, el vehículo a la
/// derecha. Elige el modo y abre el planificador.
class _ServiceTile extends StatelessWidget {
  const _ServiceTile({
    required this.mode,
    required this.title,
    required this.detail,
    required this.onTap,
  });
  final String mode;
  final String title;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GSPressable(
      onTap: onTap,
      semanticLabel: '$title. $detail',
      child: Container(
        constraints: const BoxConstraints(minHeight: 60),
        decoration: BoxDecoration(
          color: GSColors.surfaceSunken,
          borderRadius: BorderRadius.circular(GSRadius.lg),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // El vehículo asoma por la esquina; el nombre tiene todo el ancho.
            Positioned(
              right: -6,
              bottom: 2,
              child: GSModeVisual(mode: mode, height: 30),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  GSSpacing.s3, GSSpacing.s2, GSSpacing.s2, GSSpacing.s2),
              child: MediaQuery.withClampedTextScaling(
                maxScaleFactor: 1.4,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: GSFonts.sans,
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                        color: GSColors.text,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(right: 44),
                      child: Text(
                        detail,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: GSFonts.sans,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          color: GSColors.textMuted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// El asistente en la cabecera honda de la marca: es la otra forma de
/// planear, así que se distingue de las acciones grises.
class _AssistantCard extends StatelessWidget {
  const _AssistantCard({required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GSPressable(
      onTap: onTap,
      semanticLabel:
          'Pregúntale al asistente. Cómo llegar, cuánto cuesta, cómo está la vía',
      child: Container(
        padding: const EdgeInsets.all(GSSpacing.s4),
        decoration: BoxDecoration(
          color: GSColors.brandDeep,
          borderRadius: BorderRadius.circular(GSRadius.lg),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: GSColors.onBrandDeep.withValues(alpha: 0.14),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.auto_awesome_rounded,
                  color: GSColors.onBrandDeep, size: 22),
            ),
            const SizedBox(width: GSSpacing.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pregúntale al asistente',
                    style: TextStyle(
                      fontFamily: GSFonts.sans,
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: GSColors.onBrandDeep,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '"¿Cuánto cuesta un mototaxi a la Uniguajira?"',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: GSFonts.sans,
                      fontSize: 13.5,
                      height: 1.35,
                      color: GSColors.onBrandDeepMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: GSSpacing.s2),
            Icon(Icons.arrow_forward_rounded, color: GSColors.onBrandDeep),
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
