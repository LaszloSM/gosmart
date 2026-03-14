import 'package:flutter/material.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/gs_button.dart';
import '../../widgets/gs_card.dart';

enum PaymentValidationState { processing, authorized, insufficient, error, offline }

class PaymentValidationScreen extends StatefulWidget {
  const PaymentValidationScreen({super.key});

  @override
  State<PaymentValidationScreen> createState() =>
      _PaymentValidationScreenState();
}

class _PaymentValidationScreenState extends State<PaymentValidationScreen>
    with SingleTickerProviderStateMixin {
  PaymentValidationState _state = PaymentValidationState.processing;
  late final AnimationController _pulseCtrl;

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat(reverse: true);
    _simulateValidation();
  }

  @override
  void dispose() {
    _pulseCtrl.dispose();
    super.dispose();
  }

  Future<void> _simulateValidation() async {
    await Future.delayed(const Duration(seconds: 3));
    if (mounted) {
      setState(() => _state = PaymentValidationState.authorized);
      _pulseCtrl.stop();
    }
  }

  void _setDemo(PaymentValidationState s) => setState(() => _state = s);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bgColor,
      body: SafeArea(
        child: Column(
          children: [
            // Demo state switcher (dev tool)
            if (true) _DemoSwitcher(onSelect: _setDemo),

            Expanded(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(GSSpacing.s8),
                  child: _buildContent(),
                ),
              ),
            ),

            // CTA
            if (_state != PaymentValidationState.processing)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    GSSpacing.s5, 0, GSSpacing.s5, GSSpacing.s6),
                child: _buildCta(context),
              ),
          ],
        ),
      ),
    );
  }

  Color get _bgColor {
    switch (_state) {
      case PaymentValidationState.authorized:
        return GSColors.successLight;
      case PaymentValidationState.insufficient:
        return GSColors.warningLight;
      case PaymentValidationState.error:
        return GSColors.errorLight;
      case PaymentValidationState.offline:
        return GSColors.surfaceDark;
      default:
        return GSColors.bg;
    }
  }

  Widget _buildContent() {
    switch (_state) {
      case PaymentValidationState.processing:
        return _ProcessingView(controller: _pulseCtrl);
      case PaymentValidationState.authorized:
        return const _ResultView(
          icon: Icons.check_circle_rounded,
          iconColor: GSColors.success,
          title: 'Payment Authorized',
          subtitle: 'Have a great trip!',
          amount: '\$2.80',
          detail: 'GoSmart Card ••••4242',
          badgeLabel: 'AUTHORIZED',
          badgeColor: GSColors.success,
        );
      case PaymentValidationState.insufficient:
        return const _ResultView(
          icon: Icons.account_balance_wallet_rounded,
          iconColor: GSColors.warning,
          title: 'Insufficient Balance',
          subtitle: 'Top up your card to continue',
          amount: '\$0.45',
          detail: 'Remaining balance',
          badgeLabel: 'DECLINED',
          badgeColor: GSColors.warning,
        );
      case PaymentValidationState.error:
        return const _ResultView(
          icon: Icons.error_rounded,
          iconColor: GSColors.error,
          title: 'Payment Failed',
          subtitle: 'Please try again or use QR',
          amount: '—',
          detail: 'Validator error #E401',
          badgeLabel: 'ERROR',
          badgeColor: GSColors.error,
        );
      case PaymentValidationState.offline:
        return const _OfflineView();
    }
  }

  Widget _buildCta(BuildContext context) {
    switch (_state) {
      case PaymentValidationState.authorized:
        return GSButton(
          label: 'Done',
          onPressed: () => Navigator.pop(context),
          leadingIcon: Icons.home_rounded,
        );
      case PaymentValidationState.insufficient:
        return Column(
          children: [
            GSButton(
              label: 'Top up now',
              onPressed: () => Navigator.pop(context),
              leadingIcon: Icons.add_rounded,
            ),
            const SizedBox(height: GSSpacing.s3),
            GSButton(
              label: 'Use QR code instead',
              onPressed: () {},
              variant: GSButtonVariant.outline,
              leadingIcon: Icons.qr_code_rounded,
            ),
          ],
        );
      case PaymentValidationState.error:
        return Column(
          children: [
            GSButton(
              label: 'Use QR code',
              onPressed: () {},
              leadingIcon: Icons.qr_code_rounded,
            ),
            const SizedBox(height: GSSpacing.s3),
            GSButton(
              label: 'Try again',
              onPressed: () {
                setState(() => _state = PaymentValidationState.processing);
                _pulseCtrl.repeat(reverse: true);
                _simulateValidation();
              },
              variant: GSButtonVariant.outline,
              leadingIcon: Icons.refresh_rounded,
            ),
          ],
        );
      case PaymentValidationState.offline:
        return GSButton(
          label: 'Generate offline QR',
          onPressed: () {},
          leadingIcon: Icons.qr_code_rounded,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

// ─── Views ────────────────────────────────────────────────────────────────────

class _ProcessingView extends StatelessWidget {
  const _ProcessingView({required this.controller});
  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedBuilder(
          animation: controller,
          builder: (_, child) {
            final scale = 0.85 + (controller.value * 0.15);
            return Transform.scale(
              scale: scale,
              child: Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  color: GSColors.accentLight,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: GSColors.primary
                          .withOpacity(0.20 * controller.value),
                      blurRadius: 40,
                      spreadRadius: 20,
                    ),
                  ],
                ),
                child: const Icon(Icons.contactless_rounded,
                    size: 72, color: GSColors.primary),
              ),
            );
          },
        ),
        const SizedBox(height: GSSpacing.s8),
        const Text('Processing payment...',
            style: TextStyle(
              
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: GSColors.textPrimary,
            )),
        const SizedBox(height: GSSpacing.s3),
        const Text('Hold your phone near the validator',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, color: GSColors.textSecondary)),
        const SizedBox(height: GSSpacing.s8),
        const CircularProgressIndicator(color: GSColors.primary),
      ],
    );
  }
}

