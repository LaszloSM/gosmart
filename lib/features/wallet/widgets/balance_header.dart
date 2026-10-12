// lib/features/wallet/widgets/balance_header.dart
// Saldo de la billetera: una sola vez, en mono grande (DESIGN.md mono-display).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money.dart';
import '../../../providers/wallet_provider.dart';
import '../../../theme/design_tokens.dart';
import '../../../widgets/gs_skeleton_loader.dart';
import '../../../widgets/gs_inline_error.dart';

class BalanceHeader extends ConsumerWidget {
  const BalanceHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final walletAsync = ref.watch(walletProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          GSSpacing.s4, GSSpacing.s2, GSSpacing.s4, GSSpacing.s4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Saldo disponible', style: text.labelMedium),
          const SizedBox(height: GSSpacing.s1),
          walletAsync.when(
            skipLoadingOnRefresh: true,
            loading: () => const GSSkeletonLoader(
                width: 180, height: 40, radius: GSRadius.sm),
            error: (_, __) => GSInlineError(
              message: 'No pudimos cargar tu saldo',
              onRetry: () => ref.invalidate(walletProvider),
            ),
            data: (wallet) {
              if (wallet == null) {
                return GSInlineError(
                  message: 'Tu billetera aún no está lista',
                  onRetry: () => ref.invalidate(walletProvider),
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(children: [
                      TextSpan(
                        text: formatCop(wallet.balance),
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: GSColors.text,
                        ),
                      ),
                      TextSpan(
                        text: ' COP',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                          color: GSColors.textMuted,
                        ),
                      ),
                    ]),
                    style: const TextStyle(fontFamily: GSFonts.mono, fontFeatures: GSFonts.tabular),
                    semanticsLabel:
                        'Saldo ${formatCop(wallet.balance)} pesos',
                  ),
                  const SizedBox(height: GSSpacing.s1),
                  // PRODUCT.md: las recargas simuladas nunca se presentan
                  // como dinero real.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Icon(Icons.science_outlined,
                            size: 18, color: GSColors.textMuted),
                      ),
                      const SizedBox(width: GSSpacing.s1),
                      Expanded(
                        child: Text(
                          'Saldo de prueba: las recargas aún son simuladas',
                          style: text.bodySmall,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: GSSpacing.s2),
                  // El número enmascarado nunca se parte en dos líneas.
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'Tarjeta ${wallet.maskedCardNumber}'
                      '${wallet.cardStatus == 'active' ? '' : ' · bloqueada'}',
                      softWrap: false,
                      style: text.bodySmall?.copyWith(
                          fontFamily: GSFonts.mono,
                          fontFeatures: GSFonts.tabular),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
