// lib/features/splash/splash_screen.dart
// Arranque: carrocería ultramar con el nombre. Sin espera artificial ni
// rebote: pasa en cuanto lee si ya se vio la intro.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../router/app_router.dart';
import '../../theme/design_tokens.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigate();
  }

  Future<void> _navigate() async {
    final prefs = await SharedPreferences.getInstance();
    final onboardingDone = prefs.getBool('onboarding_complete') ?? false;
    if (!mounted) return;
    // Modo invitado (DS3): con o sin sesión se entra al inicio.
    context.go(onboardingDone ? AppRoutes.home : AppRoutes.intro);
  }

  @override
  Widget build(BuildContext context) {
    return const AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: GSColors.brand,
        body: Center(
          child: Text(
            'GoSmart',
            style: TextStyle(
              fontFamily: GSFonts.display,
              fontSize: 48,
              fontWeight: FontWeight.w800,
              color: GSColors.onBrand,
            ),
          ),
        ),
      ),
    );
  }
}
