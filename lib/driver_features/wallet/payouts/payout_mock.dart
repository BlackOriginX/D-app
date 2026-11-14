import 'package:rider_app/driver_features/wallet/wallet_payout_api.dart';

/// What the withdraw flow shows on the result screens.
class WithdrawReceipt {
  const WithdrawReceipt({
    required this.amount,
    required this.transactionId,
    required this.dateTime,
    this.fee = 0,
    this.method = 'Bank transfer',
    this.paidTo = '',
    this.status = 'Completed',
  });

  final double amount;
  final String transactionId;
  final String dateTime;
  final double fee;
  final String method;
  final String paidTo;
  final String status;

  static const _months = [
    'jan',
    'feb',
    'mar',
    'apr',
    'may',
    'jun',
    'jul',
    'aug',
    'sep',
    'oct',
    'nov',
    'dec',
  ];

  /// Receipt built from the withdraw API reply.
  factory WithdrawReceipt.fromResult(WithdrawResult r, {String paidTo = ''}) {
    final base = WithdrawReceipt.now(r.amount);
    return WithdrawReceipt(
      amount: r.amount,
      transactionId: r.id.isEmpty ? base.transactionId : r.id,
      dateTime: base.dateTime,
      fee: r.fee,
      paidTo: paidTo,
      status: r.status.isEmpty ? 'Completed' : r.status,
    );
  }

  factory WithdrawReceipt.now(double amount) {
    final t = DateTime.now();
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    final m = t.minute.toString().padLeft(2, '0');
    final ampm = t.hour < 12 ? 'am' : 'pm';
    return WithdrawReceipt(
      amount: amount,
      transactionId: '${t.millisecondsSinceEpoch}'.substring(2, 13),
      dateTime:
          '${t.day} ${_months[t.month - 1]} , '
          '${h.toString().padLeft(2, '0')}:$m $ampm',
    );
  }
}
