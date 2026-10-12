// lib/features/trip/receipt_screen.dart
// Un solo recibo por viaje con el desglose por tramo (D5).
import 'package:flutter/material.dart';

import '../../core/money.dart';
import '../../services/payment_service.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/gs_inline_error.dart';
import '../../widgets/gs_list_row.dart';
import '../../widgets/gs_route_plate.dart';
import 'trip_screen.dart' show legModeIcon, legModeLabel;

String paymentMethodLabel(List<String> methods) {
  if (methods.isEmpty) return 'Sin pago registrado';
  return methods.map((m) => switch (m) {
        'wallet' => 'saldo',
        'qr' => 'QR',
        'cash' => 'efectivo',
        _ => m,
      }).join(' + ');
}

class ReceiptScreen extends StatefulWidget {
  const ReceiptScreen({super.key, required this.tripId, this.load});
  final String tripId;
  final Future<TripReceipt?> Function(String id)? load;

  @override
  State<ReceiptScreen> createState() => _ReceiptScreenState();
}

class _ReceiptScreenState extends State<ReceiptScreen> {
  late Future<TripReceipt?> _f = _load();

  Future<TripReceipt?> _load() =>
      (widget.load ?? paymentService.receipt)(widget.tripId);

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      backgroundColor: GSColors.background,
      appBar: AppBar(title: const Text('Recibo del viaje')),
      body: FutureBuilder<TripReceipt?>(
        future: _f,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final r = snap.data;
          if (snap.hasError || r == null) {
            return Padding(
              padding: const EdgeInsets.all(GSSpacing.s4),
              child: GSInlineError(
                message: 'No pudimos cargar el recibo',
                onRetry: () => setState(() => _f = _load()),
              ),
            );
          }
          return ListView(
            padding: const EdgeInsets.only(bottom: GSSpacing.s8),
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    GSSpacing.s4, GSSpacing.s4, GSSpacing.s4, 0),
                child: GSRoutePlate(
                  text: r.destination ?? 'Viaje',
                  leading: Icons.receipt_long_rounded,
                  maxLines: 3,
                  detailMaxLines: 3,
                  detail: [
                    if (r.origin != null) 'Desde ${r.origin}',
                    if (r.createdAt != null)
                      '${r.createdAt!.day}/${r.createdAt!.month}/${r.createdAt!.year}',
                  ].join(' · '),
                ),
              ),
              const GSSectionTitle('Tramos'),
              for (final l in r.legs) ...[
                GSListRow(
                  icon: legModeIcon(l.mode),
                  title: '${legModeLabel(l.mode)}'
                      '${l.to == null ? '' : ' hasta ${l.to}'}',
                  subtitle: l.mode == 'walk'
                      ? 'A pie'
                      : l.methods.isEmpty
                          ? 'Sin pago registrado'
                          : 'Pagado con ${paymentMethodLabel(l.methods)}',
                  value: l.paid > 0 ? formatCop(l.paid) : '—',
                ),
                const Divider(indent: GSSpacing.s4),
              ],
              GSListRow(
                icon: Icons.payments_outlined,
                title: 'Total pagado',
                value: formatCop(r.totalPaid),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                    GSSpacing.s4, GSSpacing.s3, GSSpacing.s4, 0),
                child: Text(
                  'Cada tramo se paga al conductor que lo hizo. Los pagos con '
                  'saldo usan saldo de prueba mientras no haya recargas reales.',
                  style: text.bodySmall,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
