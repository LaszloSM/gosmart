import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/gs_button.dart';
import '../../widgets/gs_card.dart';
import '../../widgets/gs_bottom_sheet.dart';
import '../../widgets/gs_toast.dart';

class WalletScreen extends StatefulWidget {
  const WalletScreen({super.key});

  @override
  State<WalletScreen> createState() => _WalletScreenState();
}

class _WalletScreenState extends State<WalletScreen>
    with SingleTickerProviderStateMixin {
  bool _cardLocked = false;
  bool _showNumber = false;
  bool _useNfc = true;
  late final TabController _tabCtrl;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: GSColors.bg,
      appBar: AppBar(
        title: const Text('My Wallet'),
        leading: const BackButton(),
        actions: [
          IconButton(
            icon: Icon(
              _cardLocked ? Icons.lock_rounded : Icons.lock_open_rounded,
              color: _cardLocked ? GSColors.error : GSColors.textSecondary,
            ),
            tooltip: _cardLocked ? 'Unlock card' : 'Lock card',
            onPressed: () {
              setState(() => _cardLocked = !_cardLocked);
              GSToast.show(
                context,
                message: _cardLocked
                    ? 'Card locked successfully'
                    : 'Card unlocked',
                type: _cardLocked ? GSToastType.warning : GSToastType.success,
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(GSSpacing.s5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Physical / NFC card ─────────────────────────────────────────
            _SmartCard(
              locked: _cardLocked,
              showNumber: _showNumber,
              onToggleNumber: () => setState(() => _showNumber = !_showNumber),
            ),
            const SizedBox(height: GSSpacing.s5),

            // ── NFC / QR toggle ─────────────────────────────────────────────
            _PaymentModeToggle(
              useNfc: _useNfc,
              onToggle: (v) => setState(() => _useNfc = v),
            ),
            const SizedBox(height: GSSpacing.s5),

            // ── Quick actions ────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: GSButton(
                    label: 'Top up',
                    onPressed: () => _showTopUpSheet(context),
                    leadingIcon: Icons.add_rounded,
                    size: GSButtonSize.md,
                  ),
                ),
                const SizedBox(width: GSSpacing.s3),
                Expanded(
                  child: GSButton(
                    label: 'Send',
                    onPressed: () {},
                    leadingIcon: Icons.send_rounded,
                    variant: GSButtonVariant.outline,
                    size: GSButtonSize.md,
                  ),
                ),
              ],
            ),
            const SizedBox(height: GSSpacing.s5),

            // ── Linked payment methods ───────────────────────────────────────
            Text('Payment methods',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: GSSpacing.s3),
            ..._paymentMethods.map((m) => _PaymentMethodTile(method: m)),
            const SizedBox(height: GSSpacing.s3),
            GSButton(
              label: 'Add payment method',
              onPressed: () {},
              variant: GSButtonVariant.secondary,
              leadingIcon: Icons.add_rounded,
            ),
            const SizedBox(height: GSSpacing.s5),

            // ── Card controls ────────────────────────────────────────────────
            Text('Card controls',
                style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: GSSpacing.s3),
            GSCard(
              padding: const EdgeInsets.all(GSSpacing.s4),
              child: Column(
                children: [
                  _ControlRow(
                    icon: Icons.lock_rounded,
                    label: 'Lock card',
                    sublabel: 'Temporarily disable card',
                    iconColor: GSColors.error,
                    trailing: Switch(
                      value: _cardLocked,
                      activeColor: GSColors.error,
                      onChanged: (v) => setState(() => _cardLocked = v),
                    ),
                  ),
                  const Divider(height: 1),
                  _ControlRow(
                    icon: Icons.report_problem_rounded,
                    label: 'Report lost/stolen',
                    sublabel: 'Block and request new card',
                    iconColor: GSColors.warning,
                    trailing: const Icon(Icons.arrow_forward_ios_rounded,
                        size: 14, color: GSColors.textDisabled),
                    onTap: () {},
                  ),
                  const Divider(height: 1),
                  _ControlRow(
                    icon: Icons.contactless_rounded,
                    label: 'NFC payments',
                    sublabel: 'Use phone as card',
                    iconColor: GSColors.primary,
                    trailing: Switch(
                      value: _useNfc,
                      activeColor: GSColors.primary,
                      onChanged: (v) => setState(() => _useNfc = v),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showTopUpSheet(BuildContext context) {
    GSBottomSheet.show(
      context: context,
      title: 'Top up credit',
      initialChildSize: 0.60,
      child: Column(
        children: [
          // Amounts
          Wrap(
            spacing: GSSpacing.s3,
            runSpacing: GSSpacing.s3,
            children: ['\$5', '\$10', '\$20', '\$50', '\$100'].map((a) {
              return ChoiceChip(
                label: Text(a,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 15)),
                selected: false,
                onSelected: (_) {},
                selectedColor: GSColors.primaryLight,
                backgroundColor: GSColors.surface2,
                padding: const EdgeInsets.symmetric(
                    horizontal: GSSpacing.s4, vertical: GSSpacing.s2),
              );
            }).toList(),
          ),
          const SizedBox(height: GSSpacing.s5),
          const Divider(),
          const SizedBox(height: GSSpacing.s4),
          GSButton(
            label: 'Pay with Apple Pay',
            onPressed: () => Navigator.pop(context),
            leadingIcon: Icons.apple_rounded,
          ),
          const SizedBox(height: GSSpacing.s3),
          GSButton(
            label: 'Pay with card',
            onPressed: () => Navigator.pop(context),
            variant: GSButtonVariant.outline,
            leadingIcon: Icons.credit_card_rounded,
          ),
        ],
      ),
    );
  }

  static const _paymentMethods = [
    _PaymentMethod('Visa •••• 4242', 'Expires 03/26', Icons.credit_card_rounded, GSColors.primary),
    _PaymentMethod('Apple Pay', 'Default', Icons.apple_rounded, GSColors.textPrimary),
  ];
}

// ─── Smart Card widget ────────────────────────────────────────────────────────

class _SmartCard extends StatelessWidget {
  const _SmartCard({
    required this.locked,
    required this.showNumber,
    required this.onToggleNumber,
  });
  final bool locked;
  final bool showNumber;
  final VoidCallback onToggleNumber;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.586,
      child: AnimatedContainer(
        duration: GSDuration.normal,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(GSRadius.xl),
          gradient: LinearGradient(
            colors: locked
                ? [const Color(0xFF6B7280), const Color(0xFF374151)]
                : [GSColors.primary, const Color(0xFF1A3FCC)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: locked
              ? [
                  BoxShadow(
                      color: Colors.grey.withOpacity(0.3),
                      blurRadius: 20,
                      offset: const Offset(0, 8))
                ]
              : GSShadow.primary,
        ),
        padding: const EdgeInsets.all(GSSpacing.s6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('GoSmart',
                        style: TextStyle(
                            
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800)),
                    Text('Transit Card',
                        style: TextStyle(
                            color: Colors.white60, fontSize: 12)),
                  ],
                ),
                if (locked)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: GSColors.error.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(GSRadius.full),
                      border: Border.all(color: GSColors.error),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.lock_rounded,
                            size: 12, color: Colors.white),
                        SizedBox(width: 4),
                        Text('LOCKED',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700)),
                      ],
                    ),
                  )
                else
                  const Icon(Icons.contactless_rounded,
                      color: Colors.white60, size: 32),
              ],
            ),
            const Spacer(),
            // Card number
            GestureDetector(
              onTap: onToggleNumber,
              child: Row(
                children: [
                  Text(
                    showNumber
                        ? '4242  4242  4242  4242'
                        : '••••  ••••  ••••  4242',
                    style: const TextStyle(
                      
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    showNumber ? Icons.visibility_off : Icons.visibility,
                    color: Colors.white54,
                    size: 16,
                  ),
                ],
              ),
            ),
            const SizedBox(height: GSSpacing.s4),
            // Bottom row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Balance',
                        style: TextStyle(color: Colors.white60, fontSize: 11)),
                    Text('\$100.00',
                        style: TextStyle(
                            
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w700)),
                  ],
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Valid thru',
                        style: TextStyle(
                            color: Colors.white60, fontSize: 11)),
                    const Text('12/28',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── NFC / QR toggle ─────────────────────────────────────────────────────────

class _PaymentModeToggle extends StatelessWidget {
  const _PaymentModeToggle({
    required this.useNfc,
    required this.onToggle,
  });
  final bool useNfc;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    return GSCard(
      padding: const EdgeInsets.all(GSSpacing.s4),
      child: Column(
        children: [
          Row(
            children: [
              _ModeBtn(
                icon: Icons.contactless_rounded,
                label: 'Tap to Pay (NFC)',
                selected: useNfc,
                color: GSColors.primary,
                onTap: () => onToggle(true),
              ),
              const SizedBox(width: GSSpacing.s3),
              _ModeBtn(
                icon: Icons.qr_code_rounded,
                label: 'QR Code',
                selected: !useNfc,
                color: GSColors.eco,
                onTap: () => onToggle(false),
              ),
            ],
          ),
          const SizedBox(height: GSSpacing.s4),
          if (useNfc) ...[
            Container(
              padding: const EdgeInsets.all(GSSpacing.s4),
              decoration: BoxDecoration(
                color: GSColors.primaryLight,
                borderRadius: BorderRadius.circular(GSRadius.lg),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.contactless_rounded,
                      color: GSColors.primary, size: 32),
                  SizedBox(width: GSSpacing.s3),
                  Text('Hold phone near validator',
                      style: TextStyle(
                        
                        color: GSColors.primary,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      )),
                ],
              ),
            ),
          ] else ...[
            Container(
              width: 160,
              height: 160,
              decoration: BoxDecoration(
                color: GSColors.surface2,
                borderRadius: BorderRadius.circular(GSRadius.lg),
              ),
              child: const Icon(Icons.qr_code_2_rounded,
                  size: 120, color: GSColors.textPrimary),
            ),
            const SizedBox(height: GSSpacing.s2),
            const Text('Temporary QR — expires in 5:00',
                style: TextStyle(
                    fontSize: 12, color: GSColors.textSecondary)),
          ],
        ],
      ),
    );
  }
}

