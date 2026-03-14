// lib/router/app_router.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/supabase_client.dart';
import '../theme/design_tokens.dart';
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

Widget _slideAndFade(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  return FadeTransition(
    opacity: CurvedAnimation(parent: animation, curve: Curves.easeInOut),
    child: SlideTransition(
      position: Tween<Offset>(
        begin: const Offset(0.04, 0),
        end: Offset.zero,
      ).animate(CurvedAnimation(parent: animation, curve: Curves.easeInOut)),
      child: child,
    ),
  );
}

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
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const OnboardingScreen(),
          transitionDuration: GSDuration.page,
          transitionsBuilder: _slideAndFade,
        ),
      ),
      GoRoute(
        path: AppRoutes.login,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const LoginScreen(),
          transitionDuration: GSDuration.page,
          transitionsBuilder: _slideAndFade,
        ),
      ),
      GoRoute(
        path: AppRoutes.register,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const RegisterScreen(),
          transitionDuration: GSDuration.page,
          transitionsBuilder: _slideAndFade,
        ),
      ),
      GoRoute(
        path: AppRoutes.smsVerify,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: SmsVerifyScreen(phone: state.extra as String),
          transitionDuration: GSDuration.page,
          transitionsBuilder: _slideAndFade,
        ),
      ),
      GoRoute(
        path: AppRoutes.home,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const HomeScreen(),
          transitionDuration: GSDuration.page,
          transitionsBuilder: _slideAndFade,
        ),
      ),
      GoRoute(
        path: AppRoutes.wallet,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const WalletScreen(),
          transitionDuration: GSDuration.page,
          transitionsBuilder: _slideAndFade,
        ),
      ),
      GoRoute(
        path: AppRoutes.history,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const HistoryScreen(),
          transitionDuration: GSDuration.page,
          transitionsBuilder: _slideAndFade,
        ),
      ),
      GoRoute(
        path: AppRoutes.profile,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const ProfileScreen(),
          transitionDuration: GSDuration.page,
          transitionsBuilder: _slideAndFade,
        ),
      ),
      GoRoute(
        path: AppRoutes.routePlanner,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const RoutePlannerScreen(),
          transitionDuration: GSDuration.page,
          transitionsBuilder: _slideAndFade,
        ),
      ),
      GoRoute(
        path: AppRoutes.routeDetail,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const RouteDetailScreen(),
          transitionDuration: GSDuration.page,
          transitionsBuilder: _slideAndFade,
        ),
      ),
      GoRoute(
        path: AppRoutes.aiChat,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const AiChatScreen(),
          transitionDuration: GSDuration.page,
          transitionsBuilder: _slideAndFade,
        ),
      ),
      GoRoute(
        path: AppRoutes.paymentValidation,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const PaymentValidationScreen(),
          transitionDuration: GSDuration.page,
          transitionsBuilder: _slideAndFade,
        ),
      ),
      GoRoute(
        path: AppRoutes.nfcSimulator,
        pageBuilder: (context, state) => CustomTransitionPage(
          key: state.pageKey,
          child: const NfcAuthSimulatorScreen(),
          transitionDuration: GSDuration.page,
          transitionsBuilder: _slideAndFade,
        ),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.error}')),
    ),
  );
});
