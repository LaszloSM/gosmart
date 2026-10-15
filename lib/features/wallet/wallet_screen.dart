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
import '../../widgets/gs_list_row.dart';
import '../../widgets/gs_pressable.dart';
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
          // Con Wompi activo, la recarga es real (sandbox) y la acredita el webhook.
          if (await paymentService.wompiEnabled()) {
            try {
              final url = await paymentService.wompiCheckout(amount);
              await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
              GSToast.showWithMessenger(messenger,
                  message: 'Cuando Wompi confirme, el saldo aparece aquí.');
            } on PaymentException catch (e) {
              GSToast.showWithMessenger(messenger,
                  message: e.message, type: GSToastType.error);
            }
            return;
          }
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
                    child: _WalletAction(
                      icon: Icons.add_rounded,
                      label: 'Recargar',
                      primary: true,
                      busy: recharging,
                      onTap: recharging ? null : _showRechargeSheet,
                    ),
                  ),
                  const SizedBox(width: GSSpacing.s3),
                  Expanded(
                    child: _WalletAction(
                      icon: Icons.qr_code_scanner_rounded,
                      label: 'Pagar con QR',
                      onTap: () => context.push(AppRoutes.scanPay),
                    ),
                  ),
                ],
              ),
            ),
            const GSSectionTitle('Movimientos'),
            WalletMovements(
              limit: _limit,
              onLoadMore: () =>
                  setState(() => _limit += walletPageSize),
            ),
            const GSSectionTitle('Tarjeta GoSmart'),
            const CardControls(),
            SizedBox(
              height: MediaQuery.of(context).padding.bottom +
                  GSSpacing.s4,
            ),
          ],
        ),
      ),
      bottomNavigationBar: const GSBottomNav(current: GSNavTab.wallet),
    );
  }
}

/// Acción rápida de la billetera (Nequi): tarjeta con un círculo de color
/// y la etiqueta. La primaria va en azul.
class _WalletAction extends StatelessWidget {
  const _WalletAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.primary = false,
    this.busy = false,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool primary;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return GSPressable(
      onTap: onTap,
      semanticLabel: label,
      // Ícono arriba y etiqueta debajo: con texto grande la palabra baja
      // entera a otra línea en vez de partirse ("Reca-rgar").
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: GSSpacing.s2, vertical: GSSpacing.s4),
        decoration: BoxDecoration(
          color: GSColors.surface,
          borderRadius: BorderRadius.circular(GSRadius.lg),
        ),
        child: Column(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: primary ? GSColors.brand : GSColors.brandTint,
                shape: BoxShape.circle,
              ),
              child: busy
                  ? Padding(
                      padding: const EdgeInsets.all(13),
                      child: CircularProgressIndicator(
                          strokeWidth: 2.5, color: GSColors.onBrand),
                    )
                  : Icon(icon,
                      color: primary ? GSColors.onBrand : GSColors.brand),
            ),
            const SizedBox(height: GSSpacing.s2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ],
        ),
      ),
    );
  }
}
