import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'package:rider_app/common/constants/app_urls.dart';
import 'package:rider_app/service/api_client.dart';
import 'package:rider_app/service/onboarding_api_log.dart';

/// Onboarding APIs for vehicle photos, insurance, IFSC lookup and the
/// face (liveness) check. The bank details save lives in
/// `DriverApiService.saveBankDetails`.
///
/// Every call prints `ONB_API | <STEP> | BEFORE` (with the request body) and
/// `ONB_API | <STEP> | AFTER` (status code and response body).
class KycApiException implements Exception {
  KycApiException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Registration number, model and type saved for the driver's vehicle.
class VehicleInfo {
  const VehicleInfo({
    required this.registrationNumber,
    required this.model,
    required this.type,
  });

  final String registrationNumber;
  final String model;
  final String type;
}

/// IFSC code, bank and branch found by the lookup.
class IfscDetails {
  const IfscDetails({
    required this.ifsc,
    required this.bankName,
    required this.branchName,
  });

  final String ifsc;
  final String bankName;
  final String branchName;
}

/// Photo links the server already holds for the vehicle (may be empty).
class VehiclePhotoUrls {
  const VehiclePhotoUrls({this.front = '', this.back = ''});

  final String front;
  final String back;

  bool get isEmpty => front.isEmpty && back.isEmpty;
}

class KycDocumentsApi {
  const KycDocumentsApi._();

  static const _timeout = Duration(seconds: 20);
  static const _uploadTimeout = Duration(seconds: 60);

  /// GET /api/driver/vehicle/info
  static Future<VehicleInfo> fetchVehicleInfo() async {
    final body = await _call(
      'VEHICLE INFO',
      'GET',
      AppUrls.vehicleInfo,
      () => apiClient.get(Uri.parse(AppUrls.vehicleInfo)).timeout(_timeout),
    );
    final data = _map(body['data']);
    return VehicleInfo(
      registrationNumber: _text(data['registration_number']),
      model: _text(data['vehicle_model']),
      type: _text(data['vehicle_type']),
    );
  }

  /// POST /api/driver/vehicle/photos (multipart)
  static Future<Map<String, dynamic>> uploadVehiclePhotos({
    required String frontPath,
    required String backPath,
    required String rcNumber,
    required String vehicleModel,
    required String vehicleType,
  }) {
    return _multipart(
      'VEHICLE PHOTOS UPLOAD',
      'POST',
      AppUrls.vehiclePhotos,
      fields: {
        'rc_number': rcNumber,
        'vehicle_model': vehicleModel,
        'vehicle_type': vehicleType,
      },
      files: {'front_photo': frontPath, 'back_photo': backPath},
    );
  }

  /// GET /api/driver/vehicle/photos?vehicle_id=...
  /// The reply format is not fixed, so the links are looked up by key name.
  static Future<VehiclePhotoUrls> fetchVehiclePhotos({
    String? vehicleId,
  }) async {
    final url = vehicleId == null || vehicleId.isEmpty
        ? AppUrls.vehiclePhotos
        : '${AppUrls.vehiclePhotos}?vehicle_id=${Uri.encodeComponent(vehicleId)}';
    final body = await _call(
      'VEHICLE PHOTOS GET',
      'GET',
      url,
      () => apiClient.get(Uri.parse(url)).timeout(_timeout),
    );
    final data = _map(body['data']).isNotEmpty ? _map(body['data']) : body;
    String find(String side) {
      for (final entry in data.entries) {
        final key = entry.key.toLowerCase();
        final value = _text(entry.value);
        if (key.contains(side) && value.startsWith('http')) return value;
      }
      return '';
    }

    return VehiclePhotoUrls(front: find('front'), back: find('back'));
  }

  /// PUT /api/driver/vehicle/photos/{front|back} (multipart, field `photo`)
  static Future<void> replaceVehiclePhoto({
    required String type,
    required String path,
  }) async {
    await _multipart(
      'VEHICLE PHOTO REPLACE ($type)',
      'PUT',
      AppUrls.vehiclePhotoReplace(type),
      files: {'photo': path},
    );
  }

  /// POST /api/driver/vehicle/insurance (multipart)
  /// [expiryDate] must be `YYYY-MM-DD`.
  static Future<void> uploadInsurance({
    required String pdfPath,
    required String expiryDate,
  }) async {
    await _multipart(
      'INSURANCE UPLOAD',
      'POST',
      AppUrls.vehicleInsurance,
      fields: {'expiry_date': expiryDate},
      files: {'insurance_pdf': pdfPath},
    );
  }

