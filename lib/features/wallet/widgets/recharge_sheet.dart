// lib/features/wallet/widgets/recharge_sheet.dart
// Elegir monto de recarga. Simulada hasta Wompi (Fase 7): no cobra dinero real.
import 'package:flutter/material.dart';

import '../../../core/money.dart';
import '../../../theme/design_tokens.dart';
import '../../../widgets/gs_button.dart';

class RechargeSheetContent extends StatefulWidget {
  const RechargeSheetContent({super.key, required this.onConfirm});
  final ValueChanged<int> onConfirm;

  @override
  State<RechargeSheetContent> createState() => _RechargeSheetContentState();
}

class _RechargeSheetContentState extends State<RechargeSheetContent> {
  int _selected = 10000;

  // Dentro de los límites de wallet_recharge_simulated (1.000–200.000).
  static const _amounts = [5000, 10000, 20000, 50000, 100000];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Elige cuánto recargar', style: text.bodyMedium),
        const SizedBox(height: GSSpacing.s4),
        Wrap(
          spacing: GSSpacing.s2,
          runSpacing: GSSpacing.s2,
          children: [
            for (final a in _amounts)
              _AmountOption(
                label: formatCop(a),
                selected: _selected == a,
                onTap: () => setState(() => _selected = a),
              ),
          ],
        ),
        const SizedBox(height: GSSpacing.s4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline_rounded,
                size: GSSize.iconMd, color: GSColors.textMuted),
            const SizedBox(width: GSSpacing.s2),
            Expanded(
              child: Text(
                'Recarga de prueba: suma saldo sin cobrar dinero real.',
                style: text.bodySmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: GSSpacing.s4),
        GSButton(
          label: 'Recargar ${formatCop(_selected)}',
          onPressed: () => widget.onConfirm(_selected),
          leadingIcon: Icons.add_rounded,
        ),
      ],
    );
  }
}

class _AmountOption extends StatelessWidget {
  const _AmountOption({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: Material(
        color: selected ? GSColors.brand : GSColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GSRadius.sm),
          side: BorderSide(
            color: selected ? GSColors.brand : GSColors.textMuted,
            width: 1.5,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(GSRadius.sm),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: GSSize.touchTarget),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: GSSpacing.s4),
              child: Center(
                widthFactor: 1,
                heightFactor: 1,
                child: Text(
                  label,
                  style: TextStyle(
                    fontFamily: GSFonts.mono, fontFeatures: GSFonts.tabular,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: selected ? GSColors.onBrand : GSColors.text,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
