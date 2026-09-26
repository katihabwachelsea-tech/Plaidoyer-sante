// lib/widgets/notification_bell.dart
//
// Icône cloche avec badge de notifications non lues.
// À placer dans l'AppBar ou le header de n'importe quel écran.

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';
import '../config/app_config.dart';
import '../pages/notifications_page.dart';
import '../services/api_logger.dart';
import 'metric_card.dart';

class NotificationBell extends StatefulWidget {
  final Color? color;
  const NotificationBell({super.key, this.color});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  int _unread = 0;
  static const _storage = FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _loadCount();
  }

  Future<void> _loadCount() async {
    try {
      final token = await _storage.read(key: AppConfig.keyJwtToken);
      if (token == null) return;
      final url = '${AppConfig.baseUrl}/notifications/unread-count';
      final headers = {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };
      ApiLogger.request(method: 'GET', url: url, headers: headers);
      final res = await http.get(
        Uri.parse(url),
        headers: headers,
      ).timeout(AppConfig.shortTimeout);
      ApiLogger.response(url: url, statusCode: res.statusCode, body: res.body);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        if (mounted) setState(() => _unread = (data['count'] as int?) ?? 0);
      }
    } catch (e, st) {
      ApiLogger.error(url: '${AppConfig.baseUrl}/notifications/unread-count', error: e, stackTrace: st);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        IconButton(
          icon: Icon(
            _unread > 0
                ? Icons.notifications_rounded
                : Icons.notifications_none_rounded,
            color: widget.color ?? Colors.white,
          ),
          tooltip: 'Notifications',
          onPressed: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                  builder: (_) => const NotificationsPage()),
            );
            _loadCount(); // Rafraîchir après retour
          },
        ),
        if (_unread > 0)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(
                color: AppColors.error,
                shape: BoxShape.circle,
              ),
              constraints:
                  const BoxConstraints(minWidth: 16, minHeight: 16),
              child: Text(
                _unread > 99 ? '99+' : '$_unread',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ),
      ],
    );
  }
}
