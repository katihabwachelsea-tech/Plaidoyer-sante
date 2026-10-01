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
//   • Bouton vert  "Save Working Time"  → génère les créneaux sur 4 semaines
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
    'Monday', 'Tuesday', 'Wednesday', 'Thursday',
    'Friday', 'Saturday', 'Sunday',
  ];

  late final List<_DaySchedule> _days;
  final List<_Exception> _exceptions = [];

  bool _autoSync  = false;
  bool _isSaving  = false;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _days = List.generate(7, (i) {
      return _DaySchedule(
        active: i < 5, // Lun–Ven actifs, Sam–Dim désactivés
        slots: [
          _TimeSlot(
            start: const TimeOfDay(hour: 8, minute: 0),
            end:   const TimeOfDay(hour: 12, minute: 0)),
          _TimeSlot(
            start: const TimeOfDay(hour: 14, minute: 0),
            end:   const TimeOfDay(hour: 17, minute: 30)),
        ],
      );
    });
    _loadPrefs();
  }

  Future<void> _loadPrefs() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _autoSync = prefs.getBool(_prefKey) ?? false);
  }

  Future<void> _setAutoSync(bool v) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefKey, v);
    setState(() => _autoSync = v);
  }

  // ── Génération et sauvegarde ──────────────────────────────────────────────

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final slots = _generateSlots(weeksAhead: 4);
      if (slots.isEmpty) {
        _toast('Aucun créneau à créer. Activez au moins un jour.', error: true);
        return;
      }

      int totalCreated = 0;
      int totalSkipped = 0;

      for (var i = 0; i < slots.length; i += 50) {
        final batch = slots.sublist(
            i, (i + 50) > slots.length ? slots.length : i + 50);
        final result = await MedecinApiService.instance.bulkCreateCreneaux(batch);
        totalCreated += (result['created'] as int? ?? 0);
        totalSkipped += (result['skipped'] as int? ?? 0);
      }

      _toast(
        '$totalCreated créneau(x) créé(s)'
        '${totalSkipped > 0 ? ", $totalSkipped doublon(s) ignoré(s)" : ""} ✅',
      );

      if (_autoSync) unawaited(_syncToCalendar(silent: true));
    } catch (e) {
      _toast('$e', error: true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Génère la liste de tous les créneaux en tenant compte des exceptions.
  List<Map<String, String>> _generateSlots({int weeksAhead = 4}) {
    final result  = <Map<String, String>>[];
    final today   = DateTime.now();
    final start   = DateTime(today.year, today.month, today.day);
    final end     = start.add(Duration(days: weeksAhead * 7));

    final exceptionDates = _exceptions
        .map((e) => DateFormat('yyyy-MM-dd').format(e.date))
        .toSet();

    for (var d = start; d.isBefore(end); d = d.add(const Duration(days: 1))) {
      final dateStr = DateFormat('yyyy-MM-dd').format(d);
      if (exceptionDates.contains(dateStr)) continue;

      final dayIndex = (d.weekday - 1) % 7; // 0=Lun … 6=Dim
      final schedule = _days[dayIndex];
      if (!schedule.active) continue;

      final duration = schedule.durationOverride ?? _globalDuration;

      for (final slot in schedule.slots) {
        int cur = slot.start.hour * 60 + slot.start.minute;
        final slotEnd = slot.end.hour * 60 + slot.end.minute;

        while (cur + duration <= slotEnd) {
          final sh = (cur ~/ 60).toString().padLeft(2, '0');
          final sm = (cur  % 60).toString().padLeft(2, '0');
          final eh = ((cur + duration) ~/ 60).toString().padLeft(2, '0');
          final em = ((cur + duration)  % 60).toString().padLeft(2, '0');
          result.add({
            'date':        dateStr,
            'heure_debut': '$sh:$sm',
            'heure_fin':   '$eh:$em',
          });
          cur += duration;
        }
      }
    }
    return result;
  }

  // ── Sync calendrier ───────────────────────────────────────────────────────

  Future<void> _syncToCalendar({bool silent = false}) async {
    if (!silent) setState(() => _isSyncing = true);
    try {
      // Ouvre l'app calendrier pour le premier créneau actif aujourd'hui ou demain
      final today = DateTime.now();
      for (var i = 0; i < 7; i++) {
        final d = today.add(Duration(days: i));
        final dayIdx = (d.weekday - 1) % 7;
        if (!_days[dayIdx].active || _days[dayIdx].slots.isEmpty) continue;
        final slot = _days[dayIdx].slots.first;
        await CalendarSyncService.instance.addAppointmentToCalendar(
          dateRdv:    DateTime(d.year, d.month, d.day,
              slot.start.hour, slot.start.minute),
          doctorName: 'Mob-Clinic',
          serviceName: 'Disponibilité',
          motif:      'Créneau de disponibilité',
        );
        break;
      }
      if (!silent) _toast('Agenda téléphone ouvert ✅');
    } catch (e) {
      if (!silent) _toast('Erreur sync : $e', error: true);
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
              onPressed: _isSaving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.success,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _isSaving
                  ? const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text(
                      'Save Working Time',
                      style: TextStyle(
                          fontSize: 16, fontWeight: FontWeight.w700),
                    ),
            ),
          ),
          const SizedBox(height: 12),

          // ── Sync Weekly with Android Calendar ─────────────────────
          SizedBox(
            height: 52,
            child: FilledButton(
              onPressed: _isSyncing ? null : () => _syncToCalendar(),
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.navy,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
              child: _isSyncing
                  ? const SizedBox(
                      width: 22, height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Text(
                      'Sync Weekly with Android Calendar',
                      style: TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w700),
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
            child: Row(children: [
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
                          color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _autoSync,
                onChanged: _setAutoSync,
                activeColor: AppColors.primary,
              ),
            ]),
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
    child: Row(children: [
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
          if (_globalDuration > 5) {
            setState(() => _globalDuration -= 5);
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
        onTap: () => setState(() => _globalDuration += 5),
      ),
    ]),
  );

  // ── Widget : carte d'un jour ──────────────────────────────────────────────

  Widget _buildDayCard(int i) {
    final schedule = _days[i];
    final name     = _dayNames[i];

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
            child: Row(children: [
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
            ]),
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
                        fontSize: 13, color: AppColors.textLight),
                  ),
                  Text(
                    'Visit duration: ${schedule.durationOverride ?? _globalDuration} min',
                    style: const TextStyle(
                        fontSize: 12, color: AppColors.textLight),
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
                    final idx  = entry.key;
                    final slot = entry.value;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(children: [
                        Text(
                          '${_fmt(slot.start)} - ${_fmt(slot.end)}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 14),
                        ),
                        const SizedBox(width: 10),
                        // ✏️ Modifier
                        GestureDetector(
                          onTap: () => _editSlot(i, idx),
                          child: const Icon(Icons.edit_rounded,
                              size: 18, color: AppColors.info),
                        ),
                        const SizedBox(width: 8),
                        // 🗑️ Supprimer
                        GestureDetector(
                          onTap: () => setState(
                              () => schedule.slots.removeAt(idx)),
                          child: const Icon(Icons.delete_rounded,
                              size: 18, color: AppColors.error),
                        ),
                      ]),
                    );
                  }),

                  // + Add time slot
                  GestureDetector(
                    onTap: () => _addSlot(i),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(children: const [
                        Icon(Icons.add_rounded,
                            size: 18, color: AppColors.primary),
                        SizedBox(width: 4),
                        Text(
                          '+ Add time slot',
                          style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600),
                        ),
                      ]),
                    ),
                  ),

                  // Durée individuelle
                  Row(children: [
                    const Text('Visit duration: ',
                        style: TextStyle(fontSize: 13)),
                    _roundBtn(
                      icon: Icons.remove,
                      size: 26,
                      onTap: () {
                        final cur = schedule.durationOverride ?? _globalDuration;
                        if (cur > 5) {
                          setState(() => schedule.durationOverride = cur - 5);
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
                        final cur = schedule.durationOverride ?? _globalDuration;
                        setState(() => schedule.durationOverride = cur + 5);
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
                              decoration: TextDecoration.underline),
                        ),
                      ),
                    ],
                  ]),
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
      Row(children: [
        const Text(
          'Exceptions',
          style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
        ),
        const Spacer(),
        GestureDetector(
          onTap: _addException,
          child: Container(
            padding: const EdgeInsets.symmetric(
                horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(99),
            ),
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(Icons.add_rounded,
                  size: 16, color: AppColors.primary),
              SizedBox(width: 4),
              Text('Add',
                  style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        ),
      ]),
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
            style: TextStyle(
                color: AppColors.textSecondary, fontSize: 13),
            textAlign: TextAlign.center,
          ),
        )
      else
        ..._exceptions.asMap().entries.map((entry) {
          final idx = entry.key;
          final exc = entry.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(children: [
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
                          color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_rounded,
                    color: AppColors.error, size: 20),
                onPressed: () =>
                    setState(() => _exceptions.removeAt(idx)),
              ),
            ]),
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
    TimeOfDay newEnd   = TimeOfDay(
      hour:   (lastEnd.hour + 1).clamp(0, 23),
      minute: lastEnd.minute,
    );

    final result = await _showSlotDialog(
        context, start: newStart, end: newEnd);
    if (result != null) {
      setState(() => schedule.slots.add(result));
    }
  }

  Future<void> _editSlot(int dayIndex, int slotIndex) async {
    final slot   = _days[dayIndex].slots[slotIndex];
    final result = await _showSlotDialog(
        context, start: slot.start, end: slot.end);
    if (result != null) {
      setState(() {
        _days[dayIndex].slots[slotIndex].start = result.start;
        _days[dayIndex].slots[slotIndex].end   = result.end;
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
        builder: (ctx, setD) => AlertDialog(
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18)),
          title: const Text('Time slot',
              style: TextStyle(fontWeight: FontWeight.w800)),
          content: Row(children: [
            Expanded(child: _dialogTimeBtn(
              label: 'Start',
              time:  s,
              onTap: () async {
                final t = await showTimePicker(
                    context: ctx, initialTime: s);
                if (t != null) setD(() => s = t);
              },
            )),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Text('→',
                  style: TextStyle(color: AppColors.textSecondary,
                      fontSize: 18)),
            ),
            Expanded(child: _dialogTimeBtn(
              label: 'End',
              time:  e,
              onTap: () async {
                final t = await showTimePicker(
                    context: ctx, initialTime: e);
                if (t != null) setD(() => e = t);
              },
            )),
          ]),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Annuler'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.pop(ctx, _TimeSlot(start: s, end: e)),
              style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary),
              child: const Text('OK'),
            ),
          ],
        ),
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
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18)),
        title: const Text('Exception label',
            style: TextStyle(fontWeight: FontWeight.w800)),
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
              child: const Text('Annuler')),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary),
            child: const Text('OK'),
          ),
        ],
      ),
    );

    if (!mounted) return;
    if (label != null && label.isNotEmpty) {
      setState(() => _exceptions.add(
          _Exception(date: picked, label: label)));
    }
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  String _fmt(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  void _toast(String msg, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppColors.error : AppColors.success,
    ));
  }

  Widget _roundBtn({
    required IconData icon,
    required VoidCallback onTap,
    double size = 32,
  }) =>
      GestureDetector(
        onTap: onTap,
        child: Container(
          width:  size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.background,
            border: Border.all(color: AppColors.border),
            borderRadius: BorderRadius.circular(99),
          ),
          child: Icon(icon, size: size * 0.55,
              color: AppColors.textSecondary),
        ),
      );

  Widget _dialogTimeBtn({
    required String label,
    required TimeOfDay time,
    required VoidCallback onTap,
  }) =>
      GestureDetector(
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
              Text(label,
                  style: const TextStyle(
                      fontSize: 11, color: AppColors.textSecondary)),
              const SizedBox(height: 4),
              Text(
                _fmt(time),
                style: const TextStyle(
                    fontWeight: FontWeight.w800, fontSize: 18),
              ),
            ],
          ),
        ),
      );
}
