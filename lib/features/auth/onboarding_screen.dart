import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/gs_button.dart';
import '../../router/app_router.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(children: [
        // Layer 1 — fondo de marca sólido (texto blanco encima, 9.8:1)
        Container(color: GSColors.brand),
        // Layer 2 — content
        SafeArea(
          child: Column(children: [
            // Hero area (flex:5) — illustration or icon fallback
            Expanded(
              flex: 5,
              child: Center(
                child: Image.asset(
                  'assets/images/onboarding_illustration.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // GoSmart logo mark
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          color: GSColors.accent.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.directions_transit_rounded,
                          size: 64,
                          color: GSColors.accent,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Decorative mode icons row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _modeIcon(Icons.two_wheeler_rounded, GSColors.onBrand),
                          const SizedBox(width: 16),
                          _modeIcon(Icons.directions_bus_rounded, GSColors.onBrand),
                          const SizedBox(width: 16),
                          _modeIcon(Icons.local_taxi_rounded, GSColors.onBrand),
                          const SizedBox(width: 16),
                          _modeIcon(Icons.directions_walk_rounded, GSColors.onBrand),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Bottom card (flex:4) — dark rounded top
            Expanded(
              flex: 4,
              child: Container(
                width: double.infinity,
                decoration: const BoxDecoration(
                  color: GSColors.surface,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
                ),
                padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Brand name in accent teal
                    const Text(
                      'GoSmart',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w800,
                        color: GSColors.accent,
                        letterSpacing: -1.0,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Tu movilidad inteligente',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 16,
                        color: GSColors.textSecondary,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 32),
                    GSButton(
                      label: 'Iniciar sesión',
                      onPressed: () => context.go(AppRoutes.login),
                    ),
                    const SizedBox(height: 12),
                    GSButton(
                      label: 'Crear cuenta',
                      variant: GSButtonVariant.outline,
                      onPressed: () => context.go(AppRoutes.register),
                    ),
                    const Spacer(),
                    const Text(
                      'Al continuar aceptas nuestros Términos y Política de Privacidad',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: GSColors.textDisabled,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ]),
        ),
      ]),
    );
  }

  static Widget _modeIcon(IconData icon, Color color) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: color, size: 22),
    );
  }
}
