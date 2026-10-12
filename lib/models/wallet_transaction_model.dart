// lib/models/wallet_transaction_model.dart
import 'package:flutter/material.dart';
import '../core/money.dart';

enum WalletTxType { recharge, trip, refund, bonus, earning }

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
        'earning' => WalletTxType.earning,
        _ => WalletTxType.recharge,
      };

  bool get isIncome => amount >= 0;

  /// "+$10.000" o "−$2.500". El signo dice si entra o sale; sin colores
  /// rojo/verde (DESIGN.md: esos son solo para la vía).
  String get formattedAmount => formatCop(amount, signed: true);

  String get typeLabel => switch (type) {
        WalletTxType.recharge => 'Recarga',
        WalletTxType.trip => 'Viaje',
        WalletTxType.refund => 'Reembolso',
        WalletTxType.bonus => 'Bono',
        WalletTxType.earning => 'Cobro de viaje',
      };

  IconData get icon => switch (type) {
        WalletTxType.recharge => Icons.add_circle_outline_rounded,
        WalletTxType.trip => _tripIcon,
        WalletTxType.refund => Icons.replay_rounded,
        WalletTxType.bonus => Icons.card_giftcard_rounded,
        WalletTxType.earning => Icons.payments_outlined,
      };

  /// El movimiento no guarda el modo; se deduce de la descripción con los
  /// mismos íconos del planificador. Sin pista, ícono genérico de ruta.
  IconData get _tripIcon {
    final d = (description ?? '').toLowerCase();
    if (d.contains('mototaxi')) return Icons.two_wheeler_rounded;
    if (d.contains('taxi')) return Icons.local_taxi_rounded;
    if (d.contains('colectivo')) return Icons.airport_shuttle_rounded;
    if (d.contains('transpadilla')) return Icons.directions_bus_rounded;
    if (d.contains('intermunicipal')) return Icons.directions_bus_filled_rounded;
    if (d.contains('a pie')) return Icons.directions_walk_rounded;
    return Icons.route_rounded;
  }

  String get formattedDate {
    final now = DateTime.now();
    final diff = now.difference(createdAt);
    if (diff.inMinutes < 1) return 'Ahora';
    if (diff.inMinutes < 60) return 'Hace ${diff.inMinutes} min';
    if (diff.inHours < 24) return 'Hace ${diff.inHours}h';
    if (diff.inDays == 1) return 'Ayer';
    if (diff.inDays < 7) return 'Hace ${diff.inDays} días';
    // Sin DateFormat('es'): exige initializeDateFormatting y lanzaría aquí.
    const months = ['ene', 'feb', 'mar', 'abr', 'may', 'jun',
        'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
    final local = createdAt.toLocal();
    return '${local.day} ${months[local.month - 1]}';
  }
}
