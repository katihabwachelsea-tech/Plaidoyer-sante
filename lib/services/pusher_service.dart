// lib/services/pusher_service.dart
//
// Connexion WebSocket Pusher pour la messagerie temps réel.
// Remplace le polling toutes les 5s dans ChatPage.
//
// Usage :
//   final pusher = PusherService.instance;
//   await pusher.subscribeToAppointment(
//     appointmentId: 42,
//     onMessage: (data) { ... },
//   );
//   await pusher.unsubscribe(42);

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';

class PusherService {
  PusherService._();
  static final PusherService instance = PusherService._();

  static const _apiKey  = '668f90ab03ddcb1b105a';
  static const _cluster = 'us2';

  final _pusher = PusherChannelsFlutter.getInstance();
  bool _initialized = false;

  // Canal actif : appointmentId → channelName
  final Map<int, String> _subscribed = {};

  // ── Initialisation ────────────────────────────────────────────────────────

  Future<void> _ensureInit() async {
    if (_initialized) return;
    await _pusher.init(
      apiKey:  _apiKey,
      cluster: _cluster,
      onError: (message, code, error) {
        debugPrint('Pusher error [$code]: $message — $error');
      },
      onConnectionStateChange: (current, previous) {
        debugPrint('Pusher state: $previous → $current');
      },
    );
    await _pusher.connect();
    _initialized = true;
  }

  // ── Abonnement ────────────────────────────────────────────────────────────

  /// S'abonne au canal du RDV et appelle [onMessage] à chaque nouveau message.
  Future<void> subscribeToAppointment({
    required int appointmentId,
    required void Function(Map<String, dynamic> messageData) onMessage,
  }) async {
    await _ensureInit();

    final channelName = 'appointment.$appointmentId';

    // Éviter le double abonnement
    if (_subscribed.containsKey(appointmentId)) return;

    await _pusher.subscribe(
      channelName: channelName,
      onEvent: (event) {
        if (event.eventName == 'MessageSent') {
          try {
            final raw = event.data;
            final decoded = raw is String ? jsonDecode(raw) : raw;
            if (decoded is Map<String, dynamic>) {
              onMessage(decoded);
            }
          } catch (e) {
            debugPrint('Pusher parse error: $e');
          }
        }
      },
    );

    _subscribed[appointmentId] = channelName;
    debugPrint('Pusher: abonné au canal $channelName');
  }

  // ── Désabonnement ─────────────────────────────────────────────────────────

  Future<void> unsubscribe(int appointmentId) async {
    final channelName = _subscribed.remove(appointmentId);
    if (channelName == null) return;
    try {
      await _pusher.unsubscribe(channelName: channelName);
      debugPrint('Pusher: désabonné de $channelName');
    } catch (e) {
      debugPrint('Pusher unsubscribe error: $e');
    }
  }

  // ── Déconnexion complète ──────────────────────────────────────────────────

  Future<void> disconnect() async {
    if (!_initialized) return;
    try {
      await _pusher.disconnect();
      _initialized = false;
      _subscribed.clear();
    } catch (e) {
      debugPrint('Pusher disconnect error: $e');
    }
  }
}
