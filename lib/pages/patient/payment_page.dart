import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/local_reminder_service.dart';
import '../../services/patient_api_service.dart';
import '../../widgets/metric_card.dart';

class PaymentPage extends StatefulWidget {
  final Map<String, dynamic> appointment;

  const PaymentPage({super.key, required this.appointment});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  final _phoneController = TextEditingController();
  String _method = 'Ecocash';
  bool _paying = false;
  Map<String, dynamic>? _receipt;

  int get _appointmentId {
    final raw = widget.appointment['id'];
    if (raw is int) return raw;
    return int.parse('$raw');
  }

  Map<String, dynamic>? get _invoice {
    final raw = widget.appointment['invoice'];
    if (raw is Map) return Map<String, dynamic>.from(raw);
    return null;
  }

  String get _doctorName {
    final medecin = widget.appointment['medecin'];
    if (medecin is Map) {
      final user = medecin['user'];
      if (user is Map && user['nom'] != null) {
        final raw = user['nom'].toString();
        return raw.toLowerCase().startsWith('dr') ? raw : 'Dr. $raw';
      }
    }
    return 'Médecin';
  }

  String get _serviceName {
    final service = widget.appointment['service'];
    if (service is Map && service['nom_service'] != null) {
      return service['nom_service'].toString();
    }
    return 'Consultation';
  }

  num? get _amount {
    final raw = _invoice?['montant'] ?? widget.appointment['montant'];
    if (raw == null) return null;
    return num.tryParse('$raw');
  }

  String get _dateLabel => (widget.appointment['date_rdv'] ?? '').toString();

  @override
  void initState() {
    super.initState();
    _phoneController.text = AuthService.instance.currentUser?.telephone ?? '';
  }

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pay() async {
    final phone = _phoneController.text.trim();
    if (phone.length < 8) {
      _showError('Entrez un numéro de téléphone valide');
      return;
    }

    setState(() => _paying = true);
    await Future<void>.delayed(const Duration(milliseconds: 900));

    try {
      final result = await PatientApiService.instance.payAppointment(
        id: _appointmentId,
        methode: _method,
        telephone: phone,
      );
      if (!mounted) return;
      setState(() {
        _receipt = {
          'transaction_id': result['transaction_id'],
          'methode': _method,
          'telephone': phone,
          'montant': _amount,
          'doctor': _doctorName,
          'service': _serviceName,
          'date': _dateLabel,
        };
        _paying = false;
      });

      // Rappels locaux J-1 / H-2
      try {
        final data = result['data'];
        final raw = (data is Map ? data['date_rdv'] : null) ??
            widget.appointment['date_rdv'];
        final dt = DateTime.parse(raw.toString().replaceFirst(' ', 'T'));
        await LocalReminderService.instance.scheduleForAppointment(
          appointmentId: _appointmentId,
          dateRdv: dt,
          title: 'RDV $_doctorName',
          body: '$_serviceName · ${_dateLabel}',
        );
      } catch (_) {}
    } catch (e) {
      if (mounted) {
        setState(() => _paying = false);
        _showError('$e');
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.error),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_receipt != null) {
      return _ReceiptView(receipt: _receipt!);
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Paiement Mobile Money'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_doctorName, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(_serviceName, style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                      if (_dateLabel.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(_dateLabel, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      ],
                      const SizedBox(height: 14),
                      const Text('Montant à payer', style: TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      Text(
                        formatFbu(_amount),
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                const Text('Choisir le moyen de paiement', style: TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                _methodCard(
                  id: 'Ecocash',
                  title: 'Ecocash',
                  subtitle: 'Simulation — aucun débit réel',
                ),
                const SizedBox(height: 8),
                _methodCard(
                  id: 'Lumicash',
                  title: 'Lumicash',
                  subtitle: 'Simulation — aucun débit réel',
                ),
                const SizedBox(height: 18),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Numéro Mobile Money',
                    hintText: '79 000 000',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Démo de soutenance : le paiement est simulé. Le rendez-vous passe à Confirmé et un reçu est généré.',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
            decoration: const BoxDecoration(
              color: AppColors.cardBackground,
              border: Border(top: BorderSide(color: AppColors.border)),
            ),
            child: SafeArea(
              top: false,
              child: SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _paying ? null : _pay,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: _paying
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Text('Payer ${_method} · ${formatFbu(_amount)}'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _methodCard({required String id, required String title, required String subtitle}) {
    final selected = _method == id;
    return InkWell(
      onTap: () => setState(() => _method = id),
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary.withValues(alpha: 0.08) : AppColors.cardBackground,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: selected ? AppColors.primary : AppColors.border, width: selected ? 1.5 : 1),
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: selected ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
                  Text(subtitle, style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReceiptView extends StatelessWidget {
  final Map<String, dynamic> receipt;

  const _ReceiptView({required this.receipt});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
          child: Column(
            children: [
              const Spacer(),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: AppColors.success.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.check_rounded, color: AppColors.success, size: 36),
                    ),
                    const SizedBox(height: 14),
                    const Text(
                      'Paiement confirmé',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Le rendez-vous est confirmé. Le médecin le voit maintenant.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 18),
                    Text(
                      formatFbu(receipt['montant'] as num?),
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _line('Référence', '${receipt['transaction_id'] ?? '—'}'),
                    _line('Moyen', '${receipt['methode']}'),
                    _line('Téléphone', '${receipt['telephone']}'),
                    _line('Médecin', '${receipt['doctor']}'),
                    _line('Prestation', '${receipt['service']}'),
                    const SizedBox(height: 8),
                    const Text(
                      'Simulation Mobile Money — reçu numérique Plaidoyer Santé',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
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
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  child: const Text('Terminer'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _line(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          SizedBox(width: 96, child: Text(label, style: const TextStyle(color: AppColors.textSecondary))),
          Expanded(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}

String formatFbu(num? value) {
  if (value == null) return '—';
  final digits = value.round().toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    final fromEnd = digits.length - i;
    if (i > 0 && fromEnd % 3 == 0) buf.write(' ');
    buf.write(digits[i]);
  }
  return '${buf.toString()} FBu';
}
