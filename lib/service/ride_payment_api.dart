import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:rider_app/common/constants/app_urls.dart';
import 'package:rider_app/service/api_client.dart';
import 'package:rider_app/service/razorpay_service.dart';
import 'package:rider_app/service/ride_api_log.dart';

class RidePaymentException implements Exception {
  RidePaymentException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// The payment calls of a ride that go to our own backend.
class RidePaymentApi {
  RidePaymentApi._();

  static const _timeout = Duration(seconds: 20);

  /// POST /api/ride/payment/qr {"ride_id": N}. The server creates the UPI QR
  /// and returns it. The reply is read by key names (id / image url / UPI
  /// string), because the exact format is not fixed.
  static Future<RazorpayQr> createQr({
    required int rideId,
    required double amountRupees,
  }) async {
    const step = 'PAYMENT QR';
    final body = jsonEncode({'ride_id': rideId});
    rideBefore(step, 'POST', AppUrls.paymentQr, body);
    final http.Response response;
    try {
      response = await apiClient
          .post(
            Uri.parse(AppUrls.paymentQr),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(_timeout);
    } catch (e) {
      rideFailed(step, e);
      throw RidePaymentException('Could not reach the server');
    }
    rideAfter(step, response.statusCode, response.body);

    Map<String, dynamic> root = {};
    try {
      final decoded = jsonDecode(response.body);
      if (decoded is Map) root = Map<String, dynamic>.from(decoded);
    } catch (_) {}
    final failedFlag = root['status'] == 'error' || root['success'] == false;
    if (response.statusCode < 200 || response.statusCode >= 300 || failedFlag) {
      throw RidePaymentException(_message(root, response.statusCode));
    }

    Map<String, dynamic> map(dynamic v) =>
        v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};
    final inner = map(root['data']).isNotEmpty
        ? map(root['data'])
        : map(root['qr']).isNotEmpty
        ? map(root['qr'])
        : root;
    String pick(List<String> keys) {
      for (final key in keys) {
        final text = '${inner[key] ?? root[key] ?? ''}'.trim();
        if (text.isNotEmpty && text != 'null') return text;
      }
      return '';
    }

    final id = pick(['qr_id', 'qr_code_id', 'id']);
    final imageUrl = pick(['image_url', 'qr_image_url', 'qr_url', 'qr_image']);
    final content = pick([
      'image_content',
      'upi_url',
      'upi_link',
      'upi_string',
      'qr_string',
      'qr_data',
    ]);
    if (imageUrl.isEmpty && content.isEmpty) {
      throw RidePaymentException('The server did not send a QR code');
    }
    final amount = num.tryParse(pick(['payment_amount', 'amount_paise']));
    return RazorpayQr(
      id: id,
      imageUrl: imageUrl,
      imageContent: content,
      amountPaise: amount != null
          ? amount.toInt()
          : (amountRupees * 100).round(),
    );
  }

  static String _message(Map<String, dynamic> body, int status) {
    for (final key in ['message', 'error', 'detail']) {
      final text = '${body[key] ?? ''}'.trim();
      if (text.isNotEmpty && text != 'null') return text;
    }
    return 'Could not create the QR ($status)';
  }
}
