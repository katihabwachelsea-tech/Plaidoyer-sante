import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../widgets/metric_card.dart';

/// Bouton « Rejoindre » Meet/WhatsApp pour téléconsultation le jour J.
class JoinTeleButton extends StatelessWidget {
  final String? meetingUrl;
  final bool enabled;
  final bool compact;

  const JoinTeleButton({
    super.key,
    required this.meetingUrl,
    this.enabled = true,
    this.compact = false,
  });

  Future<void> _open(BuildContext context) async {
    final raw = meetingUrl?.trim() ?? '';
    if (raw.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Lien de téléconsultation indisponible')),
      );
      return;
    }
    final uri = Uri.tryParse(raw);
    if (uri == null) return;
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Impossible d\'ouvrir le lien')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!enabled) return const SizedBox.shrink();
    final isWa = (meetingUrl ?? '').contains('wa.me');
    final label = isWa ? 'WhatsApp' : 'Rejoindre';
    final icon = isWa ? Icons.chat_rounded : Icons.videocam_rounded;

    if (compact) {
      return TextButton.icon(
        onPressed: () => _open(context),
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: TextButton.styleFrom(foregroundColor: AppColors.info),
      );
    }

    return FilledButton.icon(
      onPressed: () => _open(context),
      style: FilledButton.styleFrom(backgroundColor: AppColors.info),
      icon: Icon(icon),
      label: Text(label),
    );
  }
}

/// Helpers patient (maps API) pour bouton rejoindre.
bool canJoinTeleFromMap(Map<String, dynamic> appt) {
  final mode = ((appt['service'] as Map?)?['mode'] ?? '').toString();
  final statut = (appt['statut'] ?? '').toString();
  final url = (appt['meeting_url'] ?? '').toString();
  if (mode != 'teleconsultation' || statut != 'Confirme' || url.isEmpty) {
    return false;
  }
  try {
    final dt = DateTime.parse(
      (appt['date_rdv'] ?? '').toString().replaceFirst(' ', 'T'),
    ).toLocal();
    final now = DateTime.now();
    return dt.year == now.year && dt.month == now.month && dt.day == now.day;
  } catch (_) {
    return false;
  }
}
