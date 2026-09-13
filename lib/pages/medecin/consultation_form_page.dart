// lib/pages/medecin/consultation_form_page.dart
//
// Formulaire de consultation + aide IA Gemini (sans modifier ai_chat_service.dart)

import 'package:flutter/material.dart';
import '../../models/appointment.dart';
import '../../models/patient.dart';
import '../../services/medecin_api_service.dart';
import '../../services/ai_chat_service.dart';
import '../../widgets/metric_card.dart';

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
        notes: _notesController.text.trim().isEmpty
            ? null
            : _notesController.text.trim(),
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
          SnackBar(
            content: Text('Erreur : $e'),
            backgroundColor: AppColors.error,
          ),
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
            Card(
              child: ListTile(
                leading: const Icon(Icons.person, color: AppColors.primary),
                title: Text(rdv.patientDisplayName),
                subtitle: Text('Motif : ${rdv.motif}'),
                trailing: const Chip(
                  label: Text('Payé ✓', style: TextStyle(fontSize: 11)),
                  backgroundColor: Color(0xFFE8F5E9),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _diagnosticController,
              decoration: const InputDecoration(
                labelText: 'Diagnostic *',
                hintText: 'Diagnostic clinique',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Diagnostic requis' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _ordonnanceController,
              decoration: const InputDecoration(
                labelText: 'Ordonnance *',
                hintText: 'Ex. Paracétamol 500 mg, 2 fois par jour',
                border: OutlineInputBorder(),
              ),
              maxLines: 4,
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Ordonnance requise' : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _notesController,
              decoration: const InputDecoration(
                labelText: 'Notes',
                hintText: 'Observations complémentaires',
                border: OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _isAiLoading ? null : _askGeminiHelp,
              icon: _isAiLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.psychology_rounded, color: AppColors.primary),
              label: const Text('Aide IA Gemini'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                side: const BorderSide(color: AppColors.primary),
              ),
            ),
            if (_aiSuggestion != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withOpacity(0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Row(
                      children: [
                        Icon(Icons.lightbulb_outline, color: AppColors.primary, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Suggestions IA (aide à la décision)',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(_aiSuggestion!, style: const TextStyle(fontSize: 13)),
                    const SizedBox(height: 8),
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
            ElevatedButton(
              onPressed: _isSaving ? null : _submitConsultation,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: AppColors.textOnPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: _isSaving
                  ? const SizedBox(
                      height: 22,
                      width: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.textOnPrimary,
                      ),
                    )
                  : const Text('Terminer la consultation'),
            ),
          ],
        ),
      ),
    );
  }
}
