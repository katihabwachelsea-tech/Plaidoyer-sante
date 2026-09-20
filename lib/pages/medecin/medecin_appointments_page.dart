import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/appointment.dart';
import '../../services/medecin_api_service.dart';
import '../../widgets/metric_card.dart';
import 'consultation_form_page.dart';
import 'medecin_ui.dart';

class MedecinAppointmentsPage extends StatefulWidget {
  const MedecinAppointmentsPage({super.key});

  @override
  State<MedecinAppointmentsPage> createState() => _MedecinAppointmentsPageState();
}

class _MedecinAppointmentsPageState extends State<MedecinAppointmentsPage> {
  final _api = MedecinApiService.instance;
  List<Appointment> _appointments = [];
  bool _isLoading = true;
  String? _error;
  String _filter = 'today';
  bool _showAll = false;
  static const int _previewCount = 5;

  @override
  void initState() {
    super.initState();
    _loadAppointments();
  }

  Future<void> _loadAppointments() async {
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

  List<Appointment> get _visible {
    final now = DateTime.now();
    bool isSameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;

    switch (_filter) {
      case 'today':
        return _appointments.where((a) => isSameDay(a.dateHeure.toLocal(), now)).toList();
      case 'upcoming':
        return _appointments.where((a) => a.dateHeure.toLocal().isAfter(now)).toList();
      default:
        return _appointments;
    }
  }

  Future<void> _cancel(Appointment rdv) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Annuler ce rendez-vous ?'),
        content: Text('Le RDV de ${rdv.patientDisplayName} sera annulé.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Non')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Annuler')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.cancelAppointment(rdv.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Rendez-vous annulé'), backgroundColor: AppColors.success),
        );
      }
      await _loadAppointments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _startConsultation(Appointment rdv) async {
    if (!rdv.isToday) {
      final dateLabel = DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(rdv.dateHeure.toLocal());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Consultation possible uniquement le jour du RDV ($dateLabel).'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }
    final done = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => ConsultationFormPage(appointment: rdv)),
    );
    if (done == true) _loadAppointments();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _loadAppointments,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                decoration: const BoxDecoration(gradient: MedecinDecor.headerGradient),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Agenda',
                          style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_appointments.length} rendez-vous confirmés et payés',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(
                  children: [
                    _FilterChip(label: 'Aujourd’hui', selected: _filter == 'today', onTap: () => setState(() => _filter = 'today')),
                    const SizedBox(width: 8),
                    _FilterChip(label: 'À venir', selected: _filter == 'upcoming', onTap: () => setState(() => _filter = 'upcoming')),
                    const SizedBox(width: 8),
                    _FilterChip(label: 'Tous', selected: _filter == 'all', onTap: () => setState(() => _filter = 'all')),
                  ],
                ),
              ),
            ),
            if (_isLoading)
              const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
            else if (_error != null)
              SliverFillRemaining(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        ElevatedButton(onPressed: _loadAppointments, child: const Text('Réessayer')),
                      ],
                    ),
                  ),
                ),
              )
            else if (_visible.isEmpty)
              const SliverFillRemaining(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: EmptyHint(
                    icon: Icons.event_busy_rounded,
                    title: 'Aucun rendez-vous ici',
                    subtitle: 'Les RDV n’apparaissent qu’après paiement du professionnel.',
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
                sliver: SliverList.builder(
                  itemCount: _showAll
                      ? _visible.length + (_visible.length > _previewCount ? 1 : 0)
                      : _visible.take(_previewCount).length +
                          (_visible.length > _previewCount ? 1 : 0),
                  itemBuilder: (context, index) {
                    final list = _visible;
                    final visibleList =
                        _showAll ? list : list.take(_previewCount).toList();

                    // Bouton voir plus / voir moins
                    if (index == visibleList.length && list.length > _previewCount) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 12),
                        child: OutlinedButton.icon(
                          onPressed: () => setState(() => _showAll = !_showAll),
                          icon: Icon(_showAll
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded),
                          label: Text(_showAll
                              ? 'Voir moins'
                              : 'Voir plus (${list.length - _previewCount} autres)'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side: const BorderSide(color: AppColors.primary),
                            padding:
                                const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      );
                    }

                    if (index >= visibleList.length) return const SizedBox.shrink();
                    final rdv = visibleList[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _AppointmentCard(
                        appointment: rdv,
                        onConsult: () => _startConsultation(rdv),
                        onCancel: () => _cancel(rdv),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(99),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(99),
            boxShadow: selected ? null : MedecinDecor.cardShadow,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: selected ? Colors.white : AppColors.navy,
              fontWeight: FontWeight.w700,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  final Appointment appointment;
  final VoidCallback onConsult;
  final VoidCallback onCancel;

  const _AppointmentCard({
    required this.appointment,
    required this.onConsult,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('EEE d MMM', 'fr_FR').format(appointment.dateHeure.toLocal());
    final time = DateFormat('HH:mm').format(appointment.dateHeure.toLocal());
    final canConsult = appointment.isToday && appointment.isConfirme;

    return MedecinCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              DoctorAvatar(name: appointment.patientDisplayName, radius: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appointment.patientDisplayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                    Text(
                      appointment.motif,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: const Text('Payé', style: TextStyle(color: AppColors.success, fontSize: 11, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.ice,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_rounded, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(child: Text('$date  ·  $time', style: const TextStyle(fontWeight: FontWeight.w700))),
                if (appointment.paymentRef != null)
                  Flexible(
                    child: Text(
                      appointment.paymentRef!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ),
              ],
            ),
          ),
          if (!appointment.isToday) ...[
            const SizedBox(height: 10),
            Text(
              'Consultation disponible le jour du rendez-vous uniquement.',
              style: TextStyle(fontSize: 12, color: AppColors.warning.withValues(alpha: 0.95)),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onCancel,
                  child: const Text('Annuler'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: canConsult ? onConsult : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor: AppColors.primary.withValues(alpha: 0.35),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: Text(canConsult ? 'Consulter' : 'Pas encore'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
