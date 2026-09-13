import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/appointment.dart';
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
  bool _isLoading = true;
  late DateTime _selectedDay;
  late final List<DateTime> _days;

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

  Future<void> _loadCreneaux() async {
    setState(() => _isLoading = true);
    try {
      final from = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final to = DateFormat('yyyy-MM-dd').format(DateTime.now().add(const Duration(days: 30)));
      final list = await _api.getCreneaux(from: from, to: to);
      if (mounted) {
        setState(() {
          _creneaux = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Erreur : $e')));
      }
    }
  }

  List<Creneau> get _forDay {
    return _creneaux.where((c) {
      return c.date.year == _selectedDay.year &&
          c.date.month == _selectedDay.month &&
          c.date.day == _selectedDay.day;
    }).toList();
  }

  Future<void> _pickTime({required bool start, required TextEditingController controller}) async {
    final parts = controller.text.split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts.first) ?? 9,
      minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
    );
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked != null) {
      controller.text =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    }
  }

  Future<void> _openAddSheet() async {
    final dateController = TextEditingController(text: DateFormat('yyyy-MM-dd').format(_selectedDay));
    final debutController = TextEditingController(text: '09:00');
    final finController = TextEditingController(text: '10:00');

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + MediaQuery.of(ctx).viewInsets.bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(99)),
                ),
              ),
              const SizedBox(height: 16),
              const Text('Nouveau créneau', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
              const SizedBox(height: 16),
              TextFormField(
                controller: dateController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Date',
                  prefixIcon: Icon(Icons.calendar_today_rounded),
                ),
                onTap: () async {
                  final picked = await showDatePicker(
                    context: ctx,
                    initialDate: _selectedDay,
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (picked != null) {
                    dateController.text = DateFormat('yyyy-MM-dd').format(picked);
                  }
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: debutController,
                      readOnly: true,
                      decoration: const InputDecoration(labelText: 'Début', prefixIcon: Icon(Icons.schedule)),
                      onTap: () => _pickTime(start: true, controller: debutController),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextFormField(
                      controller: finController,
                      readOnly: true,
                      decoration: const InputDecoration(labelText: 'Fin', prefixIcon: Icon(Icons.schedule)),
                      onTap: () => _pickTime(start: false, controller: finController),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              FilledButton(
                onPressed: () async {
                  try {
                    await _api.createCreneau(
                      date: dateController.text,
                      heureDebut: debutController.text,
                      heureFin: finController.text,
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                    await _loadCreneaux();
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Créneau ajouté'), backgroundColor: AppColors.success),
                      );
                    }
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
                    }
                  }
                },
                style: FilledButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 14)),
                child: const Text('Publier le créneau'),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _delete(Creneau creneau) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Supprimer ce créneau ?'),
        content: Text('${creneau.heureDebut} – ${creneau.heureFin}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Non')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Supprimer')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _api.deleteCreneau(creneau.id);
      await _loadCreneaux();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final daySlots = _forDay;
    final libres = daySlots.where((c) => c.disponible).length;

    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAddSheet,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),
      body: RefreshIndicator(
        color: AppColors.primary,
        onRefresh: _loadCreneaux,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: Container(
                decoration: const BoxDecoration(gradient: MedecinDecor.headerGradient),
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Disponibilités', style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800)),
                        const SizedBox(height: 4),
                        Text(
                          '$libres créneau(x) libre(s) ce jour',
                          style: TextStyle(color: Colors.white.withValues(alpha: 0.8)),
                        ),
                        const SizedBox(height: 16),
                        SizedBox(
                          height: 78,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _days.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final day = _days[index];
                              final selected = day == _selectedDay;
                              return InkWell(
                                onTap: () => setState(() => _selectedDay = day),
                                borderRadius: BorderRadius.circular(16),
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 58,
                                  decoration: BoxDecoration(
                                    color: selected ? Colors.white : Colors.white.withValues(alpha: 0.16),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        DateFormat('E', 'fr_FR').format(day),
                                        style: TextStyle(
                                          color: selected ? AppColors.primary : Colors.white70,
                                          fontSize: 11,
                                        ),
                                      ),
                                      Text(
                                        '${day.day}',
                                        style: TextStyle(
                                          color: selected ? AppColors.navy : Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                        ),
                                      ),
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
                ),
              ),
            ),
            if (_isLoading)
              const SliverFillRemaining(child: Center(child: CircularProgressIndicator(color: AppColors.primary)))
            else if (daySlots.isEmpty)
              const SliverFillRemaining(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: EmptyHint(
                    icon: Icons.schedule_rounded,
                    title: 'Aucun créneau ce jour',
                    subtitle: 'Ajoutez vos horaires pour que les patients puissent réserver.',
                  ),
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                sliver: SliverList.builder(
                  itemCount: daySlots.length,
                  itemBuilder: (context, index) {
                    final c = daySlots[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: MedecinCard(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        child: Row(
                          children: [
                            Container(
                              width: 46,
                              height: 46,
                              decoration: BoxDecoration(
                                color: c.disponible ? AppColors.success.withValues(alpha: 0.12) : AppColors.warning.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Icon(
                                c.disponible ? Icons.check_rounded : Icons.lock_clock_rounded,
                                color: c.disponible ? AppColors.success : AppColors.warning,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${c.heureDebut}  –  ${c.heureFin}',
                                    style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
                                  ),
                                  Text(
                                    c.disponible ? 'Ouvert à la réservation' : 'Déjà réservé',
                                    style: TextStyle(
                                      color: c.disponible ? AppColors.success : AppColors.warning,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (c.disponible)
                              IconButton(
                                onPressed: () => _delete(c),
                                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.error),
                              ),
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