class _ResultView extends StatelessWidget {
  const _ResultView({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.detail,
    required this.badgeLabel,
    required this.badgeColor,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String amount;
  final String detail;
  final String badgeLabel;
  final Color badgeColor;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: iconColor.withOpacity(0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 64, color: iconColor),
        ),
        const SizedBox(height: GSSpacing.s5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          decoration: BoxDecoration(
            color: badgeColor,
            borderRadius: BorderRadius.circular(GSRadius.full),
          ),
          child: Text(badgeLabel,
              style: const TextStyle(
                  color: Colors.white,
                  
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  letterSpacing: 1.5)),
        ),
        const SizedBox(height: GSSpacing.s5),
        Text(title,
            style: const TextStyle(
              
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: GSColors.textPrimary,
            )),
        const SizedBox(height: GSSpacing.s2),
        Text(subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 15, color: GSColors.textSecondary)),
        const SizedBox(height: GSSpacing.s6),
        GSCard(
          padding: const EdgeInsets.all(GSSpacing.s5),
          shadow: GSShadow.md,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Amount',
                      style: TextStyle(
                          fontSize: 12, color: GSColors.textSecondary)),
                  Text(amount,
                      style: const TextStyle(
                          
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: GSColors.textPrimary)),
                  Text(detail,
                      style: const TextStyle(
                          fontSize: 12, color: GSColors.textSecondary)),
                ],
              ),
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: GSColors.accentLight,
                  borderRadius: BorderRadius.circular(GSRadius.md),
                ),
                child: const Icon(Icons.credit_card_rounded,
                    color: GSColors.primary, size: 28),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _OfflineView extends StatelessWidget {
  const _OfflineView();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: GSColors.surfaceDark,
            shape: BoxShape.circle,
          ),
          child: const Icon(Icons.wifi_off_rounded,
              size: 64, color: GSColors.textSecondary),
        ),
        const SizedBox(height: GSSpacing.s5),
        const Text('No connection',
            style: TextStyle(
              
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: GSColors.textPrimary,
            )),
        const SizedBox(height: GSSpacing.s3),
        const Text(
          'NFC payment is unavailable offline.\nYou can use a temporary QR code instead.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 14, color: GSColors.textSecondary),
        ),
        const SizedBox(height: GSSpacing.s6),
        // QR Placeholder
        Container(
          width: 180,
          height: 180,
          decoration: BoxDecoration(
            color: GSColors.surface,
            borderRadius: BorderRadius.circular(GSRadius.lg),
            boxShadow: GSShadow.md,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.qr_code_2_rounded,
                  size: 120, color: GSColors.textPrimary),
              const Text('Expires in 5:00',
                  style: TextStyle(
                      fontSize: 11, color: GSColors.textSecondary)),
            ],
          ),
        ),
      ],
    );
  }
}

class _DemoSwitcher extends StatelessWidget {
  const _DemoSwitcher({required this.onSelect});
  final ValueChanged<PaymentValidationState> onSelect;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
          horizontal: GSSpacing.s4, vertical: GSSpacing.s2),
      child: Row(
        children: [
          const Text('Demo: ',
              style: TextStyle(fontSize: 11, color: GSColors.textDisabled)),
          _DemoChip('✓ OK', () => onSelect(PaymentValidationState.authorized)),
          _DemoChip('\$ Low', () => onSelect(PaymentValidationState.insufficient)),
          _DemoChip('✗ Err', () => onSelect(PaymentValidationState.error)),
          _DemoChip('Offline', () => onSelect(PaymentValidationState.offline)),
        ],
      ),
    );
  }
}

class _DemoChip extends StatelessWidget {
  const _DemoChip(this.label, this.onTap);
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(left: 6),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: GSColors.surfaceDark,
          borderRadius: BorderRadius.circular(GSRadius.full),
        ),
        child: Text(label,
            style: const TextStyle(
                fontSize: 11, color: GSColors.textSecondary)),
      ),
    );
  }
}
