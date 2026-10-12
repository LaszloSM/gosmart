// lib/core/sync_queue.dart
// Cola de escrituras pendientes para cuando no hay señal (Fase 3, offline).
// Cada operación lleva su idempotency_key: reenviarla no duplica nada en el
// servidor (decisión E6). Se guarda en SharedPreferences como JSON: es poco
// volumen (SOS, reportes, cobros) y no exige generar código como drift.
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class SyncOp {
  const SyncOp({
    required this.kind,
    required this.key,
    required this.payload,
    required this.createdAt,
    this.attempts = 0,
  });

  /// Tipo de operación: decide qué handler la envía ('sos', 'road_report'…).
  final String kind;

  /// idempotency_key; dos operaciones con la misma llave son la misma.
  final String key;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final int attempts;

  SyncOp retried() => SyncOp(
      kind: kind,
      key: key,
      payload: payload,
      createdAt: createdAt,
      attempts: attempts + 1);

  Map<String, dynamic> toJson() => {
        'kind': kind,
        'key': key,
        'payload': payload,
        'created_at': createdAt.toIso8601String(),
        'attempts': attempts,
      };

  factory SyncOp.fromJson(Map<String, dynamic> j) => SyncOp(
        kind: j['kind'] as String,
        key: j['key'] as String,
        payload: Map<String, dynamic>.from(j['payload'] as Map),
        createdAt: DateTime.parse(j['created_at'] as String),
        attempts: (j['attempts'] as num?)?.toInt() ?? 0,
      );
}

/// Envía una operación. true = el servidor la aceptó (o ya la tenía).
/// Lanzar o devolver false = se reintenta después.
typedef SyncHandler = Future<bool> Function(SyncOp op);

class SyncQueue {
  SyncQueue({Map<String, SyncHandler>? handlers})
      : _handlers = handlers ?? {};

  static const _prefsKey = 'sync_queue_v1';

  /// Tras tantos intentos fallidos la operación se descarta (no bloquea la cola).
  static const maxAttempts = 20;

  /// Operaciones más viejas que esto ya no sirven (un SOS de hace 3 días).
  static const maxAge = Duration(days: 2);

  final Map<String, SyncHandler> _handlers;
  bool _flushing = false;

  void register(String kind, SyncHandler handler) => _handlers[kind] = handler;

  Future<List<SyncOp>> pending() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_prefsKey);
    if (raw == null) return [];
    try {
      return [
        for (final j in jsonDecode(raw) as List)
          SyncOp.fromJson(j as Map<String, dynamic>)
      ];
    } catch (_) {
      return []; // JSON dañado: mejor una cola vacía que un cierre de la app.
    }
  }

  Future<void> _save(List<SyncOp> ops) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
        _prefsKey, jsonEncode([for (final o in ops) o.toJson()]));
  }

  /// Agrega sin duplicar: misma llave = misma operación.
  Future<void> enqueue(SyncOp op) async {
    final ops = await pending();
    if (ops.any((o) => o.key == op.key)) return;
    await _save([...ops, op]);
  }

  /// Intenta enviar todo, en orden. Devuelve cuántas quedaron pendientes.
  Future<int> flush({DateTime? now}) async {
    if (_flushing) return (await pending()).length;
    _flushing = true;
    try {
      final t = now ?? DateTime.now();
      final remaining = <SyncOp>[];
      for (final op in await pending()) {
        if (t.difference(op.createdAt) > maxAge) continue;
        final handler = _handlers[op.kind];
        if (handler == null) {
          remaining.add(op); // aún no registrado en esta sesión
          continue;
        }
        var ok = false;
        try {
          ok = await handler(op);
        } catch (_) {
          ok = false;
        }
        if (ok) continue;
        final next = op.retried();
        if (next.attempts < maxAttempts) remaining.add(next);
      }
      await _save(remaining);
      return remaining.length;
    } finally {
      _flushing = false;
    }
  }
}

final syncQueue = SyncQueue();
