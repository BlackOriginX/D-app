import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import 'package:rider_app/common/constants/app_urls.dart';
import 'package:rider_app/driver_features/wallet/wallet_format.dart';
import 'package:rider_app/service/api_client.dart';
import 'package:rider_app/service/onboarding_api_log.dart';

/// The server refused or failed a payout call; [message] is shown to the
/// driver and [statusCode] lets the screen tell, say, 409 from a network error.
class PayoutApiException implements Exception {
  PayoutApiException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

Map<String, dynamic> _map(dynamic v) =>
    v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

String _text(dynamic v) => v == null ? '' : v.toString().trim();

/// First non-empty value of [keys] in [maps] (checked in order).
String pickText(List<Map<String, dynamic>> maps, List<String> keys) {
  for (final m in maps) {
    for (final k in keys) {
      final v = _text(m[k]);
      if (v.isNotEmpty && v != 'null') return v;
    }
  }
  return '';
}

double? _pickNum(List<Map<String, dynamic>> maps, List<String> keys) {
  for (final m in maps) {
    final v = pickAmount(m, keys);
    if (v != null) return v;
  }
  return null;
}

/// The reply body plus every object it nests under `data`.
List<Map<String, dynamic>> _layers(Map<String, dynamic> body) {
  final data = _map(body['data']);
  return [data, body];
}

/// A row of the payout history (a statement entry or a withdrawal).
class PayoutItem {
  const PayoutItem({
    required this.id,
    required this.title,
    required this.status,
    required this.amount,
    required this.credit,
    this.date,
    this.reference = '',
    this.note = '',
  });

  final String id;
  final String title;
  final String status;
  final double amount;

  /// True when money came in (earning / top-up), false for a debit.
  final bool credit;
  final DateTime? date;
  final String reference;
  final String note;

  factory PayoutItem.fromJson(
    Map<String, dynamic> json, {
    String? fallbackTitle,
  }) {
    final maps = [json];
    final type = pickText(maps, [
      'type',
      'transaction_type',
      'category',
      'kind',
    ]).toLowerCase();
    final raw = _pickNum(maps, ['amount', 'total', 'fare', 'earning']) ?? 0;
    final debit =
        type.contains('debit') ||
        type.contains('withdraw') ||
        type.contains('payout') ||
        raw < 0;
    final title = pickText(maps, [
      'title',
      'description',
      'narration',
      'remark',
      'transaction_type',
      'type',
    ]);
    return PayoutItem(
      id: pickText(maps, ['transaction_id', 'withdrawal_id', 'txn_id', 'id']),
      title: title.isEmpty ? (fallbackTitle ?? 'Transaction') : _pretty(title),
      status: pickText(maps, ['status', 'state']),
      amount: raw.abs(),
      credit: !debit,
      date: DateTime.tryParse(
        pickText(maps, [
          'created_at',
          'date',
          'timestamp',
          'requested_at',
          'completed_at',
        ]),
      )?.toLocal(),
      reference: pickText(maps, ['utr', 'reference', 'reference_id', 'rrn']),
      note: pickText(maps, ['failure_reason', 'reason', 'message']),
    );
  }

  static String _pretty(String v) {
    final t = v.replaceAll('_', ' ').trim();
    return t.isEmpty ? t : t[0].toUpperCase() + t.substring(1);
  }
}

/// GET /api/driver/payouts/summary
class PayoutSummary {
  const PayoutSummary({
    required this.balance,
    required this.thisWeek,
    required this.pending,
    required this.bankLabel,
    required this.recent,
  });

  final double balance;
  final double thisWeek;
  final double pending;
  final String bankLabel;
  final List<PayoutItem> recent;

  factory PayoutSummary.fromBody(Map<String, dynamic> body) {
    final layers = _layers(body);
    final bank = _map(
      layers
          .map((m) => m['bank_account'] ?? m['bank'])
          .firstWhere((v) => v is Map, orElse: () => null),
    );
    final bankName = pickText([bank], ['bank_name', 'bank']);
    final acc = pickText([bank], ['account_number', 'masked_account_number']);
    final tail = acc.length > 4 ? acc.substring(acc.length - 4) : acc;
    Object? listRaw;
    for (final m in layers) {
      listRaw = m['recent_transactions'] ?? m['transactions'] ?? m['recent'];
      if (listRaw is List) break;
    }
    return PayoutSummary(
      balance:
          _pickNum(layers, [
            'available_balance',
            'balance',
            'wallet_balance',
          ]) ??
          0,
      thisWeek:
          _pickNum(layers, [
            'this_week',
            'this_week_earnings',
            'week_earnings',
          ]) ??
          0,
      pending:
          _pickNum(layers, [
            'pending_payouts',
            'pending_payout',
            'pending',
            'pending_amount',
          ]) ??
          0,
      bankLabel: [bankName, if (tail.isNotEmpty) '••$tail'].join(' ').trim(),
      recent: [
        if (listRaw is List)
          for (final e in listRaw)
            if (e is Map) PayoutItem.fromJson(Map<String, dynamic>.from(e)),
      ],
    );
  }
}

/// What the withdraw success screen shows, read from the withdraw reply.
class WithdrawResult {
  const WithdrawResult({
    required this.id,
    required this.amount,
    required this.status,
    required this.fee,
  });

