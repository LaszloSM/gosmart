// lib/services/ride_realtime.dart
// Avisos al instante con Supabase Realtime: cuando un conductor acepta u
// ofrece, o el otro cancela, la pantalla se entera en menos de un segundo en
// vez de esperar a la siguiente consulta. El aviso solo dispara una consulta
// (la verdad sigue saliendo de las RPC y de RLS); las consultas periódicas
// quedan de respaldo, más espaciadas, por si el canal se cae.
// Requiere ride_requests y ride_offers en la publicación supabase_realtime
// (025_mvp_real.sql). Realtime respeta RLS: cada quien recibe solo lo suyo.
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_client.dart';

class RideRealtime {
  /// Escucha una solicitud y sus ofertas (pasajero). null si no hay canal.
  RealtimeChannel? watchRequest(String requestId, VoidCallback onChange) =>
      _open('ride-$requestId', [
        ('ride_requests', 'id', requestId),
        ('ride_offers', 'request_id', requestId),
      ], onChange);

  /// Escucha los viajes asignados a un conductor (aceptó, el pasajero
  /// canceló, aceptaron su contraoferta).
  RealtimeChannel? watchDriver(String driverId, VoidCallback onChange) =>
      _open('driver-$driverId', [
        ('ride_requests', 'driver_id', driverId),
        ('ride_offers', 'driver_id', driverId),
      ], onChange);

  RealtimeChannel? _open(String name,
      List<(String table, String column, String value)> tables, VoidCallback onChange) {
    try {
      var ch = GoSmartSupabase.client.channel(name);
      for (final t in tables) {
        ch = ch.onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: t.$1,
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: t.$2,
            value: t.$3,
          ),
          callback: (_) => onChange(),
        );
      }
      return ch..subscribe();
    } catch (e) {
      // Sin Supabase (pruebas) o sin red: quedan las consultas periódicas.
      debugPrint('[RideRealtime] $e');
      return null;
    }
  }

  void close(RealtimeChannel? ch) {
    if (ch == null) return;
    try {
      GoSmartSupabase.client.removeChannel(ch);
    } catch (_) {}
  }
}

final rideRealtime = RideRealtime();