class _ModeBtn extends StatelessWidget {
  const _ModeBtn({
    required this.icon,
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: GSDuration.normal,
          padding: const EdgeInsets.symmetric(
              horizontal: GSSpacing.s3, vertical: GSSpacing.s3),
          decoration: BoxDecoration(
            color: selected ? color.withOpacity(0.10) : GSColors.surface2,
            borderRadius: BorderRadius.circular(GSRadius.md),
            border: Border.all(
              color: selected ? color : Colors.transparent,
              width: 1.5,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon,
                  size: 18, color: selected ? color : GSColors.textSecondary),
              const SizedBox(width: 6),
              Flexible(
                child: Text(label,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: selected ? color : GSColors.textSecondary)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PaymentMethodTile extends StatelessWidget {
  const _PaymentMethodTile({required this.method});
  final _PaymentMethod method;

  @override
  Widget build(BuildContext context) {
    return GSCard(
      margin: const EdgeInsets.only(bottom: GSSpacing.s3),
      padding: const EdgeInsets.all(GSSpacing.s4),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: method.color.withOpacity(0.10),
              borderRadius: BorderRadius.circular(GSRadius.sm),
            ),
            child: Icon(method.icon, color: method.color, size: 22),
          ),
          const SizedBox(width: GSSpacing.s3),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(method.label,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: GSColors.textPrimary)),
                Text(method.sublabel,
                    style: const TextStyle(
                        fontSize: 12, color: GSColors.textSecondary)),
              ],
            ),
          ),
          const Icon(Icons.arrow_forward_ios_rounded,
              size: 14, color: GSColors.textDisabled),
        ],
      ),
    );
  }
}

class _ControlRow extends StatelessWidget {
  const _ControlRow({
    required this.icon,
    required this.label,
    required this.sublabel,
    required this.iconColor,
    required this.trailing,
    this.onTap,
  });
  final IconData icon;
  final String label;
  final String sublabel;
  final Color iconColor;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: GSSpacing.s3),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.10),
                borderRadius: BorderRadius.circular(GSRadius.sm),
              ),
              child: Icon(icon, size: 18, color: iconColor),
            ),
            const SizedBox(width: GSSpacing.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                          color: GSColors.textPrimary)),
                  Text(sublabel,
                      style: const TextStyle(
                          fontSize: 12, color: GSColors.textSecondary)),
                ],
              ),
            ),
            trailing,
          ],
        ),
      ),
    );
  }
}

class _PaymentMethod {
  final String label;
  final String sublabel;
  final IconData icon;
  final Color color;
  const _PaymentMethod(this.label, this.sublabel, this.icon, this.color);
}
