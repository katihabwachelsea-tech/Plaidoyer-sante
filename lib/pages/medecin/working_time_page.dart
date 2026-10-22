// lib/pages/medecin/working_time_page.dart
//
// Page "Working Time" — configuration hebdomadaire du doctor.
// Inspiré des apps médicales (Doctolib, Zocdoc).
//
// Fonctionnalités :
//   • Durée de visite globale (– / +) par pas de 5 min
//   • Par jour (Lun–Dim) : toggle ON/OFF
//   • Quand actif : plages horaires multiples (08:00–12:00, 14:00–17:30…)
//       - Modifier ✏️ / Supprimer 🗑️ chaque plage
//       - "+ Add time slot" pour en ajouter
//   • Durée de visite individuelle par jour (override du global)
//   • Section "Exceptions" : jours fériés / congés avec date + label
//   • Bouton vert  "Save Working Time"  → sauvegarde la règle hebdomadaire côté serveur
//   • Bouton bleu  "Sync Weekly with Android Calendar"
//   • Toggle       "Sync with Android Calendar" (auto)

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../services/calendar_sync_service.dart';
import '../../services/medecin_api_service.dart';
import '../../widgets/metric_card.dart';

// ── Modèles ──────────────────────────────────────────────────────────────────

class _TimeSlot {
  TimeOfDay start;
  TimeOfDay end;
  _TimeSlot({required this.start, required this.end});
}

class _DaySchedule {
  bool active;
  List<_TimeSlot> slots;
  int? durationOverride;

  _DaySchedule({required this.active, required this.slots});
}

class _Exception {
  DateTime date;
  String label;
  _Exception({required this.date, required this.label});
}

// ── Page ─────────────────────────────────────────────────────────────────────

class WorkingTimePage extends StatefulWidget {
  const WorkingTimePage({super.key});

  @override
  State<WorkingTimePage> createState() => _WorkingTimePageState();
}

class _WorkingTimePageState extends State<WorkingTimePage> {
  static const String _prefKey = 'working_time_sync_auto';

  // Durée globale de visite (minutes)
  int _globalDuration = 30;

  // Jours : index 0=Lundi … 6=Dimanche
  final List<String> _dayNames = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  late final List<_DaySchedule> _days;
  final List<_Exception> _exceptions = [];

  bool _autoSync = false;
  bool _isSaving = false;
  bool _isSyncing = false;
  bool _isLoadingSchedule = true;

  @override
  void initState() {
    super.initState();
    _days = List.generate(7, (i) {
      return _DaySchedule(
        active: i < 5, // Lun–Ven actifs, Sam–Dim désactivés
        slots: [
          _TimeSlot(
            start: const TimeOfDay(hour: 8, minute: 0),
            end: const TimeOfDay(hour: 12, minute: 0),
          ),
          _TimeSlot(
            start: const TimeOfDay(hour: 14, minute: 0),
            end: const TimeOfDay(hour: 17, minute: 30),
          ),
        ],
      );
    });
    _loadPrefs();
    _loadWorkingTime();
  }

  Future<void> _loadWorkingTime() async {
    try {
      final data = await MedecinApiService.instance.getWorkingTime();
      final configuredDays = (data['days'] as List<dynamic>)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();
      if (configuredDays.length != _days.length) {
        throw const FormatException('Configuration hebdomadaire invalide.');
      }
      final configuredExceptions = (data['exceptions'] as List<dynamic>)
          .map((item) => Map<String, dynamic>.from(item as Map))
          .toList();

      if (!mounted) return;
      setState(() {
        _globalDuration = data['global_duration_minutes'] as int;
        for (final day in configuredDays) {
          final index = (day['weekday'] as int) - 1;
          _days[index]
            ..active = day['active'] as bool
            ..durationOverride = day['duration_override_minutes'] as int?
            ..slots = (day['slots'] as List<dynamic>).map((item) {
              final slot = Map<String, dynamic>.from(item as Map);
              return _TimeSlot(
                start: _parseTime(slot['start'] as String),
                end: _parseTime(slot['end'] as String),
              );
            }).toList();
        }
        _exceptions
          ..clear()
          ..addAll(
            configuredExceptions.map(
              (exception) => _Exception(
                date: DateTime.parse(exception['date'] as String),
                label: exception['label'] as String,
              ),
            ),
          );
      });
    } catch (e) {
      if (mounted) {
        _toast(
          'Impossible de charger les horaires enregistrés : $e',
          error: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoadingSchedule = false);
    }
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _autoSync = prefs.getBool(_prefKey) ?? false);
  }

