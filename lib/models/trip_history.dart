// lib/models/trip_history.dart
// Historial de viajes (migración 026): todo lo que la persona hizo, también
// cancelado, sin aceptar o como conductor. Modelos puros: la pantalla solo
// pinta lo que estos ya resolvieron (estado en palabras, precio, conductor).
import 'package:latlong2/latlong.dart';

DateTime? _ts(Object? v) =>
    v is String ? DateTime.tryParse(v)?.toLocal() : null;

LatLng? _pt(Object? v) {
  if (v is! Map) return null;
  final lat = v['lat'], lng = v['lng'];
  if (lat is! num || lng is! num) return null;
  return LatLng(lat.toDouble(), lng.toDouble());
}

int? _int(Object? v) => (v as num?)?.toInt();

/// Una solicitud de mototaxi/taxi (un intento de pedir un tramo).
class RideCard {
  const RideCard({
    required this.id,
    required this.service,
    required this.status,
    required this.offeredFare,
    this.agreedFare,
    this.createdAt,
    this.acceptedAt,
    this.finishedAt,
    this.cancelReason,
    this.cancelledBy,
    this.originLabel,
    this.destLabel,
    this.from,
    this.to,
    this.otherName,
    this.plate,
    this.vehicle,
    this.paid = 0,
    this.payMethod,
    this.myStars,
  });

  final String id;
  final String service;

  /// open, accepted, in_progress, completed, cancelled, expired.
  final String status;
  final int offeredFare;
  final int? agreedFare;
  final DateTime? createdAt;
  final DateTime? acceptedAt;
  final DateTime? finishedAt;
  final String? cancelReason;

  /// 'passenger' | 'driver' | null.
  final String? cancelledBy;
  final String? originLabel;
  final String? destLabel;
  final LatLng? from;
  final LatLng? to;

  /// Nombre de pila de la otra persona (conductor o pasajero).
  final String? otherName;
  final String? plate;
  final String? vehicle;
  final int paid;

  /// 'cash' | 'wallet' | 'qr' | null (sin pago registrado).
  final String? payMethod;

  /// Estrellas que la persona dio (null = no calificó).
  final int? myStars;

  /// Lo que se acordó o, si nadie aceptó, lo que se ofreció.
  int get fare => agreedFare ?? offeredFare;

  bool get hadDriver => acceptedAt != null || otherName != null;

  factory RideCard.fromJson(Map<String, dynamic> j) => RideCard(
        id: j['id'] as String,
        service: (j['service'] as String?) ?? 'mototaxi',
        status: (j['status'] as String?) ?? 'open',
        offeredFare: _int(j['offered_fare']) ?? 0,
        agreedFare: _int(j['agreed_fare']),
        createdAt: _ts(j['created_at']),
        acceptedAt: _ts(j['accepted_at']),
        finishedAt: _ts(j['finished_at']),
        cancelReason: j['cancel_reason'] as String?,
        cancelledBy: j['cancelled_by'] as String?,
        originLabel: j['origin'] as String?,
        destLabel: j['destination'] as String?,
        from: _pt(j['from']),
        to: _pt(j['to']),
        otherName: j['other_name'] as String?,
        plate: j['plate'] as String?,
        vehicle: j['vehicle'] as String?,
        paid: _int(j['paid']) ?? 0,
        payMethod: j['pay_method'] as String?,
        myStars: _int(j['my_stars']),
      );
}

/// Cómo terminó, en palabras y con su tono.
enum HistoryTone { done, active, cancelled }

/// Un renglón del historial: un viaje como pasajero o una carrera como conductor.
class HistoryItem {
  const HistoryItem({
    required this.kind,
    required this.id,
    required this.status,
    this.createdAt,
    this.endedAt,
    this.originLabel,
    this.destLabel,
    this.modes = const [],
    this.from,
    this.to,
    this.totalPaid = 0,
    this.requests = 0,
    this.ride,
  });

  /// 'trip' (pasajero) | 'ride' (conductor).
  final String kind;
  final String id;
  final String status;
  final DateTime? createdAt;
  final DateTime? endedAt;
  final String? originLabel;
  final String? destLabel;
  final List<String> modes;
  final LatLng? from;
  final LatLng? to;
  final int totalPaid;

  /// Cuántas veces se pidió mototaxi/taxi en el viaje.
  final int requests;

  /// Pasajero: la solicitud más reciente (con conductor si hubo).
  /// Conductor: la carrera misma.
  final RideCard? ride;

  bool get asDriver => kind == 'ride';

  /// Se puede volver a pedir si se conocen los dos puntos (solo pasajero).
  bool get canRepeat => !asDriver && from != null && to != null;

  /// Modo principal (el primero que no es a pie).
  String get mainMode => modes.firstWhere((m) => m != 'walk',
      orElse: () => ride?.service ?? (modes.isEmpty ? 'walk' : modes.first));

  /// Precio a mostrar: lo pagado; si no, lo acordado/ofrecido; null = sin precio.
  int? get price {
    if (totalPaid > 0) return totalPaid;
    final r = ride;
    if (r == null) return null;
    if (asDriver) return r.fare;
    return r.fare > 0 ? r.fare : null;
  }

