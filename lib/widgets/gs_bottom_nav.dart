import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../router/app_router.dart';
import '../theme/design_tokens.dart';

/// Destinos de la barra inferior (DS1). El historial vive en la Billetera.
enum GSNavTab { home, trip, report, wallet, profile }

/// Barra inferior al estilo Material 3 (como Google Maps o Nequi): blanca con
/// una línea fina arriba, ícono activo relleno sobre una píldora azul clara y
/// etiqueta siempre debajo. Navega sola con `context.go`; cambiar de pestaña
/// no se anima (acción repetida).
class GSBottomNav extends StatelessWidget {
  const GSBottomNav({super.key, required this.current});

  final GSNavTab current;

  static const _items = [
    _NavItem(GSNavTab.home, Icons.home_outlined, Icons.home_rounded, 'Inicio',
        AppRoutes.home),
    _NavItem(GSNavTab.trip, Icons.directions_car_outlined,
        Icons.directions_car_rounded, 'Viaje', AppRoutes.trip),
    _NavItem(GSNavTab.report, Icons.campaign_outlined, Icons.campaign_rounded,
        'Reportar', AppRoutes.report),
    _NavItem(GSNavTab.wallet, Icons.account_balance_wallet_outlined,
        Icons.account_balance_wallet_rounded, 'Billetera', AppRoutes.wallet),
    _NavItem(GSNavTab.profile, Icons.person_outline_rounded,
        Icons.person_rounded, 'Perfil', AppRoutes.profile),
  ];

  @override
  Widget build(BuildContext context) {
    // Alto mínimo de 72 dp que crece con el texto grande del sistema
    // (PRODUCT.md: hasta 200 % sin cortar).
    return DecoratedBox(
      decoration: BoxDecoration(
        color: GSColors.shell,
        border: Border(top: BorderSide(color: GSColors.line)),
      ),
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
    return Semantics(
      selected: isActive,
      button: true,
      label: item.label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        splashFactory: NoSplash.splashFactory,
        highlightColor: Colors.transparent,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: GSSpacing.s2),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Píldora de 56 × 32 detrás del ícono activo (Material 3).
              // Sin animación: cambiar de pestaña es una acción repetida.
              Container(
                width: 56,
                height: 32,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(GSRadius.full),
                  color: isActive ? GSColors.brandTint : Colors.transparent,
                ),
                child: Icon(
                  isActive ? item.activeIcon : item.icon,
                  size: GSSize.iconLg,
                  color: isActive ? GSColors.brand : GSColors.onShellMuted,
                ),
              ),
              const SizedBox(height: GSSpacing.s1),
              // Cinco pestañas en 360 dp: la etiqueta crece hasta 1,3× y, si aun
              // así no cabe, se reduce para caber entera (nunca "Bille…" ni
              // dos etiquetas pegadas).
              MediaQuery.withClampedTextScaling(
                maxScaleFactor: 1.3,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 3),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      item.label,
                      maxLines: 1,
                      style: TextStyle(
                        fontFamily: GSFonts.sans,
                        fontSize: 12.5,
                        fontWeight:
                            isActive ? FontWeight.w700 : FontWeight.w500,
                        color:
                            isActive ? GSColors.onShell : GSColors.onShellMuted,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final GSNavTab tab;
  final IconData icon;
  final IconData activeIcon;
  final String label;
  final String route;
  const _NavItem(this.tab, this.icon, this.activeIcon, this.label, this.route);
}
