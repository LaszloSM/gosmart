import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

/// Pill-style bottom navigation bar.
/// Active tab: icon + label inside an accent-tinted pill.
/// Inactive tabs: icon only, muted color.
class GSBottomNav extends StatelessWidget {
  const GSBottomNav({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;

  static const _items = [
    _NavItem(icon: Icons.home_rounded, label: 'Inicio'),
    _NavItem(icon: Icons.route_rounded, label: 'Viajes'),
    _NavItem(icon: Icons.account_balance_wallet_rounded, label: 'Billetera'),
    _NavItem(icon: Icons.person_rounded, label: 'Perfil'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: GSSize.bottomNav + MediaQuery.of(context).padding.bottom,
      decoration: BoxDecoration(
        color: GSColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: List.generate(
            _items.length,
            (index) => Expanded(
              child: _NavTile(
                item: _items[index],
                isActive: currentIndex == index,
                onTap: () => onTap(index),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavTile extends StatelessWidget {
  const _NavTile({
    required this.item,
    required this.isActive,
    required this.onTap,
  });

  final _NavItem item;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: GSDuration.normal,
            curve: Curves.easeInOut,
            padding: EdgeInsets.symmetric(
              horizontal: isActive ? GSSpacing.s3 : GSSpacing.s2,
              vertical: GSSpacing.s1,
            ),
            decoration: BoxDecoration(
              color: isActive ? GSColors.accentLight : Colors.transparent,
              borderRadius: BorderRadius.circular(GSRadius.full),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  item.icon,
                  size: GSSize.iconLg,
                  color: isActive ? GSColors.accent : GSColors.textDisabled,
                ),
                if (isActive) ...[
                  const SizedBox(width: GSSpacing.s1),
                  Text(
                    item.label,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: GSColors.accent,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  final IconData icon;
  final String label;
  const _NavItem({required this.icon, required this.label});
}
