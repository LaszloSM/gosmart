import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router/app_router.dart';
import '../theme/design_tokens.dart';

/// Destinos de la barra inferior. "Viaje" y "Reportar" se suman cuando
/// existan (Fases 4 y 6); el historial vive dentro de la Billetera.
enum GSNavTab { home, wallet, profile }

/// Barra inferior en ultramar (la carrocería): ícono activo sobre una placa
/// blanca con franja fucsia, etiqueta siempre debajo. Navega sola con
/// `context.go`; cambiar de pestaña no se anima (acción repetida).
class GSBottomNav extends StatelessWidget {
  const GSBottomNav({super.key, required this.current});

  final GSNavTab current;

  static const _items = [
    _NavItem(GSNavTab.home, Icons.home_rounded, 'Inicio', AppRoutes.home),
    _NavItem(GSNavTab.wallet, Icons.account_balance_wallet_rounded, 'Billetera',
        AppRoutes.wallet),
    _NavItem(
        GSNavTab.profile, Icons.person_rounded, 'Perfil', AppRoutes.profile),
  ];

  @override
  Widget build(BuildContext context) {
    // Alto mínimo de 72 dp que crece con el texto grande del sistema
    // (PRODUCT.md: hasta 200 % sin cortar).
    return ColoredBox(
      color: GSColors.shell,
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: GSSize.bottomNav),
          child: IntrinsicHeight(
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
        splashColor: GSColors.onShell.withValues(alpha: 0.12),
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
                borderRadius: BorderRadius.circular(GSRadius.sm),
                color: isActive ? GSColors.surface : Colors.transparent,
                border: isActive
                    ? Border(
                        bottom: BorderSide(color: GSColors.stripe, width: 4))
                    : null,
              ),
              child: Icon(
                item.icon,
                size: GSSize.iconLg,
                color: isActive ? GSColors.brand : GSColors.onShellMuted,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              item.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontFamily: GSFonts.sans,
                fontSize: 13,
                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                color: isActive ? GSColors.onShell : GSColors.onShellMuted,
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
