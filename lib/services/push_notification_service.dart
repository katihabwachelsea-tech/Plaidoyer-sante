// lib/services/push_notification_service.dart
//
// Gère Firebase Cloud Messaging (FCM) :
//   - Demande la permission
//   - Récupère et envoie le token FCM au backend
//   - Affiche les notifications locales quand l'app est au premier plan
//   - Gère le tap sur notification (navigation)

import 'dart:convert';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';

// Handler background — doit être une fonction top-level
@pragma('vm:entry-point')
Future<void> _firebaseBackgroundHandler(RemoteMessage message) async {
  debugPrint('📩 FCM background: ${message.notification?.title}');
}

class PushNotificationService {
  PushNotificationService._();
  static final instance = PushNotificationService._();

  final _messaging  = FirebaseMessaging.instance;
  final _storage    = const FlutterSecureStorage();
  final _localNotif = FlutterLocalNotificationsPlugin();

  static const _channelId   = 'mob_clinic_channel';
  static const _channelName = 'Mob-Clinic Notifications';

  /// Initialise FCM — silencieux si Firebase non configuré.
  Future<void> init() async {
    try {
      await _initInternal();
    } catch (e) {
      debugPrint('FCM: désactivé ($e)');
    }
  }

  Future<void> _initInternal() async {
    // 1. Handler background
    FirebaseMessaging.onBackgroundMessage(_firebaseBackgroundHandler);

    // 2. Initialiser les notifications locales (Android)
    await _localNotif.initialize(
      const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: DarwinInitializationSettings(),
      ),
    );

    // 3. Créer le canal Android haute priorité
    await _localNotif
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(
          const AndroidNotificationChannel(
            _channelId,
            _channelName,
            importance: Importance.high,
            playSound: true,
          ),
        );

    // 4. Demander la permission
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    debugPrint('FCM permission: ${settings.authorizationStatus}');

    // 5. Récupérer et envoyer le token au backend
    await _registerToken();

    // 6. Rafraîchissement du token
    _messaging.onTokenRefresh.listen((token) => _sendTokenToServer(token));

    // 7. Foreground — afficher une notification locale
    FirebaseMessaging.onMessage.listen(_handleForeground);

    // 8. App ouverte depuis une notification (background/terminated)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleTap);

    // 9. Notification qui a ouvert l'app depuis terminated
    final initial = await _messaging.getInitialMessage();
    if (initial != null) _handleTap(initial);
  }

  // ── Enregistrement du token ────────────────────────────────────────

  Future<void> _registerToken() async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await _sendTokenToServer(token);
        debugPrint('FCM token: ${token.substring(0, 20)}...');
      }
    } catch (e) {
      debugPrint('FCM: impossible de récupérer le token: $e');
    }
  }

  Future<void> _sendTokenToServer(String token) async {
    final jwt = await _storage.read(key: AppConfig.keyJwtToken);
    if (jwt == null) return;
    try {
      await http.post(
        Uri.parse('${AppConfig.baseUrl}/device-token'),
        headers: {
          'Content-Type':  'application/json',
          'Accept':        'application/json',
          'Authorization': 'Bearer $jwt',
        },
        body: jsonEncode({'token': token, 'platform': 'android'}),
      ).timeout(AppConfig.shortTimeout);
    } catch (e) {
      debugPrint('FCM: erreur envoi token: $e');
    }
  }

  /// Appelé à la déconnexion pour retirer le token du backend.
  Future<void> removeToken() async {
    final jwt   = await _storage.read(key: AppConfig.keyJwtToken);
    final token = await _messaging.getToken();
    if (jwt == null || token == null) return;
    try {
      await http.delete(
        Uri.parse('${AppConfig.baseUrl}/device-token'),
        headers: {
          'Content-Type':  'application/json',
          'Accept':        'application/json',
          'Authorization': 'Bearer $jwt',
        },
        body: jsonEncode({'token': token}),
      ).timeout(AppConfig.shortTimeout);
    } catch (_) {}
  }

  // ── Foreground — afficher notification locale ──────────────────────

  void _handleForeground(RemoteMessage message) {
    final notif = message.notification;
    if (notif == null) return;

    _localNotif.show(
      message.hashCode,
      notif.title,
      notif.body,
      NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          importance:  Importance.high,
          priority:    Priority.high,
          icon:        '@mipmap/ic_launcher',
          styleInformation: BigTextStyleInformation(notif.body ?? ''),
        ),
        iOS: const DarwinNotificationDetails(),
      ),
      payload: jsonEncode(message.data),
    );
  }

  // ── Tap sur notification → navigation ─────────────────────────────

  void _handleTap(RemoteMessage message) {
    final type = message.data['type'] as String?;
    debugPrint('FCM tap: type=$type data=${message.data}');
    // La navigation est gérée par le NotificationNavigator (voir main.dart)
    // On stocke juste les données pour les lire au premier build
    _pendingNavigation = message.data;
  }

  Map<String, dynamic>? _pendingNavigation;

  /// Consomme la navigation en attente (appelé une fois après init).
  Map<String, dynamic>? consumePendingNavigation() {
    final data = _pendingNavigation;
    _pendingNavigation = null;
    return data;
  }
}
