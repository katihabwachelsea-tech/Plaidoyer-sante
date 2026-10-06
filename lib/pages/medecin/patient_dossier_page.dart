// lib/pages/medecin/patient_dossier_page.dart
//
// Dossier médical complet d'un patient — vue médecin.
// Onglets : Résumé | Ordonnances | Consultations
//
// Données chargées depuis GET /api/medecin/patients/{patient_id}/dossier

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../config/app_config.dart';
import '../../services/prescription_pdf_service.dart';
import '../../widgets/metric_card.dart';
import 'medecin_ui.dart';

class PatientDossierPage extends StatefulWidget {
  final int patientId;
  final String patientNom;

  const PatientDossierPage({
    super.key,
    required this.patientId,
    required this.patientNom,
  });

  @override
  State<PatientDossierPage> createState() => _PatientDossierPageState();
}

class _PatientDossierPageState extends State<PatientDossierPage>
    with SingleTickerProviderStateMixin {
  static const _storage = FlutterSecureStorage();

  late TabController _tabCtrl;
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 3, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final token = await _storage.read(key: AppConfig.keyJwtToken);
      final url = '${AppConfig.baseUrl}/medecin/patients/${widget.patientId}/dossier';
      final res = await http.get(
        Uri.parse(url),
        headers: {
          'Accept': 'application/json',
          'Authorization': 'Bearer $token',
        },
      ).timeout(AppConfig.defaultTimeout);
      final body = jsonDecode(res.body);
      if (res.statusCode == 200 && body['status'] == true) {
        if (mounted) setState(() { _data = body['data']; _loading = false; });
      } else {
        if (mounted) setState(() { _error = body['message'] ?? 'Erreur'; _loading = false; });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Dossier Patient'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _load,
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: Colors.white,
          indicatorWeight: 3,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
          tabs: const [
            Tab(text: 'Résumé'),
            Tab(text: 'Ordonnances'),
            Tab(text: 'Consultations'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? _ErrorView(error: _error!, onRetry: _load)
              : TabBarView(
                  controller: _tabCtrl,
                  children: [
                    _ResumeTab(data: _data!),
                    _OrdonnancesTab(historique: _data!['historique'] as List? ?? []),
                    _ConsultationsTab(historique: _data!['historique'] as List? ?? []),
                  ],
                ),
    );
  }
}

// ── En-tête patient ───────────────────────────────────────────────────────────
class _PatientHeader extends StatelessWidget {
  final Map<String, dynamic> profil;
  const _PatientHeader({required this.profil});

  @override
  Widget build(BuildContext context) {
    final nom           = (profil['nom'] ?? '').toString();
    final tel           = (profil['telephone'] ?? '').toString();
    final groupe        = (profil['groupe_sanguin'] ?? '').toString();
    final maladie       = (profil['maladie'] ?? '').toString();
    final antecedents   = (profil['antecedents'] ?? '').toString();

    // Âge depuis date_naissance
    String age = '';
    try {
      final dn = profil['date_naissance']?.toString() ?? '';
      if (dn.isNotEmpty) {
        final dt = DateTime.parse(dn);
        age = '${DateTime.now().year - dt.year} ans';
      }
    } catch (_) {}

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: MedecinDecor.cardShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Avatar
          CircleAvatar(
            radius: 30,
            backgroundColor: AppColors.ice,
            child: Text(
              nom.isNotEmpty ? nom[0].toUpperCase() : 'P',
              style: const TextStyle(
                  fontSize: 26, fontWeight: FontWeight.w800,
                  color: AppColors.primary),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(nom,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6, runSpacing: 4,
                  children: [
                    if (age.isNotEmpty) _Chip(age, AppColors.success),
                    if (groupe.isNotEmpty) _Chip(groupe, AppColors.error),
                    if (maladie.isNotEmpty) _Chip(maladie, AppColors.warning),
                  ],
                ),
                if (tel.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(children: [
                    const Icon(Icons.phone_rounded, size: 13, color: AppColors.textSecondary),
                    const SizedBox(width: 4),
                    Text(tel, style: const TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  ]),
                ],
                if (antecedents.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text('Antécédents : $antecedents',
                      style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                      maxLines: 2, overflow: TextOverflow.ellipsis),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(label,
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

// ── Onglet Résumé ─────────────────────────────────────────────────────────────
class _ResumeTab extends StatelessWidget {
  final Map<String, dynamic> data;
  const _ResumeTab({required this.data});

  @override
  Widget build(BuildContext context) {
    final profil      = data['profil'] as Map<String, dynamic>? ?? {};
    final constantes  = data['dernieres_constantes'] as Map<String, dynamic>?;
    final consultDate = data['derniere_consult_date']?.toString() ?? '';
    final medicaments = data['medicaments'] as List? ?? [];

    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        _PatientHeader(profil: profil),

        // ── Constantes vitales ───────────────────────────────────────
        if (constantes != null && constantes.isNotEmpty) ...[
          _SectionTitle(
            icon: Icons.monitor_heart_outlined,
            label: 'Constantes vitales',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (consultDate.isNotEmpty) ...[
                  Row(children: [
                    const Icon(Icons.calendar_today_rounded, size: 12, color: AppColors.primary),
                    const SizedBox(width: 4),
                    Text(
                      _fmt(consultDate),
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.primary,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '· Dernière mesure · ${constantes.length} constante(s)',
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ]),
                  const SizedBox(height: 10),
                ],
                GridView.count(
                  crossAxisCount: 3,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: 1.0,
                  children: [
                    if (constantes['ta'] != null)
                      _VitaleCard('${constantes['ta']}', 'mmHg', 'Pression'),
                    if (constantes['pouls'] != null)
                      _VitaleCard('${constantes['pouls']}', 'bpm', 'Pouls'),
                    if (constantes['temperature'] != null)
                      _VitaleCard('${constantes['temperature']}', '°C', 'Temp.'),
                    if (constantes['poids'] != null)
                      _VitaleCard('${constantes['poids']}', 'kg', 'Poids'),
                    if (constantes['taille'] != null)
                      _VitaleCard('${constantes['taille']}', 'cm', 'Taille'),
                    if (constantes['spo2'] != null)
                      _VitaleCard('${constantes['spo2']}', '%', 'SpO₂'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],

        // ── Traitements en cours ─────────────────────────────────────
        if (medicaments.isNotEmpty) ...[
          _SectionTitle(
            icon: Icons.medication_rounded,
            label: 'Traitements en cours',
          ),
          ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: medicaments.length,
            itemBuilder: (_, i) {
              final m = medicaments[i] as Map<String, dynamic>;
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: MedecinDecor.cardShadow,
                ),
                child: Row(
                  children: [
                    Container(
                      width: 30, height: 30,
                      decoration: const BoxDecoration(
                          color: AppColors.primary, shape: BoxShape.circle),
                      child: Center(
                        child: Text('${i + 1}',
                            style: const TextStyle(
                                color: Colors.white, fontWeight: FontWeight.w800,
                                fontSize: 13)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${m['nom'] ?? '—'}'
                            '${(m['dosage']?.toString().isNotEmpty ?? false) ? ' — ${m['dosage']} ${m['unite'] ?? ''}' : ''}'
                            '${(m['frequence']?.toString().isNotEmpty ?? false) ? ' · ${m['frequence']}' : ''}'
                            '${(m['duree']?.toString().isNotEmpty ?? false) ? ' · ${m['duree']} ${m['unite_duree'] ?? ''}' : ''}',
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          if (m['prescrit_le'] != null)
                            Text('Prescrit le ${m['prescrit_le']}',
                                style: const TextStyle(
                                    fontSize: 11, color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  static String _fmt(String raw) {
    try {
      return DateFormat('d MMM yyyy · HH:mm', 'fr_FR')
          .format(DateTime.parse(raw.replaceFirst(' ', 'T')).toLocal());
    } catch (_) {
      return raw;
    }
  }
}

// ── Carte constante vitale ────────────────────────────────────────────────────
class _VitaleCard extends StatelessWidget {
  final String value;
  final String unit;
  final String label;
  const _VitaleCard(this.value, this.unit, this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.ice,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800,
                  color: AppColors.primary)),
          const SizedBox(height: 2),
          Text(unit,
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
          const SizedBox(height: 2),
          Text(label,
              style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

// ── Onglet Ordonnances ────────────────────────────────────────────────────────
class _OrdonnancesTab extends StatelessWidget {
  final List historique;
  const _OrdonnancesTab({required this.historique});

  @override
  Widget build(BuildContext context) {
    // Ne garder que les consultations qui ont des médicaments
    final withMeds = historique
        .where((h) => (h['medicaments'] as List?)?.isNotEmpty == true)
        .toList();

    if (withMeds.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.medication_outlined, size: 56, color: AppColors.textLight),
            SizedBox(height: 12),
            Text('Aucune ordonnance',
                style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: withMeds.length,
      itemBuilder: (_, i) {
        final h = withMeds[i] as Map<String, dynamic>;
        final meds = h['medicaments'] as List;
        final dateRaw = h['date_consultation']?.toString() ?? '';
        final dateLabel = _fmtDate(dateRaw);
        final rxNum = 'rx-${(i + 1).toString().padLeft(3, '0')}';

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(dateLabel,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: MedecinDecor.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // En-tête
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.ice,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(Icons.medical_services_rounded,
                            color: AppColors.primary, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(rxNum,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800, fontSize: 15)),
                            Text('${meds.length} médicament(s)',
                                style: const TextStyle(
                                    fontSize: 12, color: AppColors.textSecondary)),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.success.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: const Text('Signé',
                            style: TextStyle(
                                fontSize: 11, fontWeight: FontWeight.w700,
                                color: AppColors.success)),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  // Liste médicaments
                  ...List.generate(meds.length, (j) {
                    final m = meds[j] as Map<String, dynamic>;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 11,
                            backgroundColor: AppColors.primary,
                            child: Text('${j + 1}',
                                style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10, fontWeight: FontWeight.w800)),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${m['nom'] ?? '—'}'
                              '${(m['dosage']?.toString().isNotEmpty ?? false) ? ' — ${m['dosage']} ${m['unite'] ?? ''}' : ''}',
                              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                  const SizedBox(height: 8),
                  // Boutons PDF + Voir
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            try {
                              await PrescriptionPdfService.previewAndShare(
                                context: context,
                                record: h,
                              );
                            } catch (e) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text('Erreur PDF : $e'),
                                    backgroundColor: AppColors.error,
                                  ),
                                );
                              }
                            }
                          },
                          icon: const Icon(Icons.download_rounded, size: 16),
                          label: const Text('PDF'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _showConsultDetail(context, h),
                          icon: const Icon(Icons.visibility_rounded, size: 16),
                          label: const Text('Voir'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  static String _fmtDate(String raw) {
    try {
      return DateFormat('yyyy-MM-dd', 'fr_FR')
          .format(DateTime.parse(raw.replaceFirst(' ', 'T')).toLocal());
    } catch (_) {
      return raw.substring(0, raw.length > 10 ? 10 : raw.length);
    }
  }

  void _showConsultDetail(BuildContext context, Map<String, dynamic> h) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _ConsultDetailSheet(h: h),
    );
  }
}

// ── Onglet Consultations ──────────────────────────────────────────────────────
class _ConsultationsTab extends StatelessWidget {
  final List historique;
  const _ConsultationsTab({required this.historique});

  @override
  Widget build(BuildContext context) {
    if (historique.isEmpty) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_open_rounded, size: 56, color: AppColors.textLight),
            SizedBox(height: 12),
            Text('Aucune consultation enregistrée',
                style: TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: historique.length,
      itemBuilder: (_, i) {
        final h = historique[i] as Map<String, dynamic>;
        final dateRaw  = h['date_consultation']?.toString() ?? '';
        final dateDay  = _fmtDay(dateRaw);
        final dateTime = _fmtTime(dateRaw);
        final diag     = (h['diagnostic'] ?? '').toString();
        final motif    = (h['motif'] ?? '').toString();
        final medecin  = (h['medecin'] ?? '').toString();
        final service  = (h['service'] ?? '').toString();
        final soap     = (h['soap_a'] ?? h['anamnese'] ?? '').toString();

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(dateDay,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary)),
            const SizedBox(height: 6),
            InkWell(
              onTap: () => _showConsultDetail(context, h),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: MedecinDecor.cardShadow,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.ice,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.folder_rounded,
                          color: AppColors.primary, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            diag.isNotEmpty ? diag : 'Consultation',
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 14),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (motif.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text('Motif : $motif',
                                style: const TextStyle(
                                    fontSize: 12, color: AppColors.textSecondary)),
                          ],
                          if (soap.isNotEmpty) ...[
                            const SizedBox(height: 3),
                            Text(soap,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 12, color: AppColors.textSecondary)),
                          ],
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              const Icon(Icons.person_outline, size: 13,
                                  color: AppColors.textSecondary),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text(
                                  medecin.isNotEmpty ? 'Dr. $medecin' : service,
                                  style: const TextStyle(
                                      fontSize: 11, color: AppColors.textSecondary),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (dateTime.isNotEmpty)
                                Text(dateTime,
                                    style: const TextStyle(
                                        fontSize: 11, color: AppColors.textLight)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const Icon(Icons.chevron_right_rounded,
                        color: AppColors.textLight),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  static String _fmtDay(String raw) {
    try {
      return DateFormat('yyyy-MM-dd', 'fr_FR')
          .format(DateTime.parse(raw.replaceFirst(' ', 'T')).toLocal());
    } catch (_) {
      return raw.substring(0, raw.length > 10 ? 10 : raw.length);
    }
  }

  static String _fmtTime(String raw) {
    try {
      return DateFormat('HH:mm', 'fr_FR')
          .format(DateTime.parse(raw.replaceFirst(' ', 'T')).toLocal());
    } catch (_) {
      return '';
    }
  }

  void _showConsultDetail(BuildContext context, Map<String, dynamic> h) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (_) => _ConsultDetailSheet(h: h),
    );
  }
}

// ── Bottom sheet détail consultation ─────────────────────────────────────────
class _ConsultDetailSheet extends StatelessWidget {
  final Map<String, dynamic> h;
  const _ConsultDetailSheet({required this.h});

  @override
  Widget build(BuildContext context) {
    final diag    = h['diagnostic']?.toString() ?? '—';
    final ordoTxt = h['ordonnance']?.toString() ?? '';
    final soapS   = h['soap_s']?.toString() ?? '';
    final soapO   = h['soap_o']?.toString() ?? '';
    final soapA   = h['soap_a']?.toString() ?? '';
    final soapP   = h['soap_p']?.toString() ?? '';
    final meds    = h['medicaments'] as List? ?? [];
    final exams   = h['examens_complementaires'] as List? ?? [];

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      maxChildSize: 0.95,
      minChildSize: 0.4,
      expand: false,
      builder: (_, ctrl) => Column(
        children: [
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
                const Text('Détail de la consultation',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                const SizedBox(height: 16),

                // SOAP
                if (soapS.isNotEmpty) _soapRow('S', soapS, const Color(0xFF8E44AD)),
                if (soapO.isNotEmpty) _soapRow('O', soapO, const Color(0xFF2980B9)),
                if (soapA.isNotEmpty) _soapRow('A', soapA, const Color(0xFFE67E22)),
                if (soapP.isNotEmpty) _soapRow('P', soapP, const Color(0xFF27AE60)),

                // Diagnostic
                _block('Diagnostic', diag, accent: true),

                // Médicaments
                if (meds.isNotEmpty) ...[
                  const Text('Médicaments prescrits',
                      style: TextStyle(fontWeight: FontWeight.w700,
                          color: AppColors.primary)),
                  const SizedBox(height: 8),
                  ...meds.map((m) {
                    final med = m as Map<String, dynamic>;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6, left: 8),
                      child: Text(
                        '• ${med['nom'] ?? ''}'
                        '${(med['dosage']?.toString().isNotEmpty ?? false) ? ' — ${med['dosage']} ${med['unite'] ?? ''}' : ''}'
                        '${(med['frequence']?.toString().isNotEmpty ?? false) ? ' · ${med['frequence']}' : ''}',
                        style: const TextStyle(fontSize: 13),
                      ),
                    );
                  }),
                  const SizedBox(height: 12),
                ],

                // Examens
                if (exams.isNotEmpty) ...[
                  const Text('Examens complémentaires',
                      style: TextStyle(fontWeight: FontWeight.w700,
                          color: AppColors.primary)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6, runSpacing: 6,
                    children: exams.map((e) {
                      final ex = e as Map<String, dynamic>;
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.ice,
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(ex['nom']?.toString() ?? '',
                            style: const TextStyle(
                                fontSize: 12, color: AppColors.primary,
                                fontWeight: FontWeight.w600)),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                ],

                // Ordonnance texte (fallback)
                if (ordoTxt.isNotEmpty && meds.isEmpty)
                  _block('Ordonnance', ordoTxt),

                // Bouton PDF
                const SizedBox(height: 8),
                FilledButton.icon(
                  onPressed: () async {
                    try {
                      await PrescriptionPdfService.previewAndShare(
                        context: context,
                        record: h,
                      );
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Erreur PDF : $e'),
                              backgroundColor: AppColors.error),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.picture_as_pdf_rounded),
                  label: const Text('Ordonnance PDF'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size(double.infinity, 48),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _soapRow(String letter, String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26, height: 26,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            child: Center(
              child: Text(letter,
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w900,
                      fontSize: 12)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(text, style: const TextStyle(fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _block(String title, String body, {bool accent = false}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: accent ? AppColors.ice : AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: accent
            ? Border.all(color: AppColors.primary.withValues(alpha: 0.25))
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, color: AppColors.primary,
                  fontSize: 12)),
          const SizedBox(height: 4),
          Text(body, style: const TextStyle(fontSize: 13, height: 1.4)),
        ],
      ),
    );
  }
}

// ── Widgets utilitaires ───────────────────────────────────────────────────────
class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String label;
  const _SectionTitle({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.ice,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: 16, color: AppColors.primary),
          ),
          const SizedBox(width: 8),
          Text(label,
              style: const TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 16,
                  color: AppColors.navy)),
        ],
      ),
    );
  }
}

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
