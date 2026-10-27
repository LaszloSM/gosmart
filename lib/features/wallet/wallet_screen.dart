// lib/features/wallet/wallet_screen.dart
// Billetera = saldo + recargar/pagar + movimientos + tarjeta. Reemplaza al
// antiguo "Historial": el dinero vive en un solo lugar (`wallets`).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/money.dart';
import '../../router/app_router.dart';
import '../../services/payment_service.dart';
import '../../providers/wallet_provider.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/gs_bottom_nav.dart';
import '../../widgets/gs_bottom_sheet.dart';
import '../../widgets/gs_brand_hero.dart';
import '../../widgets/gs_list_row.dart';
import '../../widgets/gs_toast.dart';
import 'widgets/balance_header.dart';
import 'widgets/card_controls.dart';
import 'widgets/recharge_sheet.dart';
import 'widgets/wallet_movements.dart';
import '../../widgets/gs_nav_spacer.dart';

class WalletScreen extends ConsumerStatefulWidget {
  const WalletScreen({super.key});

  @override
  ConsumerState<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends ConsumerState<WalletScreen> {
  int _limit = walletPageSize;

  void _showRechargeSheet() {
    GSBottomSheet.show(
      context: context,
      title: 'Recargar saldo',
      initialChildSize: 0.6,
      child: RechargeSheetContent(
        onConfirm: (amount) async {
          Navigator.pop(context);
          final messenger = ScaffoldMessenger.of(context);
          // Con Wompi activo, la recarga es real (sandbox) y la acredita el webhook.
          if (await paymentService.wompiEnabled()) {
            try {
              final url = await paymentService.wompiCheckout(amount);
              await launchUrl(Uri.parse(url),
                  mode: LaunchMode.externalApplication);
              GSToast.showWithMessenger(messenger,
                  message: 'Cuando Wompi confirme, el saldo aparece aquí.');
            } on PaymentException catch (e) {
              GSToast.showWithMessenger(messenger,
                  message: e.message, type: GSToastType.error);
            }
            return;
          }
          final ok =
              await ref.read(walletNotifierProvider.notifier).recharge(amount);
          GSToast.showWithMessenger(
            messenger,
            message: ok
                ? 'Recargaste ${formatCop(amount)}'
                : 'La recarga no se confirmó. Intenta de nuevo.',
            type: ok ? GSToastType.success : GSToastType.error,
          );
        },
      ),
    );
  }

  Future<void> _refresh() async {
    ref.invalidate(walletProvider);
    await ref.read(walletProvider.future).catchError((_) => null);
  }

  @override
  Widget build(BuildContext context) {
    final recharging = ref.watch(walletNotifierProvider).isLoading;

    return Scaffold(
      extendBody: true,
      backgroundColor: GSColors.background,
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            BalanceHeader(actions: [
              GSHeroAction(
                icon: Icons.add_rounded,
                label: 'Recargar',
                primary: true,
                busy: recharging,
                onTap: recharging ? null : _showRechargeSheet,
              ),
              GSHeroAction(
                icon: Icons.qr_code_scanner_rounded,
                label: 'Pagar con QR',
                onTap: () => context.push(AppRoutes.scanPay),
              ),
            ]),
            GSHeroBody(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const GSSectionTitle('Movimientos'),
                  WalletMovements(
                    limit: _limit,
                    onLoadMore: () => setState(() => _limit += walletPageSize),
                  ),
                  const GSSectionTitle('Tarjeta GoSmart'),
                  const CardControls(),
                  const GSNavSpacer(extra: GSSpacing.s4 + GSRadius.xl),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const GSBottomNav(current: GSNavTab.wallet),
    );
  }
}
