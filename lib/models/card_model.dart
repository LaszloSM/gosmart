// lib/models/card_model.dart

class CardModel {
  final String id;
  final String userId;
  final String numberMasked;
  final double balance;
  final String currency;
  final String status;
  final bool nfcEnabled;
  final String? expiresAt;

  const CardModel({
    required this.id,
    required this.userId,
    required this.numberMasked,
    required this.balance,
    required this.currency,
    required this.status,
    required this.nfcEnabled,
    this.expiresAt,
  });

  factory CardModel.fromMap(Map<String, dynamic> map) {
    return CardModel(
      id: map['id'] as String,
      userId: map['user_id'] as String,
      numberMasked: map['number_masked'] as String? ?? '•••• •••• •••• 0000',
      balance: (map['balance'] as num?)?.toDouble() ?? 0.0,
      currency: (map['currency'] as String?)?.toUpperCase() ?? 'COP',
      status: map['status'] as String? ?? 'active',
      nfcEnabled: map['nfc_enabled'] as bool? ?? true,
      expiresAt: map['expires_at'] as String?,
    );
  }

  bool get isLocked => status == 'locked';
  bool get isActive => status == 'active';

  String get formattedBalance {
    // Format as Colombian peso: $100.000
    final formatted = balance.toStringAsFixed(0).replaceAllMapped(
          RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
          (m) => '${m[1]}.',
        );
    return '\$$formatted COP';
  }

  CardModel copyWith({
    double? balance,
    String? status,
    bool? nfcEnabled,
  }) {
    return CardModel(
      id: id,
      userId: userId,
      numberMasked: numberMasked,
      balance: balance ?? this.balance,
      currency: currency,
      status: status ?? this.status,
      nfcEnabled: nfcEnabled ?? this.nfcEnabled,
      expiresAt: expiresAt,
    );
  }
}
