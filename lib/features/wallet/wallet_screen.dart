// lib/features/wallet/wallet_screen.dart
// Billetera = saldo + recargar/pagar + movimientos + tarjeta. Reemplaza al
// antiguo "Historial": el dinero vive en un solo lugar (`wallets`).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/money.dart';
import '../../providers/wallet_provider.dart';
import '../../router/app_router.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/gs_bottom_nav.dart';
import '../../widgets/gs_bottom_sheet.dart';
import '../../widgets/gs_button.dart';
import '../../widgets/gs_toast.dart';
import 'widgets/balance_header.dart';
import 'widgets/card_controls.dart';
import 'widgets/recharge_sheet.dart';
import 'widgets/wallet_movements.dart';

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
          final ok = await ref
              .read(walletNotifierProvider.notifier)
              .recharge(amount);
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
    final text = Theme.of(context).textTheme;
    final recharging = ref.watch(walletNotifierProvider).isLoading;

    return Scaffold(
      extendBody: true,
      backgroundColor: GSColors.background,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: const Text('Billetera'),
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            const BalanceHeader(),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: GSSpacing.s4),
              child: Row(
                children: [
                  Expanded(
                    child: GSButton(
                      label: 'Recargar',
                      leadingIcon: Icons.add_rounded,
                      isLoading: recharging,
                      onPressed: recharging ? null : _showRechargeSheet,
                    ),
                  ),
                  const SizedBox(width: GSSpacing.s3),
                  Expanded(
                    child: GSButton(
                      label: 'Pagar',
                      leadingIcon: Icons.qr_code_rounded,
                      variant: GSButtonVariant.outline,
                      onPressed: () =>
                          context.push(AppRoutes.paymentValidation),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: GSSpacing.s6),
            _SectionTitle('Movimientos', style: text.titleLarge),
            WalletMovements(
              limit: _limit,
              onLoadMore: () =>
                  setState(() => _limit += walletPageSize),
            ),
            const SizedBox(height: GSSpacing.s6),
            _SectionTitle('Tarjeta GoSmart', style: text.titleLarge),
            const CardControls(),
            SizedBox(
              height: GSSize.bottomNav +
                  MediaQuery.of(context).padding.bottom +
                  GSSpacing.s4,
            ),
          ],
        ),
      ),
      bottomNavigationBar: const GSBottomNav(current: GSNavTab.wallet),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label, {this.style});
  final String label;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
          GSSpacing.s4, 0, GSSpacing.s4, GSSpacing.s2),
      child: Text(label, style: style),
    );
  }
}
