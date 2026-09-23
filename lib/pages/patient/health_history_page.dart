import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/app_config.dart';
import '../../services/patient_api_service.dart';
import '../../services/prescription_pdf_service.dart';
import '../../utils/doctor_photo.dart';
import '../../widgets/metric_card.dart';
import 'payment_page.dart';

class HealthHistoryPage extends StatefulWidget {
  /// Si fourni, ouvre automatiquement le compte rendu de ce RDV (deep-link notif).
  final int? openAppointmentId;

  const HealthHistoryPage({super.key, this.openAppointmentId});

  @override
  State<HealthHistoryPage> createState() => _HealthHistoryPageState();
}

class _HealthHistoryPageState extends State<HealthHistoryPage> {
  final _api = PatientApiService.instance;
  List<Map<String, dynamic>> _records = [];
  bool _loading = true;
  String? _error;
  bool _didAutoOpen = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _api.getMedicalRecord();
      if (mounted) {
        setState(() => _records = list);
        _maybeAutoOpen();
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _maybeAutoOpen() {
    final target = widget.openAppointmentId;
    if (_didAutoOpen || target == null || _records.isEmpty) return;
    Map<String, dynamic>? match;
    for (final item in _records) {
      final apptId = item['appointment_id'] ?? item['appointment']?['id'];
      final id = apptId is int ? apptId : int.tryParse('$apptId');
      if (id == target) {
        match = item;
        break;
      }
    }
    if (match == null) return;
    _didAutoOpen = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ConsultationDetailPage(record: match!),
        ),
      );
    });
  }

  bool _isRecent(Map<String, dynamic> item) {
    try {
      final raw = (item['date_consultation'] ?? '').toString();
      final dt = DateTime.parse(raw.replaceFirst(' ', 'T')).toLocal();
      return DateTime.now().difference(dt).inDays <= 3;
    } catch (_) {
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Dossier médical'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
      ),
      body: RefreshIndicator(onRefresh: _load, child: _body()),
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
    if (_records.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 80),
          Center(
            child: Text(
              'Aucune consultation enregistrée.\nVos comptes rendus et ordonnances apparaîtront ici.',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      );
    }

    final fmt = DateFormat('d MMM yyyy', 'fr_FR');
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16),
      itemCount: _records.length,
      itemBuilder: (context, index) {
        final item = _records[index];
        final appt = item['appointment'] as Map<String, dynamic>?;
        final medecin = appt?['medecin'] as Map<String, dynamic>?;
        final doctorUser = medecin?['user'] as Map?;
        final doctor = doctorUser?['nom'] ?? 'Médecin';
        final serviceMap = appt?['service'] as Map?;
        final service = serviceMap?['nom_service'] ?? 'Consultation';
        final mode = (serviceMap?['mode'] ?? '').toString();
        final raw = (item['date_consultation'] ?? '').toString();
        var date = raw;
        try {
          date =
              fmt.format(DateTime.parse(raw.replaceFirst(' ', 'T')).toLocal());
        } catch (_) {}
        final recent = _isRecent(item);
        final hasOrdonnance =
            (item['ordonnance'] ?? '').toString().trim().isNotEmpty;
        final hasSignature =
            (item['signature_path'] ?? '').toString().isNotEmpty;

        return InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => ConsultationDetailPage(record: item),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: recent
                    ? AppColors.primary.withValues(alpha: 0.35)
                    : AppColors.border,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    DoctorPhotoImage(
                      url: doctorPhotoUrl({
                        'nom': doctor,
                        'photo_url': doctorUser?['photo_url'],
                        'user': doctorUser,
                      }),
                      width: 44,
                      height: 44,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(doctor.toString(),
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 16)),
                          Text('$service • $date',
                              style: TextStyle(color: AppColors.textSecondary)),
                        ],
                      ),
                    ),
                    if (recent)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: const Text('Nouveau',
                            style: TextStyle(
                                color: AppColors.primary,
                                fontSize: 11,
                                fontWeight: FontWeight.w800)),
                      ),
                  ],
                ),
                if (mode.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    mode == 'teleconsultation'
                        ? 'Téléconsultation'
                        : 'Présentiel',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: mode == 'teleconsultation'
                          ? AppColors.info
                          : AppColors.success,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Text('Diagnostic',
                    style: TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600)),
                Text((item['diagnostic'] ?? '—').toString()),
                if (hasOrdonnance) ...[
                  const SizedBox(height: 8),
                  const Text('Ordonnance',
                      style: TextStyle(fontWeight: FontWeight.w600)),
                  Text(
                    item['ordonnance'].toString(),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    if (hasSignature)
                      const _MiniChip(
                          icon: Icons.draw_rounded, label: 'Signé'),
                    if (hasOrdonnance) ...[
                      const SizedBox(width: 6),
                      const _MiniChip(
                          icon: Icons.medication_rounded,
                          label: 'Ordonnance'),
                    ],
                  ],
                ),
                _invoiceLine(item),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _invoiceLine(Map<String, dynamic> item) {
    final appt = item['appointment'];
    if (appt is! Map) return const SizedBox.shrink();
    final invoice = appt['invoice'];
    if (invoice is! Map || invoice['montant'] == null) {
      return const SizedBox.shrink();
    }
    final paid = invoice['statut_paiement'] == 'Paye';
    final amount = formatFbu(num.tryParse('${invoice['montant']}'));
    final ref = invoice['transaction_id'];

    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Text(
        paid
            ? 'Facture $amount · Payée${ref == null ? '' : ' · $ref'}'
            : 'Facture $amount · Non payée',
        style: TextStyle(
          fontWeight: FontWeight.w700,
          color: paid ? AppColors.success : AppColors.warning,
        ),
      ),
    );
  }
}

