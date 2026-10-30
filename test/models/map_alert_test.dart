import 'package:flutter_test/flutter_test.dart';
import 'package:gosmart/features/alerts/alert_banner.dart';
import 'package:gosmart/models/map_alert.dart';
import 'package:gosmart/widgets/gs_alert_badge.dart';
import 'package:latlong2/latlong.dart';

MapAlert _alert(String id, String kind, LatLng at, {bool mine = false}) => MapAlert(
      id: id,
      kind: AlertKind.byId(kind),
      at: at,
      happenedAt: DateTime(2026, 10, 29, 8),
      mine: mine,
    );

void main() {
  group('MapAlert', () {
    test('fromMap lee lo que devuelve map_alerts', () {
      final a = MapAlert.fromMap({
        'id': 'a1',
        'kind': 'trancon',
        'lat': 11.54,
        'lng': -72.9,
        'happened_at': '2026-10-29T13:00:00Z',
        'segment_name': null,
        'confirmations': 2,
        'denials': 1,
        'mine': true,
        'my_vote': null,
      });
      expect(a.kind, AlertKind.trancon);
      expect(a.at.latitude, 11.54);
      expect(a.confirmations, 2);
      expect(a.denials, 1);
      expect(a.mine, isTrue);
      expect(a.myVote, isNull);
    });

    test('un tipo desconocido cae en Peligro (no rompe el mapa)', () {
      expect(AlertKind.byId('otro'), AlertKind.peligro);
      expect(AlertKind.byId('despejado'), AlertKind.despejado);
    });

    test('withVote suma una sola vez y cambia de lado al cambiar el voto', () {
      final a = _alert('a', 'hueco', const LatLng(11.5, -72.9));
      final yes = a.withVote(true);
      expect(yes.confirmations, 1);
      expect(yes.myVote, isTrue);
      expect(yes.withVote(true).confirmations, 1);
      final no = yes.withVote(false);
      expect(no.denials, 1);
      expect(no.myVote, isFalse);
    });

    test('alertAge en palabras', () {
      final now = DateTime(2026, 10, 29, 12);
      expect(alertAge(now, now: now), 'ahora');
      expect(alertAge(now.subtract(const Duration(minutes: 5)), now: now), 'hace 5 min');
      expect(alertAge(now.subtract(const Duration(hours: 2)), now: now), 'hace 2 h');
      expect(alertAge(now.subtract(const Duration(days: 1)), now: now), 'hace 1 día');
      expect(alertAge(now.subtract(const Duration(days: 3)), now: now), 'hace 3 días');
    });

    test('AlertPref ida y vuelta por JSON; lo que falta queda encendido', () {
      const p = AlertPref(show: true, warn: false);
      final back = AlertPref.fromJson(p.toJson());
      expect(back.show, isTrue);
      expect(back.warn, isFalse);
      expect(AlertPref.fromJson(const {}).warn, isTrue);
    });
  });

  group('nextAlertToWarn', () {
    const here = LatLng(11.5440, -72.9070);
    // ~110 m y ~330 m al norte; ~1,1 km al norte.
    final near = _alert('near', 'reten', const LatLng(11.5450, -72.9070));
    final mid = _alert('mid', 'trancon', const LatLng(11.5470, -72.9070));
    final far = _alert('far', 'bloqueo', const LatLng(11.5540, -72.9070));
    final prefs = {for (final k in AlertKind.all) k.id: const AlertPref()};

    test('elige la más cercana dentro de 400 m', () {
      expect(nextAlertToWarn(here, [far, mid, near], prefs, {})?.id, 'near');
    });

    test('no repite ni avisa lo que está lejos', () {
      expect(nextAlertToWarn(here, [near, mid], prefs, {'near'})?.id, 'mid');
      expect(nextAlertToWarn(here, [far], prefs, {}), isNull);
    });

    test('respeta "Avisarme" apagado y no avisa de lo tuyo', () {
      final off = {...prefs, 'reten': const AlertPref(warn: false)};
      expect(nextAlertToWarn(here, [near, mid], off, {})?.id, 'mid');
      final mine = _alert('m', 'trancon', const LatLng(11.5441, -72.9070), mine: true);
      expect(nextAlertToWarn(here, [mine], prefs, {}), isNull);
    });
  });

  test('pines por zoom: ciudad punto, barrio pequeño, calle completo', () {
    expect(alertPinSizeFor(10), AlertPinSize.dot);
    // Riohacha entera a la vista (~13): puntos, no globos.
    expect(alertPinSizeFor(13), AlertPinSize.dot);
    expect(alertPinSizeFor(14), AlertPinSize.small);
    expect(alertPinSizeFor(16), AlertPinSize.full);
  });

  test('muy lejos solo se ve lo grave', () {
    final grave = AlertKind.all.firstWhere((k) => k.severity == AlertSeverity.severe);
    final leve = AlertKind.all.firstWhere((k) => k.severity != AlertSeverity.severe);
    expect(alertVisibleAt(grave, 10), isTrue);
    expect(alertVisibleAt(leve, 10), isFalse);
    expect(alertVisibleAt(leve, 12), isTrue);
  });
}
