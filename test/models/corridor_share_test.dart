import 'package:flutter_test/flutter_test.dart';
import 'package:gosmart/core/corridor_share.dart';
import 'package:gosmart/models/corridor_status.dart';

void main() {
  test('sin datos lo dice tal cual', () {
    expect(corridorShareMessage(const CorridorStatus.noData()),
        'La Troncal Riohacha–Maicao: sin reportes vigentes.');
  });

  test('lista los problemas en orden de km, con palabra y motivo', () {
    final s = CorridorStatus(segments: const [
      CorridorSegment(kmFrom: 40, kmTo: 50, state: RoadState.caution, reason: 'Retén'),
      CorridorSegment(kmFrom: 0, kmTo: 10, state: RoadState.open),
      CorridorSegment(kmFrom: 30, kmTo: 40, state: RoadState.closed, reason: 'Bloqueo'),
    ], updatedAt: DateTime(2026, 10, 12, 7, 5));
    expect(
        corridorShareMessage(s, link: corridorPageLink('https://x.io/g')),
        'La Troncal Riohacha–Maicao:\n'
        '• Cerrada: Bloqueo (km 30–40)\n'
        '• Precaución: Retén (km 40–50)\n'
        'Último reporte: 7:05 a. m.\n'
        'Míralo en vivo: https://x.io/g/via.html');
  });
}
