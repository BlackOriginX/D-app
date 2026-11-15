import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:rider_app/common/constants/app_urls.dart';
import 'package:rider_app/service/api_client.dart';
import 'package:rider_app/service/onboarding_api_log.dart';

/// The onboarding HTTP calls. Each returns the raw response; the caller
/// ([OnboardingSession]) decides what the status and body mean.
class OnboardingApi {
  const OnboardingApi._();

  /// POST JSON with the `ONB_API` before/after console lines.
  static Future<http.Response> _post(
    String step,
    String url,
    String body,
    Duration timeout,
  ) async {
    onbBefore(step, 'POST', url, body);
    try {
      final response = await apiClient
          .post(
            Uri.parse(url),
            headers: {'Content-Type': 'application/json'},
            body: body,
          )
          .timeout(timeout);
      onbAfter(step, response.statusCode, response.body);
      return response;
    } catch (e) {
      onbFailed(step, e);
      rethrow;
    }
  }

  static Future<http.Response> sendOtp({required String phone}) {
    return _post(
      'SEND OTP',
      AppUrls.sendOtp,
      json.encode({'phone': phone}),
      const Duration(seconds: 15),
    );
  }

  static Future<http.Response> verifyOtp({
    required String phone,
    required String otp,
  }) {
    return _post(
      'VERIFY OTP',
      AppUrls.verifyOtp,
      json.encode({'phone': phone, 'otp': otp, 'code': otp}),
      const Duration(seconds: 15),
    );
  }

  static Future<http.Response> verifyAadhaar({
    required String aadhaarNumber,
    required String phone,
    required String panNumber,
  }) {
    return _post(
      'AADHAAR+PAN VERIFY',
      AppUrls.verifyAadhaar,
      json.encode({
        'aadhaar_number': aadhaarNumber,
        'phone': phone,
        'pan_number': panNumber,
      }),
      const Duration(seconds: 10),
    );
  }

  static Future<http.Response> register(Map<String, dynamic> body) {
    return _post(
      'PROFILE SUBMIT (REGISTER)',
      AppUrls.driverRegister,
      json.encode(body),
      const Duration(seconds: 15),
    );
  }
}
