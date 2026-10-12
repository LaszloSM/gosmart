// lib/services/dispatch_service.dart
// Cliente de las RPCs de despacho (migración 015). Las decisiones que pueden
// chocar (aceptar, reservar cupo) las toma el servidor con bloqueo (D7);
// aquí solo se llaman y se traducen los errores a palabras.
import 'package:latlong2/latlong.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_client.dart';
import '../models/dispatch_models.dart';
import '../models/route_result.dart';

/// Error del servidor con su código ('already_taken', 'no_seats'…).
class DispatchException implements Exception {
  const DispatchException(this.code);
  final String code;

  String get message => switch (code) {
        'already_taken' => 'Otro conductor tomó este viaje primero.',
        'no_seats' => 'Ya no quedan cupos en esa salida.',
        'dispatch_disabled' => 'Pedir viajes está pausado por ahora.',
        'request_already_open' => 'Ya tienes una solicitud abierta.',
        'driver_busy' => 'Termina tu viaje actual antes de tomar otro.',
        'not_active_driver' => 'Ponte disponible para ver y tomar viajes.',
        'trip_in_progress' => 'Ya tienes un viaje en curso.',
        'too_far' => 'Es muy lejos para mototaxi o taxi.',
        'offer_gone' => 'Esa oferta ya no está.',
        _ => 'No se pudo. Revisa tu conexión e intenta de nuevo.',
      };

  static const _known = [
    'already_taken', 'no_seats', 'dispatch_disabled', 'request_already_open',
    'driver_busy', 'not_active_driver', 'trip_in_progress', 'too_far',
    'offer_gone', 'invalid_transition', 'previous_leg_open', 'own_request',
  ];

  static Never rethrowFrom(Object e) {
    final msg = e is PostgrestException ? e.message : e.toString();
    for (final c in _known) {
      if (msg.contains(c)) throw DispatchException(c);
    }
    throw DispatchException(e is PostgrestException ? 'server' : 'network');
  }
}

class DispatchService {
  SupabaseClient get _db => GoSmartSupabase.client;

  Future<T> _rpc<T>(String fn, [Map<String, dynamic>? params]) async {
    try {
      return await _db.rpc(fn, params: params) as T;
    } catch (e) {
      DispatchException.rethrowFrom(e);
    }
  }

  Future<bool> dispatchEnabled() async {
    try {
      final row = await _db
          .from('app_flags')
          .select('enabled')
          .eq('key', 'dispatch_enabled')
          .maybeSingle();
      return row?['enabled'] as bool? ?? false;
    } catch (_) {
      return false;
    }
  }

  // ── Pasajero ──────────────────────────────────────────────────────────────
  Future<String> requestRide({
    required String service,
    required LatLng origin,
    required String originLabel,
    required LatLng dest,
    required String destLabel,
    required int offeredFare,
    required String idempotencyKey,
    String? tripLegId,
  }) =>
      _rpc<String>('request_ride', {
        'p_service': service,
        'p_origin_lat': origin.latitude,
        'p_origin_lng': origin.longitude,
        'p_origin_label': originLabel,
        'p_dest_lat': dest.latitude,
        'p_dest_lng': dest.longitude,
        'p_dest_label': destLabel,
        'p_offered_fare': offeredFare,
        'p_idempotency_key': idempotencyKey,
        'p_trip_leg_id': tripLegId,
      });

  Future<RideRequest?> fetchRequest(String id) async {
    final row =
        await _db.from('ride_requests').select().eq('id', id).maybeSingle();
    return row == null ? null : RideRequest.fromJson(row);
  }

  Future<List<RideOffer>> offersFor(String requestId) async {
    final rows = await _db
        .from('ride_offers')
        .select('id, fare, status')
        .eq('request_id', requestId)
        .eq('status', 'pending')
        .order('fare');
    return [for (final r in rows as List) RideOffer.fromJson(r as Map<String, dynamic>)];
  }

  Future<void> acceptOffer(String offerId) =>
      _rpc<dynamic>('accept_offer', {'p_offer_id': offerId});

  Future<void> transitionRide(String requestId, RideStatus to) =>
      _rpc<dynamic>('ride_transition',
          {'p_request_id': requestId, 'p_to': rideStatusName(to)});

  Future<AssignedDriver?> driverFor(String requestId) async {
    final rows = await _rpc<List<dynamic>>(
        'ride_driver_view', {'p_request_id': requestId});
    return rows.isEmpty
        ? null
        : AssignedDriver.fromJson(Map<String, dynamic>.from(rows.first as Map));
  }

  Future<List<ColectivoDeparture>> departures(String fromNode, String toNode) async {
    final rows = await _db
        .from('colectivo_departures')
        .select()
        .eq('from_node', fromNode)
        .eq('to_node', toNode)
        .eq('status', 'open')
        .gte('depart_at',
            DateTime.now().subtract(const Duration(minutes: 30)).toUtc().toIso8601String())
        .order('depart_at')
        .limit(10);
    return [
      for (final r in rows as List)
        ColectivoDeparture.fromJson(r as Map<String, dynamic>)
    ];
  }

