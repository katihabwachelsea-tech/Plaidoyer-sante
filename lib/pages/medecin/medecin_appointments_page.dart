import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../config/app_config.dart';
import '../../models/appointment.dart';
import '../../services/medecin_api_service.dart';
import '../../widgets/join_tele_button.dart';
import '../../widgets/metric_card.dart';
import '../chat_page.dart';
import 'consultation_form_page.dart';
import 'medecin_ui.dart';

class MedecinAppointmentsPage extends StatefulWidget {
  const MedecinAppointmentsPage({super.key});

  @override
  State<MedecinAppointmentsPage> createState() =>
      _MedecinAppointmentsPageState();
}

class _MedecinAppointmentsPageState extends State<MedecinAppointmentsPage> {
  final _api = MedecinApiService.instance;
  List<Appointment> _appointments = [];
  bool _isLoading = true;
  String? _error;
  // 'pending' = En_attente, 'today', 'upcoming', 'all'
  String _filter = 'pending';
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
      if (mounted) setState(() { _error = e.toString(); _isLoading = false; });
    }
  }

  List<Appointment> get _visible {
    final now = DateTime.now();
    bool sameDay(DateTime a, DateTime b) =>
        a.year == b.year && a.month == b.month && a.day == b.day;

    switch (_filter) {
      case 'pending':
        return _appointments.where((a) => a.isPending).toList();
      case 'today':
        return _appointments
            .where((a) => sameDay(a.dateHeure.toLocal(), now))
            .toList();
      case 'upcoming':
        return _appointments
            .where((a) => a.dateHeure.toLocal().isAfter(now))
            .toList();
      default:
        return _appointments;
    }
  }

  // ── Nombre de demandes en attente (badge) ───────────────────────────
  int get _pendingCount =>
      _appointments.where((a) => a.isPending).length;

  // ── Actions ─────────────────────────────────────────────────────────

  Future<void> _accept(Appointment rdv) async {
    try {
      await _api.acceptAppointment(rdv.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Demande acceptée — le patient peut maintenant payer'),
          backgroundColor: AppColors.success,
        ));
      }
      await _loadAppointments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$e'), backgroundColor: AppColors.error));
      }
    }
  }

  Future<void> _refuse(Appointment rdv) async {
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
      }
      await _loadAppointments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('$e'), backgroundColor: AppColors.error));
      }
    }
  }

  Future<void> _cancel(Appointment rdv) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Annuler ce rendez-vous ?'),
        content: Text('Le RDV de ${rdv.patientDisplayName} sera annulé.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Non')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Annuler le RDV')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.cancelAppointment(rdv.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Rendez-vous annulé'),
            backgroundColor: AppColors.success));
      }
      await _loadAppointments();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  Future<void> _startConsultation(Appointment rdv) async {
    if (!rdv.isToday) {
      final label =
          DateFormat('EEEE d MMMM yyyy', 'fr_FR').format(rdv.dateHeure.toLocal());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Consultation possible uniquement le jour du RDV ($label).'),
        backgroundColor: AppColors.warning,
      ));
      return;
    }
    final done = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
          builder: (_) => ConsultationFormPage(appointment: rdv)),
    );
    if (done == true) _loadAppointments();
  }

  // ── Build ────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final pendingCount = _pendingCount;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _loadAppointments,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: Container(
                decoration:
                    const BoxDecoration(gradient: MedecinDecor.headerGradient),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('Agenda',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 28,
                                      fontWeight: FontWeight.w800)),
                              const SizedBox(height: 4),
                              Text(
                                '${_appointments.length} rendez-vous au total',
                                style: TextStyle(
                                    color: Colors.white.withValues(alpha: 0.8)),
                              ),
                            ],
                          ),
                        ),
                        // Badge demandes en attente
                        if (pendingCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.warning,
                              borderRadius: BorderRadius.circular(99),
                            ),
                            child: Text(
                              '$pendingCount en attente',
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Filtres — scrollable horizontalement
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _Chip(
                        label: 'À valider',
                        badge: pendingCount,
                        selected: _filter == 'pending',
                        color: AppColors.warning,
                        onTap: () => setState(() {
                          _filter = 'pending';
                          _showAll = false;
                        }),
                      ),
                      const SizedBox(width: 8),
                      _Chip(
                        label: "Aujourd'hui",
                        selected: _filter == 'today',
                        onTap: () => setState(() {
                          _filter = 'today';
                          _showAll = false;
                        }),
                      ),
                      const SizedBox(width: 8),
                      _Chip(
                        label: 'À venir',
                        selected: _filter == 'upcoming',
                        onTap: () => setState(() {
                          _filter = 'upcoming';
                          _showAll = false;
                        }),
                      ),
                      const SizedBox(width: 8),
                      _Chip(
                        label: 'Tous',
                        selected: _filter == 'all',
                        onTap: () => setState(() {
                          _filter = 'all';
                          _showAll = false;
                        }),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            // Contenu
            if (_isLoading)
              const SliverFillRemaining(
                  child: Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary)))
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
                        ElevatedButton(
                            onPressed: _loadAppointments,
                            child: const Text('Réessayer')),
                      ],
                    ),
                  ),
                ),
              )
            else if (_visible.isEmpty)
              SliverFillRemaining(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: EmptyHint(
                    icon: _filter == 'pending'
                        ? Icons.check_circle_outline_rounded
                        : Icons.event_busy_rounded,
                    title: _filter == 'pending'
                        ? 'Aucune demande en attente'
                        : 'Aucun rendez-vous ici',
                    subtitle: _filter == 'pending'
                        ? 'Toutes les demandes ont été traitées.'
                        : 'Les RDV confirmés et payés apparaissent ici.',
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                sliver: SliverList.builder(
                  itemCount: (_showAll
                          ? _visible
                          : _visible.take(_previewCount).toList())
                      .length +
                      (_visible.length > _previewCount ? 1 : 0),
                  itemBuilder: (context, index) {
                    final visibleList = _showAll
                        ? _visible
                        : _visible.take(_previewCount).toList();

                    if (index == visibleList.length &&
                        _visible.length > _previewCount) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 4, bottom: 12),
                        child: OutlinedButton.icon(
                          onPressed: () =>
                              setState(() => _showAll = !_showAll),
                          icon: Icon(_showAll
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded),
                          label: Text(_showAll
                              ? 'Voir moins'
                              : 'Voir plus (${_visible.length - _previewCount} autres)'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.primary,
                            side:
                                const BorderSide(color: AppColors.primary),
                            padding:
                                const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      );
                    }
                    if (index >= visibleList.length) {
                      return const SizedBox.shrink();
                    }

                    final rdv = visibleList[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: rdv.isPending
                          ? _PendingCard(
                              appointment: rdv,
                              onAccept: () => _accept(rdv),
                              onRefuse: () => _refuse(rdv),
                            )
                          : _AppointmentCard(
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

// ── Chip filtre ──────────────────────────────────────────────────────────────
class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int badge;
  final Color? color;

  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.badge = 0,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final activeColor = color ?? AppColors.primary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(99),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        decoration: BoxDecoration(
          color: selected ? activeColor : Colors.white,
          borderRadius: BorderRadius.circular(99),
          boxShadow: selected ? null : MedecinDecor.cardShadow,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected ? Colors.white : AppColors.navy,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
            if (badge > 0) ...[
              const SizedBox(width: 6),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: selected
                      ? Colors.white.withValues(alpha: 0.3)
                      : activeColor,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  '$badge',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: selected ? Colors.white : Colors.white,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Carte demande EN ATTENTE — Accepter / Refuser ───────────────────────────
class _PendingCard extends StatelessWidget {
  final Appointment appointment;
  final VoidCallback onAccept;
  final VoidCallback onRefuse;

  const _PendingCard({
    required this.appointment,
    required this.onAccept,
    required this.onRefuse,
  });

  @override
  Widget build(BuildContext context) {
    final date = DateFormat('EEE d MMM · HH:mm', 'fr_FR')
        .format(appointment.dateHeure.toLocal());

    return MedecinCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête statut + urgence
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.hourglass_top_rounded,
                        size: 13, color: AppColors.warning),
                    SizedBox(width: 4),
                    Text('Demande en attente',
                        style: TextStyle(
                            color: AppColors.warning,
                            fontWeight: FontWeight.w800,
                            fontSize: 11)),
                  ],
                ),
              ),
              if (appointment.isTresUrgent || appointment.isUrgent) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: (appointment.isTresUrgent
                            ? AppColors.error
                            : AppColors.warning)
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
                        size: 13,
                        color: appointment.isTresUrgent
                            ? AppColors.error
                            : AppColors.warning,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        appointment.urgenceLabel,
                        style: TextStyle(
                          color: appointment.isTresUrgent
                              ? AppColors.error
                              : AppColors.warning,
                          fontWeight: FontWeight.w800,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),

          // Infos patient
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
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                    Text(
                      appointment.motif,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Date
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.ice,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_rounded,
                    size: 14, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(date,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 13)),
                if (appointment.serviceName != null) ...[
                  const Spacer(),
                  Text(
                    appointment.serviceName!,
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Pièces jointes (si présentes)
          if (appointment.hasAttachments) ...[
            Text(
              '${appointment.piecesJointes.length} pièce(s) jointe(s)',
              style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary),
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 70,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: appointment.piecesJointes.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, i) {
                  final url = appointment.piecesJointes[i];
                  final fullUrl = url.startsWith('http')
                      ? url
                      : '${AppConfig.baseUrl.replaceAll('/api', '')}$url';
                  return ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.network(
                      fullUrl,
                      width: 70,
                      height: 70,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        width: 70,
                        height: 70,
                        color: AppColors.surfaceVariant,
                        child: const Icon(Icons.insert_drive_file_rounded,
                            color: AppColors.primary),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Bouton Messagerie
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ChatPage(
                  appointmentId: appointment.id,
                  otherName: appointment.patientDisplayName,
                ),
              ),
            ),
            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
            label: const Text('Message'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              minimumSize: const Size(double.infinity, 42),
            ),
          ),
          const SizedBox(height: 10),

          // Boutons Accepter / Refuser
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
                    padding: const EdgeInsets.symmetric(vertical: 11),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: onAccept,
                  icon: const Icon(Icons.check_rounded, size: 16),
                  label: const Text('Accepter'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.success,
                    padding: const EdgeInsets.symmetric(vertical: 11),
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

// ── Carte RDV confirmé — Consulter / Annuler ────────────────────────────────
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
    final date =
        DateFormat('EEE d MMM', 'fr_FR').format(appointment.dateHeure.toLocal());
    final time = DateFormat('HH:mm').format(appointment.dateHeure.toLocal());
    final canConsult = appointment.isToday && appointment.isConfirme;

    // Couleur et label du badge statut
    final (badgeColor, badgeLabel) = switch (appointment.statut) {
      'Confirme' => (AppColors.success, 'Payé'),
      'Accepte'  => (AppColors.info, 'Accepté'),
      'Termine'  => (AppColors.textSecondary, 'Terminé'),
      _          => (AppColors.warning, appointment.statut),
    };

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
                      style: const TextStyle(
                          fontWeight: FontWeight.w800, fontSize: 16),
                    ),
                    Text(
                      appointment.motif,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          color: AppColors.textSecondary, fontSize: 13),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(badgeLabel,
                    style: TextStyle(
                        color: badgeColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w800)),
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
                const Icon(Icons.calendar_today_rounded,
                    size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                    child: Text('$date  ·  $time',
                        style: const TextStyle(fontWeight: FontWeight.w700))),
                if (appointment.paymentRef != null)
                  Flexible(
                    child: Text(
                      appointment.paymentRef!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.textSecondary),
                    ),
                  ),
              ],
            ),
          ),
          if (!appointment.isToday && appointment.isConfirme) ...[
            const SizedBox(height: 10),
            Text(
              'Consultation disponible le jour du rendez-vous uniquement.',
              style: TextStyle(
                  fontSize: 12,
                  color: AppColors.warning.withValues(alpha: 0.95)),
            ),
          ],
          if (appointment.isTeleconsultation) ...[
            const SizedBox(height: 8),
            const Text('Téléconsultation',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: AppColors.info)),
          ],
          if (appointment.canJoinTele) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: JoinTeleButton(meetingUrl: appointment.meetingUrl),
            ),
          ],
          const SizedBox(height: 14),
          // Bouton Messagerie
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ChatPage(
                  appointmentId: appointment.id,
                  otherName: appointment.patientDisplayName,
                ),
              ),
            ),
            icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
            label: const Text('Message'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              minimumSize: const Size(double.infinity, 42),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              if (appointment.isConfirme) ...[
                Expanded(
                  child: OutlinedButton(
                    onPressed: onCancel,
                    child: const Text('Annuler'),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                flex: 2,
                child: FilledButton.icon(
                  onPressed: canConsult ? onConsult : null,
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    disabledBackgroundColor:
                        AppColors.primary.withValues(alpha: 0.35),
                  ),
                  icon: const Icon(Icons.play_arrow_rounded),
                  label:
                      Text(canConsult ? 'Consulter' : 'Pas encore'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
