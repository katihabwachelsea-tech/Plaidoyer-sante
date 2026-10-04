// lib/pages/medecin/medecin_schedule_page.dart
//
// Gestion des créneaux — planning style Doctolib.
// • Vue calendrier mensuelle avec dots de disponibilité
// • Créneaux du jour : disponible ✅ / réservé 🔒
// • Ajout unitaire + bouton "Working time" → WorkingTimePage
// • Modifier / Supprimer un créneau
// • Sync agenda téléphone

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/appointment.dart';
import '../../services/calendar_sync_service.dart';
import '../../services/medecin_api_service.dart';
import '../../widgets/metric_card.dart';
import 'medecin_ui.dart';
import 'working_time_page.dart';

class MedecinSchedulePage extends StatefulWidget {
  const MedecinSchedulePage({super.key});

  @override
  State<MedecinSchedulePage> createState() => _MedecinSchedulePageState();
}

class _MedecinSchedulePageState extends State<MedecinSchedulePage> {
  final _api = MedecinApiService.instance;

  List<Creneau> _creneaux = [];
  bool _isLoading = true;
  bool _isSyncing = false;

  late DateTime _currentMonth;
  late DateTime _selectedDay;
  late final List<DateTime> _monthDays;
  bool _showAllSlots = false;
  static const int _slotsPreviewCount = 5;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _selectedDay  = DateTime(today.year, today.month, today.day);
    _currentMonth = DateTime(today.year, today.month);
    _monthDays    = _buildMonthDays(_currentMonth);
    _loadCreneaux();
  }

  // ── Calendrier ────────────────────────────────────────────────────────────

  List<DateTime> _buildMonthDays(DateTime month) {
    final first = DateTime(month.year, month.month, 1);
    final last  = DateTime(month.year, month.month + 1, 0);
    return List.generate(last.day, (i) => first.add(Duration(days: i)));
  }

  void _prevMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1);
      _monthDays.clear();
      _monthDays.addAll(_buildMonthDays(_currentMonth));
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
      _monthDays.clear();
      _monthDays.addAll(_buildMonthDays(_currentMonth));
    });
  }

  // ── Chargement ────────────────────────────────────────────────────────────

  Future<void> _loadCreneaux() async {
    setState(() => _isLoading = true);
    try {
      final from = DateFormat('yyyy-MM-dd')
          .format(DateTime(_currentMonth.year, _currentMonth.month, 1));
      final to = DateFormat('yyyy-MM-dd')
          .format(DateTime(_currentMonth.year, _currentMonth.month + 1, 0));
      final list = await _api.getCreneaux(from: from, to: to);
      if (mounted) setState(() { _creneaux = list; _isLoading = false; });
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        _toast('Erreur chargement : $e', error: true);
      }
    }
  }

  List<Creneau> get _forDay => _creneaux.where((c) =>
      c.date.year  == _selectedDay.year  &&
      c.date.month == _selectedDay.month &&
      c.date.day   == _selectedDay.day).toList();

  int _countForDay(DateTime day) => _creneaux.where((c) =>
      c.date.year  == day.year  &&
      c.date.month == day.month &&
      c.date.day   == day.day   &&
      c.disponible).length;

  // ── Sync agenda ───────────────────────────────────────────────────────────

  Future<void> _syncDayToCalendar() async {
    final daySlots = _forDay.where((c) => c.disponible).toList();
    if (daySlots.isEmpty) {
      _toast('Aucun créneau disponible ce jour', error: true);
      return;
    }
    setState(() => _isSyncing = true);
    try {
      await CalendarSyncService.instance.addCreneauToCalendar(daySlots.first);
      _toast('Créneau ouvert dans votre agenda ✅');
    } catch (e) {
      _toast('Erreur sync : $e', error: true);
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  // ── Ajout unitaire ────────────────────────────────────────────────────────

  Future<void> _openAddSheet() async {
    final dateCtrl  = TextEditingController(
        text: DateFormat('yyyy-MM-dd').format(_selectedDay));
    final debutCtrl = TextEditingController(text: '09:00');
    final finCtrl   = TextEditingController(text: '10:00');

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 16, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(99)),
            )),
            const SizedBox(height: 16),
            const Text('Nouveau créneau',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 16),
            TextFormField(
              controller: dateCtrl, readOnly: true,
              decoration: const InputDecoration(
                  labelText: 'Date',
                  prefixIcon: Icon(Icons.calendar_today_rounded)),
              onTap: () async {
                final picked = await showDatePicker(
                  context: ctx,
                  initialDate: _selectedDay,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(const Duration(days: 365)),
                );
                if (picked != null) {
                  dateCtrl.text = DateFormat('yyyy-MM-dd').format(picked);
                }
              },
            ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: TextFormField(
                controller: debutCtrl, readOnly: true,
                decoration: const InputDecoration(
                    labelText: 'Début', prefixIcon: Icon(Icons.schedule)),
                onTap: () => _pickTime(ctx, debutCtrl),
              )),
              const SizedBox(width: 10),
              Expanded(child: TextFormField(
                controller: finCtrl, readOnly: true,
                decoration: const InputDecoration(
                    labelText: 'Fin', prefixIcon: Icon(Icons.schedule)),
                onTap: () => _pickTime(ctx, finCtrl),
              )),
            ]),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () async {
                try {
                  final c = await _api.createCreneau(
                    date:       dateCtrl.text,
                    heureDebut: debutCtrl.text,
                    heureFin:   finCtrl.text,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  await _loadCreneaux();
                  _toast('Créneau ajouté ✅');
                  unawaited(
                      CalendarSyncService.instance.addCreneauToCalendar(c));
                } catch (e) {
                  _toast('$e', error: true);
                }
              },
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              child: const Text('Publier le créneau'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Modifier ──────────────────────────────────────────────────────────────

  Future<void> _openEditSheet(Creneau creneau) async {
    final debutCtrl = TextEditingController(text: creneau.heureDebut);
    final finCtrl   = TextEditingController(text: creneau.heureFin);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => Padding(
        padding: EdgeInsets.fromLTRB(
            20, 16, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(99)),
            )),
            const SizedBox(height: 16),
            Text(
              'Modifier — ${DateFormat("EEEE d MMM", "fr_FR").format(creneau.date)}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: TextFormField(
                controller: debutCtrl, readOnly: true,
                decoration: const InputDecoration(
                    labelText: 'Début', prefixIcon: Icon(Icons.schedule)),
                onTap: () => _pickTime(ctx, debutCtrl),
              )),
              const SizedBox(width: 10),
              Expanded(child: TextFormField(
                controller: finCtrl, readOnly: true,
                decoration: const InputDecoration(
                    labelText: 'Fin', prefixIcon: Icon(Icons.schedule)),
                onTap: () => _pickTime(ctx, finCtrl),
              )),
            ]),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () async {
                try {
                  await _api.updateCreneau(creneau.id,
                    heureDebut: debutCtrl.text,
                    heureFin:   finCtrl.text,
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                  await _loadCreneaux();
                  _toast('Créneau mis à jour ✅');
                } catch (e) {
                  _toast('$e', error: true);
                }
              },
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14)),
              child: const Text('Enregistrer'),
            ),
          ],
        ),
      ),
    );
  }

  // ── Suppression ───────────────────────────────────────────────────────────

  Future<void> _delete(Creneau creneau) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce créneau ?'),
        content: Text('${creneau.heureDebut} – ${creneau.heureFin}'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Non')),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.deleteCreneau(creneau.id);
      await _loadCreneaux();
    } catch (e) {
      _toast('$e', error: true);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<void> _pickTime(BuildContext ctx, TextEditingController ctrl) async {
    final parts = ctrl.text.split(':');
    final initial = TimeOfDay(
      hour:   int.tryParse(parts.first) ?? 9,
      minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
    );
    final picked = await showTimePicker(context: ctx, initialTime: initial);
    if (picked != null) {
      ctrl.text =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    }
  }

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppColors.error : AppColors.success,
    ));
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final daySlots = _forDay;
    final libres   = daySlots.where((c) => c.disponible).length;
    final total    = _creneaux.where((c) => c.disponible).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // → WorkingTimePage (planning hebdomadaire complet)
          FloatingActionButton.extended(
            heroTag: 'weekly',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const WorkingTimePage()),
            ).then((_) => _loadCreneaux()),
            backgroundColor: AppColors.navy,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.access_time_rounded),
            label: const Text('Working time'),
          ),
          const SizedBox(height: 10),
          FloatingActionButton(
            heroTag: 'add',
            onPressed: _openAddSheet,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            child: const Icon(Icons.add),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _loadCreneaux,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [

            // ── Header ──────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Container(
                decoration: const BoxDecoration(
                    gradient: MedecinDecor.headerGradient),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                    child: Row(children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Disponibilités',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 28,
                                    fontWeight: FontWeight.w800)),
                            Text(
                              '$total créneau(x) libre(s) ce mois',
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8)),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: _isSyncing ? null : _syncDayToCalendar,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(99),
                          ),
                          child: Row(mainAxisSize: MainAxisSize.min, children: [
                            const Icon(Icons.calendar_month_rounded,
                                color: Colors.white, size: 15),
                            const SizedBox(width: 4),
                            const Text('Sync',
                                style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600)),
                          ]),
                        ),
                      ),
                    ]),
                  ),
                ),
              ),
            ),

            // ── Calendrier mensuel ───────────────────────────────────
            SliverToBoxAdapter(child: _buildCalendar()),

            // ── Titre jour sélectionné ───────────────────────────────
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(children: [
                  Text(
                    DateFormat('EEEE d MMMM', 'fr_FR').format(_selectedDay),
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 16),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: libres > 0
                          ? AppColors.success.withValues(alpha: 0.12)
                          : AppColors.background,
                      borderRadius: BorderRadius.circular(99),
                    ),
                    child: Text(
                      '$libres libre(s)',
                      style: TextStyle(
                          fontSize: 12,
                          color: libres > 0
                              ? AppColors.success
                              : AppColors.textLight,
                          fontWeight: FontWeight.w600),
                    ),
                  ),
                ]),
              ),
            ),

            // ── Créneaux du jour ─────────────────────────────────────
            if (_isLoading)
              const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(
                      color: AppColors.primary)))
            else if (daySlots.isEmpty)
              SliverFillRemaining(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const EmptyHint(
                        icon: Icons.schedule_rounded,
                        title: 'Aucun créneau ce jour',
                        subtitle:
                            'Utilisez "Working time" pour configurer votre planning.',
                      ),
                      const SizedBox(height: 20),
                      OutlinedButton.icon(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) => const WorkingTimePage()),
                        ).then((_) => _loadCreneaux()),
                        icon: const Icon(Icons.access_time_rounded),
                        label: const Text('Configurer mon planning'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.primary,
                          side: const BorderSide(color: AppColors.primary),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                sliver: SliverList.builder(
                  itemCount: (_showAllSlots
                              ? daySlots
                              : daySlots.take(_slotsPreviewCount).toList())
                          .length +
                      (daySlots.length > _slotsPreviewCount ? 1 : 0),
                  itemBuilder: (context, index) {
                    final visible = _showAllSlots
                        ? daySlots
                        : daySlots.take(_slotsPreviewCount).toList();

                    if (index == visible.length &&
                        daySlots.length > _slotsPreviewCount) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: OutlinedButton.icon(
                          onPressed: () => setState(
                              () => _showAllSlots = !_showAllSlots),
                          icon: Icon(_showAllSlots
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded),
                          label: Text(_showAllSlots
                              ? 'Voir moins'
                              : 'Voir plus (${daySlots.length - _slotsPreviewCount} autres)'),
                          style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(color: AppColors.primary),
                              padding:
                                  const EdgeInsets.symmetric(vertical: 12)),
                        ),
                      );
                    }
                    if (index >= visible.length) return const SizedBox.shrink();

                    final c = visible[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: MedecinCard(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(children: [
                          Container(
                            width: 46, height: 46,
                            decoration: BoxDecoration(
                              color: c.disponible
                                  ? AppColors.success.withValues(alpha: 0.12)
                                  : AppColors.warning.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Icon(
                              c.disponible
                                  ? Icons.check_rounded
                                  : Icons.lock_clock_rounded,
                              color: c.disponible
                                  ? AppColors.success
                                  : AppColors.warning,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${c.heureDebut}  –  ${c.heureFin}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16)),
                              Text(
                                c.disponible
                                    ? 'Ouvert à la réservation'
                                    : 'Déjà réservé',
                                style: TextStyle(
                                  color: c.disponible
                                      ? AppColors.success
                                      : AppColors.warning,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          )),
                          if (c.disponible) ...[
                            IconButton(
                              tooltip: 'Modifier',
                              onPressed: () => _openEditSheet(c),
                              icon: const Icon(Icons.edit_rounded,
                                  color: AppColors.info, size: 20),
                            ),
                            IconButton(
                              tooltip: 'Supprimer',
                              onPressed: () => _delete(c),
                              icon: const Icon(Icons.delete_outline_rounded,
                                  color: AppColors.error, size: 20),
                            ),
                          ],
                        ]),
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

  // ── Calendrier mensuel ────────────────────────────────────────────────────

  Widget _buildCalendar() {
    final firstWeekday =
        DateTime(_currentMonth.year, _currentMonth.month, 1).weekday % 7;
    const dayHeaders = ['Di', 'Lu', 'Ma', 'Me', 'Je', 'Ve', 'Sa'];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(children: [
        Row(children: [
          IconButton(
            icon: const Icon(Icons.chevron_left_rounded),
            onPressed: _prevMonth,
          ),
          Expanded(
            child: Text(
              DateFormat('MMMM yyyy', 'fr_FR').format(_currentMonth),
              textAlign: TextAlign.center,
              style: const TextStyle(
                  fontWeight: FontWeight.w800, fontSize: 16),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.chevron_right_rounded),
            onPressed: _nextMonth,
          ),
        ]),
        const SizedBox(height: 8),
        Row(children: dayHeaders.map((d) => Expanded(
          child: Text(d,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: d == 'Di' || d == 'Sa'
                      ? AppColors.error.withValues(alpha: 0.7)
                      : AppColors.textSecondary)),
        )).toList()),
        const SizedBox(height: 6),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 1,
          ),
          itemCount: firstWeekday + _monthDays.length,
          itemBuilder: (_, i) {
            if (i < firstWeekday) return const SizedBox.shrink();
            final day = _monthDays[i - firstWeekday];
            final isToday = day.year == DateTime.now().year &&
                day.month == DateTime.now().month &&
                day.day == DateTime.now().day;
            final isSelected = day == _selectedDay;
            final count     = _countForDay(day);
            final isPast    = day.isBefore(DateTime(
                DateTime.now().year,
                DateTime.now().month,
                DateTime.now().day));

            return GestureDetector(
              onTap: () => setState(() {
                _selectedDay  = day;
                _showAllSlots = false;
              }),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppColors.primary
                      : isToday
                          ? AppColors.primary.withValues(alpha: 0.12)
                          : null,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      '${day.day}',
                      style: TextStyle(
                        fontWeight: isSelected || isToday
                            ? FontWeight.w800
                            : FontWeight.w500,
                        fontSize: 13,
                        color: isSelected
                            ? Colors.white
                            : isPast
                                ? AppColors.textLight
                                : AppColors.textPrimary,
                      ),
                    ),
                    if (count > 0)
                      Container(
                        width: 5, height: 5,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.8)
                              : AppColors.success,
                        ),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
      ]),
    );
  }
}
