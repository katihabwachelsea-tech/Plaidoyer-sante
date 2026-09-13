import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/appointment.dart';
import '../config/app_config.dart';
import 'mock_medecin_data.dart';

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
    if (MockMedecinDataService.isEnabled) {
      return MockMedecinDataService.instance.getAppointmentsDemo();
    }

    final uri = Uri.parse('$baseUrl/medecin/appointments').replace(
      queryParameters: todayOnly ? {'today': '1'} : null,
    );
    final response = await http
        .get(uri, headers: await _headers())
        .timeout(_timeout);
    _checkStatus(response);
    final data = _decode(response);
    final list = (data['data'] as List<dynamic>? ?? []);
    return list
        .map((e) => Appointment.fromApiMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<int> getTodayAppointmentsCount() async {
    if (MockMedecinDataService.isEnabled) {
      return MockMedecinDataService.instance.getTodayAppointmentsCountDemo();
    }

    final response = await http
        .get(
          Uri.parse('$baseUrl/medecin/appointments/today-count'),
          headers: await _headers(),
        )
        .timeout(_timeout);
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
  }) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/consultations'),
          headers: await _headers(),
          body: jsonEncode({
            'rendez_vous_id': rendezVousId,
            'diagnostic': diagnostic,
            'ordonnance': ordonnance,
            'notes': notes,
          }),
        )
        .timeout(_timeout);
    _checkStatus(response);
    return Map<String, dynamic>.from(_decode(response) as Map);
  }

  Future<MedecinProfile> getProfile() async {
    if (MockMedecinDataService.isEnabled) {
      return MockMedecinDataService.instance.getProfileDemo();
    }

    final response = await http
        .get(Uri.parse('$baseUrl/medecin/profile'), headers: await _headers())
        .timeout(_timeout);
    _checkStatus(response);
    final data = _decode(response);
    return MedecinProfile.fromApiMap(
      Map<String, dynamic>.from(data['data'] as Map),
    );
  }

  Future<MedecinProfile> updateProfile(Map<String, dynamic> body) async {
    final response = await http
        .put(
          Uri.parse('$baseUrl/medecin/profile'),
          headers: await _headers(),
          body: jsonEncode(body),
        )
        .timeout(_timeout);
    _checkStatus(response);
    final data = _decode(response);
    return MedecinProfile.fromApiMap(
      Map<String, dynamic>.from(data['data'] as Map),
    );
  }

  Future<List<Creneau>> getCreneaux({String? from, String? to}) async {
    if (MockMedecinDataService.isEnabled) {
      return MockMedecinDataService.instance.getCreneauxDemo(from: from, to: to);
    }

    final params = <String, String>{};
    if (from != null) params['from'] = from;
    if (to != null) params['to'] = to;
    final uri = Uri.parse('$baseUrl/medecin/creneaux').replace(
      queryParameters: params.isEmpty ? null : params,
    );
    final response = await http.get(uri, headers: await _headers()).timeout(_timeout);
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
    final response = await http
        .post(
          Uri.parse('$baseUrl/medecin/creneaux'),
          headers: await _headers(),
          body: jsonEncode({
            'date': date,
            'heure_debut': heureDebut,
            'heure_fin': heureFin,
            'disponible': disponible,
          }),
        )
        .timeout(_timeout);
    _checkStatus(response);
    final data = _decode(response);
    return Creneau.fromApiMap(
      Map<String, dynamic>.from(data['data'] as Map),
    );
  }

  /// GET /api/medecin/dashboard — indicateurs réels du cabinet
  Future<Map<String, dynamic>> getDashboard() async {
    final response = await http
        .get(Uri.parse('$baseUrl/medecin/dashboard'), headers: await _headers())
        .timeout(_timeout);
    _checkStatus(response);
    final data = _decode(response);
    return Map<String, dynamic>.from(data['data'] as Map);
  }

  Future<void> deleteCreneau(int id) async {
    final response = await http
        .delete(
          Uri.parse('$baseUrl/medecin/creneaux/$id'),
          headers: await _headers(),
        )
        .timeout(_timeout);
    _checkStatus(response);
  }

  /// POST /api/medecin/appointments/{id}/cancel
  Future<void> cancelAppointment(int id) async {
    final response = await http
        .post(
          Uri.parse('$baseUrl/medecin/appointments/$id/cancel'),
          headers: await _headers(),
        )
        .timeout(_timeout);
    _checkStatus(response);
  }
}