  final String id;
  final double amount;
  final String status;
  final double fee;
}

class WalletPayoutApi {
  const WalletPayoutApi._();

  static const _timeout = Duration(seconds: 15);

  /// A fresh Idempotency-Key (4 to 36 characters). Make one per withdrawal and
  /// reuse it only to retry that same withdrawal.
  static String newIdempotencyKey() {
    final rand = Random.secure().nextInt(0xFFFFFF).toRadixString(36);
    return 'wd-${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}-$rand';
  }

  static Future<Map<String, dynamic>> _call(
    String step,
    String method,
    String url, {
    Object? body,
    Map<String, String> headers = const {},
  }) async {
    onbBefore(step, method, url, body);
    final http.Response response;
    try {
      final h = {
        if (body != null) 'Content-Type': 'application/json',
        ...headers,
      };
      final uri = Uri.parse(url);
      final future = method == 'POST'
          ? apiClient.post(uri, headers: h, body: jsonEncode(body))
          : apiClient.get(uri, headers: h);
      response = await future.timeout(_timeout);
    } catch (e) {
      onbFailed(step, e);
      throw PayoutApiException(
        'Could not reach the server. Check your internet and try again.',
      );
    }
    onbAfter(step, response.statusCode, response.body);
    dynamic decoded;
    try {
      decoded = response.body.isEmpty ? null : jsonDecode(response.body);
    } catch (_) {}
    final map = decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};
    final saidNo = map['success'] == false || map['status'] == 'error';
    if (response.statusCode < 200 || response.statusCode >= 300 || saidNo) {
      var message = pickText([map], ['message', 'error', 'detail']);
      if (message.isEmpty) {
        message = 'Something went wrong (${response.statusCode}).';
      }
      throw PayoutApiException(message, statusCode: response.statusCode);
    }
    // A bare JSON list is wrapped so callers always get a map.
    if (decoded is List) return {'data': decoded};
    return map;
  }

  /// GET /api/driver/payouts/summary
  static Future<PayoutSummary> fetchSummary() async {
    final body = await _call('PAYOUT SUMMARY', 'GET', AppUrls.payoutSummary);
    final summary = PayoutSummary.fromBody(body);
    debugPrint(
      'PAYOUT_API | summary parsed: balance=${summary.balance} '
      'thisWeek=${summary.thisWeek} pending=${summary.pending} '
      'bank="${summary.bankLabel}" recent=${summary.recent.length}',
    );
    return summary;
  }

  /// POST /api/driver/wallet/withdraw with an Idempotency-Key header.
  /// 409 means the bank account is not verified yet.
  static Future<WithdrawResult> withdraw({
    required double amount,
    required String idempotencyKey,
  }) async {
    final num value = amount == amount.roundToDouble()
        ? amount.round()
        : amount;
    final body = await _call(
      'WALLET WITHDRAW',
      'POST',
      AppUrls.walletWithdraw,
      body: {'amount': value},
      headers: {'Idempotency-Key': idempotencyKey},
    );
    final layers = [
      ..._layers(body),
      ..._layers(_map(_layers(body).first['withdrawal'])),
    ];
    return WithdrawResult(
      id: pickText(layers, [
        'withdrawal_id',
        'transaction_id',
        'reference',
        'id',
      ]),
      amount: _pickNum(layers, ['amount']) ?? amount,
      status: pickText(layers, ['status', 'state']),
      fee: _pickNum(layers, ['fee', 'withdraw_fee', 'charges']) ?? 0,
    );
  }

  /// GET /api/driver/wallet/withdrawals (the settlement list)
  static Future<List<PayoutItem>> fetchWithdrawals() async {
    final body = await _call(
      'WALLET WITHDRAWALS',
      'GET',
      AppUrls.walletWithdrawals,
    );
    return _items(body, const [
      'withdrawals',
      'data',
      'items',
      'results',
    ]).map((e) => PayoutItem.fromJson(e, fallbackTitle: 'Withdrawal')).toList();
  }

  /// GET /api/driver/wallet/transactions?limit&offset[&from&to]
  static Future<List<PayoutItem>> fetchTransactions({
    int limit = 20,
    int offset = 0,
    String? from,
    String? to,
  }) async {
    final body = await _call(
      'WALLET TRANSACTIONS',
      'GET',
      AppUrls.walletTransactions(
        limit: limit,
        offset: offset,
        from: from,
        to: to,
      ),
    );
    return _items(body, const [
      'transactions',
      'data',
      'items',
      'results',
    ]).map((e) => PayoutItem.fromJson(e)).toList();
  }

  static List<Map<String, dynamic>> _items(
    Map<String, dynamic> body,
    List<String> keys,
  ) {
    Object? list;
    for (final layer in _layers(body)) {
      for (final k in keys) {
        final v = layer[k];
        if (v is List) {
          list = v;
          break;
        }
        // e.g. {data: {transactions: [...]}}
        if (v is Map) {
          for (final inner in keys) {
            if (v[inner] is List) list = v[inner];
          }
        }
      }
      if (list != null) break;
    }
    return [
      if (list is List)
        for (final e in list)
          if (e is Map) Map<String, dynamic>.from(e),
    ];
  }
}
