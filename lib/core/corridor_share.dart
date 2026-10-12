// lib/core/corridor_share.dart
// Texto para mandar el estado de la Troncal por WhatsApp. Puro y probado.
import '../models/corridor_status.dart';
import 'safety_links.dart' show clock12;

String? corridorPageLink(String baseUrl) {
  final base = baseUrl.trim();
  if (base.isEmpty) return null;
  return '${base.endsWith('/') ? base : '$base/'}via.html';
}

String corridorShareMessage(CorridorStatus s, {String? link}) {
  final b = StringBuffer('La Troncal Riohacha–Maicao');
  final problems = s.mainSegments
      .where((x) => x.state == RoadState.closed || x.state == RoadState.caution)
      .toList()
    ..sort((a, c) => a.kmFrom.compareTo(c.kmFrom));
  if (!s.hasData) {
    b.write(': sin reportes vigentes.');
  } else if (problems.isEmpty) {
    b.write(': reportada despejada.');
  } else {
    b.write(':');
    for (final p in problems) {
      b.write('\n• ${p.state.label}: ${p.reason ?? 'reporte'} '
          '(km ${p.kmFrom.round()}–${p.kmTo.round()})');
    }
  }
  if (s.updatedAt != null) {
    b.write('\nÚltimo reporte: ${clock12(s.updatedAt!)}');
  }
  if (link != null) b.write('\nMíralo en vivo: $link');
  return b.toString();
}
