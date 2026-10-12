// lib/router/app_router.dart
import 'dart:async';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../core/supabase_client.dart';
import '../theme/design_tokens.dart';
import '../features/splash/splash_screen.dart';
import '../features/onboarding/intro_screen.dart';
import '../features/onboarding/location_permission_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/register_screen.dart';
import '../features/auth/sms_verify_screen.dart';
import '../features/home/home_screen.dart';
import '../features/wallet/wallet_screen.dart';
import '../features/profile/profile_screen.dart';
import '../features/routes/route_planner_screen.dart';
import '../features/routes/route_detail_screen.dart';
import '../features/ai_chat/ai_chat_screen.dart';
import '../features/nfc_simulator/nfc_auth_simulator_screen.dart';
import '../features/safety/emergency_contacts_screen.dart';
import '../features/legal/legal_screen.dart';
import '../features/legal/legal_texts.dart';

/// Transición de pantalla: fundido + 4 % de desplazamiento con ease-out
/// fuerte (Emil). Con "quitar animaciones" queda solo el fundido.
Widget _slideAndFade(
  BuildContext context,
  Animation<double> animation,
  Animation<double> secondaryAnimation,
  Widget child,
) {
  final curved = CurvedAnimation(
    parent: animation,
    curve: GSCurve.enter,
    reverseCurve: GSCurve.exit,
  );
  final faded = FadeTransition(opacity: curved, child: child);
  if (MediaQuery.of(context).disableAnimations) return faded;
  return SlideTransition(
    position: Tween<Offset>(begin: const Offset(0.04, 0), end: Offset.zero)
        .animate(curved),
    child: faded,
  );
}

/// Pantalla con transición; volver es más rápido que entrar.
CustomTransitionPage<void> _page(GoRouterState state, Widget child) =>
    CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: GSDuration.page,
      reverseTransitionDuration: GSDuration.sheetOut,
      transitionsBuilder: _slideAndFade,
    );

/// Raíz de pestaña: cambiar de pestaña no se anima (acción repetida).
NoTransitionPage<void> _tab(GoRouterState state, Widget child) =>
    NoTransitionPage<void>(key: state.pageKey, child: child);

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
  static const splash           = '/splash';
  static const intro            = '/intro';
  static const locationPermission = '/location-permission';
  static const onboarding       = '/onboarding';
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
  static const emergencyContacts = '/safety/contacts';
  static const privacy          = '/legal/privacy';
  static const terms            = '/legal/terms';
}

final appRouterProvider = Provider<GoRouter>((ref) {
  // refreshListenable bridges the Supabase auth stream to GoRouter so that
  // redirect() is re-evaluated automatically on login / logout.
  final notifier = _StreamChangeNotifier(
    GoSmartSupabase.client.auth.onAuthStateChange,
  );
  ref.onDispose(notifier.dispose);

  return GoRouter(
    initialLocation: AppRoutes.splash,
    refreshListenable: notifier,
    redirect: (context, state) {
      final session = GoSmartSupabase.client.auth.currentSession;
      final isAuth = session != null;
      // Rutas públicas. Modo invitado (DS3): el inicio, el planificador y el
      // asistente funcionan sin cuenta; lo demás pide entrar.
      final isPublicPage = state.matchedLocation == AppRoutes.home ||
          state.matchedLocation == AppRoutes.routePlanner ||
          state.matchedLocation == AppRoutes.routeDetail ||
          state.matchedLocation == AppRoutes.aiChat ||
          state.matchedLocation == AppRoutes.privacy ||
          state.matchedLocation == AppRoutes.terms ||
          state.matchedLocation == AppRoutes.splash ||
          state.matchedLocation == AppRoutes.intro ||
          state.matchedLocation == AppRoutes.locationPermission ||
          state.matchedLocation == AppRoutes.login ||
          state.matchedLocation == AppRoutes.register ||
          state.matchedLocation == AppRoutes.onboarding ||
          state.matchedLocation == AppRoutes.smsVerify;

      // Si autenticado y en página auth → ir a home
      if (isAuth &&
          (state.matchedLocation == AppRoutes.login ||
              state.matchedLocation == AppRoutes.register ||
              state.matchedLocation == AppRoutes.onboarding)) {
        return AppRoutes.home;
      }
      // Si no autenticado y en página protegida → login
      if (!isAuth && !isPublicPage) return AppRoutes.login;
      return null;
    },
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        pageBuilder: (context, state) => _page(state, const SplashScreen()),
      ),
      GoRoute(
        path: AppRoutes.intro,
        pageBuilder: (context, state) => _page(state, const IntroScreen()),
      ),
      GoRoute(
        path: AppRoutes.locationPermission,
        pageBuilder: (context, state) => _page(state, const LocationPermissionScreen()),
      ),
      // La bienvenida antigua se retiró: con el modo invitado se entra
      // directo al inicio.
      GoRoute(
        path: AppRoutes.onboarding,
        redirect: (_, __) => AppRoutes.home,
      ),
      GoRoute(
        path: AppRoutes.login,
        pageBuilder: (context, state) => _page(state, const LoginScreen()),
      ),
      GoRoute(
        path: AppRoutes.register,
        pageBuilder: (context, state) => _page(state, const RegisterScreen()),
      ),
      GoRoute(
        path: AppRoutes.smsVerify,
        pageBuilder: (context, state) => _page(state, SmsVerifyScreen(phone: state.extra as String)),
      ),
      GoRoute(
        path: AppRoutes.home,
        pageBuilder: (context, state) => _tab(state, const HomeScreen()),
      ),
      GoRoute(
        path: AppRoutes.wallet,
        pageBuilder: (context, state) => _tab(state, const WalletScreen()),
      ),
      // El historial vive ahora dentro de la Billetera.
      GoRoute(
        path: AppRoutes.history,
        redirect: (_, __) => AppRoutes.wallet,
      ),
      GoRoute(
        path: AppRoutes.profile,
        pageBuilder: (context, state) => _tab(state, const ProfileScreen()),
      ),
      GoRoute(
        path: AppRoutes.routePlanner,
        pageBuilder: (context, state) => _page(state, const RoutePlannerScreen()),
      ),
      GoRoute(
        path: AppRoutes.routeDetail,
        pageBuilder: (context, state) => _page(state, const RouteDetailScreen()),
      ),
      GoRoute(
        path: AppRoutes.emergencyContacts,
        pageBuilder: (context, state) =>
            _page(state, const EmergencyContactsScreen()),
      ),
      GoRoute(
        path: AppRoutes.privacy,
        pageBuilder: (context, state) =>
            _page(state, const LegalScreen(doc: privacyPolicy)),
      ),
      GoRoute(
        path: AppRoutes.terms,
        pageBuilder: (context, state) =>
            _page(state, const LegalScreen(doc: termsOfUse)),
      ),
      GoRoute(
        path: AppRoutes.aiChat,
        pageBuilder: (context, state) => _page(state, const AiChatScreen()),
      ),
      // El pago real (QR del conductor) llega en la Fase 7; mientras tanto
      // la ruta vieja de validación NFC lleva a la billetera.
      GoRoute(
        path: AppRoutes.paymentValidation,
        redirect: (_, __) => AppRoutes.wallet,
      ),
      // Simulador local: solo en builds de depuración.
      if (kDebugMode)
        GoRoute(
          path: AppRoutes.nfcSimulator,
          pageBuilder: (context, state) => _page(state, const NfcAuthSimulatorScreen()),
        ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.error}')),
    ),
  );
});
