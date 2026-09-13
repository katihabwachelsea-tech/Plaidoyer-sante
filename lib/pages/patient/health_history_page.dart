import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/patient_api_service.dart';
import '../../widgets/metric_card.dart';
import 'payment_page.dart';

class HealthHistoryPage extends StatefulWidget {
  final int initialTab;

  const HealthHistoryPage({super.key, this.initialTab = 0});

  @override
  State<HealthHistoryPage> createState() => _HealthHistoryPageState();
}

class _HealthHistoryPageState extends State<HealthHistoryPage> {
  final _api = PatientApiService.instance;
  List<Map<String, dynamic>> _records = [];
  bool _loading = true;
  String? _error;

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
      if (mounted) setState(() => _records = list);
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
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
      return const Center(child: CircularProgressIndicator(color: AppColors.primary));
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
              'Aucune consultation enregistrée.\nVos comptes rendus apparaîtront ici après le rendez-vous.',
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
        final doctor = medecin?['user']?['nom'] ?? 'Médecin';
        final service = (appt?['service'] as Map?)?['nom_service'] ?? 'Consultation';
        final raw = (item['date_consultation'] ?? '').toString();
        var date = raw;
        try {
          date = fmt.format(DateTime.parse(raw.replaceFirst(' ', 'T')).toLocal());
        } catch (_) {}

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(doctor, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text('$service • $date', style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 10),
              Text('Diagnostic', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
              Text((item['diagnostic'] ?? '—').toString()),
              if ((item['ordonnance'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('Ordonnance', style: TextStyle(fontWeight: FontWeight.w600)),
                Text(item['ordonnance'].toString()),
              ],
              if ((item['conseils_ia'] ?? '').toString().isNotEmpty) ...[
                const SizedBox(height: 8),
                const Text('Notes du médecin', style: TextStyle(fontWeight: FontWeight.w600)),
                Text(item['conseils_ia'].toString()),
              ],
              _invoiceLine(item),
            ],
          ),
        );
      },
    );
  }

  Widget _invoiceLine(Map<String, dynamic> item) {
    final appt = item['appointment'];
    if (appt is! Map) return const SizedBox.shrink();
    final invoice = appt['invoice'];
    if (invoice is! Map || invoice['montant'] == null) return const SizedBox.shrink();
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
