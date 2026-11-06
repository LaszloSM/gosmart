// lib/features/trip/widgets/cancel_sheet.dart
// Cancelar con confirmación, como InDrive, Maxim o Uber: si el conductor ya
// aceptó, hay que elegir un motivo (lista cerrada, sin texto libre: el
// servidor solo acepta estos códigos). Sin conductor, basta confirmar.
import 'package:flutter/material.dart';

import '../../../theme/design_tokens.dart';
import '../../../widgets/gs_button.dart';

/// Motivos de cancelación (los mismos códigos que 024_mvp_real.sql).
class CancelReason {
  const CancelReason(this.code, this.label, this.icon);
  final String code;
  final String label;
  final IconData icon;

  static const passenger = [
    CancelReason(
        'driver_late', 'El conductor tarda mucho', Icons.schedule_rounded),
    CancelReason(
        'driver_not_moving',
        'El conductor no se mueve o va por otro lado',
        Icons.wrong_location_rounded),
    CancelReason(
        'driver_asked', 'El conductor me pidió cancelar', Icons.forum_rounded),
    CancelReason('price_changed', 'Me pidió otro precio', Icons.sell_rounded),
    CancelReason('wrong_address', 'Puse mal la dirección',
        Icons.edit_location_alt_rounded),
    CancelReason(
        'found_other', 'Conseguí otro transporte', Icons.directions_rounded),
    CancelReason(
        'changed_plans', 'Ya no necesito el viaje', Icons.event_busy_rounded),
    CancelReason(
        'unsafe', 'No me sentí seguro', Icons.health_and_safety_rounded),
    CancelReason('other', 'Otro motivo', Icons.more_horiz_rounded),
  ];

  static const driver = [
    CancelReason(
        'passenger_no_show', 'El pasajero no llegó', Icons.person_off_rounded),
    CancelReason('passenger_asked', 'El pasajero me pidió cancelar',
        Icons.forum_rounded),
    CancelReason(
        'vehicle_problem', 'Problema con el vehículo', Icons.build_rounded),
    CancelReason('unsafe_pickup', 'El punto de recogida no es seguro',
        Icons.health_and_safety_rounded),
    CancelReason('other', 'Otro motivo', Icons.more_horiz_rounded),
  ];
}

/// Resultado de la hoja: null = no canceló.
class CancelChoice {
  const CancelChoice(this.reason);

  /// Código del motivo, o null si no hacía falta (nadie había aceptado).
  final String? reason;
}

/// Pregunta antes de cancelar. Con [driverAssigned] pide un motivo.
Future<CancelChoice?> showCancelSheet(
  BuildContext context, {
  required bool driverAssigned,
  bool asDriver = false,
  String what = 'el viaje',
}) {
  return showModalBottomSheet<CancelChoice>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    sheetAnimationStyle: MediaQuery.of(context).disableAnimations
        ? AnimationStyle.noAnimation
        : null,
    backgroundColor: GSColors.surface,
    shape: RoundedRectangleBorder(borderRadius: GSRadius.sheetRadius),
    builder: (_) => _CancelSheet(
      driverAssigned: driverAssigned,
      asDriver: asDriver,
      what: what,
    ),
  );
}

class _CancelSheet extends StatefulWidget {
  const _CancelSheet({
    required this.driverAssigned,
    required this.asDriver,
    required this.what,
  });
  final bool driverAssigned;
  final bool asDriver;
  final String what;

  @override
  State<_CancelSheet> createState() => _CancelSheetState();
}

class _CancelSheetState extends State<_CancelSheet> {
  String? _reason;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final reasons =
        widget.asDriver ? CancelReason.driver : CancelReason.passenger;
    final needsReason = widget.driverAssigned;
    final title = '¿Cancelar ${widget.what}?';
    final subtitle = !needsReason
        ? 'Aún nadie lo ha aceptado. Puedes pedir otro cuando quieras.'
        : widget.asDriver
            ? 'El pasajero te está esperando. Cuéntanos por qué cancelas.'
            : 'Tu conductor ya viene en camino. Cuéntanos por qué cancelas: '
                'nos ayuda a cuidar a pasajeros y conductores.';

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.88),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: GSSpacing.s3),
                decoration: BoxDecoration(
                  color: GSColors.line,
                  borderRadius: BorderRadius.circular(GSRadius.full),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  GSSpacing.s5, 0, GSSpacing.s5, GSSpacing.s2),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: text.titleLarge),
                  const SizedBox(height: GSSpacing.s1),
                  Text(subtitle, style: text.bodyMedium),
                ],
              ),
            ),
            if (needsReason)
              Flexible(
                child: RadioGroup<String>(
                  groupValue: _reason,
                  onChanged: (v) => setState(() => _reason = v),
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: GSSpacing.s2),
                    children: [
                      for (final r in reasons)
                        RadioListTile<String>(
                          value: r.code,
                          secondary: Icon(r.icon, color: GSColors.textMuted),
                          title: Text(r.label, style: text.bodyLarge),
                          controlAffinity: ListTileControlAffinity.trailing,
                          contentPadding: const EdgeInsets.symmetric(
                              horizontal: GSSpacing.s5),
                        ),
                    ],
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(
                  GSSpacing.s4, GSSpacing.s2, GSSpacing.s4, GSSpacing.s4),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GSButton(
                    label: 'Sí, cancelar',
                    variant: GSButtonVariant.outline,
                    isFullWidth: true,
                    onPressed: needsReason && _reason == null
                        ? null
                        : () =>
                            Navigator.of(context).pop(CancelChoice(_reason)),
                  ),
                  const SizedBox(height: GSSpacing.s2),
                  GSButton(
                    label: widget.asDriver
                        ? 'Seguir con el viaje'
                        : 'Seguir esperando',
                    isFullWidth: true,
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
