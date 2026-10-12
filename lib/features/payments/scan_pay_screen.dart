// lib/features/payments/scan_pay_screen.dart
// Pagar con el QR del conductor: escanear → ver monto, nombre y placa →
// confirmar. Nada se cobra sin ese último toque.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:uuid/uuid.dart';

import '../../core/money.dart';
import '../../providers/wallet_provider.dart';
import '../../services/payment_service.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/gs_button.dart';
import '../../widgets/gs_route_plate.dart';
import '../../widgets/gs_toast.dart';

class ScanPayScreen extends ConsumerStatefulWidget {
  const ScanPayScreen({super.key, this.tripLegId});
  final String? tripLegId;

  @override
  ConsumerState<ScanPayScreen> createState() => _ScanPayScreenState();
}

class _ScanPayScreenState extends ConsumerState<ScanPayScreen> {
  String? _chargeId;
  ChargePreview? _preview;
  bool _busy = false;
  bool _paid = false;
  String? _problem;
  final _key = const Uuid().v4();

  Future<void> _onDetect(BarcodeCapture cap) async {
    if (_chargeId != null) return;
    for (final b in cap.barcodes) {
      final id = chargeIdFromQr(b.rawValue ?? '');
      if (id == null) continue;
      setState(() {
        _chargeId = id;
        _problem = null;
      });
      try {
        final p = await paymentService.chargePreview(id);
        if (!mounted) return;
        setState(() {
          _preview = p;
          if (p == null) _problem = 'Ese QR no es de un cobro válido.';
          if (p != null && p.status != 'open') {
            _problem = 'Ese cobro ya se pagó o venció. Pide uno nuevo.';
          }
        });
      } on PaymentException catch (e) {
        if (mounted) setState(() => _problem = e.message);
      }
      return;
    }
    if (mounted && _problem == null) {
      setState(() => _problem = 'Ese QR no es de GoSmart.');
    }
  }

  Future<void> _pay() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      await paymentService.payCharge(_chargeId!, _key, tripLegId: widget.tripLegId);
      ref.invalidate(walletProvider);
      setState(() => _paid = true);
    } on PaymentException catch (e) {
      GSToast.showWithMessenger(messenger, message: e.message, type: GSToastType.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _reset() => setState(() {
        _chargeId = null;
        _preview = null;
        _problem = null;
      });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final p = _preview;
    return Scaffold(
      backgroundColor: GSColors.background,
      appBar: AppBar(title: const Text('Pagar con QR')),
      body: ListView(
        padding: const EdgeInsets.all(GSSpacing.s4),
        children: [
          if (_chargeId == null) ...[
            Text('Apunta al QR que te muestra el conductor.', style: text.bodyLarge),
            const SizedBox(height: GSSpacing.s3),
            ClipRRect(
              borderRadius: BorderRadius.circular(GSRadius.lg),
              child: AspectRatio(
                aspectRatio: 1,
                child: MobileScanner(
                  onDetect: _onDetect,
                  errorBuilder: (context, error, child) => ColoredBox(
                    color: GSColors.surfaceSunken,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(GSSpacing.s4),
                        child: Text(
                          'No pudimos abrir la cámara. Revisa el permiso en '
                          'Ajustes → Apps → GoSmart.',
                          textAlign: TextAlign.center,
                          style: text.bodyMedium,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
          if (_problem != null) ...[
            const SizedBox(height: GSSpacing.s3),
            Text(_problem!, style: text.bodyLarge),
            const SizedBox(height: GSSpacing.s3),
            GSButton(label: 'Escanear otro', variant: GSButtonVariant.outline, onPressed: _reset),
          ],
          if (p != null && _problem == null) ...[
            GSRoutePlate(
              text: formatCop(p.amount),
              leading: _paid ? Icons.check_circle_rounded : Icons.qr_code_2_rounded,
              isActive: true,
              size: GSPlateSize.lg,
              detail: _paid
                  ? 'Pagado a ${p.driverName ?? 'el conductor'}'
                  : 'Para ${p.driverName ?? 'el conductor'}'
                      '${p.plate == null ? '' : ' · placa ${p.plate}'}',
            ),
            const SizedBox(height: GSSpacing.s3),
            if (!_paid) ...[
              Text('Revisa que el nombre y la placa coincidan. Se descuenta de '
                  'tu saldo de prueba.', style: text.bodyMedium),
              const SizedBox(height: GSSpacing.s4),
              GSButton(
                label: 'Pagar ${formatCop(p.amount)}',
                isLoading: _busy,
                onPressed: _busy ? null : _pay,
              ),
              TextButton(onPressed: _reset, child: const Text('No es este cobro')),
            ] else
              GSButton(
                label: 'Listo',
                onPressed: () => Navigator.of(context).maybePop(),
              ),
          ],
        ],
      ),
    );
  }
}
