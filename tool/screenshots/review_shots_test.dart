import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gosmart/features/routes/widgets/mode_options.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:latlong2/latlong.dart';
import 'package:gosmart/features/ai_chat/ai_chat_screen.dart';
import 'package:gosmart/features/auth/login_screen.dart';
import 'package:gosmart/features/auth/register_screen.dart';
import 'package:gosmart/features/home/home_screen.dart';
import 'package:gosmart/features/home/widgets/home_sheet.dart';
import 'package:gosmart/providers/corridor_provider.dart';
import 'package:gosmart/features/onboarding/intro_screen.dart';
import 'package:gosmart/features/onboarding/location_permission_screen.dart';
import 'package:gosmart/features/profile/profile_screen.dart';
import 'package:gosmart/features/routes/route_detail_screen.dart';
import 'package:gosmart/features/routes/route_planner_screen.dart';
import 'package:gosmart/features/wallet/wallet_screen.dart';
import 'package:gosmart/models/ai_models.dart';
import 'package:gosmart/models/card_model.dart';
import 'package:gosmart/models/corridor_status.dart';
import 'package:gosmart/models/profile_model.dart';
import 'package:gosmart/models/route_result.dart';
import 'package:gosmart/models/wallet_model.dart';
import 'package:gosmart/models/wallet_transaction_model.dart';
import 'package:gosmart/providers/active_route_provider.dart';
import 'package:gosmart/providers/ai_conversation_provider.dart';
import 'package:gosmart/providers/auth_provider.dart';
import 'package:gosmart/providers/card_provider.dart';
import 'package:gosmart/providers/favorites_provider.dart';
import 'package:gosmart/providers/profile_provider.dart';
import 'package:gosmart/providers/selected_mode_provider.dart';
import 'package:gosmart/providers/wallet_provider.dart';
import 'package:gosmart/theme/app_theme.dart';
import 'package:gosmart/theme/design_tokens.dart';
import 'package:gosmart/widgets/gs_bottom_nav.dart';
import 'package:gosmart/features/alerts/alert_detail_sheet.dart';
import 'package:gosmart/features/alerts/report_sheet.dart';
import 'package:gosmart/features/settings/alert_settings_screen.dart';
import 'package:gosmart/features/settings/settings_screen.dart';
import 'package:gosmart/models/map_alert.dart';
import 'package:gosmart/providers/map_alerts_provider.dart';
import 'shot_util.dart';

// Capturas para la revisión final de impeccable. Correr con:
//   flutter test tool/screenshots/review_shots_test.dart
// Escribe en .impeccable/review/ (ignorado por git).
const dir = '.impeccable/review';

class _Card extends ActiveCardNotifier {
  _Card() { state = const AsyncData(CardModel(id: 'c', userId: 'u', numberMasked: 'x', balance: 0, currency: 'COP', status: 'active', nfcEnabled: true, expiresAt: '12/28')); }
  @override Future<void> load() async {}
  @override void subscribeRealtime() {}
}
class _P extends ProfileNotifier {
  @override Future<void> load() async { state = const AsyncData(ProfileModel(id: 'u', name: 'Yeinis Epiayú Pushaina', email: 'yeinis.ep@correo.co', ecoPoints: 135, cedula: '1124038745', city: 'Riohacha')); }
}
class _Ai extends AiConversationNotifier {
  _Ai() { state = AiConversationState(messages: [...state.messages,
    AiMessage(role: 'user', content: '¿Cuánto debería costar un mototaxi al terminal?', timestamp: DateTime.now()),
    AiMessage(role: 'assistant', content: 'Del centro de Riohacha al terminal son unos 3 km. En mototaxi, de día, suele estar entre \$4.000 y \$5.000.', timestamp: DateTime.now(), source: 'heuristic',
      routes: const [RouteOption(id: 'a', type: 'fastest', totalDurationMin: 9, totalCostCop: 4500, totalCo2Kg: 0.2, legs: [])]),
  ]); }
}
final _alerts = [
  MapAlert(id: 'a1', kind: AlertKind.hueco, at: const LatLng(11.5436, -72.9080), happenedAt: DateTime.now().subtract(const Duration(hours: 5)), confirmations: 3),
  MapAlert(id: 'a2', kind: AlertKind.reten, at: const LatLng(11.5462, -72.9046), happenedAt: DateTime.now().subtract(const Duration(minutes: 25)), confirmations: 1, denials: 1),
  MapAlert(id: 'a3', kind: AlertKind.trancon, at: const LatLng(11.5418, -72.9105), happenedAt: DateTime.now().subtract(const Duration(minutes: 9))),
  MapAlert(id: 'a4', kind: AlertKind.accidente, at: const LatLng(11.5470, -72.9112), happenedAt: DateTime.now().subtract(const Duration(minutes: 14))),
  MapAlert(id: 'a5', kind: AlertKind.obra, at: const LatLng(11.5405, -72.9040), happenedAt: DateTime.now().subtract(const Duration(days: 3))),
];
class _Alerts extends MapAlertsNotifier {
  @override Future<List<MapAlert>> build() async => _alerts;
  @override Future<void> refresh() async {}
}

