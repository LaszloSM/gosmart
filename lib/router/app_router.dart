import 'package:flutter/material.dart';
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

class AppRouter {
  static Route<dynamic> onGenerateRoute(RouteSettings settings) {
    Widget page;

    switch (settings.name) {
      case AppRoutes.onboarding:
        page = const OnboardingScreen();
        break;
      case AppRoutes.login:
        page = const LoginScreen();
        break;
      case AppRoutes.register:
        page = const RegisterScreen();
        break;
      case AppRoutes.smsVerification:
        final phone = settings.arguments as String? ?? '';
        page = SmsVerificationScreen(phone: phone);
        break;
      case AppRoutes.home:
        page = const HomeScreen();
        break;
      case AppRoutes.routePlanner:
        page = const RoutePlannerScreen();
        break;
      case AppRoutes.routeDetail:
        page = const RouteDetailScreen();
        break;
      case AppRoutes.wallet:
        page = const WalletScreen();
        break;
      case AppRoutes.history:
        page = const HistoryScreen();
        break;
      case AppRoutes.profile:
        page = const ProfileScreen();
        break;
      case AppRoutes.aiChat:
        page = const AiChatScreen();
        break;
      case AppRoutes.paymentValidation:
        page = const PaymentValidationScreen();
        break;
      default:
        page = const HomeScreen();
    }

    return MaterialPageRoute(
      builder: (_) => page,
      settings: settings,
    );
  }
}
