import 'package:flutter/material.dart';
import '../../models/appointment.dart';
import '../../models/patient.dart';
import '../../services/ai_chat_service.dart';
import '../../services/medecin_api_service.dart';
import '../../widgets/metric_card.dart';
import '../../widgets/signature_pad.dart';
import 'medecin_ui.dart';

/// Wizard consultation : anamnèse → examen → diagnostic → ordonnance → signature.
class ConsultationFormPage extends StatefulWidget {
  final Appointment appointment;

  const ConsultationFormPage({super.key, required this.appointment});

  @override
  State<ConsultationFormPage> createState() => _ConsultationFormPageState();
}

class _ConsultationFormPageState extends State<ConsultationFormPage> {
  static const _steps = [
    'Anamnèse',
    'Examen',
    'Diagnostic',
    'Ordonnance',
    'Signature',
  ];

  final _anamneseController = TextEditingController();
  final _examenController = TextEditingController();
  final _diagnosticController = TextEditingController();
  final _ordonnanceController = TextEditingController();
  final _signatureKey = GlobalKey<SignaturePadState>();
  final _api = MedecinApiService.instance;

  int _step = 0;
  bool _isSaving = false;
  bool _isAiLoading = false;
  String? _aiSuggestion;
  String? _signatureBase64;

  @override
  void dispose() {
    _anamneseController.dispose();
    _examenController.dispose();
    _diagnosticController.dispose();
    _ordonnanceController.dispose();
    super.dispose();
  }

  TextEditingController get _currentField {
    switch (_step) {
      case 0:
        return _anamneseController;
      case 1:
        return _examenController;
      case 2:
        return _diagnosticController;
      case 3:
        return _ordonnanceController;
      default:
        return _diagnosticController;
    }
  }

  Patient _patientFromAppointment() {
    final parts = widget.appointment.patientDisplayName.trim().split(RegExp(r'\s+'));
    return Patient(
      nom: parts.length > 1 ? parts.sublist(1).join(' ') : parts.first,
      prenom: parts.first,
      age: 30,
      pays: 'Burundi',
      maladie: widget.appointment.motif,
    );
  }

  String _promptForStep() {
    final motif = widget.appointment.motif;
    switch (_step) {
      case 0:
        return '''
Motif : $motif
Rédige une anamnèse structurée concise (antécédents, plaintes, durée) pour aider le médecin.
Français, style clinique, 4-6 lignes max. Pas de diagnostic définitif.
''';
      case 1:
        return '''
Motif : $motif
Anamnèse : ${_anamneseController.text}
Propose un plan d'examen clinique / signes à rechercher. Français, 4-6 lignes, pour un médecin.
''';
      case 2:
        return '''
Motif : $motif
Anamnèse : ${_anamneseController.text}
Examen : ${_examenController.text}
Propose 3 pistes de diagnostic différentiel (pas de diagnostic définitif). Français, concis.
''';
      case 3:
        return '''
Motif : $motif
Diagnostic provisoire : ${_diagnosticController.text}
Propose une ordonnance type réaliste (molécules, posologie simple) adaptée au Burundi.
Français, format liste courte. Mentionne que le médecin doit valider.
''';
      default:
        return '';
    }
  }

