// lib/services/card_service.dart
import 'package:uuid/uuid.dart';
import '../core/supabase_client.dart';
import '../models/authorize_result.dart';

class CardService {
  final _client = GoSmartSupabase.client;
  final _uuid = const Uuid();

  /// Generate a new idempotency key for a tap session.
  /// Callers MUST hold this key and reuse it on retries of the SAME tap.
  String newIdempotencyKey() => _uuid.v4();

  /// Authorize a tap at a validator (NFC or QR simulation)
  /// [idempotencyKey] must be generated once per tap session (not per call)
  /// so retries of the same physical tap reuse the same key and are deduplicated.
  Future<AuthorizeResult> authorize({
    required String cardId,
    required String validatorId,
    required double amount,
    required String idempotencyKey,
    String mode = 'bus',
    String? routeId,
  }) async {
    final session = _client.auth.currentSession;
    if (session == null) throw Exception('Not authenticated');

    final response = await _client.functions.invoke(
      'authorize',
      body: {
        'card_id': cardId,
        'validator_id': validatorId,
        'amount': amount,
        'idempotency_key': idempotencyKey,
        'mode': mode,
        if (routeId != null) 'route_id': routeId,
      },
    );

    final data = response.data;
    if (data == null || data is! Map<String, dynamic>) {
      return const AuthorizeResult(status: AuthorizeStatus.error, errorCode: 'NETWORK_ERROR');
    }
    return AuthorizeResult.fromMap(data, httpStatus: response.status);
  }

  /// Lock or unlock a card
  Future<void> setLocked(String cardId, bool locked) async {
    await _client
        .from('cards')
        .update({'status': locked ? 'locked' : 'active'})
        .eq('id', cardId);
  }
}

final cardService = CardService();
