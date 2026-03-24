// lib/models/wallet_transaction_model.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/design_tokens.dart';

enum WalletTxType { recharge, trip, refund, bonus }

class WalletTransactionModel {
  final String id;
  final String walletId;
  final WalletTxType type;
  final int amount;
  final String? description;
  final DateTime createdAt;

  const WalletTransactionModel({
    required this.id,
    required this.walletId,
    required this.type,
    required this.amount,
    this.description,
    required this.createdAt,
  });

  factory WalletTransactionModel.fromJson(Map<String, dynamic> json) {
    return WalletTransactionModel(
      id: json['id'] as String,
      walletId: json['wallet_id'] as String,
      type: _typeFrom(json['type'] as String),
      amount: json['amount'] as int,
      description: json['description'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  static WalletTxType _typeFrom(String v) => switch (v) {
        'recharge' => WalletTxType.recharge,
        'trip' => WalletTxType.trip,
        'refund' => WalletTxType.refund,
        'bonus' => WalletTxType.bonus,
        _ => WalletTxType.recharge,
      };

  bool get isIncome => amount >= 0;

  String get formattedAmount {
    final f = NumberFormat('#,###', 'es_CO');
    final sign = amount >= 0 ? '+' : '-';
    return '$sign\$${f.format(amount.abs())} COP';
  }

  String get typeLabel => switch (type) {
        WalletTxType.recharge => 'Recarga',
        WalletTxType.trip => 'Viaje',
        WalletTxType.refund => 'Reembolso',
        WalletTxType.bonus => 'Bono',
      };

  IconData get icon => switch (type) {
        WalletTxType.recharge => Icons.add_circle_outline_rounded,
        WalletTxType.trip => Icons.directions_bus_rounded,
        WalletTxType.refund => Icons.replay_rounded,
        WalletTxType.bonus => Icons.card_giftcard_rounded,
      };

  Color get color => isIncome ? GSColors.success : GSColors.error;

  String get formattedDate {
    final now = DateTime.now();
    final diff = now.difference(createdAt);
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours}h';
    if (diff.inDays == 1) return 'Ayer';
    if (diff.inDays < 7) return 'Hace ${diff.inDays} días';
    return DateFormat('d MMM', 'es').format(createdAt);
  }
}
