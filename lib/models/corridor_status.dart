// lib/models/corridor_status.dart
// Estado de la Troncal del Caribe (Riohacha → Maicao) para la Línea del corredor.
// Modelo puro, sin Flutter. Los datos reales llegan en la Fase 4 (`road_status`);
// mientras tanto la app muestra "Sin datos" en vez de inventar un estado.

/// Estado de un tramo. El orden importa: de menos a más grave.
enum RoadState {
  unknown,
  open,
  caution,
  closed;

  static RoadState fromName(String? name) => RoadState.values.firstWhere(
        (s) => s.name == name,
        orElse: () => RoadState.unknown,
      );

  /// Palabra que acompaña siempre al color (DESIGN.md: nunca solo color).
  String get label => switch (this) {
        RoadState.open => 'Abierta',
        RoadState.caution => 'Precaución',
        RoadState.closed => 'Cerrada',
        RoadState.unknown => 'Sin datos',
      };
}

/// Un tramo del corredor entre dos kilómetros.
class CorridorSegment {
  final double kmFrom;
  final double kmTo;
  final RoadState state;

  /// Motivo corto del reporte, p. ej. "Bloqueo". Nunca nombra personas.
  final String? reason;
  final int reports;

  /// true para el desvío Albania–Cuestecitas.
  final bool isBranch;

  const CorridorSegment({
    required this.kmFrom,
    required this.kmTo,
    this.state = RoadState.unknown,
    this.reason,
    this.reports = 0,
    this.isBranch = false,
  });

  factory CorridorSegment.fromMap(Map<String, dynamic> map) => CorridorSegment(
        kmFrom: (map['km_from'] as num).toDouble(),
        kmTo: (map['km_to'] as num).toDouble(),
        state: RoadState.fromName(map['state'] as String?),
        reason: map['reason'] as String?,
        reports: (map['reports'] as num?)?.toInt() ?? 0,
        isBranch: map['is_branch'] as bool? ?? false,
      );
}

class CorridorStatus {
  /// Longitud aproximada de la Troncal entre Riohacha (km 0) y Maicao.
  static const double lengthKm = 75;

  final List<CorridorSegment> segments;

  /// Hora del último dato. null = nunca hemos recibido datos.
  final DateTime? updatedAt;

  /// true cuando se muestra un estado guardado porque no hubo señal.
  final bool isStale;

  const CorridorStatus({
    required this.segments,
    this.updatedAt,
    this.isStale = false,
  });

  /// Sin reportes todavía: toda la línea en "Sin datos".
  const CorridorStatus.noData()
      : segments = const [
          CorridorSegment(kmFrom: 0, kmTo: lengthKm),
          CorridorSegment(kmFrom: 0, kmTo: 0, isBranch: true),
        ],
        updatedAt = null,
        isStale = false;

  Iterable<CorridorSegment> get mainSegments =>
      segments.where((s) => !s.isBranch);

  bool get hasData => segments.any((s) => s.state != RoadState.unknown);

  int get totalReports => segments.fold(0, (sum, s) => sum + s.reports);

  /// Estado que resume la línea: el tramo más grave con datos.
  RoadState get summary => mainSegments.fold(
        RoadState.unknown,
        (worst, s) => s.state.index > worst.index ? s.state : worst,
      );

  /// El tramo que explica el resumen (para "Bloqueo km 42").
  CorridorSegment? get worstSegment {
    final s = summary;
    if (s == RoadState.unknown) return null;
    return mainSegments.firstWhere((seg) => seg.state == s);
  }

  CorridorStatus copyWith({bool? isStale}) => CorridorStatus(
        segments: segments,
        updatedAt: updatedAt,
        isStale: isStale ?? this.isStale,
      );
}
