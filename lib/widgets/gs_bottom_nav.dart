import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/design_tokens.dart';

/// Glass bottom navigation bar — dark edition.
/// Active tab: kinetic green → cyan gradient pill with icon + label.
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
          decoration: const BoxDecoration(
            color: GSColors.surface,
            border: Border(
              top: BorderSide(
                color: GSColors.line,
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
        splashColor: GSColors.brand.withValues(alpha: 0.10),
        highlightColor: Colors.transparent,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Pastilla de marca detrás del ícono activo; la etiqueta siempre
            // debajo, para que quepa con texto grande y nombres largos.
            AnimatedContainer(
              duration: GSAnimDuration.pillSlide,
              curve: GSCurve.move,
              padding: const EdgeInsets.symmetric(
                horizontal: GSSpacing.s4,
                vertical: GSSpacing.s1,
              ),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(GSRadius.full),
                color: isActive ? GSColors.brand : Colors.transparent,
              ),
              child: Icon(
                item.icon,
                size: GSSize.iconLg,
                color: isActive ? GSColors.onBrand : GSColors.textMuted,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: isActive ? GSColors.brand : GSColors.textMuted,
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
