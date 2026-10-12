import 'package:flutter_test/flutter_test.dart';
import 'package:gosmart/models/corridor_status.dart';
import 'package:gosmart/widgets/gs_corridor_line.dart';

void main() {
  group('CorridorStatus', () {
    test('noData no inventa un estado', () {
      const s = CorridorStatus.noData();
      expect(s.hasData, isFalse);
      expect(s.summary, RoadState.unknown);
      expect(s.worstSegment, isNull);
      expect(s.updatedAt, isNull);
    });

    test('el resumen es el tramo más grave con datos', () {
      const s = CorridorStatus(segments: [
        CorridorSegment(kmFrom: 0, kmTo: 30, state: RoadState.open),
        CorridorSegment(
            kmFrom: 30, kmTo: 45, state: RoadState.closed, reason: 'Bloqueo'),
        CorridorSegment(kmFrom: 45, kmTo: 75, state: RoadState.caution),
        CorridorSegment(
            kmFrom: 0, kmTo: 0, state: RoadState.closed, isBranch: true),
      ]);
      expect(s.summary, RoadState.closed);
      expect(s.worstSegment?.reason, 'Bloqueo');
    });

    test('el ramal no cuenta para el resumen de la Troncal', () {
      const s = CorridorStatus(segments: [
        CorridorSegment(kmFrom: 0, kmTo: 75, state: RoadState.open),
        CorridorSegment(
            kmFrom: 0, kmTo: 0, state: RoadState.closed, isBranch: true),
      ]);
      expect(s.summary, RoadState.open);
    });

    test('fromMap tolera estados desconocidos', () {
      final seg = CorridorSegment.fromMap(
          {'km_from': 10, 'km_to': 20, 'state': 'raro'});
      expect(seg.state, RoadState.unknown);
      expect(seg.reports, 0);
    });
  });

  test('corridorAge', () {
    final now = DateTime(2026, 10, 12, 12);
    expect(corridorAge(now, now: now), 'ahora');
    expect(corridorAge(now.subtract(const Duration(minutes: 5)), now: now),
        'hace 5 min');
    expect(corridorAge(now.subtract(const Duration(hours: 3)), now: now),
        'hace 3 h');
  });
}
