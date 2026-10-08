// lib/pages/medecin/consultation_form_page.dart
//
// Wizard consultation médecin — 5 étapes :
//   1. Anamnèse      (antécédents, plaintes — non obligatoire)
//   2. Examen        (signes, constantes — non obligatoire)
//   3. Diagnostic    (obligatoire)
//   4. Ordonnance    (médicaments — obligatoire)
//   5. Signature     (canvas — obligatoire)

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/appointment.dart';
import '../../services/ai_chat_service.dart';
import '../../services/medecin_api_service.dart';
import '../../widgets/metric_card.dart';
import '../../widgets/signature_pad.dart';
import 'medecin_ui.dart';

// ── Données examens par spécialité ───────────────────────────────────────────
const Map<String, List<String>> _examsBySpeciality = {
  'Cardiologie': [
    'ECG', 'Échocardiographie', 'Holter ECG', 'Test d\'effort',
    'Bilan lipidique', 'Troponine', 'BNP',
  ],
  'Médecine générale': [
    'NFS', 'CRP', 'VS', 'Glycémie', 'Créatinine', 'Uricémie',
    'Transaminases', 'Echo abdominale', 'Rx thorax',
  ],
  'Pneumologie': [
    'Spirométrie', 'Rx thorax', 'Scanner thoracique', 'Gazométrie',
    'D-dimères', 'Peak-flow', 'Oxymétrie',
  ],
  'Dermatologie': [
    'Dermoscopie', 'Biopsie cutanée', 'Culture mycologique',
    'Patch test', 'Phototest',
  ],
  'Gynécologie': [
    'Frottis cervico-vaginal', 'Écho pelvienne', 'Beta-HCG',
    'Mammographie', 'Colposcopie', 'NFS',
  ],
  'Pédiatrie': [
    'NFS', 'CRP', 'Coproculture', 'ECBU', 'Rx thorax',
    'Echo abdominale', 'Test rapide streptocoque',
  ],
  'Neurologie': [
    'IRM cérébrale', 'Scanner cérébral', 'EEG', 'PL', 'EMG',
    'Potentiels évoqués',
  ],
  'Ophtalmologie': [
    'Fond d\'œil', 'Tonométrie', 'Acuité visuelle', 'OCT',
    'Champ visuel', 'Biométrie',
  ],
  'ORL': [
    'Audiogramme', 'Tympanogramme', 'Nasofibroscopie',
    'Rx sinus', 'Culture gorge',
  ],
  'Orthopédie': [
    'Rx osseuse', 'IRM articulaire', 'Scanner ostéo', 'Densitométrie',
    'Echo tendineuse', 'Arthroscopie',
  ],
};

List<String> _getExamsForSpeciality(String? specialite) {
  if (specialite == null || specialite.isEmpty) {
    return _examsBySpeciality['Médecine générale']!;
  }
  for (final key in _examsBySpeciality.keys) {
    if (specialite.toLowerCase().contains(key.toLowerCase()) ||
        key.toLowerCase().contains(specialite.toLowerCase().split(' ').first)) {
      return _examsBySpeciality[key]!;
    }
  }
  return _examsBySpeciality['Médecine générale']!;
}

// ── Modèle médicament ────────────────────────────────────────────────────────
class _Medicament {
  String nom;
  String type;
  String generique;
  String dosage;
  String unite;
  String frequence;
  String prise;
  String duree;
  String uniteDuree;
  String instructions;

  _Medicament({
    this.nom = '',
    this.type = 'Comprimé',
    this.generique = '',
    this.dosage = '',
    this.unite = 'mg',
    this.frequence = '1x par jour',
    this.prise = 'Après les repas',
    this.duree = '',
    this.uniteDuree = 'jours',
    this.instructions = '',
  });

  Map<String, dynamic> toMap() => {
        'nom': nom,
        'type': type,
        'generique': generique,
        'dosage': dosage,
        'unite': unite,
        'frequence': frequence,
        'prise': prise,
        'duree': duree,
        'unite_duree': uniteDuree,
        'instructions': instructions,
      };

