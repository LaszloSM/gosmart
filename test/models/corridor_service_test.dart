// test/models/corridor_service_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:gosmart/models/corridor_status.dart';
import 'package:gosmart/services/corridor_service.dart';
import 'package:latlong2/latlong.dart';

void main() {
  const segs = [
    RoadSegmentGeo(id: 'a', name: 'A', from: LatLng(11.544, -72.907), to: LatLng(11.505, -72.825)),
    RoadSegmentGeo(id: 'b', name: 'B', from: LatLng(11.505, -72.825), to: LatLng(11.465, -72.743)),
  ];

  test('ubica el tramo más cercano sobre la vía', () {
    expect(nearestSegment(const LatLng(11.49, -72.79), segs)?.id, 'b');
    expect(nearestSegment(const LatLng(11.53, -72.88), segs)?.id, 'a');
  });

  test('lejos de la vía no adivina un tramo', () {
    expect(nearestSegment(const LatLng(11.0, -72.0), segs), isNull);
  });

  test('road_status → modelo: estado, motivo, reporte y hora más reciente', () {
    final s = CorridorStatus.fromRows([
      {'segment_id': 'a', 'name': 'A', 'km_from': 0, 'km_to': 10, 'is_branch': false,
       'state': 'unknown', 'reason': null, 'reports': 0, 'report_id': null, 'updated_at': null},
      {'segment_id': 'b', 'name': 'B', 'km_from': 30, 'km_to': 40, 'is_branch': false,
       'state': 'closed', 'reason': 'Bloqueo', 'reports': 2, 'report_id': 'r1',
       'updated_at': '2026-10-12T10:00:00Z'},
    ]);
    expect(s.summary, RoadState.closed);
    expect(s.worstSegment?.reason, 'Bloqueo');
    expect(s.worstSegment?.reportId, 'r1');
    expect(s.updatedAt, DateTime.utc(2026, 10, 12, 10).toLocal());
  });

  test('sin filas = sin datos, nunca abierta', () {
    final s = CorridorStatus.fromRows([]);
    expect(s.hasData, isFalse);
    expect(s.summary, RoadState.unknown);
  });

  test('el estado guardado vuelve igual (para mostrarlo sin señal)', () {
    final s = CorridorStatus.fromRows([
      {'segment_id': 'b', 'name': 'B', 'km_from': 30, 'km_to': 40, 'is_branch': false,
       'state': 'caution', 'reason': 'Retén', 'reports': 1, 'report_id': 'r2',
       'updated_at': '2026-10-12T10:00:00Z'},
    ]);
    final back = CorridorStatus.fromJson(s.toJson()).copyWith(isStale: true);
    expect(back.isStale, isTrue);
    expect(back.worstSegment?.reason, 'Retén');
    expect(back.updatedAt, s.updatedAt);
  });
}
