// lib/router/app_router.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/supabase_client.dart';
import '../features/auth/onboarding_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/auth/sms_verify_screen.dart';
import '../features/home/home_screen.dart';
import '../features/wallet/wallet_screen.dart';
import '../features/history/history_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/routes/route_planner_screen.dart';
import '../features/routes/route_detail_screen.dart';
import '../features/ai_chat/ai_chat_screen.dart';
import '../features/payment/payment_validation_screen.dart';
import '../features/nfc_simulator/nfc_auth_simulator_screen.dart';

/// Bridges a Stream to a [ChangeNotifier] so GoRouter's [refreshListenable]
/// can trigger redirect re-evaluation on auth state changes.
class _StreamChangeNotifier extends ChangeNotifier {
  _StreamChangeNotifier(Stream<dynamic> stream) {
    _sub = stream.listen((_) => notifyListeners());
  }
  late final StreamSubscription _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

/// Route name constants — use these instead of hard-coded strings
abstract class AppRoutes {
  static const onboarding       = '/';
  static const login            = '/login';
  static const register         = '/register';
  static const smsVerify        = '/sms-verify';
  static const home             = '/home';
  static const wallet           = '/wallet';
  static const history          = '/history';
  static const profile          = '/profile';
  static const routePlanner     = '/routes';
  static const routeDetail      = '/routes/detail';
  static const aiChat           = '/ai-chat';
  static const paymentValidation = '/payment-validation';
  static const nfcSimulator     = '/debug/nfc-simulator';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  // refreshListenable bridges the Supabase auth stream to GoRouter so that
  // redirect() is re-evaluated automatically on login / logout.
  final notifier = _StreamChangeNotifier(
    GoSmartSupabase.client.auth.onAuthStateChange,
  );
  ref.onDispose(notifier.dispose);

  return GoRouter(
    initialLocation: AppRoutes.onboarding,
    refreshListenable: notifier,
    redirect: (context, state) {
      final session = GoSmartSupabase.client.auth.currentSession;
      final isAuth = session != null;
      final onAuthPage = state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.register ||
          state.matchedLocation == AppRoutes.onboarding ||
          state.matchedLocation == AppRoutes.smsVerify; // mid-OTP flow, not yet authenticated

      // If authenticated and on auth page → go to home
      if (isAuth && onAuthPage) return AppRoutes.home;
      // If not authenticated and on protected page → go to login
      if (!isAuth && !onAuthPage) return AppRoutes.login;
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (_, __) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.smsVerify,
        builder: (_, state) => SmsVerifyScreen(phone: state.extra as String),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (_, __) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.wallet,
        builder: (_, __) => const WalletScreen(),
      ),
      GoRoute(
        path: AppRoutes.history,
        builder: (_, __) => const HistoryScreen(),
      ),
      GoRoute(
        path: AppRoutes.profile,
        builder: (_, __) => const ProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.routePlanner,
        builder: (_, __) => const RoutePlannerScreen(),
      ),
      GoRoute(
        path: AppRoutes.routeDetail,
        builder: (_, __) => const RouteDetailScreen(),
      ),
      GoRoute(
        path: AppRoutes.aiChat,
        builder: (_, __) => const AiChatScreen(),
      ),
      GoRoute(
        path: AppRoutes.paymentValidation,
        builder: (_, __) => const PaymentValidationScreen(),
      ),
      GoRoute(
        path: AppRoutes.nfcSimulator,
        builder: (_, __) => const NfcAuthSimulatorScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.error}')),
    ),
  );
});