  /// Texte lisible pour le récap et l'ordonnance texte (fallback PDF)
  String toText() {
    final buf = StringBuffer('$nom');
    if (generique.isNotEmpty) buf.write(' ($generique)');
    buf.write('\n  $dosage $unite — $type');
    buf.write('\n  Fréquence : $frequence');
    buf.write('\n  Prise : $prise');
    if (duree.isNotEmpty) buf.write('\n  Durée : $duree $uniteDuree');
    if (instructions.isNotEmpty) buf.write('\n  ⚠ $instructions');
    return buf.toString();
  }
}

// ────────────────────────────────────────────────────────────────────────────
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

  int  _step     = 0;
  bool _isSaving = false;
  bool _geminiLoading = false;
  final _examenCtrl = TextEditingController();

  // ── Étape 1 : SOAP ───────────────────────────────────────────────────────
  final _allergiesCtrl = TextEditingController();
  final _soapSCtrl     = TextEditingController(); // Subjectif
  // Objectif — constantes vitales
  final _taCtrl        = TextEditingController();
  final _poulsCtrl     = TextEditingController();
  final _tempCtrl      = TextEditingController();
  final _poidsCtrl     = TextEditingController();
  final _tailleCtrl    = TextEditingController();
  final _spo2Ctrl      = TextEditingController();
  final _soapACtrl     = TextEditingController(); // Assessment
  final _soapPCtrl     = TextEditingController(); // Plan

  // ── Étape 2 : Compte-rendu ───────────────────────────────────────────────
  final _motifCtrl      = TextEditingController();
  final _diagnosticCtrl = TextEditingController();
  final _notesCtrl      = TextEditingController();
  final Set<String> _selectedExams = {};
  bool _examsExpanded = false;

  // ── Étape 3 : Prescription ───────────────────────────────────────────────
  final List<_Medicament> _medicaments = [];
  final Set<int> _expandedMeds = {0}; // premier médicament ouvert par défaut

  // ── Étape 4 : Signature ──────────────────────────────────────────────────
  final _signatureKey = GlobalKey<SignaturePadState>();

  // ── Spécialité du médecin (pour les examens) ─────────────────────────────
  String? get _specialite => widget.appointment.serviceName;

  @override
  void dispose() {
    _allergiesCtrl.dispose();
    _soapSCtrl.dispose();
    _taCtrl.dispose(); _poulsCtrl.dispose(); _tempCtrl.dispose();
    _poidsCtrl.dispose(); _tailleCtrl.dispose(); _spo2Ctrl.dispose();
    _soapACtrl.dispose(); _soapPCtrl.dispose();
    _motifCtrl.dispose();
    _diagnosticCtrl.dispose(); _notesCtrl.dispose();
    _examenCtrl.dispose();
    super.dispose();
  }

  // ── Validation ───────────────────────────────────────────────────────────
  bool _validateStep() {
    switch (_step) {
      case 0: // Anamnèse — non obligatoire
      case 1: // Examen — non obligatoire
        return true;
      case 2: // Diagnostic obligatoire
        if (_diagnosticCtrl.text.trim().isEmpty) {
          _toast('Le diagnostic est requis', error: true);
          return false;
        }
        return true;
      case 3: // Ordonnance — au moins 1 médicament avec nom
        if (_medicaments.isEmpty) {
          _toast('Ajoutez au moins un médicament', error: true);
          return false;
        }
        if (_medicaments.any((m) => m.nom.trim().isEmpty)) {
          _toast('Chaque médicament doit avoir un nom', error: true);
          return false;
        }
        return true;
      case 4: // Signature obligatoire
        if (!(_signatureKey.currentState?.hasStroke ?? false)) {
          _toast('La signature du médecin est requise', error: true);
          return false;
        }
        return true;
      default:
        return true;
    }
  }

  Future<void> _suggestGemini() async {
    final stepKey = switch (_step) {
      0 => 'anamnese',
      1 => 'examen',
      2 => 'diagnostic',
      3 => 'ordonnance',
      _ => null,
    };
    if (stepKey == null) return;

    setState(() => _geminiLoading = true);
    try {
      final text = await AIChatService.instance.suggestConsultationField(
        step: stepKey,
        motif: widget.appointment.motif.isNotEmpty
            ? widget.appointment.motif
            : (_motifCtrl.text.trim().isEmpty
                ? 'Consultation'
                : _motifCtrl.text.trim()),
        patientName: widget.appointment.patientDisplayName,
        urgence: widget.appointment.urgence,
      );
      if (!mounted) return;

      final insert = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Suggestion Gemini'),
          content: SingleChildScrollView(child: Text(text)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Fermer'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Insérer dans le champ'),
            ),
          ],
        ),
      );

      if (insert == true && mounted) {
        setState(() {
          if (_step == 0) {
            _soapSCtrl.text = text;
          } else if (_step == 1) {
            _examenCtrl.text = text;
          } else if (_step == 2) {
            _diagnosticCtrl.text = text;
          } else if (_step == 3) {
            _notesCtrl.text = text;
            if (_medicaments.isEmpty) {
              _medicaments.add(
                _Medicament(nom: 'Selon suggestion IA (à préciser)'),
              );
            }
          }
        });
        _toast('Suggestion insérée');
      }
    } catch (e) {
      if (mounted) _toast('$e', error: true);
    } finally {
      if (mounted) setState(() => _geminiLoading = false);
    }
  }

  void _next() {
    if (!_validateStep()) return;
    setState(() => _step++);
  }

  void _back() {
    if (_step == 0) { Navigator.pop(context); return; }
    setState(() => _step--);
  }

  // ── Soumission ───────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_validateStep()) return;
    final sig = await _signatureKey.currentState?.toBase64Png();
    if (sig == null) {
      _toast('Veuillez signer avant de terminer', error: true);
      return;
    }
    setState(() => _isSaving = true);
    try {
      // Constantes vitales non vides
      final constantes = <String, dynamic>{};
      void addVitale(String k, TextEditingController c) {
        if (c.text.trim().isNotEmpty) constantes[k] = c.text.trim();
      }
      addVitale('ta', _taCtrl); addVitale('pouls', _poulsCtrl); addVitale('temperature', _tempCtrl);
      addVitale('poids', _poidsCtrl); addVitale('taille', _tailleCtrl); addVitale('spo2', _spo2Ctrl);

      // Examens sélectionnés
      final examens = _selectedExams.isNotEmpty
          ? _selectedExams.map((e) => {'nom': e, 'categorie': 'examen'}).toList()
          : null;

      // Ordonnance texte fallback (depuis médicaments)
      final ordonnanceTxt = _medicaments.map((m) => m.toText()).join('\n\n');

      final anamneseParts = <String>[];
      if (_allergiesCtrl.text.trim().isNotEmpty) {
        anamneseParts.add('Allergies : ${_allergiesCtrl.text.trim()}');
      }
      if (_soapSCtrl.text.trim().isNotEmpty) {
        anamneseParts.add(_soapSCtrl.text.trim());
      }

      await MedecinApiService.instance.createConsultation(
        rendezVousId:  widget.appointment.id,
        diagnostic:    _diagnosticCtrl.text.trim(),
        ordonnance:    ordonnanceTxt,
        notes:         _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        anamnese:      anamneseParts.isEmpty ? null : anamneseParts.join('\n'),
        examen:        _examenCtrl.text.trim().isEmpty ? null : _examenCtrl.text.trim(),
        soapS: _soapSCtrl.text.trim().isEmpty ? null : _soapSCtrl.text.trim(),
        soapO: constantes.isNotEmpty
            ? constantes.entries.map((e) => '${e.key}: ${e.value}').join(' | ') : null,
        soapA: _soapACtrl.text.trim().isEmpty ? null : _soapACtrl.text.trim(),
        soapP: _soapPCtrl.text.trim().isEmpty ? null : _soapPCtrl.text.trim(),
        constantesVitales: constantes.isNotEmpty ? constantes : null,
        medicaments: _medicaments.map((m) => m.toMap()).toList(),
        examensComplementaires: examens,
        signatureBase64: sig,
      );
      if (!mounted) return;
      await Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => _ConsultationSuccessPage(
            patientName: widget.appointment.patientDisplayName,
            diagnostic:  _diagnosticCtrl.text.trim(),
            medicaments: _medicaments,
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppColors.error : AppColors.success,
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_steps[_step]),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: _back,
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(52),
          child: _WizardStepper(step: _step, labels: _steps),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
              children: [
                _PatientCard(appointment: widget.appointment),
                const SizedBox(height: 16),
                _buildStepBody(),
              ],
            ),
          ),
          _buildBottomBar(),
        ],
      ),
    );
  }

  Widget _buildStepBody() {
    return switch (_step) {
      0 => _buildAnamneseStep(),
      1 => _buildExamenStep(),
      2 => _buildDiagnosticStep(),
      3 => _buildPrescriptionStep(),
      4 => _buildSignatureStep(),
      _  => const SizedBox.shrink(),
    };
  }

  Widget _geminiButton() {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton.icon(
        onPressed: _geminiLoading ? null : _suggestGemini,
        icon: _geminiLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.auto_awesome_rounded, size: 18),
        label: Text(_geminiLoading ? 'Suggestion…' : 'Suggestion Gemini'),
      ),
    );
  }

  // ── Étape 1 : Anamnèse ───────────────────────────────────────────────────
  Widget _buildAnamneseStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _geminiButton(),
        const SizedBox(height: 8),
        _SoapSection(
          letter: 'A',
          color: const Color(0xFFE74C3C),
          label: 'Allergies / antécédents',
          subtitle: 'Allergies et antécédents pertinents (optionnel)',
          icon: Icons.warning_amber_rounded,
          child: _textArea(
            controller: _allergiesCtrl,
            hint: 'Ex : Pénicilline, Aspirine, Latex…',
          ),
        ),
        const SizedBox(height: 12),
        _SoapSection(
          letter: 'S',
          color: const Color(0xFF8E44AD),
          label: 'Plaintes / durée',
          subtitle: 'Ce que dit le patient : symptômes, histoire de la maladie',
          icon: Icons.person_outline_rounded,
          child: _textArea(
            controller: _soapSCtrl,
            hint: 'Ex : Essoufflement depuis 3 jours…',
            minLines: 4,
          ),
        ),
      ],
    );
  }

  // ── Étape 2 : Examen clinique ────────────────────────────────────────────
  Widget _buildExamenStep() {
    final exams = _getExamsForSpeciality(_specialite);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _geminiButton(),
        const SizedBox(height: 8),
        _SoapSection(
          letter: 'O',
          color: const Color(0xFF2980B9),
          label: 'Constantes vitales',
          subtitle: 'Optionnel',
          icon: Icons.monitor_heart_outlined,
          child: _buildConstantes(),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          icon: Icons.healing_outlined,
          iconColor: const Color(0xFF2980B9),
          label: 'Signes cliniques',
          child: _textArea(
            controller: _examenCtrl,
            hint: 'Ex : Auscultation, palpation, signes positifs…',
            minLines: 3,
          ),
        ),
        const SizedBox(height: 12),
        _ExamSection(
          exams: exams,
          selected: _selectedExams,
          expanded: _examsExpanded,
          onToggleExpand: () => setState(() => _examsExpanded = !_examsExpanded),
          onToggleExam: (exam) => setState(() {
            if (_selectedExams.contains(exam)) {
              _selectedExams.remove(exam);
            } else {
              _selectedExams.add(exam);
            }
          }),
        ),
      ],
    );
  }

  // ── Étape 3 : Diagnostic ─────────────────────────────────────────────────
  Widget _buildDiagnosticStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _geminiButton(),
        const SizedBox(height: 8),
        _SectionCard(
          icon: Icons.help_outline_rounded,
          iconColor: const Color(0xFF6C3483),
          label: 'Motif de consultation',
          child: _textArea(
            controller: _motifCtrl,
            hint: 'Ex : Douleurs thoraciques depuis 3 jours…',
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          icon: Icons.biotech_outlined,
          iconColor: const Color(0xFFE67E22),
          label: 'Diagnostic *',
          child: _textArea(
            controller: _diagnosticCtrl,
            hint: 'Ex : Hypertension artérielle non contrôlée…',
            minLines: 3,
          ),
        ),
        const SizedBox(height: 12),
        _SoapSection(
          letter: 'A',
          color: const Color(0xFFE67E22),
          label: 'Assessment',
          subtitle: 'Analyse clinique (optionnel)',
          icon: Icons.analytics_outlined,
          child: _textArea(
            controller: _soapACtrl,
            hint: 'Hypothèses et raisonnement…',
            minLines: 3,
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          icon: Icons.edit_note_rounded,
          iconColor: AppColors.textSecondary,
          label: 'Notes supplémentaires',
          child: _textArea(
            controller: _notesCtrl,
            hint: 'Remarques libres, suivi prévu…',
          ),
        ),
      ],
    );
  }

  Widget _buildConstantes() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: _vitaleField('TA (mmHg)', _taCtrl, '120/80')),
            const SizedBox(width: 10),
            Expanded(child: _vitaleField('Pouls (bpm)', _poulsCtrl, '72')),
            const SizedBox(width: 10),
            Expanded(child: _vitaleField('T° (°C)', _tempCtrl, '37.0')),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(child: _vitaleField('Poids (kg)', _poidsCtrl, '70')),
            const SizedBox(width: 10),
            Expanded(child: _vitaleField('Taille (cm)', _tailleCtrl, '170')),
            const SizedBox(width: 10),
            Expanded(child: _vitaleField('SpO₂ (%)', _spo2Ctrl, '98')),
          ],
        ),
      ],
    );
  }

  Widget _vitaleField(String label, TextEditingController ctrl, String hint) {
    return TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textAlign: TextAlign.center,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: const TextStyle(fontSize: 11),
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      ),
    );
  }

  // ── Étape 4 : Ordonnance ─────────────────────────────────────────────────
  Widget _buildPrescriptionStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _geminiButton(),
        const SizedBox(height: 8),
        // En-tête
        Row(
          children: [
            const Icon(Icons.medication_rounded, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(
              'Médicaments  (${_medicaments.length})',
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            const Spacer(),
            FilledButton.icon(
              onPressed: () => setState(() {
                _medicaments.add(_Medicament());
                _expandedMeds.add(_medicaments.length - 1);
              }),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Ajouter'),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                visualDensity: VisualDensity.compact,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (_medicaments.isEmpty)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: const Column(
              children: [
                Icon(Icons.medication_outlined, size: 40, color: AppColors.textLight),
                SizedBox(height: 8),
                Text(
                  'Aucun médicament ajouté\nTouchez "+ Ajouter" pour prescrire',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          )
        else
          ...List.generate(_medicaments.length, (i) => _MedicamentCard(
                index: i,
                med: _medicaments[i],
                expanded: _expandedMeds.contains(i),
                onToggle: () => setState(() {
                  if (_expandedMeds.contains(i)) {
                    _expandedMeds.remove(i);
                  } else {
                    _expandedMeds.add(i);
                  }
                }),
                onDelete: () => setState(() {
                  _medicaments.removeAt(i);
                  _expandedMeds.remove(i);
                }),
                onChanged: () => setState(() {}),
              )),
      ],
    );
  }

  // ── Étape 4 : Signature ──────────────────────────────────────────────────
  Widget _buildSignatureStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Récapitulatif
        MedecinCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Récapitulatif',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
              const SizedBox(height: 12),
              _recapRow('Diagnostic', _diagnosticCtrl.text),
              if (_medicaments.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  '${_medicaments.length} médicament(s)',
                  style: const TextStyle(
                      color: AppColors.primary, fontWeight: FontWeight.w700),
                ),
                ...(_medicaments.map((m) => Padding(
                      padding: const EdgeInsets.only(left: 12, top: 4),
                      child: Text(
                        '• ${m.nom} — ${m.dosage} ${m.unite} — ${m.frequence}',
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ))),
              ],
              if (_selectedExams.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Examens : ${_selectedExams.join(', ')}',
                  style: const TextStyle(
                      color: AppColors.textSecondary, fontSize: 13),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),

        // Zone de signature
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: MedecinDecor.cardShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Signature du médecin *',
                style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
              ),
              const SizedBox(height: 4),
              const Text(
                'Signez pour valider l\'ordonnance et clôturer la consultation.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 12),
              SignaturePad(key: _signatureKey),
            ],
          ),
        ),
      ],
    );
  }

  // ── Bottom bar ────────────────────────────────────────────────────────────
  Widget _buildBottomBar() {
    final isLast = _step == _steps.length - 1;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppColors.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            if (_step > 0) ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: _isSaving ? null : _back,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Précédent'),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed: _isSaving ? null : (isLast ? _submit : _next),
                style: FilledButton.styleFrom(
                  backgroundColor: isLast ? AppColors.success : AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                child: _isSaving
                    ? const SizedBox(
                        width: 20, height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : Text(isLast ? 'Terminer la consultation' : 'Suivant →'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────
  Widget _textArea({
    required TextEditingController controller,
    required String hint,
    int minLines = 3,
  }) {
    return TextField(
      controller: controller,
      maxLines: null,
      minLines: minLines,
      textCapitalization: TextCapitalization.sentences,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: AppColors.background,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide:
              const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.all(12),
      ),
    );
  }

  Widget _recapRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.w600, color: AppColors.primary,
                  fontSize: 12)),
          const SizedBox(height: 2),
          Text(
            value.trim().isEmpty ? '—' : value.trim(),
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

// ── Stepper horizontal ────────────────────────────────────────────────────────
class _WizardStepper extends StatelessWidget {
  final int step;
  final List<String> labels;
  const _WizardStepper({required this.step, required this.labels});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
      child: Row(
        children: List.generate(labels.length * 2 - 1, (i) {
          if (i.isOdd) {
            // Ligne entre steps
            final leftDone = i ~/ 2 < step;
            return Expanded(
              child: Container(
                height: 2,
                color: leftDone ? Colors.white : Colors.white38,
              ),
            );
          }
          final idx = i ~/ 2;
          final done = idx < step;
          final current = idx == step;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 28, height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: done || current ? Colors.white : Colors.white24,
                ),
                child: Center(
                  child: done
                      ? const Icon(Icons.check, size: 16,
                          color: AppColors.primary)
                      : Text(
                          '${idx + 1}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: current
                                ? AppColors.primary
                                : Colors.white70,
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                labels[idx],
                style: TextStyle(
                  fontSize: 9,
                  fontWeight:
                      current ? FontWeight.w700 : FontWeight.w400,
                  color: current ? Colors.white : Colors.white60,
                ),
              ),
            ],
          );
        }),
      ),
    );
  }
}