WalletTransactionModel _tx(WalletTxType t, int a, Duration ago, [String? d]) => WalletTransactionModel(id: '$a$ago', walletId: 'w', type: t, amount: a, description: d, createdAt: DateTime.now().subtract(ago));

Future<void> _save(WidgetTester t, String name) async {
  final b = t.renderObject<RenderRepaintBoundary>(find.byKey(const ValueKey('shot')));
  await t.runAsync(() async {
    final img = await b.toImage(pixelRatio: 2);
    final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
    File('$dir/$name.png').writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  testWidgets('review shots', (t) async {
    phone(t);
    dotenv.testLoad(fileInput: 'GOOGLE_MAPS_API_KEY=\n');
    await t.runAsync(loadFonts);
    const a = LatLng(11.54, -72.90), b = LatLng(11.55, -72.91), c = LatLng(11.38, -72.24);
    final route = RouteResult(legs: [
      RouteLeg(mode: 'walk', points: [a, b], color: GSColors.walk, durationMin: 6, distanceKm: 0.5, instruction: 'Camina hasta la parada de la calle 15'),
      RouteLeg(mode: 'bus', points: [b, c], color: GSColors.bus, durationMin: 72, distanceKm: 74.2, instruction: 'Toma el colectivo hasta el terminal de Maicao', lineId: 'Colectivo'),
    ], distanceKm: 74.7, durationMin: 78, profile: 'driving', estimatedCostCop: 15000, category: 'public');
    final status = CorridorStatus(segments: const [
      CorridorSegment(kmFrom: 0, kmTo: 38, state: RoadState.open),
      CorridorSegment(kmFrom: 38, kmTo: 46, state: RoadState.closed, reason: 'Bloqueo', reports: 3),
      CorridorSegment(kmFrom: 46, kmTo: 75, state: RoadState.open),
    ], updatedAt: DateTime.now().subtract(const Duration(minutes: 12)));
    var routeOn = false;
    var guest = true;
    final ov = <Override>[
      corridorStatusProvider.overrideWith((ref) async => status),
      isGuestProvider.overrideWith((ref) => guest),
      currentUserProvider.overrideWithValue(null),
      favoritePlacesProvider.overrideWith((ref) async => []),
      activeCardProvider.overrideWith((ref) => _Card()),
      profileProvider.overrideWith((ref) => _P()),
      aiConversationProvider.overrideWith((ref) => _Ai()),
      activeRouteProvider.overrideWith((ref) => routeOn ? route : null),
      selectedModeProvider.overrideWith((ref) => 'Colectivo'),
      mapAlertsProvider.overrideWith(_Alerts.new),
      walletProvider.overrideWith((ref) async => Wallet(id: 'w', userId: 'u', balance: 37500, cardNumber: 'GS-1234-5678-9012', cardStatus: 'active', createdAt: DateTime(2026))),
      walletTransactionsProvider.overrideWith((ref, l) async => [
        _tx(WalletTxType.trip, -6000, const Duration(hours: 1), 'Mototaxi, centro a terminal'),
        _tx(WalletTxType.recharge, 20000, const Duration(days: 1)),
        _tx(WalletTxType.bonus, 10000, const Duration(days: 12), 'Bono de bienvenida'),
      ]),
    ];
    // Sombras reales en las capturas (flutter_test las apaga por defecto).
    debugDisableShadows = false;
    var dark = false;
    Future<void> shot(Widget w, String n, {bool settle = true, List<Override> extra = const []}) async {
      GSColors.apply(dark ? Brightness.dark : Brightness.light);
      await t.pumpWidget(ProviderScope(key: UniqueKey(), overrides: [...ov, ...extra], child: MaterialApp(debugShowCheckedModeBanner: false, theme: dark ? AppTheme.dark : AppTheme.light,
          home: RepaintBoundary(key: const ValueKey('shot'), child: w))));
      if (settle) { await t.pumpAndSettle(); } else { await t.pump(const Duration(milliseconds: 400)); }
      // Las ilustraciones (assets) se decodifican fuera del reloj falso.
      await t.runAsync(() => Future.wait(find.byType(Image).evaluate()
          .map((e) => precacheImage((e.widget as Image).image, e))));
      await t.pump();
      await _save(t, n);
    }
    // Inicio: el mapa real carga teselas de red, que no hay en tests; se usa
    // un fondo liso en su lugar (dicho en el paquete de revisión).
    await shot(Scaffold(extendBody: true, body: Stack(children: [
      const Positioned.fill(child: ColoredBox(color: Color(0xFFE7EBF0))),
      Positioned(left: 0, right: 0, bottom: 0, height: 470, child: DecoratedBox(
        decoration: BoxDecoration(color: GSColors.surface, borderRadius: GSRadius.sheetRadius, boxShadow: GSShadow.sheet),
        child: const HomeSheetContent())),
    ]), bottomNavigationBar: const GSBottomNav(current: GSNavTab.home)), 'phone-home');
    await shot(const SettingsScreen(), 'phone-settings');
    await shot(const AlertSettingsScreen(), 'phone-alert-settings');
    guest = false;
    await shot(Scaffold(backgroundColor: const Color(0xFF9AA3B0), body: Align(alignment: Alignment.bottomCenter,
        child: ReportSheet(locate: () async => const LatLng(11.5441, -72.9071)))), 'phone-report-sheet');
    guest = true;
    await shot(Scaffold(backgroundColor: const Color(0xFF9AA3B0), body: Align(alignment: Alignment.bottomCenter,
        child: AlertDetailSheet(alertId: 'a2', initial: _alerts[1]))), 'phone-alert-detail');
    await shot(const HomeScreen(), 'phone-home-real', settle: false);
    await t.pump(const Duration(milliseconds: 300));
    await _save(t, 'phone-home-real');
    routeOn = true;
    // Inicio real (con el mapa sin teselas: en tests no hay red) para
    // verificar la altura medida de la hoja en reposo.
    await shot(const HomeScreen(), 'phone-home-route', settle: false);
    await t.pump(const Duration(milliseconds: 300));
    await _save(t, 'phone-home-route');
    await shot(const WalletScreen(), 'phone-wallet');
    await shot(const ProfileScreen(), 'phone-profile');
    await shot(const RoutePlannerScreen(), 'phone-planner', settle: false);
    await shot(const RouteDetailScreen(), 'phone-route-detail');
    await shot(const AiChatScreen(), 'phone-assistant', settle: false);
    await shot(const IntroScreen(), 'phone-intro', settle: false);
    await shot(const LocationPermissionScreen(), 'phone-location', settle: false);
    await shot(const LoginScreen(), 'phone-login', settle: false);
    await shot(const RegisterScreen(), 'phone-register', settle: false);

    // Noche: esquema propio.
    dark = true;
    // Los colores del árbol se leen al construirlo: aplicar la noche antes.
    GSColors.apply(Brightness.dark);
    await shot(Scaffold(extendBody: true, backgroundColor: GSColors.background, body: Stack(children: [
      const Positioned.fill(child: ColoredBox(color: Color(0xFF1D222B))),
      Positioned(left: 0, right: 0, bottom: 0, height: 470, child: DecoratedBox(
        decoration: BoxDecoration(color: GSColors.surface, borderRadius: GSRadius.sheetRadius, boxShadow: GSShadow.sheet),
        child: const HomeSheetContent())),
    ]), bottomNavigationBar: const GSBottomNav(current: GSNavTab.home)), 'phone-dark-home-sheet');
    await shot(const SettingsScreen(), 'phone-dark-settings');
    await shot(const HomeScreen(), 'phone-dark-home', settle: false);
    await t.pump(const Duration(milliseconds: 300));
    await _save(t, 'phone-dark-home');
    await shot(const WalletScreen(), 'phone-dark-wallet');
    await shot(const RouteDetailScreen(), 'phone-dark-route-detail');
    await shot(const ProfileScreen(), 'phone-dark-profile');
    await shot(const LoginScreen(), 'phone-dark-login', settle: false);
    await shot(const AiChatScreen(), 'phone-dark-assistant', settle: false);
    dark = false;

    // Texto grande del sistema (PRODUCT.md: hasta 200 % sin cortar).
    for (final scale in [1.3, 2.0]) {
      phone(t, scale: scale);
      final tag = (scale * 100).round();
      await shot(const WalletScreen(), 'phone-wallet-text$tag');
      await shot(const RoutePlannerScreen(), 'phone-planner-text$tag', settle: false);
      await shot(const ProfileScreen(), 'phone-profile-text$tag');
      await shot(const LoginScreen(), 'phone-login-text$tag', settle: false);
    }

    // Opciones de viaje con destino ya elegido (en tests no hay GPS, así que
    // se muestran sueltas con un origen y destino de Riohacha).
    for (final scale in [1.0, 1.3, 2.0]) {
      phone(t, scale: scale);
      final tag = scale == 1.0 ? '' : '-text${(scale * 100).round()}';
      await shot(Scaffold(body: SafeArea(child: ListView(children: const [
        SizedBox(height: 12),
        ModeOptions(from: LatLng(11.5444, -72.9072), to: LatLng(11.5320, -72.8990), selected: 'Mototaxi', onChanged: _noop),
      ]))), 'phone-mode-options$tag');
    }
    phone(t);
    debugDisableShadows = true;
  });
}

void _noop(String _) {}
