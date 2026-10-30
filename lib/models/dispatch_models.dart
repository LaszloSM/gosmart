// lib/models/dispatch_models.dart
// Despacho (migración 015): solicitudes, ofertas, salidas de colectivo y
// viaje encadenado. Modelos puros.
import 'package:latlong2/latlong.dart';

DateTime? _ts(Object? v) =>
    v == null ? null : DateTime.tryParse(v as String)?.toLocal();

enum RideStatus { open, accepted, inProgress, completed, cancelled, expired }

RideStatus rideStatusFrom(String? s) => switch (s) {
      'accepted' => RideStatus.accepted,
      'in_progress' => RideStatus.inProgress,
      'completed' => RideStatus.completed,
      'cancelled' => RideStatus.cancelled,
      'expired' => RideStatus.expired,
      _ => RideStatus.open,
    };

String rideStatusName(RideStatus s) => switch (s) {
      RideStatus.inProgress => 'in_progress',
      _ => s.name,
    };

class RideRequest {
  const RideRequest({
    required this.id,
    required this.service,
    required this.status,
    required this.offeredFare,
    required this.expiresAt,
    this.originLabel,
    this.destLabel,
    this.origin,
    this.dest,
    this.driverId,
    this.agreedFare,
    this.tripLegId,
  });

  final String id;
  final String service;
  final RideStatus status;
  final int offeredFare;
  final DateTime expiresAt;
  final String? originLabel;
  final String? destLabel;
  final LatLng? origin;
  final LatLng? dest;
  final String? driverId;
  final int? agreedFare;
  final String? tripLegId;

  /// Abierta y vigente (las vencidas se ven 'open' hasta que alguien las toque).
  bool isLive(DateTime now) =>
      status == RideStatus.open && now.isBefore(expiresAt);

  factory RideRequest.fromJson(Map<String, dynamic> j) => RideRequest(
        id: j['id'] as String,
        service: j['service'] as String,
        status: rideStatusFrom(j['status'] as String?),
        offeredFare: (j['offered_fare'] as num).toInt(),
        expiresAt: _ts(j['expires_at']) ?? DateTime.now(),
        originLabel: j['origin_label'] as String?,
        destLabel: j['dest_label'] as String?,
        origin: j['origin_lat'] == null
            ? null
            : LatLng((j['origin_lat'] as num).toDouble(),
                (j['origin_lng'] as num).toDouble()),
        dest: j['dest_lat'] == null
            ? null
            : LatLng((j['dest_lat'] as num).toDouble(),
                (j['dest_lng'] as num).toDouble()),
        driverId: j['driver_id'] as String?,
        agreedFare: (j['agreed_fare'] as num?)?.toInt(),
        tripLegId: j['trip_leg_id'] as String?,
      );
}

class RideOffer {
  const RideOffer({
    required this.id,
    required this.fare,
    this.status = 'pending',
    this.firstName,
    this.vehicle,
    this.rating,
    this.ratings = 0,
    this.pickupKm,
    this.etaMin,
  });
  final String id;
  final int fare;
  final String status;

  /// Quién ofrece (ride_offer_cards, 022). null con el respaldo de solo precio.
  final String? firstName;
  final String? vehicle;

  /// Promedio de estrellas; null con menos de 3 calificaciones.
  final double? rating;
  final int ratings;

  /// Qué tan lejos está del punto de recogida y en cuántos minutos llega.
  final double? pickupKm;
  final int? etaMin;

  factory RideOffer.fromJson(Map<String, dynamic> j) => RideOffer(
        id: j['id'] as String,
        fare: (j['fare'] as num).toInt(),
        status: j['status'] as String? ?? 'pending',
        firstName: j['first_name'] as String?,
        vehicle: j['vehicle'] as String?,
        rating: (j['rating'] as num?)?.toDouble(),
        ratings: (j['ratings'] as num?)?.toInt() ?? 0,
        pickupKm: (j['pickup_km'] as num?)?.toDouble(),
        etaMin: (j['eta_min'] as num?)?.toInt(),
      );
}

/// Lo que ve el conductor de una solicitud cercana (sin datos personales).
class NearbyRequest {
  const NearbyRequest({
    required this.id,
    required this.pickupKm,
    required this.tripKm,
    required this.offeredFare,
    required this.expiresAt,
    this.originLabel,
    this.destLabel,
    this.myOffer,
  });

