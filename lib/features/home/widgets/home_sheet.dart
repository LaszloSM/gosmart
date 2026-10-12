// lib/features/home/widgets/home_sheet.dart
// Contenido de la hoja inferior del inicio (DS1): "¿A dónde vas?",
// lugares rápidos y, en modo invitado, la invitación a crear cuenta.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers/auth_provider.dart';
import '../../../router/app_router.dart';
import '../../../theme/design_tokens.dart';
import '../../../widgets/gs_text_field.dart';
import 'quick_places_row.dart';

class HomeSheetContent extends ConsumerWidget {
  const HomeSheetContent({super.key, this.scrollController});

  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGuest = ref.watch(isGuestProvider);
    final text = Theme.of(context).textTheme;

    return ListView(
      controller: scrollController,
      padding: EdgeInsets.zero,
      children: [
        Center(
          child: Container(
            width: 40,
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
          child: GSSearchBar(
            hint: '¿A dónde vas?',
            readOnly: true,
            onTap: () => context.push(AppRoutes.routePlanner),
          ),
        ),
        const SizedBox(height: GSSpacing.s3),
        QuickPlacesRow(
          onPlaceSelected: (_) => context.push(AppRoutes.routePlanner),
        ),
        const SizedBox(height: GSSpacing.s3),
        const Divider(),
        _SheetRow(
          icon: Icons.chat_bubble_outline_rounded,
          title: 'Pregúntale al asistente',
          subtitle: 'Cómo llegar, cuánto cuesta, cómo está la vía',
          onTap: () => context.push(AppRoutes.aiChat),
        ),
        if (isGuest) ...[
          const Divider(),
          _SheetRow(
            icon: Icons.person_outline_rounded,
            title: 'Entrar o crear cuenta',
            subtitle: 'Para reportar la vía, pedir mototaxi o pagar',
            onTap: () => context.push(AppRoutes.login),
          ),
        ],
        const Divider(),
        Padding(
          padding: const EdgeInsets.fromLTRB(
              GSSpacing.s4, GSSpacing.s3, GSSpacing.s4, 0),
          child: Text(
            'Mantén presionado el mapa para elegir un punto.',
            style: text.bodySmall,
          ),
        ),
        SizedBox(
          height: GSSize.bottomNav +
              MediaQuery.of(context).padding.bottom +
              GSSpacing.s4,
        ),
      ],
    );
  }
}

/// Fila plana con divisor (DESIGN.md: sin tarjetas por defecto).
class _SheetRow extends StatelessWidget {
  const _SheetRow({
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
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 64),
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: GSSpacing.s4, vertical: GSSpacing.s3),
          child: Row(
            children: [
              Icon(icon, color: GSColors.brand),
              const SizedBox(width: GSSpacing.s3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(title, style: text.titleMedium),
                    Text(
                      subtitle,
                      style: text.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded,
                  color: GSColors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}
