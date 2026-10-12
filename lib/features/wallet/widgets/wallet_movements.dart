// lib/features/wallet/widgets/wallet_movements.dart
// Movimientos de la billetera (antes "Historial"): una sola lista, filas planas.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/wallet_transaction_model.dart';
import '../../../providers/wallet_provider.dart';
import '../../../theme/design_tokens.dart';
import '../../../widgets/gs_skeleton_loader.dart';
import '../../../widgets/gs_inline_error.dart';

/// Movimientos por página.
const walletPageSize = 20;

class WalletMovements extends ConsumerWidget {
  const WalletMovements({
    super.key,
    required this.limit,
    required this.onLoadMore,
  });

  /// Cuántos movimientos pedir; "Ver más" lo aumenta.
  final int limit;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final txAsync = ref.watch(walletTransactionsProvider(limit));
    // Mientras llega la página siguiente se sigue viendo la anterior.
    final previous = limit > walletPageSize
        ? ref.watch(walletTransactionsProvider(limit - walletPageSize))
            .valueOrNull
        : null;

    return txAsync.when(
      skipLoadingOnReload: true,
      loading: () => previous != null
          ? _list(previous, showMore: false)
          : Padding(
        padding: const EdgeInsets.symmetric(horizontal: GSSpacing.s4),
        child: Column(
          children: List.generate(
            3,
            (_) => const Padding(
              padding: EdgeInsets.only(bottom: GSSpacing.s2),
              child: GSTransactionSkeleton(),
            ),
          ),
        ),
      ),
      error: (_, __) => Padding(
        padding: const EdgeInsets.symmetric(horizontal: GSSpacing.s4),
        child: GSInlineError(
          message: 'No pudimos cargar tus movimientos',
          onRetry: () => ref.invalidate(walletTransactionsProvider(limit)),
        ),
      ),
      data: (list) {
        if (list.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: GSSpacing.s4, vertical: GSSpacing.s3),
            child: Text(
              'Aún no tienes movimientos. Cuando recargues o pagues un '
              'viaje, aparecerán aquí.',
              style: text.bodyMedium,
            ),
          );
        }
        // Si llegó la página completa, puede haber más.
        return _list(list, showMore: list.length >= limit);
      },
    );
  }

  Widget _list(List<WalletTransactionModel> list, {required bool showMore}) {
    return Column(
      children: [
        for (var i = 0; i < list.length; i++) ...[
          if (i > 0) const Divider(indent: GSSpacing.s4),
          MovementRow(tx: list[i]),
        ],
        if (showMore)
          TextButton(
            onPressed: onLoadMore,
            child: const Text('Ver más movimientos'),
          ),
      ],
    );
  }
}

class MovementRow extends StatelessWidget {
  const MovementRow({super.key, required this.tx});
  final WalletTransactionModel tx;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final detail = [
      if (tx.description != null && tx.description!.isNotEmpty)
        tx.description!,
      tx.formattedDate,
    ].join(' · ');

    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 64),
      child: Padding(
        padding: const EdgeInsets.symmetric(
            horizontal: GSSpacing.s4, vertical: GSSpacing.s3),
        child: Row(
          children: [
            Icon(tx.icon, color: GSColors.textMuted),
            const SizedBox(width: GSSpacing.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(tx.typeLabel, style: text.titleMedium),
                  Text(
                    detail,
                    style: text.bodySmall,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: GSSpacing.s3),
            Text(
              tx.formattedAmount,
              style: const TextStyle(
                fontFamily: GSFonts.mono, fontFeatures: GSFonts.tabular,
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: GSColors.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