  /// POST /api/bank/find-ifsc
  static Future<IfscDetails> findIfsc({
    required String ifsc,
  }) async {
    final requestBody = jsonEncode({'ifsc': ifsc});
    final body = await _call(
      'FIND IFSC',
      'POST',
      AppUrls.findIfsc,
      () => apiClient
          .post(
            Uri.parse(AppUrls.findIfsc),
            headers: {'Content-Type': 'application/json'},
            body: requestBody,
          )
          .timeout(_timeout),
      requestNote: requestBody,
    );
    // Reply: {success, data: {ifsc, exists, ifsc_data: {bank_name, branch, ...}}}
    final outer = _map(body['data']).isNotEmpty ? _map(body['data']) : body;
    if (outer['exists'] == false) {
      throw KycApiException('IFSC code not found.');
    }
    final data = _map(outer['ifsc_data']).isNotEmpty
        ? _map(outer['ifsc_data'])
        : outer;
    String pick(List<String> keys) {
      for (final key in keys) {
        final value = _text(data[key]);
        if (value.isNotEmpty) return value;
      }
      return '';
    }

    final code = pick(['ifsc', 'ifsc_code', 'IFSC']);
    final bank = pick(['bank_name', 'bank', 'BANK']);
    if (bank.isEmpty && code.isEmpty) {
      throw KycApiException('IFSC code not found.');
    }
    return IfscDetails(
      ifsc: code,
      bankName: bank,
      branchName: pick(['branch_name', 'branch', 'BRANCH']),
    );
  }

  /// POST /api/kyc/liveness. Returns the confidence score (0 if not sent).
  static Future<double> verifyLiveness({
    required String phone,
    required String selfiePath,
  }) async {
    final bytes = await File(selfiePath).readAsBytes();
    final encoded = base64Encode(bytes);
    final body = await _call(
      'FACE LIVENESS',
      'POST',
      AppUrls.kycLiveness,
      () => apiClient
          .post(
            Uri.parse(AppUrls.kycLiveness),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({'phone': phone, 'selfie_base64': encoded}),
          )
          .timeout(_uploadTimeout),
      // The base64 selfie is huge; do not print it.
      requestNote: 'phone=$phone selfie_base64=<${encoded.length} chars>',
    );
    final confidence = body['confidence'];
    return confidence is num ? confidence.toDouble() : 0;
  }

  static Future<Map<String, dynamic>> _multipart(
    String tag,
    String method,
    String url, {
    Map<String, String> fields = const {},
    required Map<String, String> files,
  }) {
    return _call(tag, method, url, () async {
      final request = http.MultipartRequest(method, Uri.parse(url))
        ..fields.addAll(fields);
      for (final entry in files.entries) {
        request.files.add(
          await http.MultipartFile.fromPath(entry.key, entry.value),
        );
      }
      final streamed = await apiClient.send(request).timeout(_uploadTimeout);
      return http.Response.fromStream(streamed);
    }, requestNote: 'fields=$fields files=$files');
  }

  /// Runs [send], prints the `ONB_API` before/after lines, and returns the decoded JSON map.
  /// Throws [KycApiException] with the server message on any failure.
  static Future<Map<String, dynamic>> _call(
    String tag,
    String method,
    String url,
    Future<http.Response> Function() send, {
    String? requestNote,
  }) async {
    onbBefore(tag, method, url, requestNote);
    final http.Response response;
    try {
      response = await send();
    } catch (e) {
      onbFailed(tag, e);
      throw KycApiException(
        'Could not reach the server. Check your internet and try again.',
      );
    }
    onbAfter(tag, response.statusCode, response.body);
    Map<String, dynamic> decoded = {};
    try {
      final value = response.body.isEmpty ? null : jsonDecode(response.body);
      if (value is Map) decoded = Map<String, dynamic>.from(value);
    } catch (_) {}
    final failedFlag =
        decoded['status'] == 'error' || decoded['success'] == false;
    if (response.statusCode < 200 || response.statusCode >= 300 || failedFlag) {
      throw KycApiException(_errorMessage(decoded, response.statusCode));
    }
    return decoded;
  }

  static String _errorMessage(Map<String, dynamic> body, int status) {
    for (final key in ['message', 'error', 'detail']) {
      final text = _text(body[key]);
      if (text.isNotEmpty) return text;
    }
    return 'Something went wrong ($status). Please try again.';
  }

  static Map<String, dynamic> _map(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  static String _text(dynamic value) {
    if (value == null) return '';
    final text = value.toString().trim();
    return text == 'null' ? '' : text;
  }
}