  Future<void> _askGemini() async {
    if (_step >= 4) return;
    setState(() {
      _isAiLoading = true;
      _aiSuggestion = null;
    });
    try {
      final patient = _patientFromAppointment();
      AIChatService.instance.initializeChat(patient);
      final response = await AIChatService.instance.sendMessage(_promptForStep());
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

  void _insertAi() {
    if (_aiSuggestion == null || _aiSuggestion!.startsWith('Aide IA')) return;
    final field = _currentField;
    if (field.text.trim().isEmpty) {
      field.text = _aiSuggestion!;
    } else {
      field.text = '${field.text.trim()}\n\n$_aiSuggestion';
    }
    setState(() {});
  }

  bool _validateStep() {
    switch (_step) {
      case 2:
        if (_diagnosticController.text.trim().isEmpty) {
          _toast('Le diagnostic est requis', error: true);
          return false;
        }
        return true;
      case 3:
        if (_ordonnanceController.text.trim().isEmpty) {
          _toast('L\'ordonnance est requise', error: true);
          return false;
        }
        return true;
      case 4:
        if (_signatureBase64 == null ||
            !(_signatureKey.currentState?.hasStroke ?? false)) {
          _toast('La signature du médecin est requise', error: true);
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  void _next() {
    if (!_validateStep()) return;
    setState(() {
      _aiSuggestion = null;
      if (_step < _steps.length - 1) {
        _step++;
      }
    });
  }

  void _back() {
    if (_step == 0) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _aiSuggestion = null;
      _step--;
    });
  }

  Future<void> _submit() async {
    if (!_validateStep()) return;

    // Capture fraîche de la signature
    final sig = await _signatureKey.currentState?.toBase64Png();
    if (sig == null) {
      _toast('Veuillez signer avant de terminer', error: true);
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _api.createConsultation(
        rendezVousId: widget.appointment.id,
        anamnese: _anamneseController.text.trim().isEmpty
            ? null
            : _anamneseController.text.trim(),
        examen: _examenController.text.trim().isEmpty
            ? null
            : _examenController.text.trim(),
        diagnostic: _diagnosticController.text.trim(),
        ordonnance: _ordonnanceController.text.trim(),
        notes: null,
        signatureBase64: sig,
      );
      if (!mounted) return;
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => _ConsultationSuccessPage(
            patientName: widget.appointment.patientDisplayName,
            diagnostic: _diagnosticController.text.trim(),
            ordonnance: _ordonnanceController.text.trim(),
          ),
        ),
      );
    } catch (e) {
      if (mounted) _toast('$e', error: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _toast(String msg, {bool error = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? AppColors.error : AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rdv = widget.appointment;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text('Consultation · ${_steps[_step]}'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _back,
        ),
      ),
      body: Column(
        children: [
          _StepHeader(step: _step, labels: _steps),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                MedecinCard(
                  child: Row(
                    children: [
                      DoctorAvatar(name: rdv.patientDisplayName, radius: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              rdv.patientDisplayName,
                              style: const TextStyle(
                                fontWeight: FontWeight.w800,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'Motif : ${rdv.motif}',
                              style: const TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                _buildStepBody(),
                if (_step < 4) ...[
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
                    onPressed: _isAiLoading ? null : _askGemini,
                    icon: _isAiLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.psychology_rounded),
                    label: const Text('Suggestion Gemini'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.primary,
                      side: const BorderSide(color: AppColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 14),
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
                              Icon(Icons.lightbulb_outline,
                                  color: AppColors.primary, size: 20),
                              SizedBox(width: 8),
                              Text('Suggestion IA',
                                  style: TextStyle(fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(_aiSuggestion!, style: const TextStyle(fontSize: 13)),
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton.icon(
                              onPressed: _insertAi,
                              icon: const Icon(Icons.add_rounded, size: 18),
                              label: const Text('Insérer dans le champ'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
                const SizedBox(height: 88),
              ],
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: Row(
            children: [
              if (_step > 0)
                Expanded(
                  child: OutlinedButton(
                    onPressed: _isSaving ? null : _back,
                    child: const Text('Précédent'),
                  ),
                ),
              if (_step > 0) const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: _isSaving
                      ? null
                      : (_step == _steps.length - 1 ? _submit : _next),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : Text(
                          _step == _steps.length - 1
                              ? 'Terminer'
                              : 'Suivant',
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepBody() {
    switch (_step) {
      case 0:
        return _field(
          controller: _anamneseController,
          label: 'Anamnèse',
          hint: 'Plaintes, antécédents, durée des symptômes…',
        );
      case 1:
        return _field(
          controller: _examenController,
          label: 'Examen clinique',
          hint: 'Signes cliniques, constantes, observations…',
        );
      case 2:
        return _field(
          controller: _diagnosticController,
          label: 'Diagnostic *',
          hint: 'Diagnostic clinique',
          required: true,
        );
      case 3:
        return _field(
          controller: _ordonnanceController,
          label: 'Ordonnance *',
          hint: 'Médicaments, posologie, durée…',
          required: true,
        );
      case 4:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Signature du médecin *',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
            ),
            const SizedBox(height: 6),
            Text(
              'Signez pour valider l\'ordonnance et clôturer la consultation.',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 12),
            SignaturePad(
              key: _signatureKey,
              onChanged: (b64) => setState(() => _signatureBase64 = b64),
            ),
            const SizedBox(height: 12),
            MedecinCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Récapitulatif',
                      style: TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  _recapLine('Diagnostic', _diagnosticController.text),
                  _recapLine('Ordonnance', _ordonnanceController.text),
                ],
              ),
            ),
          ],
        );
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    required String hint,
    bool required = false,
  }) {
    return TextField(
      controller: controller,
      maxLines: 6,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
      ),
      onChanged: (_) => setState(() {}),
    );
  }

  Widget _recapLine(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
          Text(
            value.trim().isEmpty ? '—' : value.trim(),
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _StepHeader extends StatelessWidget {
  final int step;
  final List<String> labels;

  const _StepHeader({required this.step, required this.labels});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
      color: Colors.white,
      child: Column(
        children: [
          Row(
            children: List.generate(labels.length, (i) {
              final done = i < step;
              final current = i == step;
              return Expanded(
                child: Container(
                  margin: EdgeInsets.only(right: i == labels.length - 1 ? 0 : 6),
                  height: 5,
                  decoration: BoxDecoration(
                    color: done || current
                        ? AppColors.primary
                        : AppColors.border,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 8),
          Text(
            'Étape ${step + 1}/${labels.length} — ${labels[step]}',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          ),
        ],
      ),
    );
  }
}

class _ConsultationSuccessPage extends StatelessWidget {
  final String patientName;
  final String diagnostic;
  final String ordonnance;

  const _ConsultationSuccessPage({
    required this.patientName,
    required this.diagnostic,
    required this.ordonnance,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: 88,
                height: 88,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded,
                    size: 48, color: AppColors.success),
              ),
              const SizedBox(height: 20),
              const Text(
                'Consultation terminée',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 10),
              Text(
                'Le dossier de $patientName a été mis à jour.\n'
                'Le patient a été notifié et peut consulter l\'ordonnance.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 16),
              MedecinCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Diagnostic',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(diagnostic),
                    if (ordonnance.trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text('Ordonnance',
                          style: TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(ordonnance,
                          style: const TextStyle(
                              color: AppColors.textSecondary, height: 1.35)),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.ice,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.notifications_active_rounded,
                        color: AppColors.primary, size: 20),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Notification « Résultats disponibles » envoyée au patient.',
                        style: TextStyle(fontSize: 13, height: 1.3),
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.pop(context, true),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: const Text('Retour à l\'agenda'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
