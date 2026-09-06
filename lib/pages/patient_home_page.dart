import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/intl.dart';
import '../services/auth_service.dart';
import '../widgets/metric_card.dart';
import '../config/app_config.dart';
import 'doctors_list_page.dart';
import 'patient/doctor_detail_page.dart';
import 'patient/health_detail_page.dart';

class PatientHomePage extends StatefulWidget {
  const PatientHomePage({super.key});

  @override
  State<PatientHomePage> createState() => _PatientHomePageState();
}

class _PatientHomePageState extends State<PatientHomePage> {
  static const _baseUrl = AppConfig.baseUrl;
  static const _storage = FlutterSecureStorage();

  final _searchController = TextEditingController();

  // Médecins
  List<dynamic> _doctors = [];
  List<dynamic> _recommendedDoctors = [];
  bool _isLoading = false;

  // Vrais rendez-vous chargés depuis GET /api/appointments
  List<Map<String, dynamic>> _appointments = [];
  bool _isLoadingAppointments = false;

  @override
  void initState() {
    super.initState();
    _loadDoctors();
    _loadAppointments();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ── Médecins ────────────────────────────────────────────────────────────

  Future<void> _loadDoctors() async {
    setState(() => _isLoading = true);
    try {
      final result = await AuthService.instance.fetchDoctors();
      if (result['success'] == true) {
        final list = result['doctors'] as List<dynamic>? ?? [];
        if (mounted) {
          setState(() {
            _doctors = list;
            _recommendedDoctors = list.take(4).toList();
          });
        }
      }
    } catch (e) {
      debugPrint('Erreur chargement médecins: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ── Rendez-vous ─────────────────────────────────────────────────────────

  /// Charge les vrais rendez-vous du patient connecté.
  /// GET /api/appointments → filtre côté Flutter : futurs + En_attente|Confirme
  Future<void> _loadAppointments() async {
    setState(() => _isLoadingAppointments = true);
    try {
      final token = await _storage.read(key: 'jwt_token');
      if (token == null) return;

      final response = await http
          .get(
            Uri.parse('$_baseUrl/appointments'),
            headers: {
              'Accept': 'application/json',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(const Duration(seconds: 20));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final rawList = data['data'] as List<dynamic>? ?? [];

        final filtered = rawList
            .map((e) => Map<String, dynamic>.from(e as Map))
            .where((appt) {
              final statut = (appt['statut'] as String?) ?? '';
              final rawDate =
                  (appt['date_rdv'] ?? appt['date_heure'] ?? '').toString();
              if (rawDate.isEmpty) return false;
              try {
                final dt =
                    DateTime.parse(rawDate.replaceFirst(' ', 'T'));
                return dt.isAfter(DateTime.now()) &&
                    (statut == 'En_attente' || statut == 'Confirme');
              } catch (_) {
                return false;
              }
            })
            .take(3)
            .toList();

        if (mounted) setState(() => _appointments = filtered);
      }
    } catch (e) {
      debugPrint('Erreur chargement RDV: $e');
    } finally {
      if (mounted) setState(() => _isLoadingAppointments = false);
    }
  }

  // ── Recherche ────────────────────────────────────────────────────────────

  void _searchDoctors(String query) async {
    if (query.isEmpty) {
      _loadDoctors();
      return;
    }
    setState(() => _isLoading = true);
    try {
      final result =
          await AuthService.instance.fetchDoctors(searchQuery: query);
      if (result['success'] == true && mounted) {
        setState(() => _doctors = result['doctors'] as List<dynamic>? ?? []);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _navigateToDoctorsList() {
    Navigator.of(context)
        .push(MaterialPageRoute(builder: (_) => const DoctorsListPage()))
        .then((_) {
      _loadDoctors();
      _loadAppointments();
    });
  }

  // ── Build principal ─────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final user = AuthService.instance.currentUser;
    final firstName = user?.fullName.split(' ').first ?? 'Utilisateur';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // En-tête
            SliverAppBar(
              expandedHeight: 180,
              floating: true,
              elevation: 0,
              backgroundColor: AppColors.primary,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [AppColors.primary, Color(0xFF1565C0)],
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AppSizes.paddingL),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Text(
                          'Bonjour, $firstName 👋',
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                                color: AppColors.textOnPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: AppSizes.paddingS),
                        Text(
                          'Comment allez-vous aujourd\'hui ?',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                                color: AppColors.textOnPrimary.withAlpha(200),
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Contenu principal
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(AppSizes.paddingL),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSearchBar(),
                    const SizedBox(height: AppSizes.paddingXL),

                    Text('Actions rapides',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: AppSizes.paddingM),
                    _buildQuickShortcuts(),
                    const SizedBox(height: AppSizes.paddingXL),

                    Text('Vue d\'ensemble',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: AppSizes.paddingM),
                    _buildHealthOverview(),
                    const SizedBox(height: AppSizes.paddingXL),

                    Text('Prochains rendez-vous',
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold)),
                    const SizedBox(height: AppSizes.paddingM),
                    _buildNextAppointment(),
                    const SizedBox(height: AppSizes.paddingXL),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('Médecins recommandés',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        TextButton(
                          onPressed: _navigateToDoctorsList,
                          child: const Text('Voir tous'),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSizes.paddingM),
                    _buildRecommendedDoctors(),
                    const SizedBox(height: AppSizes.paddingXL),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Widgets ──────────────────────────────────────────────────────────────

  Widget _buildSearchBar() {
    return TextFormField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Chercher un médecin ou une spécialité...',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: _searchController.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  _searchController.clear();
                  _loadDoctors();
                },
              )
            : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onChanged: _searchDoctors,
    );
  }

  Widget _buildQuickShortcuts() {
    // Le compteur de RDV est dynamique — basé sur _appointments réels
    final rdvCount = _appointments.length;
    final quickActions = [
      _ShortcutItem(
        icon: Icons.calendar_today,
        label: 'Rendez-vous',
        subtitle: rdvCount > 0 ? '$rdvCount à venir' : 'Aucun',
        color: AppColors.primary,
        onTap: _navigateToDoctorsList,
      ),
      _ShortcutItem(
        icon: Icons.description,
        label: 'Mes analyses',
        subtitle: 'Voir tout',
        color: const Color(0xFF14B8A6),
        onTap: () => _openHealthDetail('analyses'),
      ),
      _ShortcutItem(
        icon: Icons.local_hospital,
        label: 'Urgences',
        subtitle: 'Accès rapide',
        color: const Color(0xFFEF4444),
        onTap: () => _openHealthDetail('urgences'),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: quickActions.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 0.82,
      ),
      itemBuilder: (context, index) => _buildShortcutCard(quickActions[index]),
    );
  }

  void _openHealthDetail(String section) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => HealthDetailPage(section: section)),
    );
  }

  Widget _buildShortcutCard(_ShortcutItem item) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                item.color.withAlpha((0.14 * 255).round()),
                Colors.white
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
                color: item.color.withAlpha((0.25 * 255).round()), width: 1.5),
            boxShadow: [
              BoxShadow(
                color: item.color.withAlpha((0.08 * 255).round()),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: item.color.withAlpha((0.14 * 255).round()),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(item.icon, color: item.color, size: 22),
              ),
              const SizedBox(height: 10),
              Text(
                item.label,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                item.subtitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: item.color,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHealthOverview() {
    // Ces données n'ont pas d'endpoint dédié dans le backend actuel.
    // Elles restent illustratives — un badge "Info" indique qu'elles
    // ne proviennent pas de mesures réelles.
    final overview = [
      _OverviewItem(
          title: 'Pression',
          value: '—',
          meta: 'Non renseigné',
          color: const Color(0xFF3B82F6)),
      _OverviewItem(
          title: 'Glycémie',
          value: '—',
          meta: 'Non renseigné',
          color: const Color(0xFF14B8A6)),
      _OverviewItem(
          title: 'Suivi',
          value: '${_appointments.length}',
          meta: 'RDV à venir',
          color: const Color(0xFFF59E0B)),
    ];

    return Row(
      children: overview
          .map(
            (item) => Expanded(
              child: Container(
                margin: const EdgeInsets.only(right: 12),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: item.color.withAlpha((0.2 * 255).round()),
                      width: 1),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(16),
                      blurRadius: 8,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.title,
                        style: Theme.of(context)
                            .textTheme
                            .labelSmall
                            ?.copyWith(
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w600,
                            )),
                    const SizedBox(height: 8),
                    Text(item.value,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(
                              color: item.color,
                              fontWeight: FontWeight.bold,
                            )),
                    const SizedBox(height: 4),
                    Text(item.meta,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }

  /// Section Prochains rendez-vous — données réelles depuis GET /api/appointments
  Widget _buildNextAppointment() {
    // Chargement en cours
    if (_isLoadingAppointments) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 32),
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Aucun RDV à venir
    if (_appointments.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withAlpha(18),
                blurRadius: 12,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          children: [
            Icon(Icons.event_available,
                size: 48,
                color: AppColors.primary.withAlpha((0.55 * 255).round())),
            const SizedBox(height: 12),
            const Text('Aucun rendez-vous à venir',
                style:
                    TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            const SizedBox(height: 6),
            Text(
              'Prenez rendez-vous avec l\'un de nos médecins',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _navigateToDoctorsList,
                icon: const Icon(Icons.search),
                label: const Text('Trouver un médecin'),
              ),
            ),
          ],
        ),
      );
    }

    // RDV réels chargés depuis le backend
    final dateFormat = DateFormat('EEE d MMM • HH:mm', 'fr_FR');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withAlpha(18),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          // En-tête avec bouton actualiser
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primary.withAlpha((0.12 * 255).round()),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.calendar_month,
                    color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${_appointments.length} rendez-vous à venir',
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.refresh,
                    size: 20, color: AppColors.primary),
                tooltip: 'Actualiser',
                onPressed: _loadAppointments,
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Cartes RDV
          ..._appointments.map((appt) {
            // Extraction des champs retournés par AppointmentController.index()
            final medecinObj =
                appt['medecin'] as Map<String, dynamic>?;
            final medecinUser =
                medecinObj?['user'] as Map<String, dynamic>?;
            final doctorName =
                medecinUser?['nom'] ?? appt['motif'] ?? 'Médecin';

            final serviceObj =
                appt['service'] as Map<String, dynamic>?;
            final serviceName =
                serviceObj?['nom_service'] ?? appt['motif'] ?? 'Consultation';

            final statut = (appt['statut'] as String?) ?? '';
            final isConfirme = statut == 'Confirme';

            // Format date — Laravel retourne date_rdv (datetime)
            final rawDate =
                (appt['date_rdv'] ?? appt['date_heure'] ?? '').toString();
            String dateLabel = rawDate;
            try {
              final dt = DateTime.parse(rawDate.replaceFirst(' ', 'T'))
                  .toLocal();
              dateLabel = dateFormat.format(dt);
            } catch (_) {}

            return Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.primary.withAlpha((0.04 * 255).round()),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color:
                        AppColors.primary.withAlpha((0.15 * 255).round())),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(doctorName,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 3),
                        Text(serviceName,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                    color: AppColors.textSecondary)),
                        Text(dateLabel,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                                    color: AppColors.textSecondary)),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: isConfirme
                          ? Colors.green.shade50
                          : Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      isConfirme ? 'Confirmé ✓' : 'En attente',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color:
                            isConfirme ? Colors.green : Colors.orange,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),

          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _navigateToDoctorsList,
              icon: const Icon(Icons.add),
              label: const Text('Nouveau rendez-vous'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendedDoctors() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_recommendedDoctors.isEmpty) {
      return Center(
        child: Text('Aucun médecin disponible',
            style: Theme.of(context).textTheme.bodyMedium),
      );
    }

    return SizedBox(
      height: 220,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: _recommendedDoctors.length,
        itemBuilder: (context, index) =>
            _buildDoctorCard(_recommendedDoctors[index]),
      ),
    );
  }

