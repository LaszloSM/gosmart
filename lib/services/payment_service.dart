// lib/services/payment_service.dart
// Pago por tramo (migración 016, D5): saldo, QR del conductor o efectivo, y
// un recibo por viaje. Recargas reales con Wompi (sandbox) si están activas.
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/supabase_client.dart';
import '../models/dispatch_models.dart';

/// Contenido del QR de cobro: 'gosmart:pay:<charge_id>'.
String chargeQrData(String chargeId) => 'gosmart:pay:$chargeId';

/// Id del cobro si el QR es de GoSmart; null si es otra cosa.
String? chargeIdFromQr(String raw) {
  final m = RegExp(r'^gosmart:pay:([0-9a-f-]{36})$').firstMatch(raw.trim());
  return m?.group(1);
}

class PaymentException implements Exception {
  const PaymentException(this.code);
  final String code;

  String get message => switch (code) {
        'insufficient_balance' => 'No te alcanza el saldo. Recarga o paga en efectivo.',
        'already_paid' => 'Este viaje ya está pagado.',
        'charge_closed' => 'Ese cobro ya se pagó o venció. Pide uno nuevo.',
        'wallet_blocked' => 'Tu tarjeta está bloqueada. Desbloquéala en la Billetera.',
        'not_payable' => 'Este viaje todavía no se puede pagar.',
        'own_charge' => 'No puedes pagarte a ti mismo.',
        'not_configured' => 'Las recargas con Wompi no están activas todavía.',
        _ => 'No se pudo pagar. Revisa tu conexión e intenta de nuevo.',
      };

  static Never from(Object e) {
    final msg = e is PostgrestException ? e.message : e.toString();
    for (final c in const [
      'insufficient_balance', 'already_paid', 'charge_closed', 'wallet_blocked',
      'not_payable', 'own_charge', 'not_configured',
    ]) {
      if (msg.contains(c)) throw PaymentException(c);
    }
    throw const PaymentException('network');
  }
}

class ChargePreview {
  const ChargePreview({required this.amount, required this.status, this.driverName, this.plate});
  final int amount;
  final String status;
  final String? driverName;
  final String? plate;
}

class ReceiptLeg {
  const ReceiptLeg({
    required this.mode,
    required this.paid,
    required this.methods,
    this.from,
    this.to,
    this.status,
  });
  final String mode;
  final int paid;
  final List<String> methods;
  final String? from;
  final String? to;
  final String? status;
}

class TripReceipt {
  const TripReceipt({
    required this.tripId,
    required this.legs,
    required this.totalPaid,
    this.origin,
    this.destination,
    this.createdAt,
  });
  final String tripId;
  final List<ReceiptLeg> legs;
  final int totalPaid;
  final String? origin;
  final String? destination;
  final DateTime? createdAt;

  factory TripReceipt.fromJson(Map<String, dynamic> j) => TripReceipt(
        tripId: j['trip_id'] as String,
        origin: j['origin'] as String?,
        destination: j['destination'] as String?,
        createdAt: DateTime.tryParse(j['created_at'] as String? ?? '')?.toLocal(),
        totalPaid: (j['total_paid'] as num?)?.toInt() ?? 0,
        legs: [
          for (final l in (j['legs'] as List? ?? const []))
            ReceiptLeg(
              mode: (l as Map)['mode'] as String,
              from: l['from'] as String?,
              to: l['to'] as String?,
              status: l['status'] as String?,
              paid: (l['paid'] as num?)?.toInt() ?? 0,
              methods: [for (final m in (l['methods'] as List? ?? const [])) m as String],
            )
        ],
      );
}

class PaymentService {
  SupabaseClient get _db => GoSmartSupabase.client;

  Future<T> _rpc<T>(String fn, Map<String, dynamic> params) async {
    try {
      return await _db.rpc(fn, params: params) as T;
    } catch (e) {
      PaymentException.from(e);
    }
  }

  /// [method]: 'wallet' o 'cash'.
  Future<void> payRide(String requestId, String method, String key) =>
      _rpc<dynamic>('pay_ride', {
        'p_request_id': requestId,
        'p_method': method,
        'p_idempotency_key': key,
      });

