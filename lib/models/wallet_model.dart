// lib/models/wallet_model.dart
import '../core/money.dart';

/// Billetera GoSmart (tabla `wallets`). Saldo en COP enteros.
class Wallet {
  final String id;
  final String userId;
  final int balance; // En COP (enteros)
  final String cardNumber;
  final String cardStatus;
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Wallet({
    required this.id,
    required this.userId,
    required this.balance,
    required this.cardNumber,
    required this.cardStatus,
    required this.createdAt,
    this.updatedAt,
  });

  factory Wallet.fromJson(Map<String, dynamic> json) {
    return Wallet(
      id: json['id'] as String,
      userId: json['user_id'] as String,
      balance: json['balance'] as int,
      cardNumber: json['card_number'] as String,
      cardStatus: json['card_status'] as String? ?? 'active',
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'] as String)
          : null,
    );
  }

  /// Saldo formateado con separadores de miles en COP
  String get formattedBalance => '${formatCop(balance)} COP';

  /// Número de tarjeta con dígitos centrales ocultos
  /// GS-1234-5678-9012 → GS-****-****-9012
  String get maskedCardNumber {
    final parts = cardNumber.split('-');
    if (parts.length == 4) {
      return '${parts[0]}-****-****-${parts[3]}';
    }
    return cardNumber;
  }

  bool get isActive => cardStatus == 'active';

  bool hasSufficientBalance(int amount) => balance >= amount;
}
