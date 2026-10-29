// lib/features/wallet/widgets/balance_header.dart
// Saldo de la billetera como en Nequi: banda azul honda con el saldo grande,
// un ojo para ocultarlo en la calle, el aviso de que el saldo es de prueba y
// las acciones redondas debajo.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/money.dart';
import '../../../providers/wallet_provider.dart';
import '../../../theme/design_tokens.dart';
import '../../../widgets/gs_skeleton_loader.dart';
import '../../../widgets/gs_brand_hero.dart';
import '../../../widgets/gs_inline_error.dart';

class BalanceHeader extends ConsumerStatefulWidget {
  const BalanceHeader({super.key, required this.actions});

  /// Acciones redondas bajo el saldo (Recargar, Pagar con QR…).
  final List<Widget> actions;

  @override
  ConsumerState<BalanceHeader> createState() => _BalanceHeaderState();
}

class _BalanceHeaderState extends ConsumerState<BalanceHeader> {
  /// Ocultar el saldo (se usa en la calle, con gente alrededor).
  bool _hidden = false;

  @override
  Widget build(BuildContext context) {
    final walletAsync = ref.watch(walletProvider);
    final on = GSColors.onBrandDeep;
    final onMuted = GSColors.onBrandDeepMuted;

    return GSBrandHero(
      // Sin título: la pestaña ya dice "Billetera"; la línea de arriba es el
      // saldo con su ojo (el ojo abierto = se está viendo).
      trailing: null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          walletAsync.when(
            skipLoadingOnRefresh: true,
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: GSSpacing.s3),
              child:
                  GSSkeletonLoader(width: 200, height: 44, radius: GSRadius.sm),
            ),
            error: (_, __) => _OnHero(
              child: GSInlineError(
                message: 'No pudimos cargar tu saldo',
                onRetry: () => ref.invalidate(walletProvider),
              ),
            ),
            data: (wallet) {
              if (wallet == null) {
                return _OnHero(
                  child: GSInlineError(
                    message: 'Tu billetera aún no está lista',
                    onRetry: () => ref.invalidate(walletProvider),
                  ),
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
                            fontWeight: FontWeight.w700,
                            color: onMuted,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: _hidden ? 'Mostrar saldo' : 'Ocultar saldo',
                        onPressed: () => setState(() => _hidden = !_hidden),
                        icon: Icon(
                          _hidden
                              ? Icons.visibility_off_rounded
                              : Icons.visibility_rounded,
                          color: on,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: GSSpacing.s1),
                  // Cuando el saldo cambia (una recarga, un pago) cuenta hasta
                  // la cifra nueva en 600 ms; al abrir la pantalla no se anima.
                  TweenAnimationBuilder<double>(
                    tween: Tween(end: wallet.balance.toDouble()),
                    duration: MediaQuery.of(context).disableAnimations
                        ? Duration.zero
                        : const Duration(milliseconds: 600),
                    curve: GSCurve.enter,
                    builder: (context, v, _) => FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text.rich(
                        TextSpan(children: [
                          TextSpan(
                            text: _hidden ? r'$ • • • • •' : formatCop(v.round()),
                            style: TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.w800,
                              letterSpacing: -1.2,
                              height: 1.05,
                              color: on,
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
                  ),
                  const SizedBox(height: GSSpacing.s3),
                  Wrap(
                    spacing: GSSpacing.s2,
                    runSpacing: GSSpacing.s2,
                    children: [
                      // PRODUCT.md: las recargas simuladas nunca se
                      // presentan como dinero real.
                      _CardTag(
                        icon: Icons.info_rounded,
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
                ],
              );
            },
          ),
          const SizedBox(height: GSSpacing.s6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final a in widget.actions) Expanded(child: a),
            ],
          ),
        ],
      ),
    );
  }
}

/// Error sobre la banda: se pinta en una tarjeta clara para que se lea.
class _OnHero extends StatelessWidget {
  const _OnHero({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(GSSpacing.s3),
      decoration: BoxDecoration(
        color: GSColors.surface,
        borderRadius: BorderRadius.circular(GSRadius.md),
      ),
      child: child,
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
          Icon(icon, size: GSSize.iconSm, color: color),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: GSFonts.sans,
                fontFeatures: tabular ? GSFonts.tabular : null,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
