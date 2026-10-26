// lib/features/routes/widgets/mode_options.dart
// Con origen y destino ya elegidos: una fila por modo con tiempo y precio
// aproximados, como la lista de opciones de Uber/DiDi. La elegida va con borde
// azul. Son estimados locales (distancia en línea recta × 1,3 y la tarifa de
// referencia): la ruta real sale al tocar "Ver ruta".
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/money.dart';
import '../../../planner/fares.dart';
import '../../../planner/graph.dart';
import '../../../providers/selected_mode_provider.dart';
import '../../../theme/design_tokens.dart';
import '../../../widgets/gs_mode_visual.dart';
import '../../../widgets/gs_pressable.dart';

/// Estimado de un modo: minutos y rango de tarifa (null = sin tarifa).
class ModeEstimate {
  const ModeEstimate(this.minutes, this.fare);
  final int minutes;
  final FareRange? fare;
}

/// Velocidad media en km/h y espera típica en minutos por modo (referencia,
/// sin datos de campo todavía).
const _speed = {
  'A pie': (4.5, 0),
  'Mototaxi': (25.0, 3),
  'Taxi': (28.0, 5),
  'Colectivo': (50.0, 15),
  'TransPadilla': (18.0, 10),
  'Intermunicipal': (55.0, 20),
  'Carro': (35.0, 0),
};

const _transit = {
  'Mototaxi': TransitMode.mototaxi,
  'Taxi': TransitMode.taxi,
  'Colectivo': TransitMode.colectivo,
  'TransPadilla': TransitMode.transpadilla,
  'Intermunicipal': TransitMode.intermunicipal,
};

ModeEstimate estimateMode(String mode, LatLng from, LatLng to, DateTime at) {
  final km = haversineKm(from, to) * 1.3;
  final (kmh, wait) = _speed[mode] ?? (30.0, 0);
  final minutes = (km / kmh * 60).round() + wait;
  final t = _transit[mode];
  var fare = t == null ? null : estimateFare(t, km, at: at);
  // Pasajes de ruta (los mismos del grafo, 014/020): TransPadilla dentro de
  // Riohacha; colectivo e intermunicipal solo entre ciudades (> 25 km).
  if (fare == null || fare.isZero) {
    fare = switch (mode) {
      'TransPadilla' => const FareRange.exact(2500),
      'Colectivo' when km > 25 => const FareRange.exact(15000),
      'Intermunicipal' when km > 25 => const FareRange.exact(16000),
      _ => fare,
    };
  }
  return ModeEstimate(
      minutes < 1 ? 1 : minutes, fare == null || fare.max == 0 ? null : fare);
}

class ModeOptions extends StatelessWidget {
  const ModeOptions({
    super.key,
    required this.from,
    required this.to,
    required this.selected,
    required this.onChanged,
  });

  final LatLng from;
  final LatLng to;
  final String selected;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: GSSpacing.s4),
      child: Column(
        children: [
          for (final m in travelModes) ...[
            _OptionRow(
              mode: m,
              estimate: estimateMode(m, from, to, now),
              selected: m == selected,
              onTap: () => onChanged(m),
            ),
            const SizedBox(height: GSSpacing.s2),
          ],
          Text(
            'Tiempos y precios aproximados: la ruta real sale al tocar "Ver ruta".',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _OptionRow extends StatelessWidget {
  const _OptionRow({
    required this.mode,
    required this.estimate,
    required this.selected,
    required this.onTap,
  });
  final String mode;
  final ModeEstimate estimate;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final fare = estimate.fare;
    // Sin regla de tarifa no se inventa un precio: el colectivo, TransPadilla
    // e intermunicipal lo traen las rutas del grafo.
    final price = fare == null
        ? switch (mode) {
            'A pie' => 'Gratis',
            'Carro' => 'Tu carro',
            _ => 'Precio en la ruta',
          }
        : formatCop(fare.price);
    return GSPressable(
      onTap: onTap,
      selected: selected,
      semanticLabel:
          '$mode, unos ${estimate.minutes} minutos, $price aproximado',
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: GSSpacing.s3, vertical: GSSpacing.s3),
        decoration: BoxDecoration(
          color: selected
              ? Color.alphaBlend(
                  GSColors.brandTint.withValues(alpha: 0.7), GSColors.surface)
              : GSColors.surface,
          borderRadius: BorderRadius.circular(GSRadius.lg),
          border: Border.all(
            color: selected ? GSColors.brand : GSColors.line,
            width: selected ? 2 : 1,
          ),
        ),
        child: Row(
          children: [
            // El vehículo dibujado, como las opciones de Uber/DiDi.
            SizedBox(
              width: 64,
              height: 48,
              child: Center(
                child: GSModeVisual(
                    mode: mode, height: 40, iconColor: GSColors.text),
              ),
            ),
            const SizedBox(width: GSSpacing.s3),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Una línea que se reduce si no cabe: nunca "Intermunicipa/l".
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(mode,
                        maxLines: 1, softWrap: false, style: text.titleMedium),
                  ),
                  Text(
                    '~${estimate.minutes} min',
                    style:
                        text.bodySmall?.copyWith(fontFeatures: GSFonts.tabular),
                  ),
                ],
              ),
            ),
            const SizedBox(width: GSSpacing.s2),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 124),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerRight,
                child: Text(
                  price,
                  maxLines: 1,
                  softWrap: false,
                  style: fare == null
                      ? text.bodyMedium?.copyWith(fontWeight: FontWeight.w600)
                      : text.titleMedium?.copyWith(
                          fontFeatures: GSFonts.tabular,
                          fontWeight: FontWeight.w800,
                        ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