  Widget _buildDoctorCard(dynamic doctor) {
    final specialite = doctor['specialite'] ?? 'Médecin';
    final name = doctor['user']?['nom'] ?? doctor['nom'] ?? 'Dr. Inconnu';
    final imageUrl =
        doctor['user']?['profileImageUrl'] ?? doctor['profileImageUrl'];

    return InkWell(
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
            builder: (_) => DoctorDetailPage(doctor: doctor)),
      ),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: 160,
        margin: const EdgeInsets.only(right: AppSizes.paddingM),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withAlpha(25),
                blurRadius: 8,
                offset: const Offset(0, 2)),
          ],
        ),
        child: Column(
          children: [
            Container(
              height: 100,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
                color: AppColors.primary.withAlpha((0.1 * 255).round()),
                image: imageUrl != null
                    ? DecorationImage(
                        image: NetworkImage(imageUrl as String),
                        fit: BoxFit.cover)
                    : null,
              ),
              child: imageUrl == null
                  ? const Icon(Icons.person,
                      size: 50, color: AppColors.primary)
                  : null,
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 13)),
                    Text(specialite,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary)),
                    const Spacer(),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) =>
                                  DoctorDetailPage(doctor: doctor)),
                        ),
                        style: ElevatedButton.styleFrom(
                            padding:
                                const EdgeInsets.symmetric(vertical: 4)),
                        child: const Text('RDV',
                            style: TextStyle(fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Data classes ────────────────────────────────────────────────────────────

class _ShortcutItem {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _ShortcutItem({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });
}

class _OverviewItem {
  final String title;
  final String value;
  final String meta;
  final Color color;

  const _OverviewItem({
    required this.title,
    required this.value,
    required this.meta,
    required this.color,
  });
}
