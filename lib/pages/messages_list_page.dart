// lib/pages/messages_list_page.dart
//
// Liste de toutes les conversations (patient ↔ médecin).
// Charge GET /api/conversations — retourne les RDV ayant au moins 1 message.
// Tap → ouvre ChatPage de ce RDV.

import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../config/app_config.dart';
import '../widgets/metric_card.dart';
import 'chat_page.dart';

class MessagesListPage extends StatefulWidget {
  const MessagesListPage({super.key});

  @override
  State<MessagesListPage> createState() => _MessagesListPageState();
}

class _MessagesListPageState extends State<MessagesListPage> {
  static const _storage = FlutterSecureStorage();

  List<Map<String, dynamic>> _conversations = [];
  int? _currentUserId;
  bool _loading = true;
  String? _error;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _load();
    // Rafraîchit automatiquement toutes les 30 secondes
    _refreshTimer = Timer.periodic(
      const Duration(seconds: 30),
      (_) => _load(silent: true),
    );
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _load({bool silent = false}) async {
    if (!silent) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final token = await _storage.read(key: AppConfig.keyJwtToken);
      final res = await http
          .get(
            Uri.parse('${AppConfig.baseUrl}/conversations'),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(AppConfig.defaultTimeout);

      final body = jsonDecode(res.body);
      if (res.statusCode == 200 && body['status'] == true) {
        final currentUser = body['current_user'];
        final currentUserId = currentUser is Map
            ? int.tryParse(currentUser['id']?.toString() ?? '')
            : null;
        if (currentUserId == null) {
          throw const FormatException(
            'Le profil connecté est absent de la réponse de messagerie.',
          );
        }
        final list = (body['data'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        if (mounted) {
          setState(() {
            _conversations = list;
            _currentUserId = currentUserId;
            _loading = false;
          });
        }
      } else {
        if (mounted && !silent) {
          setState(() {
            _error = body['message'] ?? 'Erreur';
            _loading = false;
          });
        }
      }
    } catch (e) {
      if (mounted && !silent) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      } else if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Messages'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            )
          : _error != null
          ? _ErrorView(error: _error!, onRetry: _load)
          : _conversations.isEmpty
          ? _EmptyView()
          : RefreshIndicator(
              onRefresh: _load,
              color: AppColors.primary,
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(vertical: 8),
                itemCount: _conversations.length,
                separatorBuilder: (_, __) =>
                    const Divider(height: 1, indent: 72),
                itemBuilder: (context, i) => _ConversationTile(
                  conv: _conversations[i],
                  currentUserId: _currentUserId!,
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatPage(
                          appointmentId:
                              _conversations[i]['appointment_id'] as int,
                          otherName:
                              _conversations[i]['other_name']?.toString() ??
                              'Interlocuteur',
                          otherRole:
                              _conversations[i]['other_role']?.toString() ?? '',
                        ),
                      ),
                    );
                    // Rafraîchir les badges non lus au retour
                    if (mounted) _load(silent: true);
                  },
                ),
              ),
            ),
    );
  }
}

// ── Tuile conversation ────────────────────────────────────────────────────────
class _ConversationTile extends StatelessWidget {
  final Map<String, dynamic> conv;
  final int currentUserId;
  final VoidCallback onTap;

  const _ConversationTile({
    required this.conv,
    required this.currentUserId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final name = conv['other_name']?.toString() ?? 'Inconnu';
    final rawLastMsg = conv['last_message']?.toString() ?? '';
    final senderId = int.tryParse(
      conv['last_message_sender_id']?.toString() ?? '',
    );
    final lastIsMe = senderId == currentUserId;
    final lastMsg = rawLastMsg.isEmpty
        ? 'Touchez pour écrire un message'
        : lastIsMe
        ? 'Vous : $rawLastMsg'
        : rawLastMsg;
    final unread = (conv['unread_count'] as int?) ?? 0;
    final rawDate = conv['last_message_at']?.toString() ?? '';
    final motif = conv['motif']?.toString() ?? '';
    final statut = conv['appointment_statut']?.toString() ?? '';
    final photoUrl = conv['other_photo_url']?.toString();

    String dateLabel = '';
    try {
      final dt = DateTime.parse(rawDate.replaceFirst(' ', 'T')).toLocal();
      final now = DateTime.now();
      final isToday =
          dt.year == now.year && dt.month == now.month && dt.day == now.day;
      dateLabel = isToday
          ? DateFormat('HH:mm').format(dt)
          : DateFormat('d MMM', 'fr_FR').format(dt);
    } catch (_) {}

    // Badge couleur selon statut RDV
    final statusColor = switch (statut) {
      'Confirme' => AppColors.success,
      'Accepte' => AppColors.info,
      'Termine' => AppColors.textSecondary,
      'En_attente' => AppColors.warning,
      _ => AppColors.textLight,
    };

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Avatar
            Stack(
              children: [
                CircleAvatar(
                  radius: 26,
                  backgroundColor: AppColors.ice,
                  backgroundImage:
                      (photoUrl != null && photoUrl.startsWith('http'))
                      ? NetworkImage(photoUrl)
                      : null,
                  child: (photoUrl == null || !photoUrl.startsWith('http'))
                      ? Text(
                          name.isNotEmpty ? name[0].toUpperCase() : '?',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        )
                      : null,
                ),
                // Pastille statut RDV
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: statusColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 14),

            // Texte
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          name,
                          style: TextStyle(
                            fontWeight: unread > 0
                                ? FontWeight.w800
                                : FontWeight.w600,
                            fontSize: 15,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        dateLabel,
                        style: TextStyle(
                          fontSize: 11,
                          color: unread > 0
                              ? AppColors.primary
                              : AppColors.textLight,
                          fontWeight: unread > 0
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  if (motif.isNotEmpty)
                    Text(
                      motif,
                      style: const TextStyle(
                        fontSize: 11,
                        color: AppColors.textLight,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      if (lastIsMe)
                        const Padding(
                          padding: EdgeInsets.only(right: 4),
                          child: Icon(
                            Icons.done_all_rounded,
                            size: 13,
                            color: AppColors.textLight,
                          ),
                        ),
                      Expanded(
                        child: Text(
                          lastMsg,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13,
                            color: unread > 0
                                ? AppColors.textPrimary
                                : AppColors.textSecondary,
                            fontWeight: unread > 0
                                ? FontWeight.w600
                                : FontWeight.w400,
                          ),
                        ),
                      ),
                      if (unread > 0) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Text(
                            '$unread',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── État vide ─────────────────────────────────────────────────────────────────
class _EmptyView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.chat_bubble_outline_rounded,
            size: 72,
            color: AppColors.textLight.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 16),
          const Text(
            'Aucune conversation',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Les échanges avec vos médecins\napparaîtront ici.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, height: 1.4),
          ),
        ],
      ),
    );
  }
}

// ── Erreur ────────────────────────────────────────────────────────────────────
class _ErrorView extends StatelessWidget {
  final String error;
  final VoidCallback onRetry;
  const _ErrorView({required this.error, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text(error, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton(onPressed: onRetry, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }
}
