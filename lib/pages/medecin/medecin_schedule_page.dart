// lib/pages/medecin/medecin_schedule_page.dart
//
// Gestion des créneaux — planning hebdomadaire comme Doctolib / Zocdoc.
//
// Fonctionnalités :
//   • Vue calendrier mensuelle (scroll) avec indicateurs de créneaux
//   • Configurateur de planning hebdomadaire :
//       - Cocher les jours actifs (Lun–Dim, weekends décochés par défaut)
//       - Heure début / fin par jour
//       - Pauses (ex: 12h–14h) — plusieurs possibles
//       - Durée par créneau (15 / 20 / 30 / 45 / 60 min)
//       - Générer sur 1, 2, 3 ou 4 semaines
//   • Ajout unitaire (bottom sheet)
//   • Modifier / supprimer un créneau
//   • Sync agenda téléphone (add_2_calendar)

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/appointment.dart';
import '../../services/calendar_sync_service.dart';
import '../../services/medecin_api_service.dart';
import '../../widgets/metric_card.dart';
import 'medecin_ui.dart';
import 'working_time_page.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Modèle de planning hebdomadaire
// ─────────────────────────────────────────────────────────────────────────────

class _DayConfig {
  bool  active;
  TimeOfDay start;
  TimeOfDay end;

  _DayConfig({
    required this.active,
    required this.start,
    required this.end,
  });

  _DayConfig copy() => _DayConfig(
    active: active,
    start:  start,
    end:    end,
  );
}

class _Pause {
  TimeOfDay start;
  TimeOfDay end;
  _Pause({required this.start, required this.end});
}

// ─────────────────────────────────────────────────────────────────────────────
// Page principale
// ─────────────────────────────────────────────────────────────────────────────

class MedecinSchedulePage extends StatefulWidget {
  const MedecinSchedulePage({super.key});

  @override
  State<MedecinSchedulePage> createState() => _MedecinSchedulePageState();
}

