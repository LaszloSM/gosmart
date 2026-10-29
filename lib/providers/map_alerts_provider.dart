// lib/providers/map_alerts_provider.dart
// Alertas del mapa (Waze) y las preferencias de cada quien: qué tipos ver en
// el mapa y de cuáles avisar al acercarse. Las preferencias viven en el
// teléfono (también para invitados).
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/telemetry.dart';
import '../models/map_alert.dart';
import '../services/corridor_service.dart';

class MapAlertsNotifier extends AsyncNotifier<List<MapAlert>> {
  @override
  Future<List<MapAlert>> build() => _fetch();

  Future<List<MapAlert>> _fetch() async {
    try {
      return await corridorService.fetchAlerts();
    } catch (_) {
      Telemetry.degraded('supabase', 'map_alerts');
      return const [];
    }
  }

  /// Recarga sin mostrar "cargando": los pines se quedan mientras llega lo nuevo.
  Future<void> refresh() async {
    final next = await _fetch();
    state = AsyncData(next);
  }

  /// "Sigue ahí" / "Ya no está": se ve al instante y se manda al servidor.
  /// Si falla, vuelve como estaba y el error sube para avisar.
  Future<void> vote(MapAlert alert, {required bool stillThere}) async {
    final before = state.valueOrNull ?? const <MapAlert>[];
    state = AsyncData([
      for (final a in before)
        if (a.id == alert.id) a.withVote(stillThere) else a,
    ]);
    try {
      await corridorService.vote(alert.id, stillThere: stillThere);
    } catch (e, st) {
      state = AsyncData(before);
      Error.throwWithStackTrace(e, st);
    }
  }
}

final mapAlertsProvider =
    AsyncNotifierProvider<MapAlertsNotifier, List<MapAlert>>(MapAlertsNotifier.new);

class AlertPrefsNotifier extends StateNotifier<Map<String, AlertPref>> {
  AlertPrefsNotifier() : super(_defaults) {
    _load();
  }

  static const _key = 'alert_prefs_v1';
  static final _defaults = {for (final k in AlertKind.all) k.id: const AlertPref()};

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_key);
      if (raw == null) return;
      final m = jsonDecode(raw) as Map<String, dynamic>;
      state = {
        for (final k in AlertKind.all)
          k.id: m[k.id] is Map
              ? AlertPref.fromJson(Map<String, dynamic>.from(m[k.id] as Map))
              : const AlertPref(),
      };
    } catch (_) {}
  }

  Future<void> set(String kind, AlertPref pref) async {
    state = {...state, kind: pref};
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
          _key, jsonEncode({for (final e in state.entries) e.key: e.value.toJson()}));
    } catch (_) {}
  }

  /// Todos los tipos a la vez (interruptor general de la pantalla).
  Future<void> setAll({bool? show, bool? warn}) async {
    for (final k in AlertKind.all) {
      await set(k.id, state[k.id]!.copyWith(show: show, warn: warn));
    }
  }
}

final alertPrefsProvider =
    StateNotifierProvider<AlertPrefsNotifier, Map<String, AlertPref>>((ref) => AlertPrefsNotifier());

/// Lo que se pinta en el mapa: las alertas de los tipos que quieres ver.
final visibleAlertsProvider = Provider<List<MapAlert>>((ref) {
  final prefs = ref.watch(alertPrefsProvider);
  final alerts = ref.watch(mapAlertsProvider).valueOrNull ?? const <MapAlert>[];
  return [
    for (final a in alerts)
      if (prefs[a.kind.id]?.show ?? true) a,
  ];
});
