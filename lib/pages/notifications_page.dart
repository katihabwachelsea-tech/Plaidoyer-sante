// lib/pages/notifications_page.dart
//
// Liste des notifications in-app.
// Tap sur une notification :
//   → marque comme lue
//   → ouvre un bottom sheet avec le détail du RDV concerné
//     (nom médecin, spécialité, hôpital, date, statut, motif)

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import '../config/app_config.dart';
import '../services/api_logger.dart';
import '../widgets/metric_card.dart';
import 'patient/health_history_page.dart';

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

  // ── Chargement ────────────────────────────────────────────────────────────

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
      final res = await http.get(Uri.parse(url), headers: headers)
          .timeout(AppConfig.defaultTimeout);
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
    final headers = {'Accept': 'application/json', 'Authorization': 'Bearer $token'};
    ApiLogger.request(method: 'POST', url: url, headers: headers);
    final res = await http.post(Uri.parse(url), headers: headers)
        .timeout(AppConfig.shortTimeout);
    ApiLogger.response(url: url, statusCode: res.statusCode, body: res.body);
    await _load();
  }

  Future<void> _markRead(int id) async {
    final token = await _token();
    final url = '${AppConfig.baseUrl}/notifications/$id/read';
    final headers = {'Accept': 'application/json', 'Authorization': 'Bearer $token'};
    ApiLogger.request(method: 'POST', url: url, headers: headers);
    final res = await http.post(Uri.parse(url), headers: headers)
        .timeout(AppConfig.shortTimeout);
    ApiLogger.response(url: url, statusCode: res.statusCode, body: res.body);
  }

  // ── Charger le détail du RDV ──────────────────────────────────────────────

  Future<Map<String, dynamic>?> _fetchAppointment(int appointmentId) async {
    final token = await _token();
    final url = '${AppConfig.baseUrl}/patient/appointments';
    try {
      final res = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(AppConfig.defaultTimeout);
      if (res.statusCode == 200) {
        final data = jsonDecode(res.body);
        final list = (data['data'] as List? ?? []);
        for (final item in list) {
          final id = item['id'] is int
              ? item['id'] as int
              : int.tryParse('${item['id']}') ?? -1;
          if (id == appointmentId) {
            return Map<String, dynamic>.from(item as Map);
          }
        }
      }
    } catch (_) {}
    return null;
  }

  // ── Bottom sheet détail ───────────────────────────────────────────────────

  void _showDetail(Map<String, dynamic> notif) {
    // Extraire appointment_id depuis notif['data']
    final rawData = notif['data'];
    int? appointmentId;
    if (rawData is Map) {
      final raw = rawData['appointment_id'];
      appointmentId = raw is int ? raw : int.tryParse('$raw');
    }

    final type = (notif['type'] ?? '').toString();

    // ── Résultats de consultation → ouvrir directement le dossier médical ──
    if (type == 'consultation_done' || type.contains('prescription')) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => HealthHistoryPage(openAppointmentId: appointmentId),
        ),
      );
      return;
    }

    // ── Tous les autres types → bottom sheet détail RDV ──────────────────
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _NotifDetailSheet(
        notif: notif,
        appointmentId: appointmentId,
        fetchAppointment: appointmentId != null ? _fetchAppointment : null,
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

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
              Text('$unread non lue${unread > 1 ? "s" : ""}',
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w400)),
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
            child: Column(children: [
              Icon(Icons.notifications_off_outlined,
                  size: 64, color: AppColors.textLight),
              SizedBox(height: 12),
              Text('Aucune notification',
                  style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        ],
      );
    }

    final fmt = DateFormat('d MMM · HH:mm', 'fr_FR');

    return ListView.separated(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: 8),
      itemCount: _notifications.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
      itemBuilder: (context, index) {
        final notif    = _notifications[index];
        final isUnread = notif['read_at'] == null;
        final type     = (notif['type'] ?? '').toString();
        final rawDate  = (notif['created_at'] ?? '').toString();
        var dateLabel  = '';
        try {
          dateLabel = fmt.format(
              DateTime.parse(rawDate.replaceFirst(' ', 'T')).toLocal());
        } catch (_) {}

        return InkWell(
          onTap: () async {
            // 1. Marquer comme lue
            if (isUnread) {
              await _markRead(notif['id'] as int);
              if (mounted) {
                setState(() =>
                    notif['read_at'] = DateTime.now().toIso8601String());
              }
            }
            // 2. Ouvrir le détail
            if (mounted) _showDetail(notif);
          },
          child: Container(
            color: isUnread
                ? AppColors.primary.withValues(alpha: 0.05)
                : Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Icône type
                Container(
                  width: 42, height: 42,
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
                      Row(children: [
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
                            width: 8, height: 8,
                            decoration: const BoxDecoration(
                              color: AppColors.primary,
                              shape: BoxShape.circle,
                            ),
                          ),
                      ]),
                      const SizedBox(height: 3),
                      Text(
                        (notif['body'] ?? '').toString(),
                        style: const TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13,
                            height: 1.3),
                      ),
                      const SizedBox(height: 4),
                      Row(children: [
                        Text(dateLabel,
                            style: const TextStyle(
                                color: AppColors.textLight, fontSize: 11)),
                        const Spacer(),
                        // Flèche indiquant que c'est cliquable
                        const Icon(Icons.chevron_right_rounded,
                            size: 16, color: AppColors.textLight),
                      ]),
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

  // ── Helpers type ──────────────────────────────────────────────────────────

  Color _typeColor(String type) {
    if (type.contains('accept') || type.contains('confirm')) return AppColors.success;
    if (type.contains('refus')  || type.contains('cancel'))  return AppColors.error;
    if (type.contains('consultation') || type.contains('prescription')) return AppColors.primary;
    if (type.contains('payment') || type.contains('invoice')) return AppColors.warning;
    if (type.contains('message')) return AppColors.info;
    return AppColors.info;
  }

  IconData _typeIcon(String type) {
    if (type.contains('accept') || type.contains('confirm')) return Icons.check_circle_rounded;
    if (type.contains('refus')  || type.contains('cancel'))  return Icons.cancel_rounded;
    if (type.contains('consultation'))  return Icons.medical_services_rounded;
    if (type.contains('prescription'))  return Icons.medication_rounded;
    if (type.contains('payment') || type.contains('invoice')) return Icons.receipt_rounded;
    if (type.contains('message')) return Icons.chat_bubble_rounded;
    return Icons.notifications_rounded;
  }
}

// ── Bottom sheet détail notification ─────────────────────────────────────────

class _NotifDetailSheet extends StatefulWidget {
  final Map<String, dynamic> notif;
  final int? appointmentId;
  final Future<Map<String, dynamic>?> Function(int)? fetchAppointment;

  const _NotifDetailSheet({
    required this.notif,
    this.appointmentId,
    this.fetchAppointment,
  });

  @override
  State<_NotifDetailSheet> createState() => _NotifDetailSheetState();
}

class _NotifDetailSheetState extends State<_NotifDetailSheet> {
  Map<String, dynamic>? _appointment;
  bool _loadingAppt = false;

  @override
  void initState() {
    super.initState();
    if (widget.appointmentId != null && widget.fetchAppointment != null) {
      _loadAppt();
    }
  }

  Future<void> _loadAppt() async {
    setState(() => _loadingAppt = true);
    try {
      final appt = await widget.fetchAppointment!(widget.appointmentId!);
      if (mounted) setState(() => _appointment = appt);
    } finally {
      if (mounted) setState(() => _loadingAppt = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final type     = (widget.notif['type'] ?? '').toString();
    final title    = (widget.notif['title'] ?? '').toString();
    final body     = (widget.notif['body'] ?? '').toString();
    final rawDate  = (widget.notif['created_at'] ?? '').toString();
    var dateLabel  = '';
    try {
      dateLabel = DateFormat('EEEE d MMMM yyyy · HH:mm', 'fr_FR')
          .format(DateTime.parse(rawDate.replaceFirst(' ', 'T')).toLocal());
    } catch (_) {}

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.4,
      maxChildSize: 0.92,
      expand: false,
      builder: (_, ctrl) => Column(children: [
        // Poignée
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 8),
          child: Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(99)),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            controller: ctrl,
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
            children: [

              // ── Icône + titre ───────────────────────────────────
              Row(children: [
                Container(
                  width: 48, height: 48,
                  decoration: BoxDecoration(
                    color: _color(type).withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(_icon(type), color: _color(type), size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 16)),
                      const SizedBox(height: 2),
                      Text(dateLabel,
                          style: const TextStyle(
                              color: AppColors.textLight, fontSize: 12)),
                    ],
                  ),
                ),
              ]),
              const SizedBox(height: 14),

              // ── Corps du message ────────────────────────────────
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.background,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Text(body,
                    style: const TextStyle(
                        fontSize: 14, height: 1.5,
                        color: AppColors.textPrimary)),
              ),
              const SizedBox(height: 20),

              // ── Détails du RDV ──────────────────────────────────
              if (_loadingAppt)
                const Center(child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(color: AppColors.primary),
                ))
              else if (_appointment != null) ...[
                const Text('Rendez-vous concerné',
                    style: TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 15)),
                const SizedBox(height: 10),
                _buildApptCard(_appointment!),
              ] else if (widget.appointmentId != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.background,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Text(
                    'Impossible de charger les détails du rendez-vous.',
                    style: TextStyle(color: AppColors.textSecondary),
                  ),
                ),
              ],
            ],
          ),
        ),
      ]),
    );
  }

  Widget _buildApptCard(Map<String, dynamic> appt) {
    final medecin     = appt['medecin'] as Map?;
    final user        = medecin?['user'] as Map?;
    final service     = appt['service'] as Map?;
    final invoice     = appt['invoice'] as Map?;

    final doctorName  = user?['nom']?.toString() ?? 'Médecin';
    final specialty   = medecin?['specialite']?.toString() ?? '';
    final hopital     = medecin?['hopital']?.toString() ?? '';
    final serviceName = service?['nom_service']?.toString() ?? 'Consultation';
    final mode        = service?['mode']?.toString() ?? 'presentiel';
    final statut      = (appt['statut'] ?? '').toString();
    final motif       = (appt['motif'] ?? '').toString();
    final rawDate     = (appt['date_rdv'] ?? '').toString();
    var dateLabel     = rawDate;
    try {
      dateLabel = DateFormat('EEEE d MMM yyyy · HH:mm', 'fr_FR')
          .format(DateTime.parse(rawDate.replaceFirst(' ', 'T')).toLocal());
    } catch (_) {}

    final montant = invoice?['montant'];
    final payStatut = invoice?['statut_paiement']?.toString();
    final txId = invoice?['transaction_id']?.toString();

    // Couleur statut
    final (statusColor, statusLabel) = switch (statut) {
      'Confirme'    => (AppColors.success, 'Confirmé'),
      'Accepte'     => (AppColors.info,    'Accepté — À payer'),
      'En_attente'  => (AppColors.warning, 'En attente'),
      'Annule'      => (AppColors.error,   'Annulé'),
      'Termine'     => (AppColors.textSecondary, 'Terminé'),
      _             => (AppColors.textLight, statut),
    };

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(
          color: Colors.black.withValues(alpha: 0.05),
          blurRadius: 8, offset: const Offset(0, 2),
        )],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [

          // ── En-tête doctor ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Row(children: [
              // Avatar
              Container(
                width: 48, height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    doctorName.isNotEmpty ? doctorName[0].toUpperCase() : 'D',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                        color: AppColors.primary),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    doctorName.toLowerCase().startsWith('dr')
                        ? doctorName : 'Dr. $doctorName',
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  if (specialty.isNotEmpty)
                    Text(specialty,
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                            fontSize: 13)),
                ],
              )),
              // Badge statut
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(statusLabel,
                    style: TextStyle(
                        color: statusColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w700)),
              ),
            ]),
          ),

          const Divider(height: 1),

          // ── Détails ───────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hopital.isNotEmpty)
                  _detailRow(Icons.local_hospital_rounded,
                      hopital, AppColors.primary),
                _detailRow(Icons.calendar_today_rounded,
                    dateLabel, AppColors.textPrimary),
                _detailRow(Icons.medical_services_rounded,
                    '$serviceName · ${mode == "teleconsultation" ? "Téléconsultation" : "Présentiel"}',
                    mode == 'teleconsultation' ? AppColors.info : AppColors.success),
                if (motif.isNotEmpty)
                  _detailRow(Icons.notes_rounded,
                      motif, AppColors.textSecondary),
                if (montant != null) ...[
                  _detailRow(
                    Icons.payment_rounded,
                    '${formatFbu(num.tryParse('$montant'))} · ${payStatut == "Paye" ? "Payé ✅" : "À payer"}',
                    payStatut == 'Paye' ? AppColors.success : AppColors.warning,
                  ),
                  if (txId != null)
                    _detailRow(Icons.receipt_rounded,
                        'Reçu : $txId', AppColors.textSecondary),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _detailRow(IconData icon, String text, Color color) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 16, color: color),
      const SizedBox(width: 8),
      Expanded(child: Text(text,
          style: TextStyle(fontSize: 13, color: AppColors.textPrimary))),
    ]),
  );

  Color _color(String type) {
    if (type.contains('accept') || type.contains('confirm')) return AppColors.success;
    if (type.contains('refus')  || type.contains('cancel'))  return AppColors.error;
    if (type.contains('consultation')) return AppColors.primary;
    if (type.contains('payment'))      return AppColors.warning;
    if (type.contains('message'))      return AppColors.info;
    return AppColors.info;
  }

  IconData _icon(String type) {
    if (type.contains('accept') || type.contains('confirm')) return Icons.check_circle_rounded;
    if (type.contains('refus')  || type.contains('cancel'))  return Icons.cancel_rounded;
    if (type.contains('consultation')) return Icons.medical_services_rounded;
    if (type.contains('payment'))      return Icons.receipt_rounded;
    if (type.contains('message'))      return Icons.chat_bubble_rounded;
    return Icons.notifications_rounded;
  }
}

// ── Helper formatage FBu (réutilisé depuis metric_card) ──────────────────────
String formatFbu(num? value) {
  if (value == null) return '—';
  final digits = value.round().toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final fromEnd = digits.length - i;
    if (i > 0 && fromEnd % 3 == 0) buf.write(' ');
    buf.write(digits[i]);
  }
  return '${buf.toString()} FBu';
}
