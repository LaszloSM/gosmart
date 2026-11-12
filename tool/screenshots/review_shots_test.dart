import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gosmart/features/driver/driver_console.dart';
import 'package:gosmart/models/driver_model.dart';
import 'package:gosmart/providers/driver_provider.dart';
import 'package:gosmart/features/trip/trip_screen.dart';
import 'package:gosmart/features/trip/widgets/leg_panels.dart';
import 'package:gosmart/models/dispatch_models.dart';
import 'package:gosmart/providers/dispatch_provider.dart';
import 'package:gosmart/features/routes/widgets/mode_options.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gosmart/features/trip/trip_detail_screen.dart';
import 'package:gosmart/features/trip/trip_history_screen.dart';
import 'package:gosmart/models/trip_history.dart';
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
    var shotMode = 'Colectivo';
    final ov = <Override>[
      corridorStatusProvider.overrideWith((ref) async => status),
      isGuestProvider.overrideWith((ref) => guest),
      currentUserProvider.overrideWithValue(null),
      favoritePlacesProvider.overrideWith((ref) async => []),
      activeCardProvider.overrideWith((ref) => _Card()),
      profileProvider.overrideWith((ref) => _P()),
      aiConversationProvider.overrideWith((ref) => _Ai()),
      activeRouteProvider.overrideWith((ref) => routeOn ? route : null),
      selectedModeProvider.overrideWith((ref) => shotMode),
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
      if (settle) { await t.pumpAndSettle(); } else { for (var i = 0; i < 6; i++) { await t.pump(const Duration(milliseconds: 80)); } }
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
    // Viaje (InDrive/Uber): cada fase del tramo en mototaxi, sin red.
    const leg = TripLegRow(id: 'l', seq: 0, mode: 'mototaxi', status: LegStatus.awaitingDispatch,
        fromLabel: 'Parque Padilla', toLabel: 'Universidad de La Guajira',
        from: LatLng(11.5441, -72.9071), to: LatLng(11.5262, -72.8740), fareMin: 5000, fareMax: 5000);
    final req = RideRequest(id: 'r', service: 'mototaxi', status: RideStatus.open, offeredFare: 5000,
        expiresAt: DateTime.now().add(const Duration(minutes: 2, seconds: 14)));
    const offers = [
      RideOffer(id: 'o1', fare: 5500, firstName: 'Wilmer', vehicle: 'Bajaj negra', rating: 4.8, ratings: 51, pickupKm: 0.6, etaMin: 3),
      RideOffer(id: 'o2', fare: 6000, firstName: 'Yair', vehicle: 'AKT roja', pickupKm: 1.3, etaMin: 5),
    ];
    const drv = AssignedDriver(firstName: 'Wilmer', service: 'mototaxi', plate: 'ABC12D',
        vehicle: 'Bajaj negra', at: LatLng(11.5470, -72.9040), rating: 4.8, ratings: 51);
    Widget phase(RideRequest? r, {List<RideOffer> o = const [], AssignedDriver? d, bool paid = false}) =>
        Scaffold(backgroundColor: GSColors.background, body: SafeArea(child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Container(padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: GSColors.surface, borderRadius: BorderRadius.circular(16)),
            child: RideLegPanel(leg: leg, preview: (request: r, offers: o, driver: d, paid: paid))))));
    guest = false;
    await shot(phase(null), 'phone-trip-ask');
    await shot(phase(req, o: offers), 'phone-trip-offers', settle: false);
    await shot(phase(req), 'phone-trip-searching', settle: false);
    await shot(phase(RideRequest(id: 'r', service: 'mototaxi', status: RideStatus.accepted, offeredFare: 5000,
        agreedFare: 5500, expiresAt: DateTime.now()), d: drv), 'phone-trip-coming');
    // Pedir en un toque: los dos puntos listos, opciones y "Pedir mototaxi · $X".
    shotMode = 'Mototaxi';
    await shot(const RoutePlannerScreen(), 'phone-planner-ready', settle: false, extra: [
      pendingPlanProvider.overrideWith((ref) => const PlannerPreset(
          origin: LatLng(11.5444, -72.9072), originLabel: 'Calle 15 # 10-20, Riohacha',
          dest: LatLng(11.5275, -72.8880), destLabel: 'Universidad de La Guajira')),
    ]);
    shotMode = 'Colectivo';
    // Historial completo y detalle estilo InDrive.
    final hist = [
      HistoryItem.fromJson({'kind': 'trip', 'id': 'h1', 'status': 'completed',
        'created_at': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
        'origin': 'Parque Padilla', 'destination': 'Universidad de La Guajira', 'modes': ['mototaxi'],
        'from': {'lat': 11.54, 'lng': -72.90}, 'to': {'lat': 11.52, 'lng': -72.88}, 'total_paid': 5500, 'requests': 1,
        'last_ride': {'id': 'r1', 'service': 'mototaxi', 'status': 'completed', 'offered_fare': 5000,
          'agreed_fare': 5500, 'other_name': 'Wilmer', 'plate': 'ABC12D', 'pay_method': 'cash'}}),
      HistoryItem.fromJson({'kind': 'trip', 'id': 'h2', 'status': 'cancelled',
        'created_at': DateTime.now().subtract(const Duration(days: 1)).toIso8601String(),
        'origin': 'Calle 15 # 10-20', 'destination': 'Terminal de Riohacha', 'modes': ['taxi'],
        'from': {'lat': 11.54, 'lng': -72.90}, 'to': {'lat': 11.53, 'lng': -72.91}, 'requests': 1,
        'last_ride': {'id': 'r2', 'service': 'taxi', 'status': 'expired', 'offered_fare': 9000}}),
      HistoryItem.fromJson({'kind': 'ride', 'id': 'h3', 'service': 'mototaxi', 'status': 'completed',
        'created_at': DateTime.now().subtract(const Duration(days: 3)).toIso8601String(),
        'origin': 'Barrio Los Almendros', 'destination': 'Hospital', 'offered_fare': 4000,
        'agreed_fare': 4500, 'other_name': 'Ana', 'paid': 4500}),
    ];
    await shot(TripHistoryScreen(load: (o) async => o == 0 ? hist : []), 'phone-history');
    await shot(TripDetailScreen(item: hist[0], showMap: false, load: (_) async => TripDetail.fromJson({
      'kind': 'trip', 'id': 'h1', 'status': 'completed', 'origin': 'Parque Padilla',
      'destination': 'Universidad de La Guajira', 'total_paid': 5500,
      'created_at': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
      'legs': [{'seq': 0, 'mode': 'mototaxi', 'status': 'completed',
        'from': {'lat': 11.54, 'lng': -72.90}, 'to': {'lat': 11.52, 'lng': -72.88},
        'rides': [
          {'id': 'a', 'service': 'mototaxi', 'status': 'expired', 'offered_fare': 5000,
           'created_at': DateTime.now().subtract(const Duration(hours: 2, minutes: 6)).toIso8601String()},
          {'id': 'b', 'service': 'mototaxi', 'status': 'completed', 'offered_fare': 5500, 'agreed_fare': 5500,
           'other_name': 'Wilmer', 'plate': 'ABC12D', 'vehicle': 'Bajaj negra', 'pay_method': 'cash', 'my_stars': 5,
           'created_at': DateTime.now().subtract(const Duration(hours: 2, minutes: 2)).toIso8601String(),
           'accepted_at': DateTime.now().subtract(const Duration(hours: 2)).toIso8601String(),
           'finished_at': DateTime.now().subtract(const Duration(hours: 1, minutes: 46)).toIso8601String()},
        ]}],
    })), 'phone-trip-detail');
    await shot(phase(RideRequest(id: 'r', service: 'mototaxi', status: RideStatus.inProgress, offeredFare: 5000,
        agreedFare: 5500, expiresAt: DateTime.now()), d: drv), 'phone-trip-riding');
    final trip = ChainedTrip.fromJson({
      'id': 't', 'status': 'in_progress', 'origin_label': 'Parque Padilla', 'dest_label': 'Universidad de La Guajira',
      'trip_legs': [
        {'id': 'a', 'seq': 0, 'mode': 'walk', 'status': 'completed', 'to_label': 'Calle 2 con carrera 7', 'minutes': 3},
        {'id': 'b', 'seq': 1, 'mode': 'walk', 'status': 'planned', 'to_label': 'Universidad de La Guajira', 'minutes': 4},
      ],
    });
    await shot(const TripScreen(), 'phone-trip-screen', settle: false, extra: [
      activeTripProvider.overrideWith((ref) async => trip),
      recentTripsProvider.overrideWith((ref) async => const []),
    ]);
    final me = DriverProfile.fromJson({
      'user_id': 'u', 'full_name': 'Wilmer Pushaina', 'cedula': '1118555444', 'phone': '+573001234567',
      'service': 'mototaxi', 'zone': 'riohacha', 'status': 'approved', 'available': false,
      'vehicles': [{'plate': 'ABC12D', 'kind': 'moto', 'seats': 1, 'brand': 'Bajaj', 'color': 'negra'}],
      'driver_documents': [],
    });
    final earn = [driverEarningsProvider.overrideWith((ref) async => const DriverEarnings(
        todayTotal: 23000, todayTrips: 4, todayCash: 8000, weekTotal: 118000, weekTrips: 21,
        weekCash: 40000, rating: 4.8, ratings: 51))];
    await shot(DriverConsole(driver: me), 'phone-driver-offline', settle: false, extra: earn);
    guest = true;
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
    guest = false;
    await shot(phase(req, o: offers), 'phone-dark-trip-offers', settle: false);
    await shot(DriverConsole(driver: me), 'phone-dark-driver-offline', settle: false, extra: earn);
    guest = true;
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
