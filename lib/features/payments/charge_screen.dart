// lib/features/payments/charge_screen.dart
// Cobrar con QR (conductor, DS6): el monto en grande, un botón de 72 dp y
// el QR para que el pasajero lo escanee. Se actualiza solo cuando pagan.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/money.dart';
import '../../services/payment_service.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/gs_button.dart';
import '../../widgets/gs_toast.dart';

class ChargeScreen extends StatefulWidget {
  const ChargeScreen({super.key, this.initialAmount = 5000});
  final int initialAmount;

  @override
  State<ChargeScreen> createState() => _ChargeScreenState();
}

class _ChargeScreenState extends State<ChargeScreen> {
  late int _amount = widget.initialAmount;
  ({String id, int amount})? _charge;
  String _status = 'open';
  bool _busy = false;
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _create() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _busy = true);
    try {
      final c = await paymentService.createCharge(_amount);
      setState(() {
        _charge = c;
        _status = 'open';
      });
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 3), (_) => _poll());
    } on PaymentException catch (e) {
      GSToast.showWithMessenger(messenger, message: e.message, type: GSToastType.error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _poll() async {
    final c = _charge;
    if (c == null) return;
    try {
      final s = await paymentService.chargeStatus(c.id);
      if (!mounted) return;
      setState(() => _status = s);
      if (s != 'open') _timer?.cancel();
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final c = _charge;
    final big = TextStyle(
      fontFamily: GSFonts.display,
      fontFeatures: GSFonts.tabular,
      fontSize: 34,
      fontWeight: FontWeight.w800,
      color: GSColors.text,
    );
    return Scaffold(
      backgroundColor: GSColors.background,
      appBar: AppBar(title: const Text('Cobrar con QR')),
      body: ListView(
        padding: const EdgeInsets.all(GSSpacing.s4),
        children: [
          if (c == null) ...[
            Text('¿Cuánto cobras?', style: text.titleLarge),
            const SizedBox(height: GSSpacing.s3),
            Row(children: [
              IconButton.filledTonal(
                iconSize: 32,
                constraints: const BoxConstraints.tightFor(
                    width: GSSize.touchTargetDriver, height: GSSize.touchTargetDriver),
                tooltip: 'Bajar \$500',
                onPressed: _amount > 500 ? () => setState(() => _amount -= 500) : null,
                icon: const Icon(Icons.remove_rounded),
              ),
              Expanded(child: Text(formatCop(_amount), textAlign: TextAlign.center, style: big)),
              IconButton.filledTonal(
                iconSize: 32,
                constraints: const BoxConstraints.tightFor(
                    width: GSSize.touchTargetDriver, height: GSSize.touchTargetDriver),
                tooltip: 'Subir \$500',
                onPressed: () => setState(() => _amount += 500),
                icon: const Icon(Icons.add_rounded),
              ),
            ]),
            const SizedBox(height: GSSpacing.s5),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: GSSize.touchTargetDriver),
              child: GSButton(
                label: 'Mostrar QR',
                size: GSButtonSize.driver,
                isLoading: _busy,
                onPressed: _busy ? null : _create,
              ),
            ),
          ] else ...[
            Text(formatCop(c.amount), textAlign: TextAlign.center, style: big),
            const SizedBox(height: GSSpacing.s3),
            if (_status != 'open' && _status != 'paid')
              Icon(Icons.timer_off_outlined, size: 96, color: GSColors.textMuted)
            else if (_status == 'paid')
              Column(children: [
                Icon(Icons.check_circle_rounded, size: 96, color: GSColors.brand),
                Text('Pagado', style: text.headlineSmall),
                Text('Ya está en tu billetera (saldo de prueba, aún no se puede retirar).',
                    textAlign: TextAlign.center, style: text.bodyMedium),
              ])
            else
              Center(
                child: Container(
                  padding: const EdgeInsets.all(GSSpacing.s4),
                  decoration: BoxDecoration(
                    // El QR siempre sobre blanco, también de noche: así lo lee cualquier cámara.
                    color: const Color(0xFFFFFFFF),
                    borderRadius: BorderRadius.circular(GSRadius.lg),
                  ),
                  child: QrImageView(
                    data: chargeQrData(c.id),
                    size: 240,
                    semanticsLabel: 'Código QR para pagar ${formatCop(c.amount)}',
                  ),
                ),
              ),
            const SizedBox(height: GSSpacing.s3),
            Text(
              _status == 'open'
                  ? 'Que el pasajero lo escanee en GoSmart, en Billetera, con Pagar con QR. '
                      'Vence en 15 minutos.'
                  : _status == 'paid'
                      ? ''
                      : 'Este cobro venció. Crea uno nuevo.',
              textAlign: TextAlign.center,
              style: text.bodyMedium,
            ),
            const SizedBox(height: GSSpacing.s4),
            ConstrainedBox(
              constraints: const BoxConstraints(minHeight: GSSize.touchTargetDriver),
              child: GSButton(
                label: 'Nuevo cobro',
                size: GSButtonSize.driver,
                variant: GSButtonVariant.outline,
                onPressed: () {
                  _timer?.cancel();
                  setState(() => _charge = null);
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
