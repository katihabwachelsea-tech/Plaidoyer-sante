import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/appointment.dart';
import '../config/app_config.dart';
import 'api_logger.dart';

class MedecinApiService {
  static const String baseUrl = AppConfig.baseUrl;
  static const _storage = FlutterSecureStorage();
  static const Duration _timeout = AppConfig.defaultTimeout;

  static final MedecinApiService instance = MedecinApiService._internal();
  MedecinApiService._internal();

  Future<String?> _token() async {
    return _storage.read(key: 'jwt_token');
  }

  Future<Map<String, String>> _headers() async {
    final token = await _token();
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

  /// RDV confirmés uniquement (filtrés côté API — statut == Confirme)
  Future<List<Appointment>> getAppointments({bool todayOnly = false}) async {
    final uri = Uri.parse('$baseUrl/medecin/appointments').replace(
      queryParameters: todayOnly ? {'today': '1'} : null,
    );
    final url = uri.toString();
    final headers = await _headers();
    ApiLogger.request(method: 'GET', url: url, headers: headers);
    final response = await http.get(uri, headers: headers).timeout(_timeout);
    ApiLogger.response(url: url, statusCode: response.statusCode, body: response.body);
    _checkStatus(response);
    final data = _decode(response);
    final list = (data['data'] as List<dynamic>? ?? []);
    return list
        .map((e) => Appointment.fromApiMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<int> getTodayAppointmentsCount() async {
    final url = '$baseUrl/medecin/appointments/today-count';
    final headers = await _headers();
    ApiLogger.request(method: 'GET', url: url, headers: headers);
    final response = await http
        .get(Uri.parse(url), headers: headers)
        .timeout(_timeout);
    ApiLogger.response(url: url, statusCode: response.statusCode, body: response.body);
    _checkStatus(response);
    final data = _decode(response);
    return data['count'] is int
        ? data['count'] as int
        : int.parse('${data['count']}');
  }

  /// POST /api/consultations — termine le RDV automatiquement
  Future<Map<String, dynamic>> createConsultation({
    required int rendezVousId,
    required String diagnostic,
    String? ordonnance,
    String? notes,
    String? anamnese,
    String? examen,
    String? signatureBase64,
  }) async {
    final url = '$baseUrl/consultations';
    final headers = await _headers();
    final body = {
      'rendez_vous_id': rendezVousId,
      'diagnostic': diagnostic,
      'ordonnance': ordonnance,
      'notes': notes,
      if (anamnese != null && anamnese.isNotEmpty) 'anamnese': anamnese,
      if (examen != null && examen.isNotEmpty) 'examen': examen,
      if (signatureBase64 != null && signatureBase64.isNotEmpty)
        'signature': signatureBase64,
    };
    ApiLogger.request(method: 'POST', url: url, headers: headers, body: body);
    final response = await http
        .post(Uri.parse(url), headers: headers, body: jsonEncode(body))
        .timeout(_timeout);
    ApiLogger.response(url: url, statusCode: response.statusCode, body: response.body);
    _checkStatus(response);
    return Map<String, dynamic>.from(_decode(response) as Map);
  }

  Future<MedecinProfile> getProfile() async {
    final url = '$baseUrl/medecin/profile';
    final headers = await _headers();
    ApiLogger.request(method: 'GET', url: url, headers: headers);
    final response = await http
        .get(Uri.parse(url), headers: headers)
        .timeout(_timeout);
    ApiLogger.response(url: url, statusCode: response.statusCode, body: response.body);
    _checkStatus(response);
    final data = _decode(response);
    return MedecinProfile.fromApiMap(
      Map<String, dynamic>.from(data['data'] as Map),
    );
  }

  Future<MedecinProfile> updateProfile(Map<String, dynamic> body) async {
    final url = '$baseUrl/medecin/profile';
    final headers = await _headers();
    ApiLogger.request(method: 'PUT', url: url, headers: headers, body: body);
    final response = await http
        .put(Uri.parse(url), headers: headers, body: jsonEncode(body))
        .timeout(_timeout);
    ApiLogger.response(url: url, statusCode: response.statusCode, body: response.body);
    _checkStatus(response);
    final data = _decode(response);
    return MedecinProfile.fromApiMap(
      Map<String, dynamic>.from(data['data'] as Map),
    );
  }

  Future<List<Creneau>> getCreneaux({String? from, String? to}) async {
    final params = <String, String>{};
    if (from != null) params['from'] = from;
    if (to != null) params['to'] = to;
    final uri = Uri.parse('$baseUrl/medecin/creneaux').replace(
      queryParameters: params.isEmpty ? null : params,
    );
    final url = uri.toString();
    final headers = await _headers();
    ApiLogger.request(method: 'GET', url: url, headers: headers);
    final response = await http.get(uri, headers: headers).timeout(_timeout);
    ApiLogger.response(url: url, statusCode: response.statusCode, body: response.body);
    _checkStatus(response);
    final data = _decode(response);
    final list = data['data'] as List<dynamic>? ?? [];
    return list
        .map((e) => Creneau.fromApiMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<Creneau> createCreneau({
    required String date,
    required String heureDebut,
    required String heureFin,
    bool disponible = true,
  }) async {
    final url = '$baseUrl/medecin/creneaux';
    final headers = await _headers();
    final body = {
      'date': date,
      'heure_debut': heureDebut,
      'heure_fin': heureFin,
      'disponible': disponible,
    };
    ApiLogger.request(method: 'POST', url: url, headers: headers, body: body);
    final response = await http
        .post(Uri.parse(url), headers: headers, body: jsonEncode(body))
        .timeout(_timeout);
    ApiLogger.response(url: url, statusCode: response.statusCode, body: response.body);
    _checkStatus(response);
    final data = _decode(response);
    return Creneau.fromApiMap(
      Map<String, dynamic>.from(data['data'] as Map),
    );
  }

  /// GET /api/medecin/dashboard — indicateurs réels du cabinet
  Future<Map<String, dynamic>> getDashboard() async {
    final url = '$baseUrl/medecin/dashboard';
    final headers = await _headers();
    ApiLogger.request(method: 'GET', url: url, headers: headers);
    final response = await http
        .get(Uri.parse(url), headers: headers)
        .timeout(_timeout);
    ApiLogger.response(url: url, statusCode: response.statusCode, body: response.body);
    _checkStatus(response);
    final data = _decode(response);
    return Map<String, dynamic>.from(data['data'] as Map);
  }

  Future<void> deleteCreneau(int id) async {
    final url = '$baseUrl/medecin/creneaux/$id';
    final headers = await _headers();
    ApiLogger.request(method: 'DELETE', url: url, headers: headers);
    final response = await http
        .delete(Uri.parse(url), headers: headers)
        .timeout(_timeout);
    ApiLogger.response(url: url, statusCode: response.statusCode, body: response.body);
    _checkStatus(response);
  }

  /// POST /api/medecin/appointments/{id}/accept
  Future<void> acceptAppointment(int id) async {
    final url = '$baseUrl/medecin/appointments/$id/accept';
    final headers = await _headers();
    ApiLogger.request(method: 'POST', url: url, headers: headers);
    final response = await http
        .post(Uri.parse(url), headers: headers)
        .timeout(_timeout);
    ApiLogger.response(url: url, statusCode: response.statusCode, body: response.body);
    _checkStatus(response);
  }

  /// POST /api/medecin/appointments/{id}/refuse
  Future<void> refuseAppointment(int id, {String? raison}) async {
    final url = '$baseUrl/medecin/appointments/$id/refuse';
    final headers = await _headers();
    final body = raison != null ? jsonEncode({'raison': raison}) : null;
    ApiLogger.request(method: 'POST', url: url, headers: headers, body: body);
    final response = await http
        .post(Uri.parse(url), headers: headers, body: body)
        .timeout(_timeout);
    ApiLogger.response(url: url, statusCode: response.statusCode, body: response.body);
    _checkStatus(response);
  }

  /// POST /api/medecin/appointments/{id}/cancel
  Future<void> cancelAppointment(int id) async {
    final url = '$baseUrl/medecin/appointments/$id/cancel';
    final headers = await _headers();
    ApiLogger.request(method: 'POST', url: url, headers: headers);
    final response = await http
        .post(Uri.parse(url), headers: headers)
        .timeout(_timeout);
    ApiLogger.response(url: url, statusCode: response.statusCode, body: response.body);
    _checkStatus(response);
  }

  /// POST /api/medecin/profile/photo (multipart)
  Future<String> uploadPhoto(String filePath) async {
    final url = '$baseUrl/medecin/profile/photo';
    final token = await _token();
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
    _checkStatus(response);
    final data = _decode(response);
    return (data['photo_url'] ?? '').toString();
  }
}
