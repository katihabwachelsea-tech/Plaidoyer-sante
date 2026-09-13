import 'package:flutter/material.dart';
import '../../models/appointment.dart';
import '../../models/patient.dart';
import '../../services/ai_chat_service.dart';
import '../../services/medecin_api_service.dart';
import '../../widgets/metric_card.dart';
import 'medecin_ui.dart';

class ConsultationFormPage extends StatefulWidget {
  final Appointment appointment;

  const ConsultationFormPage({super.key, required this.appointment});

  @override
  State<ConsultationFormPage> createState() => _ConsultationFormPageState();
}

class _ConsultationFormPageState extends State<ConsultationFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _diagnosticController = TextEditingController();
  final _ordonnanceController = TextEditingController();
  final _notesController = TextEditingController();
  final _api = MedecinApiService.instance;

  bool _isSaving = false;
  bool _isAiLoading = false;
  String? _aiSuggestion;

  @override
  void dispose() {
    _diagnosticController.dispose();
    _ordonnanceController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Patient _patientFromAppointment() {
    return Patient(
      nom: widget.appointment.patientDisplayName.split(' ').length > 1
          ? widget.appointment.patientDisplayName.split(' ').last
          : widget.appointment.patientDisplayName,
      prenom: widget.appointment.patientDisplayName.split(' ').first,
      age: 30,
      pays: 'Burundi',
      maladie: widget.appointment.motif,
      conseils: _notesController.text.isEmpty ? null : _notesController.text,
    );
  }

  Future<void> _askGeminiHelp() async {
    setState(() {
      _isAiLoading = true;
      _aiSuggestion = null;
    });

    try {
      final patient = _patientFromAppointment();
      AIChatService.instance.initializeChat(patient);
      final prompt = '''
Motif de consultation : ${widget.appointment.motif}
Notes du médecin : ${_notesController.text.isEmpty ? 'Aucune' : _notesController.text}

En tant qu'assistant clinique, propose 3 à 4 pistes de diagnostic différentiel 
et des examens complémentaires à envisager. Réponds en français, de façon concise 
(professionnelle, pour un médecin). Ne pose pas de diagnostic définitif.
''';
      final response = await AIChatService.instance.sendMessage(prompt);
      if (mounted) {
        setState(() {
          _aiSuggestion = response.message;
          _isAiLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _aiSuggestion = 'Aide IA indisponible : $e';
          _isAiLoading = false;
        });
      }
    }
  }

  Future<void> _submitConsultation() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await _api.createConsultation(
        rendezVousId: widget.appointment.id,
        diagnostic: _diagnosticController.text.trim(),
        ordonnance: _ordonnanceController.text.trim().isEmpty
            ? null
            : _ordonnanceController.text.trim(),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Consultation enregistrée — RDV terminé'),
            backgroundColor: AppColors.success,
          ),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final rdv = widget.appointment;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Consultation'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            MedecinCard(
              child: Row(
                children: [
                  DoctorAvatar(name: rdv.patientDisplayName, radius: 26),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(rdv.patientDisplayName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                        Text('Motif : ${rdv.motif}', style: const TextStyle(color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppColors.success.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: const Text('Payé', style: TextStyle(color: AppColors.success, fontWeight: FontWeight.w800, fontSize: 11)),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _diagnosticController,
              decoration: const InputDecoration(
                labelText: 'Diagnostic *',
                hintText: 'Diagnostic clinique',
                filled: true,
                fillColor: Colors.white,
              ),
              maxLines: 3,
              validator: (v) => v == null || v.trim().isEmpty ? 'Diagnostic requis' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _ordonnanceController,
              decoration: const InputDecoration(
                labelText: 'Ordonnance *',
                hintText: 'Ex. Paracétamol 500 mg, 2 fois par jour',
                filled: true,
                fillColor: Colors.white,
              ),
              maxLines: 4,
              validator: (v) => v == null || v.trim().isEmpty ? 'Ordonnance requise' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes',
                hintText: 'Observations complémentaires',
                filled: true,
                fillColor: Colors.white,
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _isAiLoading ? null : _askGeminiHelp,
              icon: _isAiLoading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.psychology_rounded, color: AppColors.primary),
              label: const Text('Aide IA Gemini'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: AppColors.primary),
              ),
            ),
            if (_aiSuggestion != null) ...[
              const SizedBox(height: 12),
              MedecinCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.lightbulb_outline, color: AppColors.primary, size: 20),
                        SizedBox(width: 8),
                        Text('Suggestions IA', style: TextStyle(fontWeight: FontWeight.bold)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(_aiSuggestion!, style: const TextStyle(fontSize: 13)),
                    TextButton(
                      onPressed: () {
                        if (_diagnosticController.text.isEmpty) {
                          _diagnosticController.text = _aiSuggestion!;
                        }
                      },
                      child: const Text('Copier vers le diagnostic'),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _isSaving ? null : _submitConsultation,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Terminer la consultation'),
            ),
          ],
        ),
      ),
    );
  }
}
