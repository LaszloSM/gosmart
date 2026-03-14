// lib/router/app_router.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../screens/onboarding/onboarding_screen.dart';
import '../screens/onboarding/login_screen.dart';
import '../screens/onboarding/register_screen.dart';
import '../screens/home/home_screen.dart';
import '../screens/route_planner/route_planner_screen.dart';
import '../screens/route_detail/route_detail_screen.dart';
import '../screens/wallet/wallet_screen.dart';
import '../screens/history/history_screen.dart';
import '../screens/profile/profile_screen.dart';
import '../screens/ai_chat/ai_chat_screen.dart';
import '../screens/payment_validation/payment_validation_screen.dart';

abstract class AppRoutes {
  static const onboarding = '/';
  static const login = '/login';
  static const register = '/register';
  static const smsVerification = '/sms-verification';
  static const home = '/home';
  static const routePlanner = '/route-planner';
  static const routeDetail = '/route-detail';
  static const wallet = '/wallet';
  static const history = '/history';
  static const profile = '/profile';
  static const aiChat = '/ai-chat';
  static const paymentValidation = '/payment-validation';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.onboarding,
    routes: [
      GoRoute(
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: AppRoutes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: AppRoutes.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: AppRoutes.routePlanner,
        builder: (context, state) => const RoutePlannerScreen(),
      ),
      GoRoute(
        path: AppRoutes.routeDetail,
        builder: (context, state) => const RouteDetailScreen(),
      ),
      GoRoute(
        path: AppRoutes.wallet,
        builder: (context, state) => const WalletScreen(),
      ),
      GoRoute(
        path: AppRoutes.history,
        builder: (context, state) => const HistoryScreen(),
      ),
      GoRoute(
        path: AppRoutes.profile,
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: AppRoutes.aiChat,
        builder: (context, state) => const AiChatScreen(),
      ),
      GoRoute(
        path: AppRoutes.paymentValidation,
        builder: (context, state) => const PaymentValidationScreen(),
      ),
    ],
  );
});
