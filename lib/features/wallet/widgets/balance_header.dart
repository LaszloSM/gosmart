// lib/features/wallet/widgets/balance_header.dart
// Saldo de la billetera como en Nequi: tarjeta azul con el saldo grande, un
// ojo para ocultarlo en la calle y el aviso de que el saldo es de prueba.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money.dart';
import '../../../providers/wallet_provider.dart';
import '../../../theme/design_tokens.dart';
import '../../../widgets/gs_skeleton_loader.dart';
import '../../../widgets/gs_inline_error.dart';

class BalanceHeader extends ConsumerStatefulWidget {
  const BalanceHeader({super.key});

  @override
  ConsumerState<BalanceHeader> createState() => _BalanceHeaderState();
}

class _BalanceHeaderState extends ConsumerState<BalanceHeader> {
  /// Ocultar el saldo (se usa en la calle, con gente alrededor).
  bool _hidden = false;

  @override
  Widget build(BuildContext context) {
    final walletAsync = ref.watch(walletProvider);
    final on = GSColors.isDark ? GSColors.text : GSColors.onBrand;
    final onMuted = GSColors.isDark ? GSColors.textMuted : GSColors.onBrandMuted;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
          GSSpacing.s4, GSSpacing.s2, GSSpacing.s4, GSSpacing.s4),
      child: Container(
        padding: const EdgeInsets.fromLTRB(
            GSSpacing.s5, GSSpacing.s4, GSSpacing.s2, GSSpacing.s5),
        decoration: BoxDecoration(
          // De noche, superficie con borde: un bloque azul claro encandila.
          color: GSColors.isDark ? GSColors.brandTint : GSColors.brand,
          borderRadius: BorderRadius.circular(GSRadius.xl),
        ),
        child: walletAsync.when(
          skipLoadingOnRefresh: true,
          loading: () => const Padding(
            padding: EdgeInsets.symmetric(vertical: GSSpacing.s3),
            child: GSSkeletonLoader(width: 200, height: 44, radius: GSRadius.sm),
          ),
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Saldo disponible',
                        style: TextStyle(
                          fontFamily: GSFonts.sans,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: onMuted,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: _hidden ? 'Mostrar saldo' : 'Ocultar saldo',
                      onPressed: () => setState(() => _hidden = !_hidden),
                      icon: Icon(
                        _hidden
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        color: on,
                      ),
                    ),
                  ],
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text.rich(
                    TextSpan(children: [
                      TextSpan(
                        text: _hidden ? r'$ • • • • •' : formatCop(wallet.balance),
                        style: TextStyle(
                          fontSize: 38,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.8,
                          color: on,
                        ),
                      ),
                      TextSpan(
                        text: '  COP',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: onMuted,
                        ),
                      ),
                    ]),
                    style: const TextStyle(
                        fontFamily: GSFonts.mono,
                        fontFeatures: GSFonts.tabular),
                    semanticsLabel: _hidden
                        ? 'Saldo oculto'
                        : 'Saldo ${formatCop(wallet.balance)} pesos',
                  ),
                ),
                const SizedBox(height: GSSpacing.s3),
                Padding(
                  padding: const EdgeInsets.only(right: GSSpacing.s3),
                  child: Wrap(
                    spacing: GSSpacing.s2,
                    runSpacing: GSSpacing.s2,
                    children: [
                      // PRODUCT.md: las recargas simuladas nunca se
                      // presentan como dinero real.
                      _CardTag(
                        icon: Icons.science_outlined,
                        label: 'Saldo de prueba',
                        color: on,
                      ),
                      _CardTag(
                        icon: wallet.cardStatus == 'active'
                            ? Icons.credit_card_rounded
                            : Icons.lock_rounded,
                        label: '${wallet.maskedCardNumber}'
                            '${wallet.cardStatus == 'active' ? '' : ' · bloqueada'}',
                        color: on,
                        tabular: true,
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _CardTag extends StatelessWidget {
  const _CardTag({
    required this.icon,
    required this.label,
    required this.color,
    this.tabular = false,
  });
  final IconData icon;
  final String label;
  final Color color;
  final bool tabular;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(GSRadius.full),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            softWrap: false,
            style: TextStyle(
              fontFamily: GSFonts.sans,
              fontFeatures: tabular ? GSFonts.tabular : null,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