  Future<void> _setAutoSync(bool v) async {
    if (v) {
      try {
        await CalendarSyncService.instance.requestCalendarPermissions();
      } catch (e) {
        _toast('Permission calendrier refusée : $e', error: true);
        return;
      }
    }
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, v);
    if (mounted) setState(() => _autoSync = v);
  }

  // ── Sauvegarde des horaires hebdomadaires ────────────────────────────────

  Future<void> _save() async {
    if (_isLoadingSchedule) return;
    setState(() => _isSaving = true);
    try {
      final validationError = _scheduleValidationError();
      if (validationError != null) {
        _toast(validationError, error: true);
        return;
      }

      final schedule = {
        'global_duration_minutes': _globalDuration,
        'days': [
          for (var dayIndex = 0; dayIndex < _days.length; dayIndex++)
            {
              'weekday': dayIndex + 1,
              'active': _days[dayIndex].active,
              'duration_override_minutes': _days[dayIndex].durationOverride,
              'slots': [
                for (final slot in _days[dayIndex].slots)
                  {'start': _fmt(slot.start), 'end': _fmt(slot.end)},
              ],
            },
        ],
        'exceptions': [
          for (final exception in _exceptions)
            {
              'date': DateFormat('yyyy-MM-dd').format(exception.date),
              'label': exception.label,
            },
        ],
      };
      await MedecinApiService.instance.saveWorkingTime(schedule);
      _toast('Horaires hebdomadaires enregistrés ✅');

      if (_autoSync) unawaited(_syncToCalendar(silent: true));
    } catch (e) {
      _toast('$e', error: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String? _scheduleValidationError() {
    for (var dayIndex = 0; dayIndex < _days.length; dayIndex++) {
      final schedule = _days[dayIndex];

      final orderedSlots = [...schedule.slots]
        ..sort(
          (a, b) => (a.start.hour * 60 + a.start.minute).compareTo(
            b.start.hour * 60 + b.start.minute,
          ),
        );

      for (var i = 0; i < orderedSlots.length; i++) {
        final slot = orderedSlots[i];
        final start = slot.start.hour * 60 + slot.start.minute;
        final end = slot.end.hour * 60 + slot.end.minute;
        if (end <= start) {
          return 'Vérifiez les heures de début et de fin pour ${_dayNames[dayIndex]}.';
        }
        if (i > 0) {
          final previousEnd =
              orderedSlots[i - 1].end.hour * 60 +
              orderedSlots[i - 1].end.minute;
          if (start < previousEnd) {
            return 'Les plages horaires de ${_dayNames[dayIndex]} se chevauchent.';
          }
        }
      }
    }
    return null;
  }

  // ── Sync calendrier ───────────────────────────────────────────────────────

  Future<void> _syncToCalendar({bool silent = false}) async {
    if (!silent) setState(() => _isSyncing = true);
    try {
      final schedules = <CalendarWorkingSlot>[
        for (var dayIndex = 0; dayIndex < _days.length; dayIndex++)
          for (final slot in _days[dayIndex].slots)
            CalendarWorkingSlot(
              dayOfWeek: dayIndex + 1,
              startTime: _fmt(slot.start),
              endTime: _fmt(slot.end),
              enabled: _days[dayIndex].active,
            ),
      ];
      final exceptions = _exceptions
          .map(
            (exception) => CalendarExceptionDay(
              date: exception.date,
              label: exception.label,
            ),
          )
          .toList();
      final appointments = await MedecinApiService.instance.getAppointments();
      final created = await CalendarSyncService.instance.syncWeeklyWorkingTime(
        slots: schedules,
        exceptions: exceptions,
        appointments: appointments,
      );
      if (!silent) {
        _toast('$created événement(s) synchronisé(s) ✅');
      }
    } catch (e) {
      _toast('Erreur sync : $e', error: true);
    } finally {
      if (mounted && !silent) setState(() => _isSyncing = false);
    }
  }

  // ── UI ────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F6FA),
      appBar: AppBar(
        backgroundColor: Colors.white,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        title: const Text(
          'Working time',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 20),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
        children: [
          // ── Durée de visite globale ────────────────────────────────
          _buildGlobalDuration(),
          const SizedBox(height: 16),

          // ── Jours ─────────────────────────────────────────────────
          ...List.generate(7, (i) => _buildDayCard(i)),

          const SizedBox(height: 24),

          // ── Exceptions ────────────────────────────────────────────
          _buildExceptionsSection(),

          const SizedBox(height: 32),

          // ── Save Working Time ──────────────────────────────────────
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _isSaving || _isLoadingSchedule ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.success,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isSaving || _isLoadingSchedule
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Save Working Time',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Sync Weekly with Android Calendar ─────────────────────
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _isSyncing || _isLoadingSchedule
                  ? null
                  : () => _syncToCalendar(),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.navy,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: _isSyncing
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Text(
                      'Sync Weekly with Android Calendar',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Auto sync toggle ───────────────────────────────────────
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Sync with Android Calendar',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        'Automatically sync weekly availability to your native calendar',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _autoSync,
                  onChanged: _setAutoSync,
                  activeColor: AppColors.primary,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Widget : durée globale ────────────────────────────────────────────────

  Widget _buildGlobalDuration() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      children: [
        const Expanded(
          child: Text(
            'Visit duration',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        // –
        _roundBtn(
          icon: Icons.remove,
          onTap: () {
            if (_globalDuration > 10) {
              setState(
                () => _globalDuration = (_globalDuration - 10)
                    .clamp(10, 120)
                    .toInt(),
              );
            }
          },
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            '$_globalDuration min',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
          ),
        ),
        // +
        _roundBtn(
          icon: Icons.add,
          onTap: () {
            if (_globalDuration < 120) {
              setState(
                () => _globalDuration = (_globalDuration + 10)
                    .clamp(10, 120)
                    .toInt(),
              );
            }
          },
        ),
      ],
    ),
  );

  // ── Widget : carte d'un jour ──────────────────────────────────────────────

  Widget _buildDayCard(int i) {
    final schedule = _days[i];
    final name = _dayNames[i];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Ligne toggle ────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    name,
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 16,
                      color: schedule.active
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
                Switch(
                  value: schedule.active,
                  onChanged: (v) => setState(() => schedule.active = v),
                  activeColor: AppColors.success,
                ),
              ],
            ),
          ),

          if (!schedule.active) ...[
            // Aperçu grisé des horaires quand désactivé
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    schedule.slots
                        .map((s) => '${_fmt(s.start)}-${_fmt(s.end)}')
                        .join(', '),
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.textLight,
                    ),
                  ),
                  Text(
                    'Visit duration: ${schedule.durationOverride ?? _globalDuration} min',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textLight,
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // ── Plages horaires actives ────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ...schedule.slots.asMap().entries.map((entry) {
                    final idx = entry.key;
                    final slot = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Text(
                            '${_fmt(slot.start)} - ${_fmt(slot.end)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(width: 10),
                          // ✏️ Modifier
                          GestureDetector(
                            onTap: () => _editSlot(i, idx),
                            child: const Icon(
                              Icons.edit_rounded,
                              size: 18,
                              color: AppColors.info,
                            ),
                          ),
                          const SizedBox(width: 8),
                          // 🗑️ Supprimer
                          GestureDetector(
                            onTap: schedule.slots.length > 1
                                ? () => setState(
                                    () => schedule.slots.removeAt(idx),
                                  )
                                : null,
                            child: Icon(
                              Icons.delete_rounded,
                              size: 18,
                              color: schedule.slots.length > 1
                                  ? AppColors.error
                                  : AppColors.textLight,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),

                  // + Add time slot
                  GestureDetector(
                    onTap: () => _addSlot(i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: const [
                          Icon(
                            Icons.add_rounded,
                            size: 18,
                            color: AppColors.primary,
                          ),
                          SizedBox(width: 4),
                          Text(
                            '+ Add time slot',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Durée individuelle
                  Row(
                    children: [
                      const Text(
                        'Visit duration: ',
                        style: TextStyle(fontSize: 13),
                      ),
                      _roundBtn(
                        icon: Icons.remove,
                        size: 26,
                        onTap: () {
                          final cur =
                              schedule.durationOverride ?? _globalDuration;
                          if (cur > 10) {
                            setState(
                              () => schedule.durationOverride = (cur - 10)
                                  .clamp(10, 120)
                                  .toInt(),
                            );
                          }
                        },
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Text(
                          '${schedule.durationOverride ?? _globalDuration} min',
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      _roundBtn(
                        icon: Icons.add,
                        size: 26,
                        onTap: () {
                          final cur =
                              schedule.durationOverride ?? _globalDuration;
                          if (cur < 120) {
                            setState(
                              () => schedule.durationOverride = (cur + 10)
                                  .clamp(10, 120)
                                  .toInt(),
                            );
                          }
                        },
                      ),
                      if (schedule.durationOverride != null) ...[
                        const SizedBox(width: 8),
                        GestureDetector(
                          onTap: () =>
                              setState(() => schedule.durationOverride = null),
                          child: Text(
                            'reset',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textLight,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Widget : section exceptions ───────────────────────────────────────────

  Widget _buildExceptionsSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(
        children: [
          const Text(
            'Exceptions',
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const Spacer(),
          GestureDetector(
            onTap: _addException,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(99),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.add_rounded, size: 16, color: AppColors.primary),
                  SizedBox(width: 4),
                  Text(
                    'Add',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 10),
      if (_exceptions.isEmpty)
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Text(
            'Aucune exception. Ajoutez les jours fériés et congés.',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        )
      else
        ..._exceptions.asMap().entries.map((entry) {
          final idx = entry.key;
          final exc = entry.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Unavailable',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      Text(
                        '${exc.label} · ${DateFormat("MMM d, yyyy", "fr_FR").format(exc.date)}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.delete_rounded,
                    color: AppColors.error,
                    size: 20,
                  ),
                  onPressed: () => setState(() => _exceptions.removeAt(idx)),
                ),
              ],
            ),
          );
        }),
    ],
  );

  // ── Actions ───────────────────────────────────────────────────────────────

  Future<void> _addSlot(int dayIndex) async {
    final schedule = _days[dayIndex];
    // Propose une plage après la dernière existante
    final lastEnd = schedule.slots.isNotEmpty
        ? schedule.slots.last.end
        : const TimeOfDay(hour: 8, minute: 0);

    TimeOfDay newStart = lastEnd;
    TimeOfDay newEnd = TimeOfDay(
      hour: (lastEnd.hour + 1).clamp(0, 23),
      minute: lastEnd.minute,
    );

    final result = await _showSlotDialog(context, start: newStart, end: newEnd);
    if (result != null) {
      setState(() => schedule.slots.add(result));
    }
  }

  Future<void> _editSlot(int dayIndex, int slotIndex) async {
    final slot = _days[dayIndex].slots[slotIndex];
    final result = await _showSlotDialog(
      context,
      start: slot.start,
      end: slot.end,
    );
    if (result != null) {
      setState(() {
        _days[dayIndex].slots[slotIndex].start = result.start;
        _days[dayIndex].slots[slotIndex].end = result.end;
      });
    }
  }

  Future<_TimeSlot?> _showSlotDialog(
    BuildContext context, {
    required TimeOfDay start,
    required TimeOfDay end,
  }) async {
    TimeOfDay s = start;
    TimeOfDay e = end;

    return showDialog<_TimeSlot>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) {
          final isValid = e.hour * 60 + e.minute > s.hour * 60 + s.minute;
          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            title: const Text(
              'Time slot',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _dialogTimeBtn(
                        label: 'Start',
                        time: s,
                        onTap: () async {
                          final t = await showTimePicker(
                            context: ctx,
                            initialTime: s,
                          );
                          if (t != null) setD(() => s = t);
                        },
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        '→',
                        style: TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 18,
                        ),
                      ),
                    ),
                    Expanded(
                      child: _dialogTimeBtn(
                        label: 'End',
                        time: e,
                        onTap: () async {
                          final t = await showTimePicker(
                            context: ctx,
                            initialTime: e,
                          );
                          if (t != null) setD(() => e = t);
                        },
                      ),
                    ),
                  ],
                ),
                if (!isValid)
                  const Padding(
                    padding: EdgeInsets.only(top: 12),
                    child: Text(
                      'L’heure de fin doit être après l’heure de début.',
                      style: TextStyle(color: AppColors.error, fontSize: 12),
                    ),
                  ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Annuler'),
              ),
              FilledButton(
                onPressed: isValid
                    ? () => Navigator.pop(ctx, _TimeSlot(start: s, end: e))
                    : null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                ),
                child: const Text('OK'),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _addException() async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked == null || !mounted) return;

    final ctrl = TextEditingController(text: 'Holiday');
    final label = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text(
          'Exception label',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: 'Raison (ex: Holiday, Congé…)',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (label != null && label.isNotEmpty) {
      setState(() => _exceptions.add(_Exception(date: picked, label: label)));
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  TimeOfDay _parseTime(String value) {
    final parts = value.split(':');
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: error ? AppColors.error : AppColors.success,
      ),
    );
  }

  Widget _roundBtn({
    required IconData icon,
    required VoidCallback onTap,
    double size = 32,
  }) => GestureDetector(
    onTap: onTap,
    child: Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.background,
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(99),
      ),
      child: Icon(icon, size: size * 0.55, color: AppColors.textSecondary),
    ),
  );

  Widget _dialogTimeBtn({
    required String label,
    required TimeOfDay time,
    required VoidCallback onTap,
  }) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _fmt(time),
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
          ),
        ],
      ),
    ),
  );
}