  final String id;
  final double pickupKm;
  final double tripKm;
  final int offeredFare;
  final DateTime expiresAt;
  final String? originLabel;
  final String? destLabel;
  final int? myOffer;

  factory NearbyRequest.fromJson(Map<String, dynamic> j) => NearbyRequest(
        id: j['id'] as String,
        pickupKm: (j['pickup_km'] as num).toDouble(),
        tripKm: (j['trip_km'] as num).toDouble(),
        offeredFare: (j['offered_fare'] as num).toInt(),
        expiresAt: _ts(j['expires_at']) ?? DateTime.now(),
        originLabel: j['origin_label'] as String?,
        destLabel: j['dest_label'] as String?,
        myOffer: (j['my_offer'] as num?)?.toInt(),
      );
}

/// Conductor asignado, como lo ve el pasajero.
class AssignedDriver {
  const AssignedDriver({
    required this.firstName,
    required this.service,
    this.plate,
    this.vehicle,
    this.at,
    this.seenAt,
    this.rating,
    this.ratings = 0,
  });

  /// Promedio de estrellas; null con menos de 3 calificaciones.
  final double? rating;
  final int ratings;
  final String firstName;
  final String service;
  final String? plate;
  final String? vehicle;
  final LatLng? at;
  final DateTime? seenAt;

  factory AssignedDriver.fromJson(Map<String, dynamic> j) => AssignedDriver(
        firstName: j['first_name'] as String? ?? 'Tu conductor',
        service: j['service'] as String,
        plate: j['plate'] as String?,
        vehicle: (j['vehicle'] as String?)?.trim().isEmpty ?? true
            ? null
            : (j['vehicle'] as String).trim(),
        at: j['lat'] == null
            ? null
            : LatLng((j['lat'] as num).toDouble(), (j['lng'] as num).toDouble()),
        seenAt: _ts(j['seen_at']),
        rating: (j['rating'] as num?)?.toDouble(),
        ratings: (j['ratings'] as num?)?.toInt() ?? 0,
      );
}

class ColectivoDeparture {
  const ColectivoDeparture({
    required this.id,
    required this.fromNode,
    required this.toNode,
    required this.departAt,
    required this.seatsTotal,
    required this.seatsTaken,
    required this.fare,
    required this.status,
  });
  final String id;
  final String fromNode;
  final String toNode;
  final DateTime departAt;
  final int seatsTotal;
  final int seatsTaken;
  final int fare;
  final String status;

  int get seatsLeft => seatsTotal - seatsTaken;

  factory ColectivoDeparture.fromJson(Map<String, dynamic> j) =>
      ColectivoDeparture(
        id: j['id'] as String,
        fromNode: j['from_node'] as String,
        toNode: j['to_node'] as String,
        departAt: _ts(j['depart_at']) ?? DateTime.now(),
        seatsTotal: (j['seats_total'] as num).toInt(),
        seatsTaken: (j['seats_taken'] as num).toInt(),
        fare: (j['fare'] as num).toInt(),
        status: j['status'] as String,
      );
}

enum LegStatus { planned, awaitingDispatch, inProgress, completed, failed, cancelled }

LegStatus legStatusFrom(String? s) => switch (s) {
      'awaiting_dispatch' => LegStatus.awaitingDispatch,
      'in_progress' => LegStatus.inProgress,
      'completed' => LegStatus.completed,
      'failed' => LegStatus.failed,
      'cancelled' => LegStatus.cancelled,
      _ => LegStatus.planned,
    };

String legStatusName(LegStatus s) => switch (s) {
      LegStatus.awaitingDispatch => 'awaiting_dispatch',
      LegStatus.inProgress => 'in_progress',
      _ => s.name,
    };

class TripLegRow {
  const TripLegRow({
    required this.id,
    required this.seq,
    required this.mode,
    required this.status,
    this.fromLabel,
    this.toLabel,
    this.fromNode,
    this.toNode,
    this.from,
    this.to,
    this.minutes,
    this.fareMin = 0,
    this.fareMax = 0,
    this.agreedFare,
  });
  final String id;
  final int seq;
  final String mode;
  final LegStatus status;
  final String? fromLabel;
  final String? toLabel;
  final String? fromNode;
  final String? toNode;
  final LatLng? from;
  final LatLng? to;
  final int? minutes;
  final int fareMin;
  final int fareMax;
  final int? agreedFare;

