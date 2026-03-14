import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

class GSBottomNav extends StatelessWidget {
  const GSBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _items = [
    _NavItem(icon: Icons.home_rounded, label: 'Home'),
    _NavItem(icon: Icons.receipt_long_rounded, label: 'Tickets'),
    _NavItem(icon: Icons.account_balance_wallet_rounded, label: 'Wallet'),
    _NavItem(icon: Icons.person_rounded, label: 'Profile'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: GSSize.bottomNav + MediaQuery.of(context).padding.bottom,
      decoration: BoxDecoration(
        color: GSColors.surface,
        boxShadow: [
          BoxShadow(
            color: GSColors.textPrimary.withOpacity(0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: List.generate(_items.length, (i) {
            final item = _items[i];
            final selected = i == currentIndex;
            return Expanded(
              child: Semantics(
                label: item.label,
                selected: selected,
                button: true,
                child: GestureDetector(
                  onTap: () => onTap(i),
                  behavior: HitTestBehavior.opaque,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedContainer(
                        duration: GSDuration.normal,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 6),
                        decoration: BoxDecoration(
                          color: selected
                              ? GSColors.primaryLight
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(GSRadius.full),
                        ),
                        child: Icon(
                          item.icon,
                          size: 22,
                          color: selected
                              ? GSColors.primary
                              : GSColors.textDisabled,
                        ),
                      ),
                      const SizedBox(height: 2),
                      AnimatedDefaultTextStyle(
                        duration: GSDuration.normal,
                        style: TextStyle(
                          
                          fontSize: 11,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: selected
                              ? GSColors.primary
                              : GSColors.textDisabled,
                        ),
                        child: Text(item.label),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}
