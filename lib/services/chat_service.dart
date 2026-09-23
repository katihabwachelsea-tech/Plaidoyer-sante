// lib/services/chat_service.dart

import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../services/api_logger.dart';

class ChatMessage {
  final int id;
  final String contenu;
  final int senderId;
  final String senderNom;
  final bool isMe;
  final bool lu;
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.contenu,
    required this.senderId,
    required this.senderNom,
    required this.isMe,
    required this.lu,
    required this.createdAt,
  });

  factory ChatMessage.fromMap(Map<String, dynamic> map) {
    return ChatMessage(
      id:        map['id'] as int,
      contenu:   map['contenu'] as String,
      senderId:  map['sender_id'] as int,
      senderNom: map['sender_nom'] as String? ?? '',
      isMe:      map['is_mine'] == true,
      lu:        map['lu'] == true,
      createdAt: DateTime.parse(
          (map['created_at'] as String).replaceFirst(' ', 'T')),
    );
  }
}

class ChatService {
  ChatService._();
  static final instance = ChatService._();

  static const _storage = FlutterSecureStorage();

  Future<Map<String, String>> _headers() async {
    final token = await _storage.read(key: AppConfig.keyJwtToken);
    return {
      'Content-Type': 'application/json',
      'Accept':       'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
    };
  }

  /// Charge tous les messages d'un RDV (marque les reçus comme lus).
  Future<List<ChatMessage>> getMessages(int appointmentId) async {
    final url = '${AppConfig.baseUrl}/appointments/$appointmentId/messages';
    final headers = await _headers();
    ApiLogger.request(method: 'GET', url: url);

    final res = await http
        .get(Uri.parse(url), headers: headers)
        .timeout(AppConfig.defaultTimeout);
    ApiLogger.response(url: url, statusCode: res.statusCode, body: res.body);

    if (res.statusCode != 200) throw Exception('Erreur ${res.statusCode}');
    final data = jsonDecode(res.body);
    return (data['data'] as List)
        .map((e) => ChatMessage.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Envoie un message.
  Future<ChatMessage> sendMessage(int appointmentId, String contenu) async {
    final url = '${AppConfig.baseUrl}/appointments/$appointmentId/messages';
    final headers = await _headers();
    ApiLogger.request(method: 'POST', url: url, body: {'contenu': contenu});

    final res = await http
        .post(Uri.parse(url), headers: headers,
            body: jsonEncode({'contenu': contenu}))
        .timeout(AppConfig.defaultTimeout);
    ApiLogger.response(url: url, statusCode: res.statusCode, body: res.body);

    if (res.statusCode != 201) {
      final err = jsonDecode(res.body);
      throw Exception(err['message'] ?? 'Erreur envoi message');
    }
    final data = jsonDecode(res.body);
    return ChatMessage.fromMap(
        Map<String, dynamic>.from(data['data'] as Map));
  }

  /// Nombre de messages non lus pour ce RDV.
  Future<int> unreadCount(int appointmentId) async {
    final url =
        '${AppConfig.baseUrl}/appointments/$appointmentId/messages/unread-count';
    final headers = await _headers();
    final res = await http
        .get(Uri.parse(url), headers: headers)
        .timeout(AppConfig.shortTimeout);
    if (res.statusCode != 200) return 0;
    final data = jsonDecode(res.body);
    return (data['count'] as int?) ?? 0;
  }
}
