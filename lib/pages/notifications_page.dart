// lib/pages/notifications_page.dart

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import '../config/app_config.dart';
import '../services/api_logger.dart';
import '../widgets/metric_card.dart';

class NotificationsPage extends StatefulWidget {
  const NotificationsPage({super.key});

  @override
  State<NotificationsPage> createState() => _NotificationsPageState();
}

class _NotificationsPageState extends State<NotificationsPage> {
  static const _storage = FlutterSecureStorage();
  List<Map<String, dynamic>> _notifications = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<String?> _token() => _storage.read(key: AppConfig.keyJwtToken);

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final token = await _token();
      final url = '${AppConfig.baseUrl}/notifications';
      final headers = {
        'Accept': 'application/json',
        'Authorization': 'Bearer $token',
      };
      ApiLogger.request(method: 'GET', url: url, headers: headers);
      final res = await http.get(
        Uri.parse(url),
        headers: headers,
      ).timeout(AppConfig.defaultTimeout);
      ApiLogger.response(url: url, statusCode: res.statusCode, body: res.body);
      final data = jsonDecode(res.body);
      if (res.statusCode == 200) {
        if (mounted) {
          setState(() {
            _notifications = (data['data'] as List)
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
          });
        }
      } else {
        _error = data['message'] ?? 'Erreur';
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _markAllRead() async {
    final token = await _token();
    final url = '${AppConfig.baseUrl}/notifications/read-all';
    final headers = {
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
    ApiLogger.request(method: 'POST', url: url, headers: headers);
    final res = await http.post(
      Uri.parse(url),
      headers: headers,
    ).timeout(AppConfig.shortTimeout);
    ApiLogger.response(url: url, statusCode: res.statusCode, body: res.body);
    await _load();
  }

  Future<void> _markRead(int id) async {
    final token = await _token();
    final url = '${AppConfig.baseUrl}/notifications/$id/read';
    final headers = {
      'Accept': 'application/json',
      'Authorization': 'Bearer $token',
    };
    ApiLogger.request(method: 'POST', url: url, headers: headers);
    final res = await http.post(
      Uri.parse(url),
      headers: headers,
    ).timeout(AppConfig.shortTimeout);
    ApiLogger.response(url: url, statusCode: res.statusCode, body: res.body);
  }

  @override
  Widget build(BuildContext context) {
    final unread = _notifications.where((n) => n['read_at'] == null).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Notifications'),
            if (unread > 0)
              Text('$unread non lue${unread > 1 ? 's' : ''}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w400)),
          ],
        ),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          if (unread > 0)
            TextButton(
              onPressed: _markAllRead,
              child: const Text('Tout lire',
                  style: TextStyle(color: Colors.white, fontSize: 12)),
            ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        color: AppColors.primary,
        child: _body(),
      ),
    );
  }

  Widget _body() {
    if (_loading) {
      return const Center(
          child: CircularProgressIndicator(color: AppColors.primary));
    }
    if (_error != null) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        children: [
          Text(_error!, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          ElevatedButton(onPressed: _load, child: const Text('Réessayer')),
        ],
      );
    }
    if (_notifications.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 80),
          Center(
            child: Column(
              children: [
                Icon(Icons.notifications_off_outlined,
                    size: 64, color: AppColors.textLight),
                SizedBox(height: 12),
                Text('Aucune notification',
                    style: TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      );
    }

    final fmt = DateFormat('d MMM · HH:mm', 'fr_FR');

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _notifications.length,
      separatorBuilder: (_, __) =>
          const Divider(height: 1, indent: 72),
      itemBuilder: (context, index) {
        final notif = _notifications[index];
        final isUnread = notif['read_at'] == null;
        final type = (notif['type'] ?? '').toString();
        final rawDate = (notif['created_at'] ?? '').toString();
        var dateLabel = '';
        try {
          dateLabel = fmt.format(
              DateTime.parse(rawDate.replaceFirst(' ', 'T')).toLocal());
        } catch (_) {}

        return InkWell(
          onTap: () async {
            if (isUnread) {
              await _markRead(notif['id'] as int);
              setState(() => notif['read_at'] = DateTime.now().toIso8601String());
            }
          },
          child: Container(
            color: isUnread
                ? AppColors.primary.withValues(alpha: 0.05)
                : Colors.white,
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icône selon type
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: _typeColor(type).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_typeIcon(type),
                      color: _typeColor(type), size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              (notif['title'] ?? '').toString(),
                              style: TextStyle(
                                fontWeight: isUnread
                                    ? FontWeight.w800
                                    : FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          if (isUnread)
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        (notif['body'] ?? '').toString(),
                        style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            height: 1.3),
                      ),
                      const SizedBox(height: 4),
                      Text(dateLabel,
                          style: const TextStyle(
                              color: AppColors.textLight, fontSize: 11)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Color _typeColor(String type) {
    if (type.contains('accept') || type.contains('confirm')) {
      return AppColors.success;
    }
    if (type.contains('refus') || type.contains('cancel')) {
      return AppColors.error;
    }
    if (type.contains('consultation') || type.contains('prescription')) {
      return AppColors.primary;
    }
    if (type.contains('payment') || type.contains('invoice')) {
      return AppColors.warning;
    }
    return AppColors.info;
  }

  IconData _typeIcon(String type) {
    if (type.contains('accept') || type.contains('confirm')) {
      return Icons.check_circle_rounded;
    }
    if (type.contains('refus') || type.contains('cancel')) {
      return Icons.cancel_rounded;
    }
    if (type.contains('consultation')) {
      return Icons.medical_services_rounded;
    }
    if (type.contains('prescription')) {
      return Icons.medication_rounded;
    }
    if (type.contains('payment') || type.contains('invoice')) {
      return Icons.receipt_rounded;
    }
    return Icons.notifications_rounded;
  }
}
