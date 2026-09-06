// lib/pages/medecin/medecin_home_page.dart

import 'package:flutter/material.dart';
import '../../models/appointment.dart';
import '../../services/medecin_api_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/metric_card.dart';
import 'medecin_appointments_page.dart';

class MedecinHomePage extends StatefulWidget {
  const MedecinHomePage({super.key});

  @override
  State<MedecinHomePage> createState() => _MedecinHomePageState();
}

class _MedecinHomePageState extends State<MedecinHomePage> {
  final _api = MedecinApiService.instance;
  int _todayCount = 0;
  bool _isLoading = true;
  String? _error;
  String _doctorName = 'Médecin'; // sera remplacé par le vrai nom via API

  @override
  void initState() {
    super.initState();
    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      // Charger le nombre de RDV du jour ET le profil en parallèle
      final results = await Future.wait([
        _api.getTodayAppointmentsCount(),
        _api.getProfile().catchError((_) => _fallbackProfile()),
      ]);

      if (mounted) {
        setState(() {
          _todayCount = results[0] as int;
          final profile = results[1] as MedecinProfile;
          _doctorName = profile.nom ?? 'Médecin';
          _isLoading = false;
        });
      }
    } catch (e) {
      // Fallback : essayer de récupérer le nom depuis AuthService
      final user = AuthService.instance.currentUser;
      if (mounted) {
        setState(() {
          _doctorName = user?.fullName ?? 'Médecin';
          _error = e.toString();
          _isLoading = false;
        });
      }
    }
  }

  MedecinProfile _fallbackProfile() {
    final user = AuthService.instance.currentUser;
    return MedecinProfile(
      id: 0,
      userId: 0,
      specialite: user?.specialization ?? '',
      hopital: '',
      nom: user?.fullName,
    );
  }

  @override
  Widget build(BuildContext context) {
    final quickActions = [
      _ShortcutItem(
        icon: Icons.event_available_rounded,
        label: 'RDV aujourd’hui',
        subtitle: '$_todayCount confirmés',
        color: AppColors.primary,
        onTap: () => _openAppointments(context),
      ),
      _ShortcutItem(
        icon: Icons.calendar_month_rounded,
        label: 'Agenda',
        subtitle: '3 créneaux',
        color: const Color(0xFF14B8A6),
        onTap: () => _openAppointments(context),
      ),
      _ShortcutItem(
        icon: Icons.medical_services_rounded,
        label: 'Consultations',
        subtitle: '2 en cours',
        color: const Color(0xFFF59E0B),
        onTap: () => _openAppointments(context),
      ),
    ];

    final summaryCards = [
      _SummaryItem(title: 'Patients', value: '48', meta: 'Actifs ce mois', color: AppColors.primary),
      _SummaryItem(title: 'Taux suivi', value: '92%', meta: 'Très bon', color: const Color(0xFF14B8A6)),
      _SummaryItem(title: 'Disponibilité', value: '14h', meta: 'À confirmer', color: const Color(0xFF3B82F6)),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _loadDashboard,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(AppSizes.paddingL),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, Color(0xFF1565C0)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Bonjour, $_doctorName 👋',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Votre journée est bien remplie. Voici le résumé du moment.',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Colors.white70,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Actions rapides',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: quickActions.length,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        crossAxisSpacing: 12,
                        mainAxisSpacing: 12,
                        childAspectRatio: 0.82,
                      ),
                      itemBuilder: (context, index) {
                        final item = quickActions[index];
                        return _buildQuickCard(item, context);
                      },
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Vue d’ensemble',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: summaryCards.map((card) {
                        return Expanded(
                          child: Container(
                            margin: const EdgeInsets.only(right: 10),
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: card.color.withAlpha((0.2 * 255).round()), width: 1),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withAlpha(12),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  card.title,
                                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  card.value,
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: card.color,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  card.meta,
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 24),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.shade50,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.orange),
                        ),
                        child: Text(
                          'Mode hors-ligne ou API indisponible.\n$_error',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: () => _openAppointments(context),
                        icon: const Icon(Icons.medical_services_rounded),
                        label: const Text('Mes rendez-vous'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: AppColors.textOnPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildQuickCard(_ShortcutItem item, BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: item.onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [item.color.withAlpha((0.14 * 255).round()), Colors.white],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: item.color.withAlpha((0.22 * 255).round()), width: 1.5),
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

  void _openAppointments(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const MedecinAppointmentsPage()),
    ).then((_) => _loadDashboard());
  }
}

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

class _SummaryItem {
  final String title;
  final String value;
  final String meta;
  final Color color;

  const _SummaryItem({
    required this.title,
    required this.value,
    required this.meta,
    required this.color,
  });
}
