// lib/features/nfc_simulator/nfc_auth_simulator_screen.dart
// Debug screen to simulate an NFC tap at a validator
// Tests the authorize Edge Function end-to-end

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../theme/design_tokens.dart';
import '../../providers/card_provider.dart';
import '../../services/card_service.dart';
import '../../models/authorize_result.dart';
import '../../widgets/gs_button.dart';
import '../../widgets/gs_toast.dart';

class NfcAuthSimulatorScreen extends ConsumerStatefulWidget {
  const NfcAuthSimulatorScreen({super.key});

  @override
  ConsumerState<NfcAuthSimulatorScreen> createState() =>
      _NfcAuthSimulatorScreenState();
}

class _NfcAuthSimulatorScreenState
    extends ConsumerState<NfcAuthSimulatorScreen> {
  String _selectedValidator = 'VLD-BOG-001';
  double _amount = 2900;
  bool _isLoading = false;
  AuthorizeResult? _lastResult;
  // One idempotency key per tap session — regenerated only when the user
  // selects a new tap (not on retries). This ensures NFC double-tap safety.
  String _idempotencyKey = cardService.newIdempotencyKey();

  final _validators = ['VLD-BOG-001', 'VLD-MED-001'];
  final _amounts = [2400.0, 2900.0, 4500.0, 5000.0];

  Future<void> _simulateTap() async {
    final card = ref.read(activeCardProvider).valueOrNull;
    if (card == null) {
      GSToast.show(context,
          message: 'No hay tarjeta activa', type: GSToastType.error);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final result = await cardService.authorize(
        cardId: card.id,
        validatorId: _selectedValidator,
        amount: _amount,
        idempotencyKey: _idempotencyKey,
      );

      setState(() {
        _lastResult = result;
        // Generate a fresh key for the next tap session
        if (result.isAuthorized) _idempotencyKey = cardService.newIdempotencyKey();
      });
      ref.read(activeCardProvider.notifier).refresh();

      if (mounted) {
        GSToast.show(
          context,
          message: result.isAuthorized
              ? '✓ Autorizado — Saldo: \$${result.remainingBalance?.toStringAsFixed(0)} COP'
              : '✗ ${_errorMessage(result)}',
          type:
              result.isAuthorized ? GSToastType.success : GSToastType.error,
        );
      }
    } catch (e) {
      if (mounted) {
        GSToast.show(context,
            message: 'Error: $e', type: GSToastType.error);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _errorMessage(AuthorizeResult result) {
    switch (result.status) {
      case AuthorizeStatus.insufficientBalance:
        return 'Saldo insuficiente';
      case AuthorizeStatus.cardLocked:
        return 'Tarjeta bloqueada';
      default:
        return 'Error al procesar';
    }
  }

  @override
  Widget build(BuildContext context) {
    final cardAsync = ref.watch(activeCardProvider);

    return Scaffold(
      backgroundColor: GSColors.bg,
      appBar: AppBar(
        title: const Text('Simulador NFC (Debug)'),
        backgroundColor: Colors.orange,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(GSSpacing.s5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Warning banner
            Container(
              padding: const EdgeInsets.all(GSSpacing.s4),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                border: Border.all(color: Colors.orange),
                borderRadius: BorderRadius.circular(GSRadius.md),
              ),
              child: const Row(
                children: [
                  Icon(Icons.bug_report, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Pantalla de prueba — simula un tap en validador físico',
                      style: TextStyle(fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: GSSpacing.s5),

            // Card info
            cardAsync.when(
              loading: () => const CircularProgressIndicator(),
              error: (e, _) => Text('Error: $e'),
              data: (card) => card != null
                  ? _InfoRow('Tarjeta', card.numberMasked)
                  : const Text('No hay tarjeta'),
            ),
            cardAsync.maybeWhen(
              data: (card) => card != null
                  ? _InfoRow('Saldo actual', card.formattedBalance)
                  : const SizedBox(),
              orElse: () => const SizedBox(),
            ),
            const SizedBox(height: GSSpacing.s5),

            // Validator selector
            Text('Validador', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: GSSpacing.s2),
            Wrap(
              spacing: GSSpacing.s2,
              children: _validators
                  .map((v) => ChoiceChip(
                        label: Text(v),
                        selected: _selectedValidator == v,
                        onSelected: (_) =>
                            setState(() => _selectedValidator = v),
                      ))
                  .toList(),
            ),
            const SizedBox(height: GSSpacing.s4),

            // Amount selector
            Text('Monto (COP)',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: GSSpacing.s2),
            Wrap(
              spacing: GSSpacing.s2,
              children: _amounts
                  .map((a) => ChoiceChip(
                        label: Text('\$${a.toStringAsFixed(0)}'),
                        selected: _amount == a,
                        onSelected: (_) => setState(() => _amount = a),
                      ))
                  .toList(),
            ),
            const SizedBox(height: GSSpacing.s6),

            // Tap button
            GSButton(
              label: 'Simular Tap NFC',
              onPressed: _isLoading ? null : _simulateTap,
              isLoading: _isLoading,
              leadingIcon: Icons.contactless_rounded,
            ),

            // Last result
            if (_lastResult != null) ...[
              const SizedBox(height: GSSpacing.s5),
              _ResultCard(result: _lastResult!),
            ],
          ],
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow(this.label, this.value);
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text('$label: ',
              style: const TextStyle(
                  fontWeight: FontWeight.w600, color: GSColors.textSecondary)),
          Text(value,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, color: GSColors.textPrimary)),
        ],
      ),
    );
  }
}

class _ResultCard extends StatelessWidget {
  const _ResultCard({required this.result});
  final AuthorizeResult result;

  @override
  Widget build(BuildContext context) {
    final color = result.isAuthorized ? Colors.green : Colors.red;
    return Container(
      padding: const EdgeInsets.all(GSSpacing.s4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        border: Border.all(color: color),
        borderRadius: BorderRadius.circular(GSRadius.md),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            result.isAuthorized ? '✓ AUTORIZADO' : '✗ RECHAZADO',
            style: TextStyle(
                fontWeight: FontWeight.w800, color: color, fontSize: 16),
          ),
          if (result.txId != null)
            Text('TX: ${result.txId}',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          if (result.remainingBalance != null)
            Text(
                'Saldo restante: \$${result.remainingBalance!.toStringAsFixed(0)} COP'),
          if (result.errorCode != null) Text('Código: ${result.errorCode}'),
        ],
      ),
    );
  }
}
