// lib/services/corridor_service.dart
// Estado del corredor y reportes viales (migración 013). El estado es público
// (también para invitados); reportar y confirmar pide cuenta. Sin señal, el
// reporte queda en la cola y el estado se muestra desde lo último guardado.
import 'dart:convert';
import 'dart:math' as math;

import 'package:latlong2/latlong.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/supabase_client.dart';
import '../core/sync_queue.dart';
import '../models/corridor_status.dart';

/// Tipos de reporte cerrados (regla ética: no hay texto libre).
const roadReportKinds = {
  'bloqueo': 'Bloqueo',
  'reten': 'Retén',
  'accidente': 'Accidente',
  'inundacion': 'Inundación',
  'hueco': 'Huecos',
  'despejado': 'Vía despejada',
};

/// Tramo con sus extremos, para saber en cuál está el usuario.
class RoadSegmentGeo {
  const RoadSegmentGeo({
    required this.id,
    required this.name,
    required this.from,
    required this.to,
    this.isBranch = false,
  });
  final String id;
  final String name;
  final LatLng from;
  final LatLng to;
  final bool isBranch;

  factory RoadSegmentGeo.fromMap(Map<String, dynamic> m) => RoadSegmentGeo(
        id: m['id'] as String,
        name: m['name'] as String,
        from: LatLng((m['lat_from'] as num).toDouble(),
            (m['lng_from'] as num).toDouble()),
        to: LatLng(
            (m['lat_to'] as num).toDouble(), (m['lng_to'] as num).toDouble()),
        isBranch: m['is_branch'] as bool? ?? false,
      );
}

/// Distancia aproximada en metros de [p] al segmento recto [a]–[b].
double distanceToSegmentMeters(LatLng p, LatLng a, LatLng b) {
  const mPerDeg = 111320.0;
  final k = math.cos(p.latitude * math.pi / 180);
  final ax = a.longitude * k, ay = a.latitude;
  final bx = b.longitude * k, by = b.latitude;
  final px = p.longitude * k, py = p.latitude;
  final dx = bx - ax, dy = by - ay;
  final len2 = dx * dx + dy * dy;
  final t = len2 == 0 ? 0.0 : (((px - ax) * dx + (py - ay) * dy) / len2).clamp(0.0, 1.0);
  final cx = ax + t * dx, cy = ay + t * dy;
  return math.sqrt((px - cx) * (px - cx) + (py - cy) * (py - cy)) * mPerDeg;
}

/// Tramo más cercano si está a menos de [maxMeters]; null si estás lejos de la vía.
RoadSegmentGeo? nearestSegment(LatLng p, List<RoadSegmentGeo> segments,
    {double maxMeters = 3000}) {
  RoadSegmentGeo? best;
  var bestD = double.infinity;
  for (final s in segments) {
    final d = distanceToSegmentMeters(p, s.from, s.to);
    if (d < bestD) {
      bestD = d;
      best = s;
    }
  }
  return bestD <= maxMeters ? best : null;
}

class CorridorService {
  static const _cacheKey = 'corridor_status_v1';

  Future<CorridorStatus> fetchStatus() async {
    final rows = await GoSmartSupabase.client.rpc('road_status');
    final status = CorridorStatus.fromRows([
      for (final r in rows as List) Map<String, dynamic>.from(r as Map)
    ]);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_cacheKey, jsonEncode(status.toJson()));
    } catch (_) {}
    return status;
  }

  /// Último estado guardado, marcado como viejo; null si nunca hubo.
  Future<CorridorStatus?> cachedStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_cacheKey);
      if (raw == null) return null;
      return CorridorStatus.fromJson(jsonDecode(raw) as Map<String, dynamic>)
          .copyWith(isStale: true);
    } catch (_) {
      return null;
    }
  }

  static const _segmentsKey = 'road_segments_v1';

  /// Tramos con su trazado. Se guardan: reportar en la Troncal sin señal es
  /// el caso principal, y la cola offline necesita poder elegir el tramo.
  Future<List<RoadSegmentGeo>> fetchSegments() async {
    try {
      final rows = await GoSmartSupabase.client
          .from('road_segments')
          .select('id, name, is_branch, lat_from, lng_from, lat_to, lng_to')
          .order('is_branch')
          .order('km_from');
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString(_segmentsKey, jsonEncode(rows));
      } catch (_) {}
      return [
        for (final r in rows as List) RoadSegmentGeo.fromMap(r as Map<String, dynamic>)
      ];
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_segmentsKey);
      if (raw == null) rethrow;
      return [
        for (final r in jsonDecode(raw) as List)
          RoadSegmentGeo.fromMap(Map<String, dynamic>.from(r as Map))
      ];
    }
  }

  /// Envía el reporte; sin señal lo encola. true = ya llegó al servidor.
  Future<bool> report({
    required String segmentId,
    required String kind,
    required String idempotencyKey,
    LatLng? at,
  }) async {
    final payload = {
      'p_segment_id': segmentId,
      'p_kind': kind,
      'p_idempotency_key': idempotencyKey,
      'p_lat': at?.latitude,
      'p_lng': at?.longitude,
      'p_happened_at': DateTime.now().toUtc().toIso8601String(),
    };
    try {
      await _sendReport(payload);
      return true;
    } on RoadReportRejected {
      rethrow;
    } catch (_) {
      await syncQueue.enqueue(SyncOp(
        kind: 'road_report',
        key: idempotencyKey,
        payload: payload,
        createdAt: DateTime.now(),
      ));
      return false;
    }
  }

  Future<void> _sendReport(Map<String, dynamic> payload) async {
    try {
      await GoSmartSupabase.client.rpc('report_road', params: payload);
    } catch (e) {
      final msg = e.toString();
      // Rechazos del servidor: reintentar no sirve.
      for (final code in ['rate_limited', 'duplicate_report', 'unknown_segment', 'invalid_kind']) {
        if (msg.contains(code)) throw RoadReportRejected(code);
      }
      rethrow;
    }
  }

  Future<void> vote(String reportId, {required bool stillThere}) async {
    await GoSmartSupabase.client.rpc('vote_road_report', params: {
      'p_report_id': reportId,
      'p_still_there': stillThere,
    });
  }

  void registerSyncHandlers(SyncQueue queue) {
    queue.register('road_report', (op) async {
      try {
        await _sendReport(op.payload);
      } on RoadReportRejected {
        // El servidor no lo quiere (límite, repetido): se descarta.
      }
      return true;
    });
  }
}

class RoadReportRejected implements Exception {
  const RoadReportRejected(this.code);
  final String code;
}

final corridorService = CorridorService();