  /// Estado en palabras, como lo diría InDrive.
  (String, HistoryTone) get statusText {
    final r = ride;
    if (asDriver) {
      return switch (r?.status) {
        'completed' => ('Completado', HistoryTone.done),
        'accepted' || 'in_progress' => ('En curso', HistoryTone.active),
        _ => (r?.cancelledBy == 'driver' ? 'Lo cancelaste' : 'Cancelado por el pasajero',
            HistoryTone.cancelled),
      };
    }
    switch (status) {
      case 'completed':
        return ('Completado', HistoryTone.done);
      case 'in_progress':
      case 'planned':
        if (r != null && r.status == 'open') return ('Buscando conductor', HistoryTone.active);
        return (status == 'planned' ? 'Planeado' : 'En curso', HistoryTone.active);
    }
    // Cancelado: por qué, de la forma más útil.
    if (r == null || requests == 0) return ('No se pidió', HistoryTone.cancelled);
    if (r.status == 'expired') return ('Nadie aceptó', HistoryTone.cancelled);
    if (r.cancelledBy == 'driver') return ('Cancelado por el conductor', HistoryTone.cancelled);
    return ('Cancelado', HistoryTone.cancelled);
  }

  factory HistoryItem.fromJson(Map<String, dynamic> j) {
    final kind = (j['kind'] as String?) ?? 'trip';
    if (kind == 'ride') {
      final r = RideCard.fromJson(j);
      return HistoryItem(
        kind: 'ride',
        id: r.id,
        status: r.status,
        createdAt: r.createdAt,
        endedAt: r.finishedAt,
        originLabel: r.originLabel,
        destLabel: r.destLabel,
        modes: [r.service],
        from: r.from,
        to: r.to,
        totalPaid: r.paid,
        requests: 1,
        ride: r,
      );
    }
    final last = j['last_ride'];
    return HistoryItem(
      kind: 'trip',
      id: j['id'] as String,
      status: (j['status'] as String?) ?? 'planned',
      createdAt: _ts(j['created_at']),
      endedAt: _ts(j['ended_at']),
      originLabel: j['origin'] as String?,
      destLabel: j['destination'] as String?,
      modes: [for (final m in (j['modes'] as List?) ?? const []) '$m'],
      from: _pt(j['from']),
      to: _pt(j['to']),
      totalPaid: _int(j['total_paid']) ?? 0,
      requests: _int(j['requests']) ?? 0,
      ride: last is Map ? RideCard.fromJson(Map<String, dynamic>.from(last)) : null,
    );
  }
}

/// Un tramo en el detalle, con todos sus intentos de pedirlo.
class HistoryLeg {
  const HistoryLeg({
    required this.seq,
    required this.mode,
    required this.status,
    this.fromLabel,
    this.toLabel,
    this.from,
    this.to,
    this.minutes,
    this.fareMax = 0,
    this.agreedFare,
    this.rides = const [],
  });
  final int seq;
  final String mode;
  final String status;
  final String? fromLabel;
  final String? toLabel;
  final LatLng? from;
  final LatLng? to;
  final int? minutes;
  final int fareMax;
  final int? agreedFare;
  final List<RideCard> rides;

  factory HistoryLeg.fromJson(Map<String, dynamic> j) => HistoryLeg(
        seq: _int(j['seq']) ?? 0,
        mode: (j['mode'] as String?) ?? 'walk',
        status: (j['status'] as String?) ?? 'planned',
        fromLabel: j['from_label'] as String?,
        toLabel: j['to_label'] as String?,
        from: _pt(j['from']),
        to: _pt(j['to']),
        minutes: _int(j['minutes']),
        fareMax: _int(j['fare_max']) ?? 0,
        agreedFare: _int(j['agreed_fare']),
        rides: [
          for (final r in (j['rides'] as List?) ?? const [])
            RideCard.fromJson(Map<String, dynamic>.from(r as Map)),
        ],
      );
}

/// Detalle de un viaje: el renglón del historial más sus tramos.
class TripDetail {
  const TripDetail({required this.item, this.legs = const []});
  final HistoryItem item;
  final List<HistoryLeg> legs;

  /// Todas las solicitudes del viaje, en orden.
  List<RideCard> get rides => [for (final l in legs) ...l.rides];

  /// La solicitud que importa: la que tuvo conductor, o la última.
  RideCard? get mainRide {
    final all = rides;
    if (all.isEmpty) return item.ride;
    return all.lastWhere((r) => r.hadDriver, orElse: () => all.last);
  }

  factory TripDetail.fromJson(Map<String, dynamic> j) {
    if (j['kind'] == 'ride') return TripDetail(item: HistoryItem.fromJson(j));
    final legs = [
      for (final l in (j['legs'] as List?) ?? const [])
        HistoryLeg.fromJson(Map<String, dynamic>.from(l as Map)),
    ];
    final rides = [for (final l in legs) ...l.rides];
    RideCard? main;
    if (rides.isNotEmpty) {
      main = rides.lastWhere((r) => r.hadDriver, orElse: () => rides.last);
    }
    final item = HistoryItem(
      kind: 'trip',
      id: j['id'] as String,
      status: (j['status'] as String?) ?? 'planned',
      createdAt: _ts(j['created_at']),
      endedAt: _ts(j['ended_at']),
      originLabel: j['origin'] as String?,
      destLabel: j['destination'] as String?,
      modes: [for (final l in legs) l.mode],
      from: legs.map((l) => l.from).whereType<LatLng>().firstOrNull,
      to: legs.reversed.map((l) => l.to).whereType<LatLng>().firstOrNull,
      totalPaid: _int(j['total_paid']) ?? 0,
      requests: rides.length,
      ride: main,
    );
    return TripDetail(item: item, legs: legs);
  }
}
