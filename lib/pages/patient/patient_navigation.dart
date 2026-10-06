import 'package:flutter/material.dart';
import 'package:flutter/material.dart';
import '../../widgets/metric_card.dart';
import '../patient_home_page.dart';
import 'patient_appointments_page.dart';
import 'health_history_page.dart';
import 'patient_profile_page.dart';
import '../../widgets/notification_bell.dart';

class PatientNavigation extends StatefulWidget {
  /// Index de l'onglet à afficher au démarrage (0=Accueil, 1=RDV, 2=Dossier, 3=Profil)
  final int initialIndex;

  const PatientNavigation({super.key, this.initialIndex = 0});

  @override
  State<PatientNavigation> createState() => _PatientNavigationState();
}

class _PatientNavigationState extends State<PatientNavigation> {
  late int _currentIndex;

  final List<Widget> _pages = const [
    PatientHomePage(),
    PatientAppointmentsPage(),
    HealthHistoryPage(),
    PatientProfilePage(),
  ];

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          AppConstants.appName,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18),
        ),
        actions: [
          NotificationBell(),
          const SizedBox(width: 4),
        ],
      ),
      body: _pages[_currentIndex],
      bottomNavigationBar: NavigationBar(
        backgroundColor: AppColors.cardBackground,
        elevation: 0,
        selectedIndex: _currentIndex,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        indicatorColor: AppColors.primary.withValues(alpha: 0.14),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Accueil',
          ),
          NavigationDestination(
            icon: Icon(Icons.event_outlined),
            selectedIcon: Icon(Icons.event_available_rounded),
            label: 'RDV',
          ),
          NavigationDestination(
            icon: Icon(Icons.folder_outlined),
            selectedIcon: Icon(Icons.folder_rounded),
            label: 'Dossier',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person_rounded),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
