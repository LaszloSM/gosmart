// test/widget/own_alert_vote_test.dart
// La alerta propia también se puede votar (como Waze), y un error dice su
// motivo real en vez de "revisa tu conexión".
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gosmart/features/alerts/alert_detail_sheet.dart';
import 'package:gosmart/models/map_alert.dart';
import 'package:gosmart/providers/auth_provider.dart';
import 'package:gosmart/providers/map_alerts_provider.dart';
import 'package:gosmart/services/corridor_service.dart';
import 'package:gosmart/theme/app_theme.dart';
import 'package:latlong2/latlong.dart';

class _Alerts extends MapAlertsNotifier {
  _Alerts(this.items);
  final List<MapAlert> items;
  @override
  Future<List<MapAlert>> build() async => items;
}

void main() {
  test('el motivo real de un voto que falla', () {
    expect(CorridorService.voteErrorText(Exception('report_not_active')),
        contains('ya no está activa'));
    expect(CorridorService.voteErrorText(Exception('cannot_vote_own')),
        contains('tu propia alerta'));
    expect(CorridorService.voteErrorText(Exception('SocketException: x')),
        contains('Sin conexión'));
  });

  testWidgets('en la alerta propia salen "Sigue ahí" y "Ya no está: quitar"',
      (tester) async {
    final mine = MapAlert(
      id: 'a1',
      kind: AlertKind.obra,
      at: const LatLng(11.54, -72.91),
      happenedAt: DateTime.now().subtract(const Duration(minutes: 5)),
      segmentName: 'Km 20 a 30',
      mine: true,
    );
    await tester.pumpWidget(ProviderScope(
      overrides: [
        isGuestProvider.overrideWithValue(false),
        currentUserProvider.overrideWithValue(null),
        mapAlertsProvider.overrideWith(() => _Alerts([mine])),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(body: AlertDetailSheet(alertId: 'a1', initial: mine)),
      ),
    ));
    await tester.pumpAndSettle();
    expect(find.text('Lo reportaste tú · hace 5 min'), findsOneWidget);
    expect(find.text('Sigue ahí'), findsOneWidget);
    expect(find.text('Ya no está: quitar'), findsOneWidget);
  });
}
