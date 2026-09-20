import 'package:flutter/material.dart';
import '../../widgets/metric_card.dart';
import 'health_history_page.dart';

/// Ancien écran fictif (analyses / urgences) — redirige vers le vrai dossier médical.
class HealthDetailPage extends StatelessWidget {
  final String section;

  const HealthDetailPage({super.key, required this.section});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Santé'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.folder_shared_outlined, size: 64, color: AppColors.primary.withValues(alpha: 0.7)),
            const SizedBox(height: 16),
            const Text(
              'Consultez votre dossier médical',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              'Diagnostics, ordonnances et historique de consultations sont disponibles dans votre dossier.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, height: 1.4),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(builder: (_) => const HealthHistoryPage()),
                  );
                },
                icon: const Icon(Icons.medical_information_outlined),
                label: const Text('Ouvrir mon dossier'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