  Future<bool> isRidePaid(String requestId) async {
    final rows = await _db
        .from('leg_payments')
        .select('id')
        .eq('ride_request_id', requestId)
        .neq('status', 'refunded')
        .limit(1);
    return (rows as List).isNotEmpty;
  }

  Future<({String id, int amount})> createCharge(int amount, {String? rideRequestId}) async {
    final row = await _rpc<Map<String, dynamic>>('create_charge', {
      'p_amount': amount,
      'p_ride_request_id': rideRequestId,
    });
    return (id: row['id'] as String, amount: (row['amount'] as num).toInt());
  }

  Future<String> chargeStatus(String id) async {
    final row = await _db.from('charges').select('status').eq('id', id).maybeSingle();
    return row?['status'] as String? ?? 'open';
  }

  Future<ChargePreview?> chargePreview(String id) async {
    final rows = await _rpc<List<dynamic>>('charge_preview', {'p_charge_id': id});
    if (rows.isEmpty) return null;
    final r = Map<String, dynamic>.from(rows.first as Map);
    return ChargePreview(
      amount: (r['amount'] as num).toInt(),
      status: r['status'] as String,
      driverName: r['driver_first_name'] as String?,
      plate: r['plate'] as String?,
    );
  }

  Future<void> payCharge(String id, String key, {String? tripLegId}) =>
      _rpc<dynamic>('pay_charge', {
        'p_charge_id': id,
        'p_idempotency_key': key,
        'p_trip_leg_id': tripLegId,
      });

  /// Pagos en efectivo que el conductor aún no confirma.
  Future<List<({String id, int amount, DateTime at})>> pendingCash(String driverId) async {
    final rows = await _db
        .from('leg_payments')
        .select('id, amount, created_at')
        .eq('driver_id', driverId)
        .eq('status', 'cash_pending')
        .order('created_at');
    return [
      for (final r in rows as List)
        (
          id: r['id'] as String,
          amount: (r['amount'] as num).toInt(),
          at: DateTime.parse(r['created_at'] as String).toLocal(),
        )
    ];
  }

  Future<void> confirmCash(String paymentId) =>
      _rpc<dynamic>('confirm_cash', {'p_payment_id': paymentId});

  Future<TripReceipt?> receipt(String tripId) async {
    final res = await _rpc<dynamic>('trip_receipt', {'p_trip_id': tripId});
    return res == null ? null : TripReceipt.fromJson(Map<String, dynamic>.from(res as Map));
  }

  /// Historial con los puntos de cada viaje (para "Repetir").
  Future<List<RecentTrip>> recentTrips() async {
    final rows = await _db
        .from('chained_trips')
        .select('id, origin_label, dest_label, status, created_at, '
            'trip_legs(seq, from_lat, from_lng, to_lat, to_lng)')
        .inFilter('status', ['completed', 'cancelled'])
        .order('created_at', ascending: false)
        .limit(10);
    return [
      for (final r in rows as List)
        RecentTrip.fromRow(Map<String, dynamic>.from(r as Map)),
    ];
  }

  Future<bool> wompiEnabled() async {
    try {
      final row = await _db.from('app_flags').select('enabled')
          .eq('key', 'wompi_enabled').maybeSingle();
      return row?['enabled'] as bool? ?? false;
    } catch (_) {
      return false;
    }
  }

  /// URL del checkout de Wompi para recargar [amount] pesos.
  Future<String> wompiCheckout(int amount) async {
    try {
      final res = await _db.functions.invoke('wompi',
          body: {'action': 'checkout', 'amount': amount});
      final data = res.data;
      if (data is Map && data['url'] is String) return data['url'] as String;
      throw PaymentException('${data is Map ? data['error'] : 'network'}');
    } on PaymentException {
      rethrow;
    } catch (e) {
      if (e is FunctionException && '${e.details}'.contains('not_configured')) {
        throw const PaymentException('not_configured');
      }
      throw const PaymentException('network');
    }
  }
}

final paymentService = PaymentService();
