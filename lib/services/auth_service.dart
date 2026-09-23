import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/user.dart';
import '../config/app_config.dart';
import 'api_logger.dart';
import 'push_notification_service.dart';

class AuthService {
  static const String baseUrl = AppConfig.baseUrl;

  // Pour stocker le Token de manière sécurisée
  final _storage = const FlutterSecureStorage();

  User? _currentUser;
  User? get currentUser => _currentUser;

  static final AuthService instance = AuthService._internal();
  factory AuthService() => instance;
  AuthService._internal();

  // CONNEXION - On tape sur ton AuthController@login de Laravel
  Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final url = '$baseUrl/login';
    try {
      ApiLogger.request(method: 'POST', url: url, body: {'email': email});
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'email': email, 'password': password}),
      );

      ApiLogger.response(url: url, statusCode: response.statusCode, body: response.body);
      final data = json.decode(response.body);

      if (response.statusCode == 200 && data['status'] == true) {
        // 1. On récupère le token renvoyé par ton Sanctum
        String token = data['token'];

        // 2. On le stocke dans le téléphone
        await _storage.write(key: 'jwt_token', value: token);
        await _storage.write(
          key: 'user_role',
          value: data['user']['role']?.toString() ?? 'patient',
        );

        // 3. On crée l'objet User à partir du JSON de Laravel
        _currentUser = User.fromMap(data['user']);

        return {
          'success': true,
          'message': data['message'],
          'user': _currentUser,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Identifiants incorrects',
        };
      }
    } catch (e) {
      ApiLogger.error(url: url, error: e);
      return {
        'success': false,
        'message': 'Erreur de connexion au serveur : $e',
      };
    }
  }

  // INSCRIPTION - Appel du backend Laravel
  Future<Map<String, dynamic>> register({
    required String email,
    String? telephone,
    required String password,
    required String fullName,
    required String role,
    String? profileImageUrl,
  }) async {
    final url = '$baseUrl/register';
    try {
      ApiLogger.request(method: 'POST', url: url, body: {'email': email, 'nom': fullName, 'role': role});
      final response = await http.post(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': email,
          'password': password,
          'password_confirmation': password,
          'nom': fullName,
          'telephone': telephone ?? '',
          'role': role,
          if (profileImageUrl != null && profileImageUrl.isNotEmpty) 'profileImageUrl': profileImageUrl,
        }),
      );

      ApiLogger.response(url: url, statusCode: response.statusCode, body: response.body);
      final data = json.decode(response.body);
      final isSuccess = response.statusCode == 200 || response.statusCode == 201;

      // Stocker le token immédiatement après l'inscription
      // pour que l'onboarding (complete-profile) puisse s'authentifier
      if (isSuccess && data['token'] != null) {
        await _storage.write(key: 'jwt_token', value: data['token'] as String);
        await _storage.write(key: 'user_role', value: role);
        if (data['user'] != null) {
          _currentUser = User.fromMap(data['user'] as Map<String, dynamic>);
        }
      }

      return {
        'success': isSuccess,
        'message': data['message'] ?? 'Inscription réussie',
        'data': data,
      };
    } catch (e) {
      ApiLogger.error(url: url, error: e);
      return {
        'success': false,
        'message': 'Erreur lors de l\'inscription : $e',
      };
    }
  }

  // COMPLÉTER LE PROFIL (Onboarding)
  Future<Map<String, dynamic>> completeProfile({
    required String role,
    String? specialite,
    String? licence,
    String? hopital,
    String? biographie,
    String? disponibilite,
    String? dateNaissance,
    String? groupeSanguin,
    String? maladie,
    String? antecedents,
  }) async {
    try {
      final token = await _storage.read(key: 'jwt_token');
      if (token == null) {
        return {
          'success': false,
          'message': 'Token non trouvé. Veuillez vous reconnecter.',
        };
      }

      final endpoint = role == 'medecin'
          ? '$baseUrl/medecin/complete-profile'
          : '$baseUrl/patient/complete-profile';

      final body = role == 'medecin'
          ? {
              'specialite': specialite,
              'licence': licence,
              'hopital': hopital,
              'biographie': biographie,
              'disponibilite': disponibilite,
            }
          : {
              'date_naissance': dateNaissance,
              'groupe_sanguin': groupeSanguin,
              'maladie': maladie,
              'antecedents': antecedents,
            };

      ApiLogger.request(method: 'POST', url: endpoint, body: body);
      final response = await http.post(
        Uri.parse(endpoint),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode(body),
      );

      ApiLogger.response(url: endpoint, statusCode: response.statusCode, body: response.body);
      final data = json.decode(response.body);

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {
          'success': true,
          'message': data['message'] ?? 'Profil complété avec succès',
          'data': data,
        };
      } else {
        return {
          'success': false,
          'message': data['message'] ?? 'Erreur lors de la complétion du profil',
        };
      }
    } catch (e) {
      ApiLogger.error(url: '$baseUrl/complete-profile', error: e);
      return {
        'success': false,
        'message': 'Erreur : $e',
      };
    }
  }

  // CHERCHER LES MÉDECINS
  Future<Map<String, dynamic>> fetchDoctors({
    String? specialite,
    String? searchQuery,
  }) async {
    try {
      final token = await _storage.read(key: 'jwt_token');

      final queryParameters = <String, String>{};

      if (specialite != null && specialite.isNotEmpty) {
        queryParameters['specialite'] = specialite;
      }
      if (searchQuery != null && searchQuery.isNotEmpty) {
        queryParameters['search'] = searchQuery;
      }

      final uri = Uri.parse('$baseUrl/patient/doctors');
      final uriWithParams = queryParameters.isNotEmpty
          ? uri.replace(queryParameters: queryParameters)
          : uri;

      final headers = {
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      };

      if (token != null) {
        headers['Authorization'] = 'Bearer $token';
      }

      final response = await http.get(
        uriWithParams,
        headers: headers,
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'doctors': data['data'] ?? data['medecins'] ?? [],
          'message': 'Médecins récupérés avec succès',
        };
      } else {
        return {
          'success': false,
          'doctors': [],
          'message': data['message'] ?? 'Erreur lors de la récupération des médecins',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'doctors': [],
        'message': 'Erreur: $e',
      };
    }
  }

  // RÉCUPÉRER TOUTES LES SPÉCIALITÉS
  Future<Map<String, dynamic>> fetchSpecialties() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/specialites'),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      );

      final data = json.decode(response.body);

      if (response.statusCode == 200) {
        return {
          'success': true,
          'specialties': data['data'] ?? data['specialites'] ?? [],
          'message': 'Spécialités récupérées',
        };
      } else {
        return {
          'success': false,
          'specialties': [],
          'message': data['message'] ?? 'Erreur',
        };
      }
    } catch (e) {
      return {
        'success': false,
        'specialties': [],
        'message': 'Erreur: $e',
      };
    }
  }

  // DÉCONNEXION
  Future<void> logout() async {
    // Retirer le token FCM avant de supprimer le JWT
    try {
      await PushNotificationService.instance.removeToken();
    } catch (_) {}
    await _storage.delete(key: 'jwt_token');
    await _storage.delete(key: 'user_role');
    _currentUser = null;
  }

  /// Met à jour la photo de profil en mémoire (après upload API).
  void updateProfileImageUrl(String? url) {
    if (_currentUser == null) return;
    _currentUser = _currentUser!.copyWith(profileImageUrl: url);
  }

  Future<String?> getStoredRole() => _storage.read(key: 'user_role');

  // Vérifie si l'utilisateur est connecté en recherchant un token sécurisé
  Future<bool> isLoggedIn() async {
    if (_currentUser != null) {
      return true;
    }

    final token = await _storage.read(key: 'jwt_token');
    return token != null && token.isNotEmpty;
  }
}