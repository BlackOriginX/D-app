import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:rider_app/common/constants/app_urls.dart';
import 'package:rider_app/service/onboarding_api_log.dart';
import 'package:rider_app/service/api_client.dart';

/// Details returned after the licence number and date of birth are checked.
class DrivingLicenceDetails {
  const DrivingLicenceDetails({
    required this.name,
    required this.licenseNumber,
    required this.dob,
    required this.vehicleClass,
    required this.validity,
  });

  final String name;
  final String licenseNumber;
  final String dob;
  final String vehicleClass;
  final String validity;

  factory DrivingLicenceDetails.fromBody(
    String body, {
    required String fallbackNumber,
    required String fallbackDob,
  }) {
    final decoded = jsonDecode(body);
    final root = decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};
    final data = _map(root['data']);
    final extracted = _map(root['extracted']);
    final source = data.isNotEmpty ? data : extracted;

    String pick(List<String> keys) {
      for (final key in keys) {
        final value = source[key] ?? root[key];
        final text = _text(value);
        if (text.isNotEmpty) return text;
      }
      return '';
    }

    return DrivingLicenceDetails(
      name: pick(['name', 'full_name', 'holder_name']),
      licenseNumber:
          pick([
            'license_number',
            'licence_number',
            'dl_number',
            'id_number',
          ]).isEmpty
          ? fallbackNumber
          : pick([
              'license_number',
              'licence_number',
              'dl_number',
              'id_number',
            ]),
      dob: pick(['dob', 'date_of_birth']).isEmpty
          ? fallbackDob
          : pick(['dob', 'date_of_birth']),
      vehicleClass: _vehicleClass(
        source['vehicle_classes'] ??
            source['vehicle_class'] ??
            root['vehicle_classes'],
      ),
      validity: pick([
        'doe',
        'expiry',
        'expiry_date',
        'validity',
        'valid_till',
      ]),
    );
  }
}

class DlVerificationException implements Exception {
  DlVerificationException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Posts `{ "document_no", "dob" }` (dob as dd-mm-yyyy) to the Torkk server,
/// which keeps the Surepass token. The login Bearer token is added by
/// [apiClient].
Future<DrivingLicenceDetails> verifyDrivingLicence({
  required String idNumber,
  required String dob,
}) async {
  var requestBody = <String, dynamic>{'document_no': idNumber, 'dob': dob};
  final encodedBody = json.encode(requestBody);
  onbBefore('DRIVING LICENCE VERIFY', 'POST', AppUrls.verifyDl, encodedBody);
  final http.Response response;
  try {
    response = await apiClient
        .post(
          Uri.parse(AppUrls.verifyDl),
          headers: {'Content-Type': 'application/json'},
          body: encodedBody,
        )
        .timeout(const Duration(seconds: 20));
  } catch (e) {
    onbFailed('DRIVING LICENCE VERIFY', e);
    rethrow;
  }
  onbAfter('DRIVING LICENCE VERIFY', response.statusCode, response.body);

  if (response.statusCode < 200 ||
      response.statusCode >= 300 ||
      _rejectedByServer(response.body)) {
    throw DlVerificationException(_errorMessage(response.body));
  }
  return DrivingLicenceDetails.fromBody(
    response.body,
    fallbackNumber: idNumber,
    fallbackDob: dob,
  );
}

Map<String, dynamic> _map(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return {};
}

String _text(dynamic value) {
  if (value == null) return '';
  return value.toString().trim();
}

String _vehicleClass(dynamic value) {
  if (value is List) {
    return value
        .map((item) {
          if (item is Map) {
            return _text(
              item['class'] ??
                  item['cov'] ??
                  item['vehicle_class'] ??
                  item['desc'],
            );
          }
          return _text(item);
        })
        .where((item) => item.isNotEmpty)
        .join(', ');
  }
  return _text(value);
}

String _errorMessage(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is Map) {
      for (final key in ['message', 'error', 'detail']) {
        final text = _text(decoded[key]);
        if (text.isNotEmpty) return text;
      }
    }
  } catch (_) {}
  return 'Driving licence could not be verified.';
}

/// True when a 2xx reply still says the check failed (`success: false`).
bool _rejectedByServer(String body) {
  try {
    final decoded = jsonDecode(body);
    if (decoded is! Map) return false;
    if (decoded['success'] == false || decoded['status'] == 'error') {
      return true;
    }
    final status = decoded['status_code'];
    return status is num && status >= 400;
  } catch (_) {
    return false;
  }
}
