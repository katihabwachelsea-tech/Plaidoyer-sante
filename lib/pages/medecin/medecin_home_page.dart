import 'package:flutter/material.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/appointment.dart';
import '../../services/auth_service.dart';
import '../../services/medecin_api_service.dart';
import '../../utils/doctor_photo.dart';
import '../../widgets/metric_card.dart';
import '../../widgets/notification_bell.dart';
import 'consultation_form_page.dart';
import 'medecin_ui.dart';

class MedecinHomePage extends StatefulWidget {
  final ValueChanged<int>? onOpenTab;

  const MedecinHomePage({super.key, this.onOpenTab});

  @override
  State<MedecinHomePage> createState() => _MedecinHomePageState();
}

class _MedecinHomePageState extends State<MedecinHomePage> {
  final _api = MedecinApiService.instance;
  int _todayCount = 0;
  int _upcomingCount = 0;
  int _patientsCount = 0;
  int _creneauxCount = 0;
  int _consultationsCount = 0;
  bool _isLoading = true;
  String? _error;
  String _doctorName = 'Médecin';
  List<Appointment> _today = [];

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await _api.getDashboard();
      final today = await _api.getAppointments(todayOnly: true);
      if (mounted) {
        setState(() {
          _today = today;
          _todayCount = _asInt(data['today_count']);
          _upcomingCount = _asInt(data['upcoming_count']);
          _patientsCount = _asInt(data['patients_count']);
          _creneauxCount = _asInt(data['creneaux_week_count']);
          _consultationsCount = _asInt(data['consultations_count']);
          _doctorName = (data['nom'] ?? 'Médecin').toString();
          _isLoading = false;
        });
      }
    } catch (e) {
      final user = AuthService.instance.currentUser;
      if (mounted) {
        setState(() {
          _doctorName = user?.fullName ?? 'Médecin';
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  int _asInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse('$value') ?? 0;
  }

  String get _shortName {
    final parts = _doctorName.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) return parts.last;
    return _doctorName;
  }

  Future<void> _acceptRdv(Appointment rdv) async {
    try {
      await _api.acceptAppointment(rdv.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Demande acceptée — le patient peut maintenant payer'),
          backgroundColor: AppColors.success,
        ));
        _loadDashboard();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$e'), backgroundColor: AppColors.error));
      }
    }
  }

  Future<void> _refuseRdv(Appointment rdv) async {
    final raisonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Refuser cette demande ?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Patient : ${rdv.patientDisplayName}'),
            const SizedBox(height: 12),
            TextField(
              controller: raisonCtrl,
              decoration: const InputDecoration(
                labelText: 'Raison (optionnel)',
                hintText: 'Ex. Pas dans ma spécialité...',
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Annuler')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppColors.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Refuser'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _api.refuseAppointment(rdv.id,
          raison: raisonCtrl.text.trim().isEmpty ? null : raisonCtrl.text.trim());
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Demande refusée'),
            backgroundColor: AppColors.warning));
        _loadDashboard();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$e'), backgroundColor: AppColors.error));
      }
    }
  }

  void _handleTodayTile(Appointment rdv) {
    switch (rdv.statut) {
      case 'En_attente':
        // Afficher bottom sheet avec Accepter / Refuser
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.white,
          shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
          builder: (_) => _PendingBottomSheet(
            appointment: rdv,
            onAccept: () {
              Navigator.pop(context);
              _acceptRdv(rdv);
            },
            onRefuse: () {
              Navigator.pop(context);
              _refuseRdv(rdv);
            },
          ),
        );
      case 'Accepte':
        // Informer que le patient n'a pas encore payé
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('En attente du paiement du patient.'),
          backgroundColor: AppColors.info,
        ));
      case 'Confirme':
        // Ouvrir la consultation (uniquement le jour J — vérifié dans _openConsultation)
        _openConsultation(rdv);
      default:
        break;
    }
  }

  Future<void> _openConsultation(Appointment rdv) async {
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
    if (done == true) _loadDashboard();
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = DateFormat("EEEE d MMMM", 'fr_FR').format(DateTime.now());

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _loadDashboard,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _Header(name: _shortName, dateLabel: dateLabel)),
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _KpiStrip(
                            items: [
                              _KpiData('Aujourd’hui', '$_todayCount', 'RDV payés', Icons.event_available_rounded, const Color(0xFF0B6EBD), () => widget.onOpenTab?.call(1)),
                              _KpiData('À venir', '$_upcomingCount', 'Confirmés', Icons.event_repeat_rounded, const Color(0xFF0E9F6E), () => widget.onOpenTab?.call(1)),
                              _KpiData('Créneaux', '$_creneauxCount', 'Cette semaine', Icons.schedule_rounded, const Color(0xFF3B82F6), () => widget.onOpenTab?.call(2)),
                              _KpiData('Patients', '$_patientsCount', 'Suivis', Icons.groups_rounded, const Color(0xFFF59E0B), () => widget.onOpenTab?.call(1)),
                              _KpiData('Dossiers', '$_consultationsCount', 'Consultés', Icons.folder_shared_rounded, const Color(0xFF8B5CF6), () => widget.onOpenTab?.call(1)),
                            ],
                          ),
                          const SizedBox(height: 22),
                          SectionLabel(
                            title: 'Agenda du jour',
                            action: 'Voir tout',
                            onAction: () => widget.onOpenTab?.call(1),
                          ),
                          const SizedBox(height: 10),
                          if (_today.isEmpty)
                            const EmptyHint(
                              icon: Icons.wb_sunny_outlined,
                              title: 'Journée encore libre',
                              subtitle: 'Les rendez-vous payés d’aujourd’hui apparaîtront ici, prêts à être consultés.',
                            )
                          else
                            ..._today.map((rdv) => Padding(
                                  padding: const EdgeInsets.only(bottom: 12),
                                  child: _TodayTile(
                                    appointment: rdv,
                                    onTap: () => _handleTodayTile(rdv),
                                  ),
                                )),
                          const SizedBox(height: 18),
                          const SectionLabel(title: 'Actions rapides'),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _QuickAction(
                                  icon: Icons.add_alarm_rounded,
                                  label: 'Créneau',
                                  onTap: () => widget.onOpenTab?.call(2),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _QuickAction(
                                  icon: Icons.medical_services_rounded,
                                  label: 'Consultations',
                                  onTap: () => widget.onOpenTab?.call(1),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: _QuickAction(
                                  icon: Icons.person_rounded,
                                  label: 'Profil',
                                  onTap: () => widget.onOpenTab?.call(3),
                                ),
                              ),
                            ],
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: 16),
                            MedecinCard(
                              child: Text(
                                'API indisponible.\n$_error',
                                style: const TextStyle(fontSize: 12, color: AppColors.warning),
                              ),
                            ),
                          ],
                          const SizedBox(height: 28),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final String name;
  final String dateLabel;

  const _Header({required this.name, required this.dateLabel});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(gradient: MedecinDecor.headerGradient),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 48),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateLabel,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.78),
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Bonjour, $name',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Votre cabinet, prêt pour la journée.',
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.82),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              NotificationBell(color: Colors.white),
              const SizedBox(width: 4),
              DoctorAvatar(
                name: name,
                radius: 26,
                background: Colors.white,
                foreground: AppColors.primary,
                imageUrl: doctorPhotoUrl({
                  'nom': name,
                  'photo_url': AuthService.instance.currentUser?.profileImageUrl,
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _KpiData {
  final String title;
  final String value;
  final String meta;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _KpiData(this.title, this.value, this.meta, this.icon, this.color, this.onTap);
}

class _KpiStrip extends StatelessWidget {
  final List<_KpiData> items;
  const _KpiStrip({required this.items});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 148,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final item = items[index];
          return InkWell(
            onTap: item.onTap,
            borderRadius: BorderRadius.circular(20),
            child: Container(
              width: 148,
              padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: MedecinDecor.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: item.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(item.icon, size: 18, color: item.color),
                  ),
                  const Spacer(),
                  Text(
                    item.value,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                      color: item.color,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  Text(
                    item.meta,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 11),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _TodayTile extends StatelessWidget {
  final Appointment appointment;
  final VoidCallback onTap;

  const _TodayTile({required this.appointment, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('HH:mm').format(appointment.dateHeure.toLocal());

    // Libellé et couleur du bouton selon le statut
    final (btnLabel, btnColor) = switch (appointment.statut) {
      'En_attente' => ('Valider', AppColors.warning),
      'Accepte'    => ('En attente paiement', AppColors.info),
      'Confirme'   => ('Consulter', AppColors.primary),
      'Termine'    => ('Terminé', AppColors.textSecondary),
      _            => ('Voir', AppColors.primary),
    };
    final isDisabled = appointment.statut == 'Termine' ||
        (appointment.statut == 'Confirme' && !appointment.isToday);

    return MedecinCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          // Heure
          Container(
            width: 58,
            padding: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.ice,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                Text(
                  time,
                  style: const TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
                const Text('RDV',
                    style: TextStyle(fontSize: 10, color: AppColors.textSecondary)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          DoctorAvatar(name: appointment.patientDisplayName),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  appointment.patientDisplayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                const SizedBox(height: 2),
                Text(
                  appointment.motif,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          FilledButton(
            onPressed: isDisabled ? null : onTap,
            style: FilledButton.styleFrom(
              backgroundColor: btnColor,
              disabledBackgroundColor: AppColors.border,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 10),
            ),
            child: Text(
              btnLabel,
              style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Bottom sheet Accept/Refus depuis l'accueil ──────────────────────────────
class _PendingBottomSheet extends StatelessWidget {
  final Appointment appointment;
  final VoidCallback onAccept;
  final VoidCallback onRefuse;

  const _PendingBottomSheet({
    required this.appointment,
    required this.onAccept,
    required this.onRefuse,
  });

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('EEEE d MMM à HH:mm', 'fr_FR')
        .format(appointment.dateHeure.toLocal());

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Poignée
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text('Demande de rendez-vous',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 14),
          // Infos patient
          Row(
            children: [
              DoctorAvatar(name: appointment.patientDisplayName, radius: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(appointment.patientDisplayName,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 15)),
                    Text(appointment.motif,
                        style: const TextStyle(
                            color: AppColors.textSecondary, fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.ice,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_rounded,
                    size: 15, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(date,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
              ],
            ),
          ),
          if (appointment.isTresUrgent || appointment.isUrgent) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: (appointment.isTresUrgent ? AppColors.error : AppColors.warning)
                    .withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    appointment.isTresUrgent
                        ? Icons.emergency_rounded
                        : Icons.warning_amber_rounded,
                    size: 14,
                    color: appointment.isTresUrgent
                        ? AppColors.error
                        : AppColors.warning,
                  ),
                  const SizedBox(width: 6),
                  Text(appointment.urgenceLabel,
                      style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: appointment.isTresUrgent
                              ? AppColors.error
                              : AppColors.warning)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onRefuse,
                  icon: const Icon(Icons.close_rounded, size: 16),
                  label: const Text('Refuser'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    side: const BorderSide(color: AppColors.error),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: onAccept,
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text('Accepter'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.success,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ── Action rapide ────────────────────────────────────────────────────────────
class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAction({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return MedecinCard(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      onTap: onTap,
      child: Column(
        children: [
          Icon(icon, color: AppColors.primary),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