class _MedecinSchedulePageState extends State<MedecinSchedulePage>
    with SingleTickerProviderStateMixin {

  final _api = MedecinApiService.instance;

  List<Creneau> _creneaux   = [];
  bool _isLoading = true;
  bool _isSyncing = false;

  // Vue calendrier
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

  // ── Données calendrier ────────────────────────────────────────────────────

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
      final to   = DateFormat('yyyy-MM-dd')
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
    c.date.day   == _selectedDay.day,
  ).toList();

  int _countForDay(DateTime day) => _creneaux.where((c) =>
    c.date.year == day.year && c.date.month == day.month &&
    c.date.day == day.day && c.disponible).length;

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

  // ── Planning hebdomadaire (wizard) ────────────────────────────────────────

  Future<void> _openWeeklyPlanner() async {
    // Config par défaut : Lun–Ven 08h-17h, weekends désactivés
    final days = [
      _DayConfig(active: false, start: const TimeOfDay(hour: 8, minute: 0), end: const TimeOfDay(hour: 17, minute: 0)), // Dim
      _DayConfig(active: true,  start: const TimeOfDay(hour: 8, minute: 0), end: const TimeOfDay(hour: 17, minute: 0)), // Lun
      _DayConfig(active: true,  start: const TimeOfDay(hour: 8, minute: 0), end: const TimeOfDay(hour: 17, minute: 0)), // Mar
      _DayConfig(active: true,  start: const TimeOfDay(hour: 8, minute: 0), end: const TimeOfDay(hour: 17, minute: 0)), // Mer
      _DayConfig(active: true,  start: const TimeOfDay(hour: 8, minute: 0), end: const TimeOfDay(hour: 17, minute: 0)), // Jeu
      _DayConfig(active: true,  start: const TimeOfDay(hour: 8, minute: 0), end: const TimeOfDay(hour: 17, minute: 0)), // Ven
      _DayConfig(active: false, start: const TimeOfDay(hour: 8, minute: 0), end: const TimeOfDay(hour: 17, minute: 0)), // Sam
    ];

    final pauses = <_Pause>[
      _Pause(start: const TimeOfDay(hour: 12, minute: 0),
             end:   const TimeOfDay(hour: 14, minute: 0)),
    ];

    final dayLabels = ['Di', 'Lu', 'Ma', 'Me', 'Je', 'Ve', 'Sa'];
    int durationMinutes = 30;
    int weeksAhead      = 2;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModal) => DraggableScrollableSheet(
          initialChildSize: 0.92,
          minChildSize: 0.5,
          maxChildSize: 0.97,
          expand: false,
          builder: (_, scrollCtrl) => Column(
            children: [
              // Poignée
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 4),
                child: Center(
                  child: Container(
                    width: 40, height: 4,
                    decoration: BoxDecoration(
                        color: AppColors.border,
                        borderRadius: BorderRadius.circular(99)),
                  ),
                ),
              ),
              // Titre
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                child: Row(children: [
                  const Icon(Icons.calendar_view_week_rounded,
                      color: AppColors.primary),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Planning hebdomadaire',
                            style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800)),
                        Text('Configurez vos horaires et générez vos créneaux',
                            style: TextStyle(
                                fontSize: 12,
                                color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                ]),
              ),
              const Divider(height: 20),
              Expanded(
                child: ListView(
                  controller: scrollCtrl,
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  children: [

                    // ── Section : Jours de travail ─────────────────────
                    _sectionTitle('Jours de travail'),
                    const SizedBox(height: 8),
                    ...List.generate(7, (i) {
                      final cfg = days[i];
                      return Column(
                        children: [
                          // Ligne du jour
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            decoration: BoxDecoration(
                              color: cfg.active
                                  ? AppColors.primary.withValues(alpha: 0.06)
                                  : AppColors.background,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: cfg.active
                                    ? AppColors.primary.withValues(alpha: 0.3)
                                    : AppColors.border,
                              ),
                            ),
                            child: Column(
                              children: [
                                // Toggle jour
                                SwitchListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 0),
                                  value:   cfg.active,
                                  onChanged: (v) =>
                                      setModal(() => cfg.active = v),
                                  activeColor: AppColors.primary,
                                  title: Text(
                                    _dayFullName(i),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: cfg.active
                                          ? AppColors.textPrimary
                                          : AppColors.textLight,
                                    ),
                                  ),
                                  subtitle: cfg.active
                                      ? Text(
                                          '${_fmt(cfg.start)} – ${_fmt(cfg.end)}',
                                          style: const TextStyle(
                                              color: AppColors.primary,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600),
                                        )
                                      : const Text('Non travaillé',
                                          style: TextStyle(
                                              color: AppColors.textLight,
                                              fontSize: 12)),
                                ),
                                // Horaires si actif
                                if (cfg.active)
                                  Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        14, 0, 14, 12),
                                    child: Row(children: [
                                      Expanded(
                                        child: _timeButton(
                                          label: 'Début',
                                          time:  cfg.start,
                                          onTap: () async {
                                            final t = await showTimePicker(
                                              context: ctx,
                                              initialTime: cfg.start,
                                            );
                                            if (t != null) {
                                              setModal(() => cfg.start = t);
                                            }
                                          },
                                        ),
                                      ),
                                      const Padding(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 8),
                                        child: Text('→',
                                            style: TextStyle(
                                                color:
                                                    AppColors.textSecondary)),
                                      ),
                                      Expanded(
                                        child: _timeButton(
                                          label: 'Fin',
                                          time:  cfg.end,
                                          onTap: () async {
                                            final t = await showTimePicker(
                                              context: ctx,
                                              initialTime: cfg.end,
                                            );
                                            if (t != null) {
                                              setModal(() => cfg.end = t);
                                            }
                                          },
                                        ),
                                      ),
                                    ]),
                                  ),
                              ],
                            ),
                          ),
                        ],
                      );
                    }),

                    const SizedBox(height: 16),

                    // ── Section : Pauses ───────────────────────────────
                    Row(children: [
                      _sectionTitle('Pauses'),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () => setModal(() => pauses.add(
                            _Pause(
                              start: const TimeOfDay(hour: 12, minute: 0),
                              end:   const TimeOfDay(hour: 13, minute: 0),
                            ))),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Ajouter'),
                        style: TextButton.styleFrom(
                            foregroundColor: AppColors.primary),
                      ),
                    ]),
                    const SizedBox(height: 4),

                    if (pauses.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Text('Aucune pause',
                            style: const TextStyle(
                                color: AppColors.textSecondary)),
                      ),

                    ...pauses.asMap().entries.map((entry) {
                      final idx   = entry.key;
                      final pause = entry.value;
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.fromLTRB(14, 4, 8, 8),
                        decoration: BoxDecoration(
                          color: AppColors.warning.withValues(alpha: 0.07),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                              color:
                                  AppColors.warning.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              const Icon(Icons.free_breakfast_rounded,
                                  color: AppColors.warning, size: 18),
                              const SizedBox(width: 6),
                              Text('Pause ${idx + 1}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: AppColors.warning)),
                              const Spacer(),
                              IconButton(
                                icon: const Icon(
                                    Icons.close_rounded,
                                    size: 18,
                                    color: AppColors.textLight),
                                onPressed: () =>
                                    setModal(() => pauses.removeAt(idx)),
                                padding: EdgeInsets.zero,
                              ),
                            ]),
                            Row(children: [
                              Expanded(
                                child: _timeButton(
                                  label: 'Début',
                                  time:  pause.start,
                                  onTap: () async {
                                    final t = await showTimePicker(
                                      context: ctx,
                                      initialTime: pause.start,
                                    );
                                    if (t != null) {
                                      setModal(() => pause.start = t);
                                    }
                                  },
                                ),
                              ),
                              const Padding(
                                padding:
                                    EdgeInsets.symmetric(horizontal: 8),
                                child: Text('→',
                                    style: TextStyle(
                                        color: AppColors.textSecondary)),
                              ),
                              Expanded(
                                child: _timeButton(
                                  label: 'Fin',
                                  time:  pause.end,
                                  onTap: () async {
                                    final t = await showTimePicker(
                                      context: ctx,
                                      initialTime: pause.end,
                                    );
                                    if (t != null) {
                                      setModal(() => pause.end = t);
                                    }
                                  },
                                ),
                              ),
                            ]),
                          ],
                        ),
                      );
                    }),

                    const SizedBox(height: 16),

                    // ── Section : Paramètres de génération ─────────────
                    _sectionTitle('Paramètres de génération'),
                    const SizedBox(height: 12),

                    Row(children: [
                      const Text('Durée par créneau :',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(width: 12),
                      DropdownButton<int>(
                        value: durationMinutes,
                        items: [15, 20, 30, 45, 60]
                            .map((v) => DropdownMenuItem(
                                value: v, child: Text('$v min')))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setModal(() => durationMinutes = v);
                          }
                        },
                      ),
                    ]),

                    const SizedBox(height: 8),

                    Row(children: [
                      const Text('Générer sur :',
                          style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(width: 12),
                      DropdownButton<int>(
                        value: weeksAhead,
                        items: [1, 2, 3, 4]
                            .map((v) => DropdownMenuItem(
                                value: v,
                                child: Text('$v semaine${v > 1 ? "s" : ""}')))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) {
                            setModal(() => weeksAhead = v);
                          }
                        },
                      ),
                    ]),

                    const SizedBox(height: 8),

                    // Aperçu du nombre de créneaux
                    Builder(builder: (_) {
                      final slots = _computeWeeklySlots(
                          days, pauses, durationMinutes, weeksAhead);
                      return Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(children: [
                          const Icon(Icons.info_outline_rounded,
                              color: AppColors.primary, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${slots.length} créneaux de ${durationMinutes} min '
                              'seront créés sur $weeksAhead semaine${weeksAhead > 1 ? "s" : ""}',
                              style: const TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700),
                            ),
                          ),
                        ]),
                      );
                    }),

                    const SizedBox(height: 24),

                    // ── Bouton Générer ─────────────────────────────────
                    FilledButton.icon(
                      icon: const Icon(Icons.auto_awesome_rounded),
                      label: const Text('Générer le planning'),
                      onPressed: () async {
                        final slots = _computeWeeklySlots(
                            days, pauses, durationMinutes, weeksAhead);
                        if (slots.isEmpty) {
                          _toast(
                            'Aucun créneau à créer — activez au moins un jour',
                            error: true,
                          );
                          return;
                        }
                        if (ctx.mounted) Navigator.pop(ctx);
                        await _doBulkCreate(slots);
                      },
                      style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          padding:
                              const EdgeInsets.symmetric(vertical: 16)),
                    ),
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Calcule tous les créneaux à partir de la config hebdomadaire.
  List<Map<String, String>> _computeWeeklySlots(
    List<_DayConfig> days,
    List<_Pause> pauses,
    int durationMin,
    int weeksAhead,
  ) {
    final slots    = <Map<String, String>>[];
    final today    = DateTime.now();
    final startDay = DateTime(today.year, today.month, today.day);
    final endDay   = startDay.add(Duration(days: weeksAhead * 7));

    for (var d = startDay;
        d.isBefore(endDay);
        d = d.add(const Duration(days: 1))) {
      final weekday  = d.weekday % 7; // 0=Dim, 1=Lun…6=Sam
      final cfg      = days[weekday];
      if (!cfg.active) continue;

      final dateStr  = DateFormat('yyyy-MM-dd').format(d);
      int cur = cfg.start.hour * 60 + cfg.start.minute;
      final end = cfg.end.hour   * 60 + cfg.end.minute;

      while (cur + durationMin <= end) {
        final slotStart = cur;
        final slotEnd   = cur + durationMin;

        // Vérifier si le créneau chevauche une pause
        final inPause = pauses.any((p) {
          final pStart = p.start.hour * 60 + p.start.minute;
          final pEnd   = p.end.hour   * 60 + p.end.minute;
          return slotStart < pEnd && slotEnd > pStart;
        });

        if (!inPause) {
          final sh = (slotStart ~/ 60).toString().padLeft(2, '0');
          final sm = (slotStart  % 60).toString().padLeft(2, '0');
          final eh = (slotEnd   ~/ 60).toString().padLeft(2, '0');
          final em = (slotEnd    % 60).toString().padLeft(2, '0');
          slots.add({
            'date':       dateStr,
            'heure_debut': '$sh:$sm',
            'heure_fin':  '$eh:$em',
          });
        } else {
          // Sauter à la fin de la pause qui chevauche
          final conflictPause = pauses.firstWhere((p) {
            final pStart = p.start.hour * 60 + p.start.minute;
            final pEnd   = p.end.hour   * 60 + p.end.minute;
            return slotStart < pEnd && slotEnd > pStart;
          });
          cur = conflictPause.end.hour * 60 + conflictPause.end.minute;
          continue;
        }
        cur += durationMin;
      }
    }
    return slots;
  }

  // ── Bulk create ───────────────────────────────────────────────────────────

  Future<void> _doBulkCreate(List<Map<String, String>> slots) async {
    try {
      // Envoyer par lots de 50 pour éviter les timeouts
      int totalCreated = 0;
      int totalSkipped = 0;
      for (var i = 0; i < slots.length; i += 50) {
        final batch = slots.sublist(
            i, i + 50 > slots.length ? slots.length : i + 50);
        final result = await _api.bulkCreateCreneaux(batch);
        totalCreated += (result['created'] as int? ?? 0);
        totalSkipped += (result['skipped'] as int? ?? 0);
      }
      await _loadCreneaux();
      _toast(
        '$totalCreated créneau(x) créé(s)'
        '${totalSkipped > 0 ? ", $totalSkipped doublon(s) ignoré(s)" : ""} ✅',
      );
    } catch (e) {
      _toast('$e', error: true);
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
              'Modifier — ${DateFormat("EEEE d MMM", "fr_FR").format(creneau.date)}',
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

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  String _dayFullName(int weekday) {
    const names = ['Dimanche', 'Lundi', 'Mardi', 'Mercredi',
                   'Jeudi', 'Vendredi', 'Samedi'];
    return names[weekday];
  }

  Widget _sectionTitle(String title) => Text(
    title,
    style: const TextStyle(
        fontWeight: FontWeight.w800,
        fontSize: 15,
        color: AppColors.textPrimary),
  );

  Widget _timeButton({
    required String label,
    required TimeOfDay time,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: const TextStyle(
                      fontSize: 10, color: AppColors.textSecondary)),
              const SizedBox(height: 2),
              Row(children: [
                const Icon(Icons.schedule, size: 14,
                    color: AppColors.primary),
                const SizedBox(width: 4),
                Text(_fmt(time),
                    style: const TextStyle(
                        fontWeight: FontWeight.w800, fontSize: 15)),
              ]),
            ],
          ),
        ),
      );

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
          // Working time (planning hebdomadaire)
          FloatingActionButton.extended(
            heroTag: 'weekly',
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute(
                  builder: (_) => const WorkingTimePage()),
            ).then((_) => _loadCreneaux()),
            backgroundColor: AppColors.navy,
            foregroundColor: Colors.white,
            icon: const Icon(Icons.access_time_rounded),
            label: const Text('Working time'),
          ),
          const SizedBox(height: 10),
          // Ajout unitaire
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

            // ── Header ────────────────────────────────────────────────
            SliverToBoxAdapter(
              child: Container(
                decoration: const BoxDecoration(
                    gradient: MedecinDecor.headerGradient),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
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
                                      color: Colors.white
                                          .withValues(alpha: 0.8)),
                                ),
                              ],
                            ),
                          ),
                          // ── Sync agenda
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
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // ── Calendrier mensuel ────────────────────────────────────
            SliverToBoxAdapter(child: _buildCalendar()),

            // ── Titre du jour sélectionné ──────────────────────────
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

            // ── Liste créneaux du jour ─────────────────────────────
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
                            'Utilisez "Planning" pour configurer votre semaine type.',
                      ),
                      const SizedBox(height: 20),
                      OutlinedButton.icon(
                        onPressed: _openWeeklyPlanner,
                        icon: const Icon(Icons.calendar_view_week_rounded),
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
    final firstWeekday = DateTime(_currentMonth.year, _currentMonth.month, 1).weekday % 7;
    final dayHeaders   = ['Di', 'Lu', 'Ma', 'Me', 'Je', 'Ve', 'Sa'];

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Column(children: [
        // Navigation mois
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
        // En-têtes jours
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
        // Grille
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
            final day    = _monthDays[i - firstWeekday];
            final isToday = day.year == DateTime.now().year &&
                day.month == DateTime.now().month &&
                day.day == DateTime.now().day;
            final isSelected = day == _selectedDay;
            final count  = _countForDay(day);
            final isPast = day.isBefore(
                DateTime(DateTime.now().year, DateTime.now().month,
                    DateTime.now().day));

            return GestureDetector(
              onTap: () => setState(() {
                _selectedDay   = day;
                _showAllSlots  = false;
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
