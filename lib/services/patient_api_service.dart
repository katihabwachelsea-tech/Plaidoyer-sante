import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/app_config.dart';
import 'api_logger.dart';

class PatientApiService {
  static const String baseUrl = AppConfig.baseUrl;
  static const _storage = FlutterSecureStorage();
  static const Duration _timeout = AppConfig.defaultTimeout;

  static final PatientApiService instance = PatientApiService._internal();
  PatientApiService._internal();

  Future<Map<String, String>> _headers() async {
    final token = await _storage.read(key: 'jwt_token');
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  dynamic _decode(http.Response response) {
    if (response.body.isEmpty) return {};
    return jsonDecode(response.body);
  }

  void _checkStatus(http.Response response, String url) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    final body = _decode(response);
    final msg = body is Map ? (body['message'] ?? body.toString()) : response.body;
    throw Exception('Erreur ${response.statusCode}: $msg');
  }

  Future<List<Map<String, dynamic>>> getAppointments() async {
    final url = '$baseUrl/patient/appointments';
    final headers = await _headers();
    ApiLogger.request(method: 'GET', url: url, headers: headers);
    final response = await http
        .get(Uri.parse(url), headers: headers)
        .timeout(_timeout);
    ApiLogger.response(url: url, statusCode: response.statusCode, body: response.body);
    _checkStatus(response, url);
    final data = _decode(response);
    return (data['data'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<void> cancelAppointment(int id) async {
    final url = '$baseUrl/patient/appointments/$id/cancel';
    final headers = await _headers();
    ApiLogger.request(method: 'POST', url: url, headers: headers);
    final response = await http
        .post(Uri.parse(url), headers: headers)
        .timeout(_timeout);
    ApiLogger.response(url: url, statusCode: response.statusCode, body: response.body);
    _checkStatus(response, url);
  }

  Future<Map<String, dynamic>> payAppointment({
    required int id,
    required String methode,
    required String telephone,
  }) async {
    final url = '$baseUrl/patient/appointments/$id/pay';
    final headers = await _headers();
    final body = {'methode_paiement': methode, 'telephone': telephone};
    ApiLogger.request(method: 'POST', url: url, headers: headers, body: body);
    final response = await http
        .post(Uri.parse(url), headers: headers, body: jsonEncode(body))
        .timeout(_timeout);
    ApiLogger.response(url: url, statusCode: response.statusCode, body: response.body);
    _checkStatus(response, url);
    return Map<String, dynamic>.from(_decode(response) as Map);
  }

  Future<Map<String, dynamic>> getProfile() async {
    final url = '$baseUrl/patient/profile';
    final headers = await _headers();
    ApiLogger.request(method: 'GET', url: url, headers: headers);
    final response = await http
        .get(Uri.parse(url), headers: headers)
        .timeout(_timeout);
    ApiLogger.response(url: url, statusCode: response.statusCode, body: response.body);
    _checkStatus(response, url);
    final data = _decode(response);
    return Map<String, dynamic>.from(data['data'] as Map);
  }

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> body) async {
    final url = '$baseUrl/patient/profile';
    final headers = await _headers();
    ApiLogger.request(method: 'PUT', url: url, headers: headers, body: body);
    final response = await http
        .put(Uri.parse(url), headers: headers, body: jsonEncode(body))
        .timeout(_timeout);
    ApiLogger.response(url: url, statusCode: response.statusCode, body: response.body);
    _checkStatus(response, url);
    final data = _decode(response);
    return Map<String, dynamic>.from(data['data'] as Map);
  }

  Future<List<Map<String, dynamic>>> getMedicalRecord() async {
    final url = '$baseUrl/patient/medical-record';
    final headers = await _headers();
    ApiLogger.request(method: 'GET', url: url, headers: headers);
    final response = await http
        .get(Uri.parse(url), headers: headers)
        .timeout(_timeout);
    ApiLogger.response(url: url, statusCode: response.statusCode, body: response.body);
    _checkStatus(response, url);
    final data = _decode(response);
    return (data['data'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  /// POST /api/patient/profile/photo (multipart)
  Future<String> uploadPhoto(String filePath) async {
    final url = '$baseUrl/patient/profile/photo';
    final token = await _storage.read(key: 'jwt_token');
    final request = http.MultipartRequest('POST', Uri.parse(url));
    if (token != null && token.isNotEmpty) {
      request.headers['Authorization'] = 'Bearer $token';
    }
    request.headers['Accept'] = 'application/json';
    request.files.add(await http.MultipartFile.fromPath('photo', filePath));
    ApiLogger.request(method: 'POST', url: url, headers: request.headers);
    final streamed = await request.send().timeout(_timeout);
    final response = await http.Response.fromStream(streamed);
    ApiLogger.response(url: url, statusCode: response.statusCode, body: response.body);
    _checkStatus(response, url);
    final data = _decode(response);
    return (data['photo_url'] ?? '').toString();
  }
}
