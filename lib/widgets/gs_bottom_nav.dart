import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// Glass bottom navigation bar.
/// Active tab: gradient pill (teal→violet) with icon + label.
/// Inactive tabs: icon + label (9sp, muted).
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
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(
          sigmaX: GSGlass.blur,
          sigmaY: GSGlass.blur,
        ),
        child: Container(
          height: GSSize.bottomNav + MediaQuery.of(context).padding.bottom,
          decoration: BoxDecoration(
            color: GSColors.surface.withValues(alpha: GSGlass.backgroundOpacity),
            border: Border(
              top: BorderSide(
                color: Colors.white.withValues(alpha: GSGlass.borderOpacity),
                width: GSGlass.borderWidth,
              ),
            ),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(GSRadius.full),
        splashColor: GSColors.accent.withValues(alpha: 0.12),
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            AnimatedContainer(
              duration: GSAnimDuration.pillSlide,
              curve: Curves.easeInOut,
              padding: const EdgeInsets.symmetric(
                horizontal: GSSpacing.s2,
                vertical: GSSpacing.s1,
              ),
              decoration: isActive
                  ? BoxDecoration(
                      borderRadius: BorderRadius.circular(GSRadius.full),
                      gradient: LinearGradient(
                        colors: GSGradient.accentPill,
                        begin: Alignment.centerLeft,
                        end: Alignment.centerRight,
                      ),
                    )
                  : const BoxDecoration(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    item.icon,
                    size: GSSize.iconLg,
                    color: isActive ? Colors.white : GSColors.textDisabled,
                  ),
                  if (isActive) ...[
                    const SizedBox(width: GSSpacing.s1),
                    Text(
                      item.label,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 2),
            if (!isActive)
              Text(
                item.label,
                style: const TextStyle(
                  fontSize: 9,
                  fontWeight: FontWeight.w400,
                  color: GSColors.textDisabled,
                ),
              ),
          ],
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
