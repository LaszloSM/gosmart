// lib/features/nfc_simulator/nfc_auth_simulator_screen.dart
// Debug screen: simulates an NFC tap locally (no backend call).
// Useful for testing the UI flow without a deployed Edge Function.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../theme/design_tokens.dart';
import '../../providers/card_provider.dart';
import '../../providers/profile_provider.dart';
import '../../models/authorize_result.dart';
import '../../services/eco_service.dart';
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
  static const _uuid = Uuid();

  String _selectedValidator = 'VLD-BOG-001';
  double _amount = 2900;
  bool _isLoading = false;
  AuthorizeResult? _lastResult;
  String _sessionKey = _uuid.v4();

  final _validators = ['VLD-BOG-001', 'VLD-MED-001'];
  final _amounts = [2400.0, 2900.0, 4500.0, 5000.0];

  /// Simulates the authorization locally without calling the backend.
  /// Logic mirrors the real authorize Edge Function:
  ///   - card locked → CARD_LOCKED
  ///   - balance < amount → INSUFFICIENT_BALANCE
  ///   - otherwise → authorized
  Future<void> _simulateTap() async {
    final card = ref.read(activeCardProvider).valueOrNull;
    if (card == null) {
      GSToast.show(context,
          message: 'No hay tarjeta activa', type: GSToastType.error);
      return;
    }

    setState(() => _isLoading = true);

    // Simulate network latency
    await Future.delayed(const Duration(milliseconds: 700));

    if (!mounted) return;

    final AuthorizeResult result;

    if (card.isLocked) {
      result = const AuthorizeResult(
        status: AuthorizeStatus.cardLocked,
        errorCode: 'CARD_LOCKED',
      );
    } else if (card.balance < _amount) {
      result = AuthorizeResult(
        status: AuthorizeStatus.insufficientBalance,
        remainingBalance: card.balance,
        errorCode: 'INSUFFICIENT_BALANCE',
      );
    } else {
      final txId = 'sim-${_sessionKey.substring(0, 8)}';
      result = AuthorizeResult(
        status: AuthorizeStatus.authorized,
        txId: txId,
        remainingBalance: card.balance - _amount,
      );
    }

    // Sumar eco-puntos al autorizar (simulación de viaje en bus ~2.5 km)
    int ecoPointsEarned = 0;
    if (result.isAuthorized) {
      ecoPointsEarned = EcoService.ecoPointsForTrip(profile: 'bus', distanceKm: 2.5);
      ref.read(profileProvider.notifier).addEcoPoints(ecoPointsEarned);
    }

    setState(() {
      _isLoading = false;
      _lastResult = result;
      // New session key for the next tap (mirrors idempotency key rotation)
      if (result.isAuthorized) _sessionKey = _uuid.v4();
    });

    if (mounted) {
      final ecoMsg = ecoPointsEarned > 0 ? ' · +$ecoPointsEarned pts 🌿' : '';
      GSToast.show(
        context,
        message: result.isAuthorized
            ? '✓ Autorizado (simulado) — Saldo: \$${result.remainingBalance!.toStringAsFixed(0)} COP$ecoMsg'
            : '✗ ${_errorMessage(result)}',
        type: result.isAuthorized ? GSToastType.success : GSToastType.error,
      );
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
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(GSSpacing.s5),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Debug info banner
            Container(
              padding: const EdgeInsets.all(GSSpacing.s4),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                border: Border.all(color: Colors.orange),
                borderRadius: BorderRadius.circular(GSRadius.md),
              ),
              child: const Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.bug_report, color: Colors.orange),
                  SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pantalla de prueba — simula un tap en validador físico',
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Simulación local · No afecta el saldo real',
                          style: TextStyle(
                              fontSize: 12, color: GSColors.textSecondary),
                        ),
                      ],
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
                  ? Column(
                      children: [
                        _InfoRow('Tarjeta', card.numberMasked),
                        _InfoRow('Saldo actual', card.formattedBalance),
                        if (card.isLocked)
                          const Padding(
                            padding: EdgeInsets.only(top: 4),
                            child: Row(
                              children: [
                                Icon(Icons.lock, size: 14, color: GSColors.error),
                                SizedBox(width: 4),
                                Text(
                                  'Tarjeta bloqueada',
                                  style: TextStyle(
                                      color: GSColors.error, fontSize: 12),
                                ),
                              ],
                            ),
                          ),
                      ],
                    )
                  : const Text('No hay tarjeta activa'),
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
                        selectedColor: GSColors.accentLight,
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
                        selectedColor: GSColors.accentLight,
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
            result.isAuthorized
                ? '✓ AUTORIZADO (simulado)'
                : '✗ RECHAZADO',
            style: TextStyle(
                fontWeight: FontWeight.w800, color: color, fontSize: 16),
          ),
          if (result.txId != null) ...[
            const SizedBox(height: 4),
            Text('TX: ${result.txId}',
                style: const TextStyle(fontSize: 12, color: Colors.grey)),
          ],
          if (result.remainingBalance != null) ...[
            const SizedBox(height: 4),
            Text(
              'Saldo estimado: \$${result.remainingBalance!.toStringAsFixed(0)} COP',
              style: const TextStyle(fontSize: 13),
            ),
          ],
          if (result.isAuthorized) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.eco_rounded, color: GSColors.eco, size: 14),
                const SizedBox(width: 4),
                Text(
                  '+${EcoService.ecoPointsForTrip(profile: "bus", distanceKm: 2.5)} puntos ecológicos ganados',
                  style: const TextStyle(color: GSColors.eco, fontSize: 12),
                ),
              ],
            ),
          ],
          if (result.errorCode != null) ...[
            const SizedBox(height: 4),
            Text(
              _codeLabel(result.errorCode!),
              style: TextStyle(fontSize: 13, color: color),
            ),
          ],
        ],
      ),
    );
  }

  String _codeLabel(String code) {
    switch (code) {
      case 'INSUFFICIENT_BALANCE':
        return 'Motivo: Saldo insuficiente';
      case 'CARD_LOCKED':
        return 'Motivo: Tarjeta bloqueada';
      default:
        return 'Código: $code';
    }
  }
}
