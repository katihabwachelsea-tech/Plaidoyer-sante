// lib/pages/doctors_list_page.dart

import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../utils/doctor_photo.dart';
import '../widgets/metric_card.dart';
import 'patient/doctor_booking_page.dart';

class DoctorsListPage extends StatefulWidget {
  final String? initialSpecialty;

  const DoctorsListPage({super.key, this.initialSpecialty});

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
    setState(() => _isLoading = true);
    try {
      final doctorsResult = await AuthService.instance.fetchDoctors();
      if (doctorsResult['success']) {
        _allDoctors = doctorsResult['doctors'] ?? [];
        _applyFilters();
      }
      final specialtiesResult = await AuthService.instance.fetchSpecialties();
      if (specialtiesResult['success']) {
        setState(() => _specialties = specialtiesResult['specialties'] ?? []);
      }
    } catch (e) {
      debugPrint('Erreur: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _applyFilters() {
    List<dynamic> filtered = _allDoctors;
    if (_selectedSpecialty != null && _selectedSpecialty!.isNotEmpty) {
      filtered = filtered.where((doc) {
        final specialite = doc['specialite']?.toString().toLowerCase() ?? '';
        return specialite.contains(_selectedSpecialty!.toLowerCase());
      }).toList();
    }
    if (_searchController.text.isNotEmpty) {
      filtered = filtered.where((doc) {
        final name =
            (doc['user']?['nom'] ?? doc['nom'] ?? '').toString().toLowerCase();
        final specialite = (doc['specialite'] ?? '').toString().toLowerCase();
        final hopital = (doc['hopital'] ?? '').toString().toLowerCase();
        final q = _searchController.text.toLowerCase();
        return name.contains(q) ||
            specialite.contains(q) ||
            hopital.contains(q);
      }).toList();
    }
    setState(() => _doctors = filtered);
  }

  void _onSpecialtyChanged(String? specialty) {
    setState(() =>
        _selectedSpecialty = specialty == _selectedSpecialty ? null : specialty);
    _applyFilters();
  }

  String _specialtyLabel(dynamic specialty) {
    if (specialty is Map) {
      return (specialty['name'] ?? specialty['specialite'] ?? specialty['label'])
              ?.toString() ??
          'Spécialité';
    }
    return specialty?.toString() ?? 'Spécialité';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          // ── AppBar style Doctolib ──────────────────────────────────
          SliverAppBar(
            expandedHeight: 120,
            pinned: true,
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [AppColors.primaryDark, AppColors.primary],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const Text(
                          'Trouver un médecin',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '${_doctors.length} médecin${_doctors.length > 1 ? 's' : ''} disponible${_doctors.length > 1 ? 's' : ''}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // ── Barre de recherche + filtres ───────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Recherche
                  TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Nom, spécialité ou hôpital…',
                      prefixIcon:
                          const Icon(Icons.search, color: AppColors.primary),
                      suffixIcon: _searchController.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _searchController.clear();
                                _applyFilters();
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 14),
                    ),
                    onChanged: (_) => _applyFilters(),
                  ),

                  // Chips spécialités
                  if (_specialties.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 36,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _specialties.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(width: 8),
                        itemBuilder: (context, i) {
                          final name = _specialtyLabel(_specialties[i]);
                          final selected = _selectedSpecialty == name;
                          return GestureDetector(
                            onTap: () => _onSpecialtyChanged(name),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 6),
                              decoration: BoxDecoration(
                                color: selected
                                    ? AppColors.primary
                                    : Colors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: selected
                                      ? AppColors.primary
                                      : AppColors.border,
                                ),
                              ),
                              child: Text(
                                name,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: selected
                                      ? Colors.white
                                      : AppColors.textSecondary,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),

          // ── Liste des médecins ─────────────────────────────────────
          if (_isLoading)
            const SliverFillRemaining(
              child: Center(
                  child: CircularProgressIndicator(color: AppColors.primary)),
            )
          else if (_doctors.isEmpty)
            SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.person_search_rounded,
                        size: 72,
                        color: AppColors.textSecondary.withOpacity(0.4)),
                    const SizedBox(height: 16),
                    const Text('Aucun médecin trouvé',
                        style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 6),
                    Text('Modifiez votre recherche ou filtre',
                        style: TextStyle(
                            fontSize: 13,
                            color: AppColors.textSecondary.withOpacity(0.7))),
                  ],
                ),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) =>
                      _DoctorCard(doctor: _doctors[index], index: index),
                  childCount: _doctors.length,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ── Carte médecin style Doctolib ────────────────────────────────────────────
class _DoctorCard extends StatelessWidget {
  final dynamic doctor;
  final int index;

  const _DoctorCard({required this.doctor, required this.index});

  @override
  Widget build(BuildContext context) {
    final name = doctor['user']?['nom'] ?? doctor['nom'] ?? 'Dr. Inconnu';
    final specialite = doctor['specialite'] ?? 'Médecin généraliste';
    final hopital = doctor['hopital'] ?? '';
    final disponibilite = doctor['disponibilite'] ?? '';
    final photoUrl = doctorPhotoUrl(doctor, index: index);

    // Note : on garde "Dr." uniquement si le nom ne commence pas déjà par Dr
    final displayName =
        name.toString().startsWith('Dr') ? name : 'Dr. $name';

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Bandeau photo + infos ───────────────────────────
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Photo médecin
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: Image.network(
                    photoUrl,
                    width: 86,
                    height: 96,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 86,
                      height: 96,
                      color: AppColors.primary.withOpacity(0.08),
                      child: const Icon(Icons.person_rounded,
                          size: 44, color: AppColors.primary),
                    ),
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        width: 86,
                        height: 96,
                        color: AppColors.surfaceVariant,
                        child: const Center(
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 14),

                // Infos texte
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName.toString(),
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          specialite.toString(),
                          style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (hopital.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            const Icon(Icons.location_on_rounded,
                                size: 13, color: AppColors.textSecondary),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                hopital.toString(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary),
                              ),
                            ),
                          ],
                        ),
                      ],
                      if (disponibilite.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            const Icon(Icons.access_time_rounded,
                                size: 13, color: AppColors.accent),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                disponibilite.toString(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                    fontSize: 12, color: AppColors.accent),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 8),
                      // Badge "Prend en charge" style Doctolib
                      Row(
                        children: [
                          const Icon(Icons.verified_rounded,
                              size: 13, color: AppColors.success),
                          const SizedBox(width: 4),
                          const Text(
                            'Accepte de nouveaux patients',
                            style: TextStyle(
                                fontSize: 11, color: AppColors.success),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Séparateur + bouton RDV ─────────────────────────
          Divider(height: 1, color: AppColors.border),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
            child: SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton.icon(
                onPressed: () {
                  final map = Map<String, dynamic>.from(doctor as Map);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                        builder: (_) => DoctorBookingPage(doctor: map)),
                  );
                },
                icon: const Icon(Icons.calendar_month_rounded, size: 17),
                label: const Text(
                  'Prendre rendez-vous',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
