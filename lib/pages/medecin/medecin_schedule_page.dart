// lib/pages/medecin/medecin_schedule_page.dart
//
// Gestion des créneaux de disponibilité du doctor.
// Fonctionnalités :
//   • Vue semaine/14 jours avec sélecteur de jours
//   • Ajout unitaire (bottom sheet)
//   • Bulk creation : génère toute une journée par tranche horaire
//   • Modification heure d'un créneau existant
//   • Suppression (désactivée si créneau réservé)
//   • Sync automatique avec l'agenda téléphone (CalendarSyncService)

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/appointment.dart';
import '../../services/calendar_sync_service.dart';
import '../../services/medecin_api_service.dart';
import '../../widgets/metric_card.dart';
import 'medecin_ui.dart';

class MedecinSchedulePage extends StatefulWidget {
  const MedecinSchedulePage({super.key});

  @override
  State<MedecinSchedulePage> createState() => _MedecinSchedulePageState();
}

class _MedecinSchedulePageState extends State<MedecinSchedulePage> {
  final _api = MedecinApiService.instance;
  List<Creneau> _creneaux = [];
  bool _isLoading  = true;
  bool _isSyncing  = false;
  late DateTime _selectedDay;
  late final List<DateTime> _days;
  bool _showAllSlots    = false;
  static const int _slotsPreviewCount = 5;

  @override
  void initState() {
    super.initState();
    final today = DateTime.now();
    _days = List.generate(14, (i) {
      final d = today.add(Duration(days: i));
      return DateTime(d.year, d.month, d.day);
    });
    _selectedDay = _days.first;
    _loadCreneaux();
  }

  // ── Chargement ────────────────────────────────────────────────────────────

