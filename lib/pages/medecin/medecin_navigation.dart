// lib/pages/medecin/medecin_navigation.dart

import 'package:flutter/material.dart';
import '../../widgets/metric_card.dart';
import 'medecin_home_page.dart';
import 'medecin_appointments_page.dart';
import 'medecin_schedule_page.dart';
import 'medecin_profile_page.dart';

class MedecinNavigation extends StatefulWidget {
  const MedecinNavigation({super.key});

  @override
  State<MedecinNavigation> createState() => _MedecinNavigationState();
}

class _MedecinNavigationState extends State<MedecinNavigation> {
  int _currentIndex = 0;

  final List<Widget> _pages = const [
    MedecinHomePage(),
    MedecinAppointmentsPage(),
    MedecinSchedulePage(),
    MedecinProfilePage(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (i) => setState(() => _currentIndex = i),
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard_rounded),
            label: 'Accueil',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.event_available_rounded),
            label: 'RDV',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.schedule_rounded),
            label: 'Créneaux',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: 'Profil',
          ),
        ],
      ),
    );
  }
}
