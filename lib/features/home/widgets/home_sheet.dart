// lib/features/home/widgets/home_sheet.dart
// Contenido de la hoja inferior del inicio (DS1): "¿A dónde vas?",
// lugares rápidos y, en modo invitado, la invitación a crear cuenta.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../providers/auth_provider.dart';
import '../../../router/app_router.dart';
import '../../../theme/design_tokens.dart';
import '../../../widgets/gs_list_row.dart';
import '../../../widgets/gs_route_plate.dart';
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
          // La placa en blanco: el destino se "pinta" en el planificador.
          child: GSRoutePlate(
            text: '¿A dónde vas?',
            isPlaceholder: true,
            leading: Icons.search_rounded,
            onTap: () => context.push(AppRoutes.routePlanner),
          ),
        ),
        const SizedBox(height: GSSpacing.s3),
        QuickPlacesRow(
          onPlaceSelected: (_) => context.push(AppRoutes.routePlanner),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
              GSSpacing.s4, GSSpacing.s2, GSSpacing.s4, GSSpacing.s3),
          child: Text(
            'También puedes mantener presionado el mapa para elegir un punto.',
            style: text.bodySmall,
          ),
        ),
        const Divider(),
        GSListRow(
          icon: Icons.chat_bubble_outline_rounded,
          title: 'Pregúntale al asistente',
          subtitle: 'Cómo llegar, cuánto cuesta, cómo está la vía',
          onTap: () => context.push(AppRoutes.aiChat),
        ),
        if (isGuest) ...[
          const Divider(),
          GSListRow(
            icon: Icons.person_outline_rounded,
            title: 'Entrar o crear cuenta',
            subtitle: 'Para reportar la vía, pedir mototaxi o pagar',
            onTap: () => context.push(AppRoutes.login),
          ),
        ],
        SizedBox(
          height: MediaQuery.of(context).padding.bottom +
              GSSpacing.s4,
        ),
      ],
    );
  }
}
