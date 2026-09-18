import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../services/patient_api_service.dart';
import '../../widgets/metric_card.dart';
import '../doctors_list_page.dart';
import 'payment_page.dart';

class PatientAppointmentsPage extends StatefulWidget {
  const PatientAppointmentsPage({super.key});

  @override
  State<PatientAppointmentsPage> createState() => _PatientAppointmentsPageState();
}

class _PatientAppointmentsPageState extends State<PatientAppointmentsPage> {
  final _api = PatientApiService.instance;
  List<Map<String, dynamic>> _appointments = [];
  bool _isLoading = true;
  String? _error;
  bool _showAll = false;
  static const int _previewCount = 5;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final list = await _api.getAppointments();
      if (mounted) {
        setState(() {
          _appointments = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _cancel(int id) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Annuler le rendez-vous ?'),
        content: const Text('Le créneau sera libéré pour un autre patient.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Non')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Annuler le RDV')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.cancelAppointment(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rendez-vous annulé'), backgroundColor: AppColors.success),
        );
      }
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _pay(Map<String, dynamic> appt) async {
    final paid = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => PaymentPage(appointment: appt)),
    );
    if (paid == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mes rendez-vous'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualiser',
            onPressed: _load,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const DoctorsListPage()),
        ).then((_) => _load()),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Prendre RDV'),
      ),
      body: RefreshIndicator(onRefresh: _load, child: _body()),
    );
  }

  Widget _body() {
    if (_isLoading) {
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
    if (_appointments.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: const [
          SizedBox(height: 80),
          Center(child: Text('Aucun rendez-vous pour le moment.')),
        ],
      );
    }

    final fmt = DateFormat('EEE d MMM yyyy • HH:mm', 'fr_FR');
    final visible = _showAll
        ? _appointments
        : _appointments.take(_previewCount).toList();
    final hasMore = _appointments.length > _previewCount;

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      itemCount: visible.length + (hasMore ? 1 : 0),
      itemBuilder: (context, index) {
        // Bouton voir plus / voir moins en bas de liste
        if (index == visible.length) {
          return Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 16),
            child: OutlinedButton.icon(
              onPressed: () => setState(() => _showAll = !_showAll),
              icon: Icon(_showAll
                  ? Icons.expand_less_rounded
                  : Icons.expand_more_rounded),
              label: Text(_showAll
                  ? 'Voir moins'
                  : 'Voir plus (${_appointments.length - _previewCount} autres)'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.primary,
                side: const BorderSide(color: AppColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          );
        }

        final appt = visible[index];
        final medecin = appt['medecin'] as Map<String, dynamic>?;
        final doctor = medecin?['user']?['nom'] ?? 'Médecin';
        final service = (appt['service'] as Map?)?['nom_service'] ?? 'Consultation';
        final statut = (appt['statut'] ?? '').toString();
        final invoice = appt['invoice'] as Map<String, dynamic>?;
        final rawDate = (appt['date_rdv'] ?? '').toString();
        var label = rawDate;
        var isFuture = false;
        try {
          final dt = DateTime.parse(rawDate.replaceFirst(' ', 'T'));
          label = fmt.format(dt.toLocal());
          isFuture = dt.isAfter(DateTime.now());
        } catch (_) {}

        final canPay = statut == 'En_attente' && isFuture;
        final canCancel = (statut == 'En_attente' || statut == 'Confirme') && isFuture;

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: 0.06), blurRadius: 10, offset: const Offset(0, 3)),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(doctor, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ),
                  _StatusChip(statut: statut),
                ],
              ),
              const SizedBox(height: 6),
              Text('$service • ${appt['motif'] ?? ''}', style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              Text(label),
              if (invoice?['montant'] != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '${formatFbu(num.tryParse('${invoice!['montant']}'))}'
                    '${invoice['statut_paiement'] == 'Paye' ? ' · Payé' : ' · À payer'}'
                    '${invoice['transaction_id'] != null ? '\nReçu ${invoice['transaction_id']}' : ''}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              if (canPay || canCancel) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    if (canPay)
                      Expanded(
                        child: FilledButton(
                          onPressed: () => _pay(appt),
                          child: const Text('Payer'),
                        ),
                      ),
                    if (canPay && canCancel) const SizedBox(width: 8),
                    if (canCancel)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _cancel(appt['id'] as int),
                          child: const Text('Annuler'),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String statut;
  const _StatusChip({required this.statut});

  @override
  Widget build(BuildContext context) {
    final color = switch (statut) {
      'Confirme' => AppColors.success,
      'Termine' => AppColors.info,
      'Annule' => AppColors.error,
      _ => AppColors.warning,
    };
    final label = switch (statut) {
      'Confirme' => 'Confirmé',
      'En_attente' => 'À payer',
      'Termine' => 'Terminé',
      'Annule' => 'Annulé',
      _ => statut,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold)),
    );
  }
}
