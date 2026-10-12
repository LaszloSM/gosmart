// lib/services/trust_service.dart
// Calificaciones (017) y funciones del panel admin.
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_client.dart';

class AdminDriverRow {
  const AdminDriverRow({
    required this.userId,
    required this.fullName,
    required this.cedula,
    required this.phone,
    required this.service,
    required this.zone,
    required this.status,
    required this.documents,
    this.plate,
  });
  final String userId, fullName, cedula, phone, service, zone, status;
  final List<String> documents;
  final String? plate;

  factory AdminDriverRow.fromJson(Map<String, dynamic> j) => AdminDriverRow(
        userId: j['user_id'] as String,
        fullName: j['full_name'] as String,
        cedula: j['cedula'] as String,
        phone: j['phone'] as String,
        service: j['service'] as String,
        zone: j['zone'] as String,
        status: j['status'] as String,
        plate: j['plate'] as String?,
        documents: [for (final d in (j['documents'] as List? ?? const [])) d as String],
      );
}

class AdminReportRow {
  const AdminReportRow({
    required this.id,
    required this.segmentId,
    required this.kind,
    required this.happenedAt,
    required this.removed,
    required this.confirmations,
    required this.denials,
  });
  final String id, segmentId, kind;
  final DateTime happenedAt;
  final bool removed;
  final int confirmations, denials;

  factory AdminReportRow.fromJson(Map<String, dynamic> j) => AdminReportRow(
        id: j['id'] as String,
        segmentId: j['segment_id'] as String,
        kind: j['kind'] as String,
        happenedAt: DateTime.parse(j['happened_at'] as String).toLocal(),
        removed: j['removed'] as bool? ?? false,
        confirmations: (j['confirmations'] as num?)?.toInt() ?? 0,
        denials: (j['denials'] as num?)?.toInt() ?? 0,
      );
}

class TrustService {
  SupabaseClient get _db => GoSmartSupabase.client;

  Future<void> rate(String requestId, int stars, List<String> tags) =>
      _db.rpc('rate_ride', params: {
        'p_request_id': requestId,
        'p_stars': stars,
        'p_tags': tags,
      });

  // ── Admin ────────────────────────────────────────────────────────────────
  Future<List<AdminDriverRow>> driverQueue() async {
    final rows = await _db.rpc('admin_driver_queue') as List;
    return [for (final r in rows) AdminDriverRow.fromJson(Map<String, dynamic>.from(r as Map))];
  }

  Future<void> reviewDriver(String userId, String status, {String? note}) =>
      _db.rpc('admin_review_driver', params: {
        'p_user_id': userId,
        'p_status': status,
        'p_note': note,
      });

  /// Enlace temporal (10 min) a la foto de un documento del bucket privado.
  Future<String> documentUrl(String userId, String kind) =>
      _db.storage.from('driver-docs').createSignedUrl('$userId/$kind.jpg', 600);

  Future<List<AdminReportRow>> recentReports() async {
    final rows = await _db.rpc('admin_recent_reports', params: {'p_hours': 72}) as List;
    return [for (final r in rows) AdminReportRow.fromJson(Map<String, dynamic>.from(r as Map))];
  }

  Future<void> removeReport(String id) =>
      _db.rpc('admin_remove_report', params: {'p_report_id': id});

  Future<Map<String, dynamic>> metrics(int days) async =>
      Map<String, dynamic>.from(
          await _db.rpc('admin_metrics', params: {'p_days': days}) as Map);

  Future<Map<String, bool>> flags() async {
    final rows = await _db.from('app_flags').select('key, enabled') as List;
    return {for (final r in rows) r['key'] as String: r['enabled'] as bool};
  }

  Future<void> setFlag(String key, bool enabled) => _db
      .from('app_flags')
      .update({'enabled': enabled, 'updated_at': DateTime.now().toUtc().toIso8601String()})
      .eq('key', key);
}

final trustService = TrustService();
