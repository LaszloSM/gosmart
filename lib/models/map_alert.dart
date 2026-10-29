// lib/models/map_alert.dart
// Alertas del mapa al estilo Waze (migración 021): la gente reporta lo que ve
// donde está y todos lo ven como un pin. Tipos cerrados (sin texto libre).
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

/// Qué tan grave es: decide el color del pin (rojo o ámbar; ver DESIGN.md).
enum AlertSeverity { severe, caution, clear }

/// Un tipo de alerta con su nombre, su ícono y su gravedad.
class AlertKind {
  const AlertKind(this.id, this.label, this.icon, this.severity, this.hint);
  final String id;
  final String label;
  final IconData icon;
  final AlertSeverity severity;

  /// Una línea para la preferencia y la hoja de reportar.
  final String hint;

  static const bloqueo = AlertKind('bloqueo', 'Bloqueo', Icons.do_not_disturb_on_rounded,
      AlertSeverity.severe, 'La vía está cerrada');
  static const accidente = AlertKind('accidente', 'Accidente', Icons.car_crash_rounded,
      AlertSeverity.severe, 'Choque o vehículo varado');
  static const reten = AlertKind('reten', 'Retén', Icons.local_police_rounded,
      AlertSeverity.caution, 'Control de policía o tránsito');
  static const trancon = AlertKind('trancon', 'Trancón', Icons.traffic_rounded,
      AlertSeverity.caution, 'El tráfico está detenido o lento');
  static const hueco = AlertKind('hueco', 'Hueco', Icons.report_rounded,
      AlertSeverity.caution, 'Hueco o vía en mal estado');
  static const inundacion = AlertKind('inundacion', 'Inundación', Icons.flood_rounded,
      AlertSeverity.caution, 'Agua en la vía');
  static const peligro = AlertKind('peligro', 'Peligro', Icons.warning_rounded,
      AlertSeverity.caution, 'Objeto, animal o algo raro en la vía');
  static const obra = AlertKind('obra', 'Obra', Icons.construction_rounded,
      AlertSeverity.caution, 'Trabajos en la vía');
  static const despejado = AlertKind('despejado', 'Vía despejada',
      Icons.check_circle_rounded, AlertSeverity.clear, 'En la Troncal ya se pasa bien');

  /// Lo que se puede reportar y ver en el mapa, en el orden de la hoja.
  static const all = [bloqueo, accidente, reten, trancon, hueco, inundacion, peligro, obra];

  static AlertKind byId(String id) =>
      [...all, despejado].firstWhere((k) => k.id == id, orElse: () => peligro);
}

/// Una alerta vigente en el mapa (`map_alerts`).
class MapAlert {
  const MapAlert({
    required this.id,
    required this.kind,
    required this.at,
    required this.happenedAt,
    this.segmentName,
    this.confirmations = 0,
    this.denials = 0,
    this.mine = false,
    this.myVote,
  });

  final String id;
  final AlertKind kind;
  final LatLng at;
  final DateTime happenedAt;
  final String? segmentName;
  final int confirmations;
  final int denials;
  final bool mine;

  /// true = dijiste "sigue ahí"; false = "ya no está"; null = no has votado.
  final bool? myVote;

  factory MapAlert.fromMap(Map<String, dynamic> m) => MapAlert(
        id: m['id'] as String,
        kind: AlertKind.byId(m['kind'] as String),
        at: LatLng((m['lat'] as num).toDouble(), (m['lng'] as num).toDouble()),
        happenedAt: DateTime.parse(m['happened_at'] as String).toLocal(),
        segmentName: m['segment_name'] as String?,
        confirmations: (m['confirmations'] as num?)?.toInt() ?? 0,
        denials: (m['denials'] as num?)?.toInt() ?? 0,
        mine: m['mine'] as bool? ?? false,
        myVote: m['my_vote'] as bool?,
      );

  MapAlert withVote(bool stillThere) => MapAlert(
        id: id,
        kind: kind,
        at: at,
        happenedAt: happenedAt,
        segmentName: segmentName,
        confirmations: confirmations + (stillThere && myVote != true ? 1 : 0),
        denials: denials + (!stillThere && myVote != false ? 1 : 0),
        mine: mine,
        myVote: stillThere,
      );
}

/// "hace 5 min", "hace 2 h", "hace 3 días".
String alertAge(DateTime at, {DateTime? now}) {
  final d = (now ?? DateTime.now()).difference(at);
  if (d.inMinutes < 1) return 'ahora';
  if (d.inMinutes < 60) return 'hace ${d.inMinutes} min';
  if (d.inHours < 24) return 'hace ${d.inHours} h';
  final days = d.inDays;
  return days == 1 ? 'hace 1 día' : 'hace $days días';
}

/// Preferencia de un tipo, como en Waze: verlo en el mapa y que te avise
/// cuando te acercas.
class AlertPref {
  const AlertPref({this.show = true, this.warn = true});
  final bool show;
  final bool warn;

  AlertPref copyWith({bool? show, bool? warn}) =>
      AlertPref(show: show ?? this.show, warn: warn ?? this.warn);

  Map<String, dynamic> toJson() => {'show': show, 'warn': warn};
  factory AlertPref.fromJson(Map<String, dynamic> j) =>
      AlertPref(show: j['show'] as bool? ?? true, warn: j['warn'] as bool? ?? true);
}