  Future<String> reserveSeat(String departureId, int seats, String key,
          {String? tripLegId}) =>
      _rpc<String>('reserve_seat', {
        'p_departure_id': departureId,
        'p_seats': seats,
        'p_idempotency_key': key,
        'p_trip_leg_id': tripLegId,
      });

  // ── Viaje encadenado ──────────────────────────────────────────────────────
  Future<String> createTrip(RouteResult route, {
    required String originLabel,
    required String destLabel,
    required String idempotencyKey,
  }) =>
      _rpc<String>('create_trip', {
        'p_origin': originLabel,
        'p_dest': destLabel,
        'p_legs': [for (final l in route.legs) legPayload(l)],
        'p_idempotency_key': idempotencyKey,
      });

  /// Tramo para create_trip. Sin modo del planificador: a pie o mototaxi.
  static Map<String, dynamic> legPayload(RouteLeg l) => {
        'mode': l.transitMode ?? (l.mode == 'walk' ? 'walk' : 'mototaxi'),
        'from_label': l.fromLabel,
        'to_label': l.toLabel,
        'from_node': l.fromNode,
        'to_node': l.toNode,
        'from_lat': l.points.isEmpty ? null : l.points.first.latitude,
        'from_lng': l.points.isEmpty ? null : l.points.first.longitude,
        'to_lat': l.points.isEmpty ? null : l.points.last.latitude,
        'to_lng': l.points.isEmpty ? null : l.points.last.longitude,
        'minutes': l.durationMin,
        'fare_min': l.fareMin,
        'fare_max': l.fareMax,
      };

  Future<ChainedTrip?> activeTrip() async {
    final row = await _db
        .from('chained_trips')
        .select('*, trip_legs(*)')
        .inFilter('status', ['planned', 'in_progress'])
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return row == null ? null : ChainedTrip.fromJson(row);
  }

  Future<void> legTransition(String legId, LegStatus to, {int? agreedFare}) =>
      _rpc<dynamic>('trip_leg_transition', {
        'p_leg_id': legId,
        'p_to': legStatusName(to),
        'p_agreed_fare': agreedFare,
      });

  Future<void> cancelTrip(String tripId) =>
      _rpc<dynamic>('cancel_trip', {'p_trip_id': tripId});

  /// Solicitud abierta o en curso ligada a un tramo (para retomar la espera).
  Future<RideRequest?> requestForLeg(String legId) async {
    final row = await _db
        .from('ride_requests')
        .select()
        .eq('trip_leg_id', legId)
        .inFilter('status', ['open', 'accepted', 'in_progress', 'completed'])
        .order('created_at', ascending: false)
        .limit(1)
        .maybeSingle();
    return row == null ? null : RideRequest.fromJson(row);
  }

  // ── Conductor ─────────────────────────────────────────────────────────────
  Future<void> ping(LatLng at) => _rpc<dynamic>(
      'driver_ping', {'p_lat': at.latitude, 'p_lng': at.longitude});

  Future<List<NearbyRequest>> nearby(LatLng at, {double radiusKm = 3}) async {
    final rows = await _rpc<List<dynamic>>('nearby_requests', {
      'p_lat': at.latitude,
      'p_lng': at.longitude,
      'p_radius_km': radiusKm,
    });
    return [
      for (final r in rows) NearbyRequest.fromJson(Map<String, dynamic>.from(r as Map))
    ];
  }

  Future<void> acceptRide(String requestId) =>
      _rpc<dynamic>('accept_ride', {'p_request_id': requestId});

  Future<void> counterOffer(String requestId, int fare) =>
      _rpc<dynamic>('counter_offer', {'p_request_id': requestId, 'p_fare': fare});

  /// Viaje que el conductor tiene asignado ahora.
  Future<RideRequest?> myAssignedRide(String driverId) async {
    final row = await _db
        .from('ride_requests')
        .select()
        .eq('driver_id', driverId)
        .inFilter('status', ['accepted', 'in_progress'])
        .limit(1)
        .maybeSingle();
    return row == null ? null : RideRequest.fromJson(row);
  }

  Future<String> publishDeparture({
    required String fromNode,
    required String toNode,
    required DateTime departAt,
    required int seats,
    required int fare,
  }) =>
      _rpc<String>('publish_departure', {
        'p_from': fromNode,
        'p_to': toNode,
        'p_depart_at': departAt.toUtc().toIso8601String(),
        'p_seats': seats,
        'p_fare': fare,
      });

  Future<List<ColectivoDeparture>> myDepartures(String driverId) async {
    final rows = await _db
        .from('colectivo_departures')
        .select()
        .eq('driver_id', driverId)
        .inFilter('status', ['open', 'full'])
        .order('depart_at');
    return [
      for (final r in rows as List)
        ColectivoDeparture.fromJson(r as Map<String, dynamic>)
    ];
  }
}

final dispatchService = DispatchService();