// ── Carte patient en-tête ─────────────────────────────────────────────────────
class _PatientCard extends StatelessWidget {
  final Appointment appointment;
  const _PatientCard({required this.appointment});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          DoctorAvatar(
              name: appointment.patientDisplayName, radius: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(appointment.patientDisplayName,
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 15)),
                Text('Motif : ${appointment.motif}',
                    style: const TextStyle(
                        color: AppColors.textSecondary, fontSize: 13)),
              ],
            ),
          ),
          if (appointment.isTresUrgent || appointment.isUrgent)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: appointment.isTresUrgent
                    ? AppColors.error.withValues(alpha: 0.12)
                    : AppColors.warning.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                appointment.urgenceLabel,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: appointment.isTresUrgent
                      ? AppColors.error
                      : AppColors.warning,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Section SOAP générique ────────────────────────────────────────────────────
class _SoapSection extends StatelessWidget {
  final String letter;
  final Color color;
  final String label;
  final String subtitle;
  final IconData icon;
  final Widget child;

  const _SoapSection({
    required this.letter,
    required this.color,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: MedecinDecor.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(letter,
                      style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                          fontSize: 16)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(label,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 14)),
                    Text(subtitle,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 12)),
                  ],
                ),
              ),
              Icon(icon, color: color, size: 20),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

