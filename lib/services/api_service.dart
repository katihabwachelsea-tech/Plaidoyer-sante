// lib/services/api_service.dart

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/patient.dart';
import '../config/app_config.dart';
import 'api_logger.dart';

class ApiService {
  static const String baseUrl = AppConfig.baseUrl;
  static const _storage = FlutterSecureStorage();
  static const Duration timeout = AppConfig.defaultTimeout;

  // Headers par défaut
  static Map<String, String> get _defaultHeaders => {
    'Content-Type': 'application/json',
    'Accept': 'application/json',
  };

  // Token d'authentification (sera défini après login)
  static String? _authToken;
  static String? get authToken => _authToken;
  static set authToken(String? token) => _authToken = token;

  // Headers avec authentification
  static Map<String, String> get _authHeaders => {
    ..._defaultHeaders,
    if (_authToken != null) 'Authorization': 'Bearer $_authToken',
  };

  // Vérifier la connexion internet
  static Future<bool> _hasInternetConnection() async {
    final results = await Connectivity().checkConnectivity();
    return results.isNotEmpty &&
        !results.every((r) => r == ConnectivityResult.none);
  }

  // Méthode générique pour les requêtes GET
  static Future<Map<String, dynamic>> get(String endpoint) async {
    if (!await _hasInternetConnection()) {
      throw Exception('Pas de connexion internet');
    }
    final url = '$baseUrl$endpoint';
    try {
      ApiLogger.request(method: 'GET', url: url, headers: _authHeaders);
      final response = await http
          .get(Uri.parse(url), headers: _authHeaders)
          .timeout(timeout);
      ApiLogger.response(url: url, statusCode: response.statusCode, body: response.body);
      return _handleResponse(response);
    } catch (e) {
      ApiLogger.error(url: url, error: e);
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Méthode générique pour les requêtes POST
  static Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    if (!await _hasInternetConnection()) {
      throw Exception('Pas de connexion internet');
    }
    final url = '$baseUrl$endpoint';
    try {
      ApiLogger.request(method: 'POST', url: url, headers: _authHeaders, body: data);
      final response = await http
          .post(Uri.parse(url), headers: _authHeaders, body: jsonEncode(data))
          .timeout(timeout);
      ApiLogger.response(url: url, statusCode: response.statusCode, body: response.body);
      return _handleResponse(response);
    } catch (e) {
      ApiLogger.error(url: url, error: e);
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Méthode générique pour les requêtes PUT
  static Future<Map<String, dynamic>> put(
    String endpoint,
    Map<String, dynamic> data,
  ) async {
    if (!await _hasInternetConnection()) {
      throw Exception('Pas de connexion internet');
    }
    final url = '$baseUrl$endpoint';
    try {
      ApiLogger.request(method: 'PUT', url: url, headers: _authHeaders, body: data);
      final response = await http
          .put(Uri.parse(url), headers: _authHeaders, body: jsonEncode(data))
          .timeout(timeout);
      ApiLogger.response(url: url, statusCode: response.statusCode, body: response.body);
      return _handleResponse(response);
    } catch (e) {
      ApiLogger.error(url: url, error: e);
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Méthode générique pour les requêtes DELETE
  static Future<Map<String, dynamic>> delete(String endpoint) async {
    if (!await _hasInternetConnection()) {
      throw Exception('Pas de connexion internet');
    }
    final url = '$baseUrl$endpoint';
    try {
      ApiLogger.request(method: 'DELETE', url: url, headers: _authHeaders);
      final response = await http
          .delete(Uri.parse(url), headers: _authHeaders)
          .timeout(timeout);
      ApiLogger.response(url: url, statusCode: response.statusCode, body: response.body);
      return _handleResponse(response);
    } catch (e) {
      ApiLogger.error(url: url, error: e);
      throw Exception('Erreur de connexion: $e');
    }
  }

  // Gestion des réponses HTTP
  static Map<String, dynamic> _handleResponse(http.Response response) {
    final statusCode = response.statusCode;
    final body = response.body;

    if (statusCode >= 200 && statusCode < 300) {
      // Succès
      if (body.isEmpty) {
        return {'success': true};
      }

      try {
        return jsonDecode(body);
      } catch (e) {
        throw Exception('Erreur de parsing JSON: $e');
      }
    } else if (statusCode == 401) {
      // Token expiré ou invalide
      _authToken = null; // Réinitialiser le token
      throw Exception('Session expirée. Veuillez vous reconnecter.');
    } else if (statusCode == 422) {
      // Erreurs de validation
      try {
        final errorData = jsonDecode(body);
        final errors = errorData['errors'] ?? errorData['message'] ?? 'Erreur de validation';
        throw Exception('Erreurs de validation: $errors');
      } catch (e) {
        throw Exception('Erreur de validation du serveur');
      }
    } else {
      // Autres erreurs
      try {
        final errorData = jsonDecode(body);
        final message = errorData['message'] ?? 'Erreur inconnue';
        throw Exception('Erreur $statusCode: $message');
      } catch (e) {
        throw Exception('Erreur $statusCode: $body');
      }
    }
  }

  // Méthode pour uploader des fichiers (si nécessaire)
  static Future<Map<String, dynamic>> uploadFile(
    String endpoint,
    String fieldName,
    String filePath,
  ) async {
    if (!await _hasInternetConnection()) {
      throw Exception('Pas de connexion internet');
    }

    try {
      var request = http.MultipartRequest(
        'POST',
        Uri.parse('$baseUrl$endpoint'),
      );

      request.headers.addAll(_authHeaders);
      request.files.add(await http.MultipartFile.fromPath(fieldName, filePath));

      final streamedResponse = await request.send().timeout(timeout);
      final response = await http.Response.fromStream(streamedResponse);

      return _handleResponse(response);
    } catch (e) {
      throw Exception('Erreur d\'upload: $e');
    }
  }

  // Nettoyer le token (logout)
  static void clearAuthToken() {
    _authToken = null;
  }

  static Future<void> loadTokenFromStorage() async {
    if (_authToken != null) return;
    final token = await _storage.read(key: 'jwt_token');
    if (token != null && token.isNotEmpty) {
      _authToken = token;
    }
  }

  // ========== PATIENTS MÉDECIN (MySQL) ==========

  static Future<List<Patient>> fetchPatients() async {
    await loadTokenFromStorage();
    final response = await get('/medecin/patients');
    final list = response['data'] as List<dynamic>? ?? [];
    return list
        .map((e) => Patient.fromApiMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  static Future<Patient> createPatient(Patient patient) async {
    await loadTokenFromStorage();
    final response = await post('/medecin/patients', patient.toApiMap());
    final data = response['data'] as Map<String, dynamic>;
    return Patient.fromApiMap(data);
  }

  static Future<Patient> updatePatient(
    int serverId,
    Map<String, dynamic> data,
  ) async {
    await loadTokenFromStorage();
    final response = await put('/medecin/patients/$serverId', data);
    final result = response['data'] as Map<String, dynamic>;
    return Patient.fromApiMap(result);
  }

  static Future<void> deletePatient(int serverId) async {
    await loadTokenFromStorage();
    await delete('/medecin/patients/$serverId');
  }
}