  bool get isOpen => status == LegStatus.planned ||
      status == LegStatus.awaitingDispatch ||
      status == LegStatus.inProgress;

  factory TripLegRow.fromJson(Map<String, dynamic> j) => TripLegRow(
        id: j['id'] as String,
        seq: (j['seq'] as num).toInt(),
        mode: j['mode'] as String,
        status: legStatusFrom(j['status'] as String?),
        fromLabel: j['from_label'] as String?,
        toLabel: j['to_label'] as String?,
        fromNode: j['from_node'] as String?,
        toNode: j['to_node'] as String?,
        from: j['from_lat'] == null
            ? null
            : LatLng((j['from_lat'] as num).toDouble(),
                (j['from_lng'] as num).toDouble()),
        to: j['to_lat'] == null
            ? null
            : LatLng((j['to_lat'] as num).toDouble(),
                (j['to_lng'] as num).toDouble()),
        minutes: (j['minutes'] as num?)?.toInt(),
        fareMin: (j['fare_min'] as num?)?.toInt() ?? 0,
        fareMax: (j['fare_max'] as num?)?.toInt() ?? 0,
        agreedFare: (j['agreed_fare'] as num?)?.toInt(),
      );
}

class ChainedTrip {
  const ChainedTrip({
    required this.id,
    required this.status,
    required this.legs,
    this.originLabel,
    this.destLabel,
  });
  final String id;
  final String status;
  final List<TripLegRow> legs;
  final String? originLabel;
  final String? destLabel;

  /// El primer tramo sin cerrar: el que toca ahora.
  TripLegRow? get currentLeg {
    for (final l in legs) {
      if (l.isOpen) return l;
    }
    return null;
  }

  bool get isFinished => status == 'completed' || status == 'cancelled';

  factory ChainedTrip.fromJson(Map<String, dynamic> j) {
    final legs = [
      for (final l in (j['trip_legs'] as List? ?? const []))
        TripLegRow.fromJson(Map<String, dynamic>.from(l as Map))
    ]..sort((a, b) => a.seq.compareTo(b.seq));
    return ChainedTrip(
      id: j['id'] as String,
      status: j['status'] as String,
      legs: legs,
      originLabel: j['origin_label'] as String?,
      destLabel: j['dest_label'] as String?,
    );
  }
}

/// Un viaje terminado o cancelado del historial, con lo necesario para
/// repetirlo: el punto de salida del primer tramo y el de llegada del último.
class RecentTrip {
  const RecentTrip({
    required this.id,
    required this.status,
    required this.at,
    this.originLabel,
    this.destLabel,
    this.origin,
    this.dest,
  });

  final String id;
  final String status;
  final DateTime at;
  final String? originLabel;
  final String? destLabel;
  final LatLng? origin;
  final LatLng? dest;

  /// Se puede repetir si se conocen los dos puntos.
  bool get canRepeat => origin != null && dest != null;

  /// Fila de `chained_trips` con sus `trip_legs` (seq y coordenadas).
  factory RecentTrip.fromRow(Map<String, dynamic> r) {
    final legs = [
      for (final l in (r['trip_legs'] as List?) ?? const [])
        Map<String, dynamic>.from(l as Map),
    ]..sort((a, b) => ((a['seq'] as num?) ?? 0).compareTo((b['seq'] as num?) ?? 0));
    LatLng? at(Map<String, dynamic>? l, String lat, String lng) {
      final a = l?[lat], b = l?[lng];
      return a is num && b is num ? LatLng(a.toDouble(), b.toDouble()) : null;
    }

    return RecentTrip(
      id: r['id'] as String,
      status: r['status'] as String,
      at: _ts(r['created_at']) ?? DateTime.now(),
      originLabel: r['origin_label'] as String?,
      destLabel: r['dest_label'] as String?,
      origin: legs.isEmpty ? null : at(legs.first, 'from_lat', 'from_lng'),
      dest: legs.isEmpty ? null : at(legs.last, 'to_lat', 'to_lng'),
    );
  }
}
