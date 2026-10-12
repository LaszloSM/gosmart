// lib/features/trust/rate_sheet.dart
// Calificar el viaje en dos toques: estrellas y etiquetas cerradas (sin texto
// libre). El conductor puede marcar "No pagó"; dos impagos confirmados
// bloquean al pasajero (017).
import 'package:flutter/material.dart';

import '../../services/trust_service.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/gs_button.dart';
import '../../widgets/gs_choice_plates.dart';
import '../../widgets/gs_toast.dart';

const passengerTags = {
  'puntual': 'Puntual',
  'amable': 'Amable',
  'manejo_seguro': 'Manejo seguro',
  'vehiculo_limpio': 'Vehículo limpio',
  'cobro_de_mas': 'Cobró de más',
  'manejo_peligroso': 'Manejo peligroso',
  'no_llego': 'No llegó',
  'grosero': 'Grosero',
};

const driverTags = {
  'puntual': 'Puntual',
  'amable': 'Amable',
  'no_pago': 'No pagó',
  'grosero': 'Grosero',
};

Future<void> showRateSheet(BuildContext context,
    {required String requestId, required bool asDriver}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => RateSheet(requestId: requestId, asDriver: asDriver),
  );
}

class RateSheet extends StatefulWidget {
  const RateSheet({super.key, required this.requestId, required this.asDriver});
  final String requestId;
  final bool asDriver;

  @override
  State<RateSheet> createState() => _RateSheetState();
}

class _RateSheetState extends State<RateSheet> {
  int _stars = 0;
  final _tags = <String>{};
  bool _busy = false;

  Future<void> _send() async {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    setState(() => _busy = true);
    try {
      await trustService.rate(widget.requestId, _stars, _tags.toList());
      nav.pop();
      GSToast.showWithMessenger(messenger, message: 'Gracias por calificar');
    } catch (_) {
      GSToast.showWithMessenger(messenger,
          message: 'No se guardó la calificación. Intenta de nuevo.',
          type: GSToastType.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tags = widget.asDriver ? driverTags : passengerTags;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
            GSSpacing.s4, 0, GSSpacing.s4, GSSpacing.s4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(widget.asDriver ? '¿Cómo te fue con el pasajero?'
                : '¿Cómo te fue con el conductor?', style: text.titleLarge),
            const SizedBox(height: GSSpacing.s3),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 1; i <= 5; i++)
                  IconButton(
                    iconSize: 40,
                    tooltip: '$i ${i == 1 ? 'estrella' : 'estrellas'}',
                    onPressed: () => setState(() => _stars = i),
                    icon: Icon(
                      i <= _stars ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: GSColors.brand,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: GSSpacing.s3),
            Wrap(
              spacing: GSSpacing.s2,
              runSpacing: GSSpacing.s2,
              children: [
                for (final e in tags.entries)
                  GSChoicePlate(
                    label: e.value,
                    selected: _tags.contains(e.key),
                    stripe: false,
                    onTap: () => setState(() =>
                        _tags.contains(e.key) ? _tags.remove(e.key) : _tags.add(e.key)),
                  ),
              ],
            ),
            if (_tags.contains('no_pago'))
              Padding(
                padding: const EdgeInsets.only(top: GSSpacing.s2),
                child: Text(
                  'Si el pasajero no tiene un pago registrado, cuenta como impago. '
                  'Con dos, no puede pedir más viajes hasta pagar.',
                  style: text.bodySmall,
                ),
              ),
            const SizedBox(height: GSSpacing.s4),
            GSButton(
              label: 'Enviar',
              isLoading: _busy,
              onPressed: _stars == 0 || _busy ? null : _send,
            ),
          ],
        ),
      ),
    );
  }
}
