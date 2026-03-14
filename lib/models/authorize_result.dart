// lib/models/authorize_result.dart

enum AuthorizeStatus { authorized, insufficientBalance, cardLocked, error }

class AuthorizeResult {
  final AuthorizeStatus status;
  final String? txId;
  final double? remainingBalance;
  final String? errorCode;

  const AuthorizeResult({
    required this.status,
    this.txId,
    this.remainingBalance,
    this.errorCode,
  });

  factory AuthorizeResult.fromMap(
    Map<String, dynamic> map, {
    int httpStatus = 200,
  }) {
    final code = map['code'] as String?;
    final statusStr = map['status'] as String?;

    AuthorizeStatus s;
    if (statusStr == 'authorized') {
      s = AuthorizeStatus.authorized;
    } else if (code == 'INSUFFICIENT_BALANCE') {
      s = AuthorizeStatus.insufficientBalance;
    } else if (code == 'CARD_LOCKED') {
      s = AuthorizeStatus.cardLocked;
    } else {
      s = AuthorizeStatus.error;
    }

    return AuthorizeResult(
      status: s,
      txId: map['tx_id'] as String?,
      remainingBalance: (map['remaining_balance'] as num?)?.toDouble(),
      errorCode: code,
    );
  }

  bool get isAuthorized => status == AuthorizeStatus.authorized;
}
