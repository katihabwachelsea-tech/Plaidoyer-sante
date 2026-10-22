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
  final String senderRole;
  final String currentUserNom;
  final bool isMe;
  final bool lu;
  final DateTime createdAt;

  const ChatMessage({
    required this.id,
    required this.contenu,
    required this.senderId,
    required this.senderNom,
    required this.senderRole,
    required this.currentUserNom,
    required this.isMe,
    required this.lu,
    required this.createdAt,
  });

  factory ChatMessage.fromMap(
    Map<String, dynamic> map, {
    required int currentUserId,
    required String currentUserNom,
  }) {
    final senderId = _parseId(map['sender_id'], 'sender_id');
    return ChatMessage(
      id: _parseId(map['id'], 'id'),
      contenu: map['contenu'] as String,
      senderId: senderId,
      senderNom: map['sender_nom'] as String? ?? '',
      senderRole: map['sender_role'] as String? ?? '',
      currentUserNom: currentUserNom,
      isMe: senderId == currentUserId,
      lu: map['lu'] == true,
      createdAt: DateTime.parse(
        (map['created_at'] as String).replaceFirst(' ', 'T'),
      ),
    );
  }

  static int _parseId(dynamic value, String field) {
    final id = value is int ? value : int.tryParse(value?.toString() ?? '');
    if (id == null) {
      throw FormatException('Identifiant $field manquant dans le message.');
    }
    return id;
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
      'Accept': 'application/json',
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
    final body = Map<String, dynamic>.from(jsonDecode(res.body) as Map);
    final currentUser = _currentUser(body);
    final data = body['data'] as List;
    return data
        .map(
          (e) => ChatMessage.fromMap(
            Map<String, dynamic>.from(e as Map),
            currentUserId: currentUser.id,
            currentUserNom: currentUser.nom,
          ),
        )
        .toList();
  }

  /// Envoie un message.
  Future<ChatMessage> sendMessage(int appointmentId, String contenu) async {
    final url = '${AppConfig.baseUrl}/appointments/$appointmentId/messages';
    final headers = await _headers();
    ApiLogger.request(method: 'POST', url: url, body: {'contenu': contenu});

    final res = await http
        .post(
          Uri.parse(url),
          headers: headers,
          body: jsonEncode({'contenu': contenu}),
        )
        .timeout(AppConfig.defaultTimeout);
    ApiLogger.response(url: url, statusCode: res.statusCode, body: res.body);

    if (res.statusCode != 201) {
      final err = jsonDecode(res.body);
      throw Exception(err['message'] ?? 'Erreur envoi message');
    }
    final body = Map<String, dynamic>.from(jsonDecode(res.body) as Map);
    final currentUser = _currentUser(body);
    return ChatMessage.fromMap(
      Map<String, dynamic>.from(body['data'] as Map),
      currentUserId: currentUser.id,
      currentUserNom: currentUser.nom,
    );
  }

  ({int id, String nom}) _currentUser(Map<String, dynamic> body) {
    final user = body['current_user'];
    if (user is! Map) {
      throw const FormatException(
        'Le profil connecté est absent de la réponse de messagerie.',
      );
    }
    final id = user['id'] is int
        ? user['id'] as int
        : int.tryParse(user['id']?.toString() ?? '');
    if (id == null) {
      throw const FormatException(
        'L’identifiant du profil connecté est invalide.',
      );
    }
    return (id: id, nom: user['nom']?.toString() ?? '');
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
