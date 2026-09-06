// lib/pages/doctors_list_page.dart

import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../widgets/metric_card.dart';
import 'patient/doctor_detail_page.dart';

class DoctorsListPage extends StatefulWidget {
  final String? initialSpecialty;

  const DoctorsListPage({
    super.key,
    this.initialSpecialty,
  });

  @override
  State<DoctorsListPage> createState() => _DoctorsListPageState();
}

class _DoctorsListPageState extends State<DoctorsListPage> {
  final _searchController = TextEditingController();
  List<dynamic> _doctors = [];
  List<dynamic> _allDoctors = [];
  List<dynamic> _specialties = [];
  String? _selectedSpecialty;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _selectedSpecialty = widget.initialSpecialty;
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Charger les médecins
      final doctorsResult = await AuthService.instance.fetchDoctors();
      if (doctorsResult['success']) {
        _allDoctors = doctorsResult['doctors'] ?? [];
        _applyFilters();
      }

      // Charger les spécialités
      final specialtiesResult = await AuthService.instance.fetchSpecialties();
      if (specialtiesResult['success']) {
        setState(() {
          _specialties = specialtiesResult['specialties'] ?? [];
        });
      }
    } catch (e) {
      debugPrint('Erreur: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    List<dynamic> filtered = _allDoctors;

    // Filtre par spécialité
    if (_selectedSpecialty != null && _selectedSpecialty!.isNotEmpty) {
      filtered = filtered.where((doc) {
        final specialite = doc['specialite']?.toString().toLowerCase() ?? '';
        return specialite.contains(_selectedSpecialty!.toLowerCase());
      }).toList();
    }

    // Filtre par recherche
    if (_searchController.text.isNotEmpty) {
      filtered = filtered.where((doc) {
        final name = (doc['user']?['nom'] ?? doc['nom'] ?? '')
            .toString()
            .toLowerCase();
        final specialite =
            (doc['specialite'] ?? '').toString().toLowerCase();
        final searchTerm = _searchController.text.toLowerCase();
        return name.contains(searchTerm) || specialite.contains(searchTerm);
      }).toList();
    }

    setState(() {
      _doctors = filtered;
    });
  }

  void _onSpecialtyChanged(String? specialty) {
    setState(() {
      _selectedSpecialty =
          specialty == _selectedSpecialty ? null : specialty;
    });
    _applyFilters();
  }

  void _onSearchChanged(String query) {
    _applyFilters();
  }

  String _specialtyLabel(dynamic specialty) {
    if (specialty is Map) {
      final value = specialty['name'] ?? specialty['specialite'] ?? specialty['label'];
      return value?.toString() ?? 'Spécialité';
    }
    return specialty?.toString() ?? 'Spécialité';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Trouver un médecin'),
        elevation: 0,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Filtres et Recherche
            Padding(
              padding: const EdgeInsets.all(AppSizes.paddingL),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Barre de recherche
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Nom du médecin, spécialité...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _onSearchChanged('');
                              },
                            )
                          : null,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onChanged: _onSearchChanged,
                  ),
                  const SizedBox(height: AppSizes.paddingL),

                  // Filtre par spécialité
                  if (_specialties.isNotEmpty) ...[
                    Text(
                      'Filtrer par spécialité',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    const SizedBox(height: AppSizes.paddingM),
                    SizedBox(
                      height: 45,
                      child: ListView.builder(
                        scrollDirection: Axis.horizontal,
                        itemCount: _specialties.length,
                        itemBuilder: (context, index) {
                          final specialty = _specialties[index];
                          final name = _specialtyLabel(specialty);
                          final isSelected = _selectedSpecialty == name;

                          return Padding(
                            padding:
                                const EdgeInsets.only(right: AppSizes.paddingM),
                            child: FilterChip(
                              selected: isSelected,
                              label: Text(name),
                              onSelected: (_) => _onSpecialtyChanged(name),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),

            // Liste des médecins
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _doctors.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.person_off,
                                size: 64,
                                color:
                                    AppColors.textSecondary.withAlpha(128),
                              ),
                              const SizedBox(height: AppSizes.paddingL),
                              Text(
                                'Aucun médecin trouvé',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyLarge,
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.all(AppSizes.paddingL),
                          itemCount: _doctors.length,
                          itemBuilder: (context, index) {
                            final doctor = _doctors[index];
                            return _buildDoctorListItem(doctor);
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDoctorListItem(dynamic doctor) {
    final name = doctor['user']?['nom'] ?? doctor['nom'] ?? 'Dr. Inconnu';
    final specialite = doctor['specialite'] ?? 'Médecin';
    final hopital = doctor['hopital'] ?? 'Clinique';
    final disponibilite = doctor['disponibilite'] ?? 'Horaires non spécifiés';
    final imageUrl = doctor['user']?['profileImageUrl'] ??
        doctor['profileImageUrl'];

    return Card(
      margin: const EdgeInsets.only(bottom: AppSizes.paddingM),
      child: Padding(
        padding: const EdgeInsets.all(AppSizes.paddingM),
        child: Column(
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar du médecin
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withAlpha((0.1 * 255).round()),
                    image: imageUrl != null
                        ? DecorationImage(
                            image: NetworkImage(imageUrl),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: imageUrl == null
                      ? const Icon(
                          Icons.person,
                          size: 40,
                          color: AppColors.primary,
                        )
                      : null,
                ),

                const SizedBox(width: AppSizes.paddingM),

                // Infos du médecin
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        name,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        specialite,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.location_on_outlined,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              hopital,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          const Icon(
                            Icons.schedule_outlined,
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              disponibilite,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: AppSizes.paddingM),

            // Bouton RDV
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => DoctorDetailPage(doctor: doctor),
                    ),
                  );
                },
                icon: const Icon(Icons.calendar_today),
                label: const Text('Prendre rendez-vous'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
