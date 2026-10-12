import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router/app_router.dart';
import '../theme/design_tokens.dart';

/// Destinos de la barra inferior. "Viaje" y "Reportar" se suman cuando
/// existan (Fases 4 y 6); el historial vive dentro de la Billetera.
enum GSNavTab { home, wallet, profile }

/// Barra inferior: superficie sal, ícono activo en pastilla de marca y la
/// etiqueta siempre debajo. Navega sola con `context.go`.
class GSBottomNav extends StatelessWidget {
  const GSBottomNav({super.key, required this.current});

  final GSNavTab current;

  static const _items = [
    _NavItem(GSNavTab.home, Icons.home_rounded, 'Inicio', AppRoutes.home),
    _NavItem(GSNavTab.wallet, Icons.account_balance_wallet_rounded,
        'Billetera', AppRoutes.wallet),
    _NavItem(GSNavTab.profile, Icons.person_rounded, 'Perfil',
        AppRoutes.profile),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      height: GSSize.bottomNav + MediaQuery.of(context).padding.bottom,
      decoration: const BoxDecoration(
        color: GSColors.surface,
        border: Border(top: BorderSide(color: GSColors.line)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            for (final item in _items)
              Expanded(
                child: _NavTile(
                  item: item,
                  isActive: item.tab == current,
                  onTap: () {
                    if (item.tab != current) context.go(item.route);
                  },
                ),
              ),
          ],
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
            // Sin animación: cambiar de pestaña es una acción repetida.
            Container(
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
  final GSNavTab tab;
  final IconData icon;
  final String label;
  final String route;
  const _NavItem(this.tab, this.icon, this.label, this.route);
}
