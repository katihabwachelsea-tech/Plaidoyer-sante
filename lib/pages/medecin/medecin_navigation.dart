import 'package:flutter/material.dart';
import '../../services/offline_sync_service.dart';
import '../../widgets/metric_card.dart';
import 'medecin_appointments_page.dart';
import 'medecin_home_page.dart';
import 'medecin_profile_page.dart';
import 'medecin_schedule_page.dart';

class MedecinNavigation extends StatefulWidget {
  const MedecinNavigation({super.key});

  @override
  State<MedecinNavigation> createState() => _MedecinNavigationState();
}

class _MedecinNavigationState extends State<MedecinNavigation> {
  int _currentIndex = 0;
  late final List<Widget> _pages;
  final _offline = OfflineSyncService.instance;

  @override
  void initState() {
    super.initState();
    _pages = [
      MedecinHomePage(onOpenTab: _openTab),
      const MedecinAppointmentsPage(),
      const MedecinSchedulePage(),
      const MedecinProfilePage(),
    ];
    // V.10.11 : écoute réseau + sync auto au retour
    _offline.start();
  }

  @override
  void dispose() {
    _offline.stop();
    super.dispose();
  }

  void _openTab(int index) => setState(() => _currentIndex = index);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          // Bandeau offline / file de sync
          ValueListenableBuilder<bool>(
            valueListenable: _offline.isOnline,
            builder: (_, online, __) {
              return ValueListenableBuilder<int>(
                valueListenable: _offline.pendingCount,
                builder: (_, pending, __) {
                  if (online && pending == 0) {
                    return const SizedBox.shrink();
                  }
                  final color =
                      online ? AppColors.warning : const Color(0xFF6C757D);
                  final label = online
                      ? '$pending élément(s) en attente de sync — toucher pour synchroniser'
                      : 'Hors ligne — les consultations seront synchronisées au retour du réseau'
                          '${pending > 0 ? ' ($pending en file)' : ''}';
                  return Material(
                    color: color.withValues(alpha: 0.15),
                    child: InkWell(
                      onTap: online
                          ? () async {
                              final r = await _offline.syncNow(reason: 'manual');
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(r.message),
                                  backgroundColor: r.success
                                      ? AppColors.success
                                      : AppColors.error,
                                ),
                              );
                            }
                          : null,
                      child: SafeArea(
                        bottom: false,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          child: Row(
                            children: [
                              Icon(
                                online
                                    ? Icons.cloud_sync_rounded
                                    : Icons.cloud_off_rounded,
                                size: 18,
                                color: color,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: color,
                                  ),
                                ),
                              ),
                              if (online && pending > 0)
                                Text(
                                  'Sync',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    color: color,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
          Expanded(
            child: IndexedStack(index: _currentIndex, children: _pages),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _openTab,
        backgroundColor: Colors.white,
        elevation: 8,
        shadowColor: AppColors.primary.withValues(alpha: 0.08),
        indicatorColor: AppColors.ice,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded, color: AppColors.primary),
            label: 'Accueil',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_outlined),
            selectedIcon:
                Icon(Icons.event_available_rounded, color: AppColors.primary),
            label: 'RDV',
          ),
          NavigationDestination(
            icon: Icon(Icons.schedule_outlined),
            selectedIcon: Icon(Icons.schedule_rounded, color: AppColors.primary),
            label: 'Créneaux',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline_rounded),
            selectedIcon: Icon(Icons.person_rounded, color: AppColors.primary),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