class _MiniChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MiniChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.ice,
        borderRadius: BorderRadius.circular(99),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(label,
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary)),
        ],
      ),
    );
  }
}

class ConsultationDetailPage extends StatelessWidget {
  final Map<String, dynamic> record;

  const ConsultationDetailPage({super.key, required this.record});

  String _absUrl(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    final base = AppConfig.baseUrl.replaceAll('/api', '');
    return path.startsWith('/') ? '$base$path' : '$base/$path';
  }

  @override
  Widget build(BuildContext context) {
    final appt = record['appointment'] as Map<String, dynamic>?;
    final medecin = appt?['medecin'] as Map<String, dynamic>?;
    final doctorUser = medecin?['user'] as Map?;
    final doctor = (doctorUser?['nom'] ?? 'Médecin').toString();
    final hopital = (medecin?['hopital'] ?? '').toString();
    final specialite = (medecin?['specialite'] ?? '').toString();
    final serviceMap = appt?['service'] as Map?;
    final service = (serviceMap?['nom_service'] ?? 'Consultation').toString();
    final mode = (serviceMap?['mode'] ?? '').toString();
    final signature = _absUrl(record['signature_path']?.toString());
    final invoice = appt?['invoice'] as Map?;

    var dateLabel = (record['date_consultation'] ?? '').toString();
    try {
      dateLabel = DateFormat("EEEE d MMMM yyyy · HH:mm", 'fr_FR').format(
        DateTime.parse(dateLabel.replaceFirst(' ', 'T')).toLocal(),
      );
    } catch (_) {}

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Compte rendu'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        actions: [
          // Bouton télécharger PDF
          IconButton(
            icon: const Icon(Icons.download_rounded),
            tooltip: 'Télécharger l\'ordonnance PDF',
            onPressed: () async {
              try {
                await PrescriptionPdfService.previewAndShare(
                  context: context,
                  record: record,
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
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          try {
            await PrescriptionPdfService.previewAndShare(
              context: context,
              record: record,
            );
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text('Erreur PDF : $e'),
                    backgroundColor: AppColors.error),
              );
            }
          }
        },
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.picture_as_pdf_rounded),
        label: const Text('Ordonnance PDF',
            style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                DoctorPhotoImage(
                  url: doctorPhotoUrl({
                    'nom': doctor,
                    'photo_url': doctorUser?['photo_url'],
                    'user': doctorUser,
                  }),
                  width: 56,
                  height: 56,
                  borderRadius: BorderRadius.circular(28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(doctor,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.w800)),
                      if (specialite.isNotEmpty)
                        Text(specialite,
                            style:
                                const TextStyle(color: AppColors.textSecondary)),
                      if (hopital.isNotEmpty)
                        Text(hopital,
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Text(service,
              style:
                  const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
          Text(dateLabel,
              style: const TextStyle(color: AppColors.textSecondary)),
          if (mode.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                mode == 'teleconsultation' ? 'Téléconsultation' : 'Présentiel',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: mode == 'teleconsultation'
                      ? AppColors.info
                      : AppColors.success,
                ),
              ),
            ),
          const SizedBox(height: 16),
          if ((record['anamnese'] ?? '').toString().isNotEmpty)
            _block('Anamnèse', record['anamnese'].toString()),
          if ((record['examen'] ?? '').toString().isNotEmpty)
            _block('Examen clinique', record['examen'].toString()),
          _block('Diagnostic', (record['diagnostic'] ?? '—').toString()),
          _block('Ordonnance', (record['ordonnance'] ?? '—').toString(),
              accent: true),
          if ((record['conseils_ia'] ?? '').toString().isNotEmpty)
            _block('Notes / conseils', record['conseils_ia'].toString()),
          if (signature.isNotEmpty) ...[
            const Text('Signature du médecin',
                style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 8),
            Container(
              height: 140,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.border),
              ),
              child: Image.network(
                signature,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => const Center(
                  child: Text('Signature indisponible'),
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (invoice != null && invoice['montant'] != null)
            _invoiceCard(invoice),
        ],
      ),
    );
  }

  Widget _invoiceCard(Map invoice) {
    final paid = invoice['statut_paiement'] == 'Paye';
    final amount = formatFbu(num.tryParse('${invoice['montant']}'));
    final method = (invoice['methode_paiement'] ?? '—').toString();
    final ref = (invoice['transaction_id'] ?? '—').toString();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Facture',
              style: TextStyle(
                  fontWeight: FontWeight.w700, color: AppColors.primary)),
          const SizedBox(height: 8),
          Text('Montant : $amount'),
          Text('Statut : ${paid ? 'Payée' : 'Non payée'}',
              style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: paid ? AppColors.success : AppColors.warning)),
          if (paid) ...[
            Text('Moyen : $method'),
            Text('Réf. : $ref'),
          ],
        ],
      ),
    );
  }

  Widget _block(String title, String body, {bool accent = false}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: accent ? AppColors.ice : Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: accent
              ? AppColors.primary.withValues(alpha: 0.25)
              : AppColors.border,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontWeight: FontWeight.w700, color: AppColors.primary)),
          const SizedBox(height: 6),
          Text(body, style: const TextStyle(height: 1.4)),
        ],
      ),
    );
  }
}
