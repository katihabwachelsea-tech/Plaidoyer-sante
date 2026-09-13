import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/app_config.dart';

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

  void _checkStatus(http.Response response) {
    if (response.statusCode >= 200 && response.statusCode < 300) return;
    final body = _decode(response);
    final msg = body is Map ? (body['message'] ?? body.toString()) : response.body;
    throw Exception('Erreur ${response.statusCode}: $msg');
  }

  Future<List<Map<String, dynamic>>> getAppointments() async {
    final response = await http
        .get(Uri.parse('$baseUrl/patient/appointments'), headers: await _headers())
        .timeout(_timeout);
    _checkStatus(response);
    final data = _decode(response);
    return (data['data'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<void> cancelAppointment(int id) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/patient/appointments/$id/cancel'),
          headers: await _headers(),
        )
        .timeout(_timeout);
    _checkStatus(response);
  }

  Future<Map<String, dynamic>> payAppointment({
    required int id,
    required String methode,
    required String telephone,
  }) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/patient/appointments/$id/pay'),
          headers: await _headers(),
          body: jsonEncode({
            'methode_paiement': methode,
            'telephone': telephone,
          }),
        )
        .timeout(_timeout);
    _checkStatus(response);
    return Map<String, dynamic>.from(_decode(response) as Map);
  }

  Future<Map<String, dynamic>> getProfile() async {
    final response = await http
        .get(Uri.parse('$baseUrl/patient/profile'), headers: await _headers())
        .timeout(_timeout);
    _checkStatus(response);
    final data = _decode(response);
    return Map<String, dynamic>.from(data['data'] as Map);
  }

  Future<Map<String, dynamic>> updateProfile(Map<String, dynamic> body) async {
    final response = await http
        .put(
          Uri.parse('$baseUrl/patient/profile'),
          headers: await _headers(),
          body: jsonEncode(body),
        )
        .timeout(_timeout);
    _checkStatus(response);
    final data = _decode(response);
    return Map<String, dynamic>.from(data['data'] as Map);
  }

  Future<List<Map<String, dynamic>>> getMedicalRecord() async {
    final response = await http
        .get(Uri.parse('$baseUrl/patient/medical-record'), headers: await _headers())
        .timeout(_timeout);
    _checkStatus(response);
    final data = _decode(response);
    return (data['data'] as List<dynamic>? ?? [])
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }
}
