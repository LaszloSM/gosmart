// lib/features/splash/splash_screen.dart
// Arranque: el nombre en blanco sobre el azul de marca (como Nequi o DiDi). Sin espera artificial ni
// rebote: pasa en cuanto lee si ya se vio la intro.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../providers/auth_provider.dart';
import '../../providers/settings_provider.dart';
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
    // Quien dejó la app en modo conductor (y tiene sesión) vuelve a ese modo.
    final driverMode = prefs.getString(AppModeNotifier.key) == AppMode.driver.name &&
        ref.read(currentUserProvider) != null;
    if (!mounted) return;
    // Modo invitado (DS3): con o sin sesión se entra al inicio.
    context.go(!onboardingDone
        ? AppRoutes.intro
        : driverMode
            ? AppRoutes.driver
            : AppRoutes.home);
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: Scaffold(
        backgroundColor: GSColors.isDark ? GSColors.background : GSColors.brand,
        body: Center(
          child: Text(
            'GoSmart',
            style: TextStyle(
              fontFamily: GSFonts.display,
              fontSize: 40,
              fontWeight: FontWeight.w800,
              letterSpacing: -1.2,
              color: GSColors.isDark ? GSColors.brand : GSColors.onBrand,
            ),
          ),
        ),
      ),
    );
  }
}
