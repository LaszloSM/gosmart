// lib/features/wallet/widgets/card_controls.dart
// Controles de la tarjeta GoSmart (tabla `cards`). Sin rojo: bloquear no es
// un estado de la vía; se usa la marca y el ícono de candado.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../providers/card_provider.dart';
import '../../../theme/design_tokens.dart';
import '../../../widgets/gs_list_row.dart';
import '../../../widgets/gs_toast.dart';

class CardControls extends ConsumerWidget {
  const CardControls({super.key});

  Future<void> _toggleLock(BuildContext context, WidgetRef ref) async {
    final card = ref.read(activeCardProvider).valueOrNull;
    if (card == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final newLocked = !card.isLocked;
    try {
      await ref
          .read(activeCardProvider.notifier)
          .toggleLock(card.id, newLocked);
      GSToast.showWithMessenger(
        messenger,
        message: newLocked ? 'Tarjeta bloqueada' : 'Tarjeta desbloqueada',
        type: GSToastType.success,
      );
    } catch (_) {
      GSToast.showWithMessenger(
        messenger,
        message: 'No se pudo cambiar el estado. Intenta de nuevo.',
        type: GSToastType.error,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final card = ref.watch(activeCardProvider).valueOrNull;
    if (card == null) return const SizedBox.shrink();

    return GSGroup(
      children: [
        SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: GSSpacing.s4),
          secondary: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: GSColors.surfaceSunken,
              shape: BoxShape.circle,
            ),
            child: Icon(
              card.isLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
              size: GSSize.iconLg,
              color: card.isLocked ? GSColors.brand : GSColors.text,
            ),
          ),
          title: const Text('Bloquear tarjeta'),
          subtitle: Text(card.isLocked
              ? 'Bloqueada. Nadie puede pagar con ella.'
              : 'Desactívala si la perdiste o no la usas.'),
          value: card.isLocked,
          onChanged: (_) => _toggleLock(context, ref),
        ),
        GSListRow(
          icon: Icons.support_agent_rounded,
          title: 'Reportar pérdida',
          subtitle: 'Bloquéala y pide una nueva',
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Contacta con soporte al cliente')),
          ),
        ),
      ],
    );
  }
}
