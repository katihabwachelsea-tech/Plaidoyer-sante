// lib/services/consultation_draft_service.dart
//
// Sauvegarde automatique du brouillon de consultation.
// Utilise SharedPreferences avec des clés préfixées par appointment.id.
// La signature n'est jamais sauvegardée — le médecin la refait à la reprise.

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ConsultationDraftService {
  ConsultationDraftService._();
  static final instance = ConsultationDraftService._();

  // ── Clé préfixée ─────────────────────────────────────────────────────────
  static String _k(int appointmentId, String field) =>
      'consult_draft_${appointmentId}_$field';

  // ── Vérifier si un brouillon existe ──────────────────────────────────────
  Future<bool> hasDraft(int appointmentId) async {
    final prefs = await SharedPreferences.getInstance();
    // Le brouillon existe si l'étape courante a été sauvegardée
    return prefs.containsKey(_k(appointmentId, 'step'));
  }

  // ── Sauvegarder le brouillon complet ─────────────────────────────────────
  Future<void> save({
    required int appointmentId,
    required int step,
    // Étape 0 — SOAP Anamnèse
    required String allergies,
    required String soapS,
    // Objectif — constantes vitales
    required String ta,
    required String pouls,
    required String temp,
    required String poids,
    required String taille,
    required String spo2,
    required String soapA,
    required String soapP,
    // Étape 1 — Examen
    required String examen,
    required List<String> selectedExams,
    // Étape 2 — Diagnostic
    required String motif,
    required String diagnostic,
    required String notes,
    // Étape 3 — Médicaments
    required List<Map<String, dynamic>> medicaments,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final id = appointmentId;

    await prefs.setInt(_k(id, 'step'), step);
    await prefs.setString(_k(id, 'allergies'), allergies);
    await prefs.setString(_k(id, 'soap_s'), soapS);
    await prefs.setString(_k(id, 'ta'), ta);
    await prefs.setString(_k(id, 'pouls'), pouls);
    await prefs.setString(_k(id, 'temp'), temp);
    await prefs.setString(_k(id, 'poids'), poids);
    await prefs.setString(_k(id, 'taille'), taille);
    await prefs.setString(_k(id, 'spo2'), spo2);
    await prefs.setString(_k(id, 'soap_a'), soapA);
    await prefs.setString(_k(id, 'soap_p'), soapP);
    await prefs.setString(_k(id, 'examen'), examen);
    await prefs.setString(_k(id, 'selected_exams'), jsonEncode(selectedExams));
    await prefs.setString(_k(id, 'motif'), motif);
    await prefs.setString(_k(id, 'diagnostic'), diagnostic);
    await prefs.setString(_k(id, 'notes'), notes);
    await prefs.setString(_k(id, 'medicaments'), jsonEncode(medicaments));
  }

  // ── Charger le brouillon ─────────────────────────────────────────────────
  Future<ConsultationDraft?> load(int appointmentId) async {
    final prefs = await SharedPreferences.getInstance();
    final id = appointmentId;

    if (!prefs.containsKey(_k(id, 'step'))) return null;

    String s(String field) => prefs.getString(_k(id, field)) ?? '';
    final step = prefs.getInt(_k(id, 'step')) ?? 0;

    final rawExams = s('selected_exams');
    final selectedExams = <String>{};
    if (rawExams.isNotEmpty) {
      try {
        final list = jsonDecode(rawExams) as List;
        selectedExams.addAll(list.map((e) => e.toString()));
      } catch (_) {}
    }

    final rawMeds = s('medicaments');
    final medicaments = <Map<String, dynamic>>[];
    if (rawMeds.isNotEmpty) {
      try {
        final list = jsonDecode(rawMeds) as List;
        medicaments.addAll(list.map((e) => Map<String, dynamic>.from(e as Map)));
      } catch (_) {}
    }

    return ConsultationDraft(
      step: step,
      allergies:     s('allergies'),
      soapS:         s('soap_s'),
      ta:            s('ta'),
      pouls:         s('pouls'),
      temp:          s('temp'),
      poids:         s('poids'),
      taille:        s('taille'),
      spo2:          s('spo2'),
      soapA:         s('soap_a'),
      soapP:         s('soap_p'),
      examen:        s('examen'),
      selectedExams: selectedExams,
      motif:         s('motif'),
      diagnostic:    s('diagnostic'),
      notes:         s('notes'),
      medicaments:   medicaments,
    );
  }

  // ── Supprimer le brouillon après soumission réussie ───────────────────────
  Future<void> clear(int appointmentId) async {
    final prefs = await SharedPreferences.getInstance();
    final id = appointmentId;
    for (final field in [
      'step', 'allergies', 'soap_s', 'ta', 'pouls', 'temp', 'poids',
      'taille', 'spo2', 'soap_a', 'soap_p', 'examen', 'selected_exams',
      'motif', 'diagnostic', 'notes', 'medicaments',
    ]) {
      await prefs.remove(_k(id, field));
    }
  }
}

// ── Modèle du brouillon ───────────────────────────────────────────────────────
class ConsultationDraft {
  final int step;
  final String allergies;
  final String soapS;
  final String ta;
  final String pouls;
  final String temp;
  final String poids;
  final String taille;
  final String spo2;
  final String soapA;
  final String soapP;
  final String examen;
  final Set<String> selectedExams;
  final String motif;
  final String diagnostic;
  final String notes;
  final List<Map<String, dynamic>> medicaments;

  const ConsultationDraft({
    required this.step,
    required this.allergies,
    required this.soapS,
    required this.ta,
    required this.pouls,
    required this.temp,
    required this.poids,
    required this.taille,
    required this.spo2,
    required this.soapA,
    required this.soapP,
    required this.examen,
    required this.selectedExams,
    required this.motif,
    required this.diagnostic,
    required this.notes,
    required this.medicaments,
  });
}
