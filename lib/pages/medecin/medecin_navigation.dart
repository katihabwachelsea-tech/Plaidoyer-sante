import 'package:flutter/material.dart';
import '../../widgets/metric_card.dart';
import '../../widgets/notification_bell.dart';
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

  @override
  void initState() {
    super.initState();
    _pages = [
      MedecinHomePage(onOpenTab: _openTab),
      const MedecinAppointmentsPage(),
      const MedecinSchedulePage(),
      const MedecinProfilePage(),
    ];
  }

  void _openTab(int index) => setState(() => _currentIndex = index);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // La cloche de notifs flotte au-dessus du contenu via un Stack
      body: Stack(
        children: [
          IndexedStack(index: _currentIndex, children: _pages),
          // Cloche positionnée en haut à droite uniquement sur Accueil et RDV
          if (_currentIndex == 0 || _currentIndex == 1)
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 4,
              child: NotificationBell(),
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
            selectedIcon: Icon(Icons.event_available_rounded, color: AppColors.primary),
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
