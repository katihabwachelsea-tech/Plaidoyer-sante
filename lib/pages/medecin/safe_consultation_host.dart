import 'package:flutter/material.dart';
import '../../models/appointment.dart';
import '../../widgets/metric_card.dart';
import 'consultation_form_page.dart';

/// Enveloppe anti-crash : si le wizard consultation plante,
/// on affiche un message au lieu de fermer l'app.
class SafeConsultationHost extends StatefulWidget {
  final Appointment appointment;

  const SafeConsultationHost({super.key, required this.appointment});

  @override
  State<SafeConsultationHost> createState() => _SafeConsultationHostState();
}

class _SafeConsultationHostState extends State<SafeConsultationHost> {
  late final ErrorWidgetBuilder _previousBuilder;

  @override
  void initState() {
    super.initState();
    _previousBuilder = ErrorWidget.builder;
    ErrorWidget.builder = (details) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Consultation'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () {
              if (Navigator.canPop(context)) Navigator.pop(context);
            },
          ),
        ),
        body: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline_rounded,
                  size: 56, color: AppColors.warning),
              const SizedBox(height: 16),
              const Text(
                'Impossible d\'ouvrir la consultation',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Text(
                'Une erreur technique est survenue. '
                'Réessayez dans un instant.\n\n'
                '${details.exceptionAsString()}',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () {
                  if (Navigator.canPop(context)) Navigator.pop(context);
                },
                child: const Text('Retour'),
              ),
            ],
          ),
        ),
      );
    };
  }

  @override
  void dispose() {
    ErrorWidget.builder = _previousBuilder;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    try {
      return ConsultationFormPage(appointment: widget.appointment);
    } catch (e) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Consultation'),
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.info_outline_rounded,
                    size: 48, color: AppColors.warning),
                const SizedBox(height: 12),
                Text(
                  'Impossible d\'ouvrir la consultation.\n$e',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Retour'),
                ),
              ],
            ),
          ),
        ),
      );
    }
  }
}
