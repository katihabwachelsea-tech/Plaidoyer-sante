import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/app_config.dart';
import 'api_logger.dart';

class NotificationApiService {
  static final NotificationApiService instance = NotificationApiService._();
  NotificationApiService._();

  static const _storage = FlutterSecureStorage();
  static const _timeout = AppConfig.defaultTimeout;

  Future<Map<String, String>> _headers() async {
    final token = await _storage.read(key: 'jwt_token');
    return {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  Future<Map<String, dynamic>> list() async {
    final url = '${AppConfig.baseUrl}/notifications';
    final headers = await _headers();
    ApiLogger.request(method: 'GET', url: url, headers: headers);
    final response =
        await http.get(Uri.parse(url), headers: headers).timeout(_timeout);
    ApiLogger.response(
        url: url, statusCode: response.statusCode, body: response.body);
    if (response.statusCode >= 300) {
      throw Exception('Erreur ${response.statusCode}');
    }
    return Map<String, dynamic>.from(jsonDecode(response.body) as Map);
  }

  Future<int> unreadCount() async {
    final url = '${AppConfig.baseUrl}/notifications/unread-count';
    final headers = await _headers();
    ApiLogger.request(method: 'GET', url: url, headers: headers);
    final response =
        await http.get(Uri.parse(url), headers: headers).timeout(_timeout);
    ApiLogger.response(url: url, statusCode: response.statusCode, body: response.body);
    if (response.statusCode >= 300) return 0;
    final data = jsonDecode(response.body);
    return data['count'] is int
        ? data['count'] as int
        : int.tryParse('${data['count']}') ?? 0;
  }

  Future<void> markRead(int id) async {
    final url = '${AppConfig.baseUrl}/notifications/$id/read';
    final headers = await _headers();
    ApiLogger.request(method: 'POST', url: url, headers: headers);
    final response = await http.post(Uri.parse(url), headers: headers).timeout(_timeout);
    ApiLogger.response(url: url, statusCode: response.statusCode, body: response.body);
  }

  Future<void> markAllRead() async {
    final url = '${AppConfig.baseUrl}/notifications/read-all';
    final headers = await _headers();
    ApiLogger.request(method: 'POST', url: url, headers: headers);
    final response = await http.post(Uri.parse(url), headers: headers).timeout(_timeout);
    ApiLogger.response(url: url, statusCode: response.statusCode, body: response.body);
  }
}