  Future<void> _loadCreneaux() async {
    setState(() => _isLoading = true);
    try {
      final from = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final to   = DateFormat('yyyy-MM-dd')
          .format(DateTime.now().add(const Duration(days: 30)));
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
    c.date.day   == _selectedDay.day,
  ).toList();

  // ── Sync agenda téléphone ─────────────────────────────────────────────────

  Future<void> _syncToCalendar() async {
    setState(() => _isSyncing = true);
    try {
      final hasPermission =
          await CalendarSyncService.instance.requestPermission();
      if (!hasPermission) {
        _toast('Permission calendrier refusée', error: true);
        return;
      }

      int count = 0;
      for (final c in _creneaux.where((c) => c.disponible)) {
        await CalendarSyncService.instance.addCreneauToCalendar(c);
        count++;
      }
      _toast('$count créneau(x) synchronisé(s) avec l\'agenda ✅');
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
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 16, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(99)),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Nouveau créneau',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              // Date
              TextFormField(
                controller: dateCtrl,
                readOnly: true,
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
              // Heures côte à côte
              Row(children: [
                Expanded(child: TextFormField(
                  controller: debutCtrl, readOnly: true,
                  decoration: const InputDecoration(
                      labelText: 'Début',
                      prefixIcon: Icon(Icons.schedule)),
                  onTap: () => _pickTime(ctx, debutCtrl),
                )),
                const SizedBox(width: 10),
                Expanded(child: TextFormField(
                  controller: finCtrl, readOnly: true,
                  decoration: const InputDecoration(
                      labelText: 'Fin',
                      prefixIcon: Icon(Icons.schedule)),
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
                    // Sync silencieuse agenda
                    unawaited(
                      CalendarSyncService.instance.addCreneauToCalendar(c));
                    if (ctx.mounted) Navigator.pop(ctx);
                    await _loadCreneaux();
                    _toast('Créneau ajouté et synchronisé ✅');
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
      ),
    );
  }

  // ── Bulk creation ─────────────────────────────────────────────────────────

  Future<void> _openBulkSheet() async {
    DateTime selectedDate = _selectedDay;
    TimeOfDay startTime   = const TimeOfDay(hour: 8, minute: 0);
    TimeOfDay endTime     = const TimeOfDay(hour: 17, minute: 0);
    int durationMinutes   = 30;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => Padding(
          padding: EdgeInsets.fromLTRB(
              20, 16, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                      color: AppColors.border,
                      borderRadius: BorderRadius.circular(99)),
                ),
              ),
              const SizedBox(height: 16),
              Row(children: [
                const Icon(Icons.auto_awesome_rounded,
                    color: AppColors.primary),
                const SizedBox(width: 8),
                const Text('Générer une journée',
                    style: TextStyle(
                        fontSize: 20, fontWeight: FontWeight.w800)),
              ]),
              const SizedBox(height: 4),
              const Text(
                'Crée automatiquement tous les créneaux pour une journée complète.',
                style: TextStyle(
                    color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 20),

              // Date
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.calendar_today_rounded,
                    color: AppColors.primary),
                title: Text(
                  DateFormat('EEEE d MMMM yyyy', 'fr_FR')
                      .format(selectedDate),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: selectedDate,
                    firstDate: DateTime.now(),
                    lastDate:
                        DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    setModal(() => selectedDate = picked);
                  }
                },
              ),
              const Divider(),

              // Plage horaire
              Row(children: [
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Début',
                        style: TextStyle(fontSize: 12,
                            color: AppColors.textSecondary)),
                    subtitle: Text(startTime.format(ctx),
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 18)),
                    onTap: () async {
                      final t = await showTimePicker(
                          context: ctx, initialTime: startTime);
                      if (t != null) setModal(() => startTime = t);
                    },
                  ),
                ),
                const Text('→',
                    style: TextStyle(fontSize: 20,
                        color: AppColors.textSecondary)),
                Expanded(
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Fin',
                        style: TextStyle(fontSize: 12,
                            color: AppColors.textSecondary)),
                    subtitle: Text(endTime.format(ctx),
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 18)),
                    onTap: () async {
                      final t = await showTimePicker(
                          context: ctx, initialTime: endTime);
                      if (t != null) setModal(() => endTime = t);
                    },
                  ),
                ),
              ]),
              const Divider(),

              // Durée par créneau
              Row(children: [
                const Text('Durée par créneau : ',
                    style: TextStyle(fontWeight: FontWeight.w600)),
                DropdownButton<int>(
                  value: durationMinutes,
                  items: [15, 20, 30, 45, 60].map((v) =>
                    DropdownMenuItem(
                        value: v,
                        child: Text('$v min'))).toList(),
                  onChanged: (v) {
                    if (v != null) setModal(() => durationMinutes = v);
                  },
                ),
              ]),

              // Aperçu du nombre de créneaux
              Builder(builder: (_) {
                final slots = _previewSlots(
                    selectedDate, startTime, endTime, durationMinutes);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    '→ ${slots.length} créneau(x) de $durationMinutes min seront créés',
                    style: const TextStyle(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w700),
                  ),
                );
              }),

              const SizedBox(height: 8),
              FilledButton.icon(
                icon: const Icon(Icons.auto_awesome_rounded),
                label: const Text('Générer les créneaux'),
                onPressed: () async {
                  final slots = _previewSlots(
                      selectedDate, startTime, endTime, durationMinutes);
                  if (slots.isEmpty) {
                    _toast('Aucun créneau à créer — vérifiez la plage horaire',
                        error: true);
                    return;
                  }
                  if (ctx.mounted) Navigator.pop(ctx);
                  await _doBulkCreate(slots);
                },
                style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(vertical: 14)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Calcule la liste des créneaux à créer pour une journée.
  List<Map<String, String>> _previewSlots(
    DateTime date,
    TimeOfDay start,
    TimeOfDay end,
    int durationMinutes,
  ) {
    final slots = <Map<String, String>>[];
    int currentMinutes = start.hour * 60 + start.minute;
    final endMinutes   = end.hour   * 60 + end.minute;
    final dateStr      = DateFormat('yyyy-MM-dd').format(date);

    while (currentMinutes + durationMinutes <= endMinutes) {
      final debutH = currentMinutes ~/ 60;
      final debutM = currentMinutes % 60;
      final finH   = (currentMinutes + durationMinutes) ~/ 60;
      final finM   = (currentMinutes + durationMinutes) % 60;

      slots.add({
        'date':       dateStr,
        'heure_debut': '${debutH.toString().padLeft(2,'0')}:${debutM.toString().padLeft(2,'0')}',
        'heure_fin':  '${finH.toString().padLeft(2,'0')}:${finM.toString().padLeft(2,'0')}',
      });
      currentMinutes += durationMinutes;
    }
    return slots;
  }

  Future<void> _doBulkCreate(List<Map<String, String>> slots) async {
    try {
      final result = await _api.bulkCreateCreneaux(slots);
      final created = result['created'] as int? ?? 0;
      final skipped = result['skipped'] as int? ?? 0;
      await _loadCreneaux();
      _toast('$created créé(s)${skipped > 0 ? ", $skipped doublon(s) ignoré(s)" : ""} ✅');
    } catch (e) {
      _toast('$e', error: true);
    }
  }

  // ── Modification ──────────────────────────────────────────────────────────

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
            Center(
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(99)),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Modifier le créneau — ${DateFormat("d MMM", "fr_FR").format(creneau.date)}',
              style: const TextStyle(
                  fontSize: 18, fontWeight: FontWeight.w800),
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
                  await _api.updateCreneau(
                    creneau.id,
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
      _toast('Créneau supprimé');
    } catch (e) {
      _toast('$e', error: true);
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<void> _pickTime(
      BuildContext ctx, TextEditingController ctrl) async {
    final parts = ctrl.text.split(':');
    final initial = TimeOfDay(
      hour:   int.tryParse(parts.first) ?? 9,
      minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
    );
    final picked = await showTimePicker(
        context: ctx, initialTime: initial);
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
          // Bulk
          FloatingActionButton.small(
            heroTag: 'bulk',
            onPressed: _openBulkSheet,
            backgroundColor: AppColors.navy,
            foregroundColor: Colors.white,
            tooltip: 'Générer une journée',
            child: const Icon(Icons.auto_awesome_rounded),
          ),
          const SizedBox(height: 10),
          // Sync agenda
          FloatingActionButton.small(
            heroTag: 'sync',
            onPressed: _isSyncing ? null : _syncToCalendar,
            backgroundColor: AppColors.info,
            foregroundColor: Colors.white,
            tooltip: 'Sync agenda téléphone',
            child: _isSyncing
                ? const SizedBox(
                    width: 18, height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.sync_rounded),
          ),
          const SizedBox(height: 10),
          // Ajout unitaire
          FloatingActionButton.extended(
            heroTag: 'add',
            onPressed: _openAddSheet,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.add),
            label: const Text('Ajouter'),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _loadCreneaux,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            // ── Header avec strip de jours ─────────────────────────────
            SliverToBoxAdapter(
              child: Container(
                decoration:
                    const BoxDecoration(gradient: MedecinDecor.headerGradient),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text('Disponibilités',
                                      style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 28,
                                          fontWeight: FontWeight.w800)),
                                  const SizedBox(height: 2),
                                  Text(
                                    '$total créneau(x) libre(s) au total',
                                    style: TextStyle(
                                        color: Colors.white
                                            .withValues(alpha: 0.8)),
                                  ),
                                ],
                              ),
                            ),
                            // Badge sync
                            GestureDetector(
                              onTap: _isSyncing ? null : _syncToCalendar,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: Colors.white.withValues(alpha: 0.18),
                                  borderRadius: BorderRadius.circular(99),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.calendar_month_rounded,
                                      color: Colors.white.withValues(
                                          alpha: 0.9),
                                      size: 15,
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      'Sync agenda',
                                      style: TextStyle(
                                          color: Colors.white
                                              .withValues(alpha: 0.9),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        // Strip de jours
                        SizedBox(
                          height: 78,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _days.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, i) {
                              final day = _days[i];
                              final selected = day == _selectedDay;
                              final count = _creneaux
                                  .where((c) =>
                                      c.date.year == day.year &&
                                      c.date.month == day.month &&
                                      c.date.day == day.day &&
                                      c.disponible)
                                  .length;
                              return InkWell(
                                onTap: () => setState(() {
                                  _selectedDay = day;
                                  _showAllSlots = false;
                                }),
                                borderRadius: BorderRadius.circular(16),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 58,
                                  decoration: BoxDecoration(
                                    color: selected
                                        ? Colors.white
                                        : Colors.white.withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        DateFormat('E', 'fr_FR').format(day),
                                        style: TextStyle(
                                            color: selected
                                                ? AppColors.primary
                                                : Colors.white70,
                                            fontSize: 11),
                                      ),
                                      Text(
                                        '${day.day}',
                                        style: TextStyle(
                                            color: selected
                                                ? AppColors.navy
                                                : Colors.white,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w800),
                                      ),
                                      if (count > 0)
                                        Container(
                                          width: 18,
                                          height: 5,
                                          decoration: BoxDecoration(
                                            color: selected
                                                ? AppColors.primary
                                                : Colors.white
                                                    .withValues(alpha: 0.7),
                                            borderRadius:
                                                BorderRadius.circular(99),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        // Compteur du jour sélectionné
                        if (!_isLoading)
                          Padding(
                            padding: const EdgeInsets.only(top: 10),
                            child: Text(
                              '$libres créneau(x) libre(s) ce jour',
                              style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.8),
                                  fontSize: 13),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── Liste des créneaux du jour ─────────────────────────────
            if (_isLoading)
              const SliverFillRemaining(
                  child: Center(
                      child: CircularProgressIndicator(
                          color: AppColors.primary)))
            else if (daySlots.isEmpty)
              SliverFillRemaining(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const EmptyHint(
                        icon: Icons.schedule_rounded,
                        title: 'Aucun créneau ce jour',
                        subtitle:
                            'Ajoutez vos horaires ou utilisez "Générer une journée" (⚡️).',
                      ),
                      const SizedBox(height: 24),
                      OutlinedButton.icon(
                        onPressed: _openBulkSheet,
                        icon: const Icon(Icons.auto_awesome_rounded),
                        label: const Text('Générer une journée complète'),
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
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
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
                          onPressed: () =>
                              setState(() => _showAllSlots = !_showAllSlots),
                          icon: Icon(_showAllSlots
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded),
                          label: Text(_showAllSlots
                              ? 'Voir moins'
                              : 'Voir plus (${daySlots.length - _slotsPreviewCount} autres)'),
                          style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.primary,
                              side: const BorderSide(
                                  color: AppColors.primary),
                              padding: const EdgeInsets.symmetric(
                                  vertical: 12)),
                        ),
                      );
                    }

                    if (index >= visible.length) {
                      return const SizedBox.shrink();
                    }

                    final c = visible[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: MedecinCard(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            // Icône statut
                            Container(
                              width: 46, height: 46,
                              decoration: BoxDecoration(
                                color: c.disponible
                                    ? AppColors.success
                                        .withValues(alpha: 0.12)
                                    : AppColors.warning
                                        .withValues(alpha: 0.14),
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
                            // Infos
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${c.heureDebut}  –  ${c.heureFin}',
                                    style: const TextStyle(
                                        fontWeight: FontWeight.w800,
                                        fontSize: 16),
                                  ),
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
                              ),
                            ),
                            // Actions (seulement si disponible)
                            if (c.disponible) ...[
                              IconButton(
                                tooltip: 'Modifier',
                                onPressed: () => _openEditSheet(c),
                                icon: const Icon(Icons.edit_rounded,
                                    color: AppColors.info),
                              ),
                              IconButton(
                                tooltip: 'Supprimer',
                                onPressed: () => _delete(c),
                                icon: const Icon(
                                    Icons.delete_outline_rounded,
                                    color: AppColors.error),
                              ),
                            ],
                          ],
                        ),
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