// ── Section générique compte-rendu ────────────────────────────────────────────
class _SectionCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final Widget child;

  const _SectionCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: MedecinDecor.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: iconColor, size: 20),
              const SizedBox(width: 8),
              Text(label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w800, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

// ── Section examens complémentaires ───────────────────────────────────────────
class _ExamSection extends StatelessWidget {
  final List<String> exams;
  final Set<String> selected;
  final bool expanded;
  final VoidCallback onToggleExpand;
  final void Function(String) onToggleExam;

  const _ExamSection({
    required this.exams,
    required this.selected,
    required this.expanded,
    required this.onToggleExpand,
    required this.onToggleExam,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: MedecinDecor.cardShadow,
      ),
      child: Column(
        children: [
          InkWell(
            onTap: onToggleExpand,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Icon(Icons.science_outlined,
                      color: Color(0xFF2980B9), size: 20),
                  const SizedBox(width: 8),
                  const Text('Examens complémentaires',
                      style: TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 14)),
                  if (selected.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 7, vertical: 2),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: Text(
                        '${selected.length}',
                        style: const TextStyle(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                            fontSize: 11),
                      ),
                    ),
                  ],
                  const Spacer(),
                  Icon(
                    expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: exams.map((exam) {
                  final isSelected = selected.contains(exam);
                  return FilterChip(
                    label: Text(exam),
                    selected: isSelected,
                    onSelected: (_) => onToggleExam(exam),
                    backgroundColor: AppColors.background,
                    selectedColor: AppColors.primary.withValues(alpha: 0.15),
                    checkmarkColor: AppColors.primary,
                    labelStyle: TextStyle(
                      fontSize: 12,
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.textSecondary,
                      fontWeight: isSelected
                          ? FontWeight.w700
                          : FontWeight.w500,
                    ),
                    side: BorderSide(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.border,
                    ),
                    showCheckmark: true,
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Carte médicament ──────────────────────────────────────────────────────────
class _MedicamentCard extends StatefulWidget {
  final int index;
  final _Medicament med;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback onChanged;

  const _MedicamentCard({
    required this.index,
    required this.med,
    required this.expanded,
    required this.onToggle,
    required this.onDelete,
    required this.onChanged,
  });

  @override
  State<_MedicamentCard> createState() => _MedicamentCardState();
}

class _MedicamentCardState extends State<_MedicamentCard> {
  late final TextEditingController _nomCtrl;
  late final TextEditingController _genCtrl;
  late final TextEditingController _dosageCtrl;
  late final TextEditingController _instructCtrl;

  static const _types = ['Comprimé', 'Gélule', 'Sirop', 'Injection',
      'Pommade', 'Crème', 'Gouttes', 'Patch', 'Suppositoire', 'Inhalateur'];
  static const _unites = ['mg', 'g', 'ml', 'UI', 'µg', '%'];
  static const _frequences = [
    '1x par jour', '2x par jour', '3x par jour',
    'Matin et soir', 'Toutes les 8h', 'Toutes les 12h',
    'Au besoin', '1x par semaine',
  ];
  static const _prises = [
    'Avant les repas', 'Pendant les repas', 'Après les repas',
    'À jeun', 'Le soir au coucher', 'Indifférent',
  ];
  static const _unitesDuree = ['jours', 'semaines', 'mois'];

  @override
  void initState() {
    super.initState();
    _nomCtrl    = TextEditingController(text: widget.med.nom);
    _genCtrl    = TextEditingController(text: widget.med.generique);
    _dosageCtrl = TextEditingController(text: widget.med.dosage);
    _instructCtrl = TextEditingController(text: widget.med.instructions);

    _nomCtrl.addListener(() {
      widget.med.nom = _nomCtrl.text;
      widget.onChanged();
    });
    _genCtrl.addListener(() {
      widget.med.generique = _genCtrl.text;
    });
    _dosageCtrl.addListener(() {
      widget.med.dosage = _dosageCtrl.text;
      widget.onChanged();
    });
    _instructCtrl.addListener(() {
      widget.med.instructions = _instructCtrl.text;
    });
  }

  @override
  void dispose() {
    _nomCtrl.dispose(); _genCtrl.dispose();
    _dosageCtrl.dispose(); _instructCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final med = widget.med;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: MedecinDecor.cardShadow,
        border: widget.expanded
            ? Border.all(color: AppColors.primary.withValues(alpha: 0.3))
            : null,
      ),
      child: Column(
        children: [
          // En-tête cliquable
          InkWell(
            onTap: widget.onToggle,
            borderRadius: BorderRadius.circular(16),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
              child: Row(
                children: [
                  Container(
                    width: 28, height: 28,
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${widget.index + 1}',
                        style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 13),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      med.nom.isEmpty
                          ? 'Nouveau médicament'
                          : med.nom,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: med.nom.isEmpty
                            ? AppColors.textLight
                            : AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_rounded,
                        color: AppColors.error, size: 20),
                    onPressed: widget.onDelete,
                    tooltip: 'Supprimer',
                    visualDensity: VisualDensity.compact,
                  ),
                  Icon(
                    widget.expanded
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    color: AppColors.textSecondary,
                  ),
                ],
              ),
            ),
          ),

          if (widget.expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 12),

                  // Nom du médicament
                  const _FieldLabel('Nom du médicament *'),
                  TextField(
                    controller: _nomCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Ex : Amoxicilline',
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Type + Nom générique
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _FieldLabel('Type'),
                            _Dropdown(
                              value: med.type,
                              items: _types,
                              onChanged: (v) =>
                                  setState(() => med.type = v!),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _FieldLabel('Nom générique'),
                            TextField(
                              controller: _genCtrl,
                              decoration: const InputDecoration(
                                hintText: 'DCI',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Dosage + Unité
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _FieldLabel('Dosage par prise'),
                            TextField(
                              controller: _dosageCtrl,
                              keyboardType:
                                  TextInputType.numberWithOptions(decimal: true),
                              decoration: const InputDecoration(hintText: '500'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _FieldLabel('Unité'),
                            _Dropdown(
                              value: med.unite,
                              items: _unites,
                              onChanged: (v) =>
                                  setState(() => med.unite = v!),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Fréquence + Prise
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _FieldLabel('Fréquence'),
                            _Dropdown(
                              value: med.frequence,
                              items: _frequences,
                              onChanged: (v) =>
                                  setState(() => med.frequence = v!),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _FieldLabel('Moment de prise'),
                            _Dropdown(
                              value: med.prise,
                              items: _prises,
                              onChanged: (v) =>
                                  setState(() => med.prise = v!),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Durée + Unité durée
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _FieldLabel('Durée'),
                            _DurationField(
                              value: med.duree,
                              onChanged: (v) =>
                                  setState(() => med.duree = v),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const _FieldLabel('Unité'),
                            _Dropdown(
                              value: med.uniteDuree,
                              items: _unitesDuree,
                              onChanged: (v) =>
                                  setState(() => med.uniteDuree = v!),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  // Instructions supplémentaires
                  const _FieldLabel('Instructions supplémentaires'),
                  TextField(
                    controller: _instructCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Ex : 4-6 UI avant chaque repas — adapter selon glycémie…',
                    ),
                    maxLines: 2,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── Widgets utilitaires ───────────────────────────────────────────────────────
class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Text(text,
          style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary)),
    );
  }
}

class _Dropdown extends StatelessWidget {
  final String value;
  final List<String> items;
  final void Function(String?) onChanged;

  const _Dropdown({
    required this.value,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: items.contains(value) ? value : items.first,
      items: items
          .map((e) => DropdownMenuItem(value: e, child: Text(e)))
          .toList(),
      onChanged: onChanged,
      decoration: const InputDecoration(isDense: true),
      style: const TextStyle(
          fontSize: 13, color: AppColors.textPrimary),
      isExpanded: true,
    );
  }
}

class _DurationField extends StatelessWidget {
  final String value;
  final void Function(String) onChanged;

  const _DurationField({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.remove_circle_outline, size: 20),
          color: AppColors.primary,
          visualDensity: VisualDensity.compact,
          onPressed: () {
            final n = (int.tryParse(value) ?? 1) - 1;
            if (n > 0) onChanged('$n');
          },
        ),
        Expanded(
          child: Text(
            value.isEmpty ? '—' : value,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline, size: 20),
          color: AppColors.primary,
          visualDensity: VisualDensity.compact,
          onPressed: () {
            final n = (int.tryParse(value) ?? 0) + 1;
            onChanged('$n');
          },
        ),
      ],
    );
  }
}

// ── Page succès ───────────────────────────────────────────────────────────────
class _ConsultationSuccessPage extends StatelessWidget {
  final String patientName;
  final String diagnostic;
  final List<_Medicament> medicaments;

  const _ConsultationSuccessPage({
    required this.patientName,
    required this.diagnostic,
    required this.medicaments,
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
                width: 80, height: 80,
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.check_rounded,
                    size: 44, color: AppColors.success),
              ),
              const SizedBox(height: 20),
              const Text('Consultation terminée',
                  style: TextStyle(
                      fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 10),
              Text(
                'Le dossier de $patientName a été mis à jour.\nL\'ordonnance est disponible pour le patient.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                    color: AppColors.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 20),
              MedecinCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Diagnostic',
                        style: TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(diagnostic),
                    if (medicaments.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text('${medicaments.length} médicament(s) prescrit(s)',
                          style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary)),
                      ...medicaments.map((m) => Padding(
                            padding: const EdgeInsets.only(top: 4, left: 8),
                            child: Text(
                              '• ${m.nom} — ${m.dosage} ${m.unite} — ${m.frequence}',
                              style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary),
                            ),
                          )),
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
                        color: AppColors.primary, size: 18),
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
