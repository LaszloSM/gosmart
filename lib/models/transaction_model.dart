// lib/models/transaction_model.dart

class TransactionModel {
  final String id;
  final String cardId;
  final String type; // trip | recharge | refund
  final double amount;
  final String currency;
  final String status;
  final String? mode;
  final String? origin;
  final String? destination;
  final double? co2Kg;
  final DateTime createdAt;

  const TransactionModel({
    required this.id,
    required this.cardId,
    required this.type,
    required this.amount,
    required this.currency,
    required this.status,
    this.mode,
    this.origin,
    this.destination,
    this.co2Kg,
    required this.createdAt,
  });

  factory TransactionModel.fromMap(Map<String, dynamic> map) {
    return TransactionModel(
      id: map['id'] as String,
      cardId: map['card_id'] as String,
      type: map['type'] as String,
      amount: (map['amount'] as num).toDouble(),
      currency: (map['currency'] as String?)?.toUpperCase() ?? 'COP',
      status: map['status'] as String? ?? 'completed',
      mode: map['mode'] as String?,
      origin: map['origin'] as String?,
      destination: map['destination'] as String?,
      co2Kg: (map['co2_kg'] as num?)?.toDouble(),
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  bool get isTrip => type == 'trip';
  bool get isRecharge => type == 'recharge';
}
