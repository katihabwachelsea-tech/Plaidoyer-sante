// lib/pages/medecin/medecin_schedule_page.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../models/appointment.dart';
import '../../services/medecin_api_service.dart';
import '../../widgets/metric_card.dart';

class MedecinSchedulePage extends StatefulWidget {
  const MedecinSchedulePage({super.key});

  @override
  State<MedecinSchedulePage> createState() => _MedecinSchedulePageState();
}

class _MedecinSchedulePageState extends State<MedecinSchedulePage> {
  final _api = MedecinApiService.instance;
  List<Creneau> _creneaux = [];
  bool _isLoading = true;

  final _dateController = TextEditingController();
  final _debutController = TextEditingController(text: '09:00');
  final _finController = TextEditingController(text: '10:00');

  @override
  void initState() {
    super.initState();
    _loadCreneaux();
  }

  @override
  void dispose() {
    _dateController.dispose();
    _debutController.dispose();
    _finController.dispose();
    super.dispose();
  }

  Future<void> _loadCreneaux() async {
    setState(() => _isLoading = true);
    try {
      final from = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final to = DateFormat('yyyy-MM-dd')
          .format(DateTime.now().add(const Duration(days: 30)));
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
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    }
  }

  Future<void> _addCreneau() async {
    if (_dateController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Choisissez une date')),
      );
      return;
    }
    try {
      await _api.createCreneau(
        date: _dateController.text,
        heureDebut: _debutController.text,
        heureFin: _finController.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Créneau ajouté'),
            backgroundColor: AppColors.success,
          ),
        );
        _loadCreneaux();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e')),
        );
      }
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateFormat = DateFormat('EEE d MMM', 'fr_FR');

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _loadCreneaux,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Mes disponibilités',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    TextFormField(
                      controller: _dateController,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Date',
                        prefixIcon: const Icon(Icons.calendar_today),
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.edit_calendar),
                          onPressed: _pickDate,
                        ),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            controller: _debutController,
                            decoration: const InputDecoration(
                              labelText: 'Début (HH:mm)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _finController,
                            decoration: const InputDecoration(
                              labelText: 'Fin (HH:mm)',
                              border: OutlineInputBorder(),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _addCreneau,
                        icon: const Icon(Icons.add),
                        label: const Text('Ajouter un créneau'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.textOnPrimary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (_isLoading)
              const Center(child: CircularProgressIndicator())
            else if (_creneaux.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(32),
                  child: Text('Aucun créneau sur les 30 prochains jours'),
                ),
              )
            else
              ..._creneaux.map((c) {
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(
                      c.disponible ? Icons.check_circle : Icons.block,
                      color: c.disponible ? Colors.green : Colors.grey,
                    ),
                    title: Text(dateFormat.format(c.date)),
                    subtitle: Text('${c.heureDebut} — ${c.heureFin}'),
                    trailing: Text(
                      c.disponible ? 'Libre' : 'Occupé',
                      style: TextStyle(
                        color: c.disponible ? Colors.green : Colors.orange,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }),
          ],e 
        ),
      ),
    );
  }
}
