// lib/main.dart

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'widgets/metric_card.dart';
import 'pages/home_page.dart';
import 'pages/add_patient.dart';
import 'pages/statistics_page.dart';
import 'pages/SponsorPage.dart';
import 'pages/login_page.dart';
import 'pages/profil_page.dart';
import 'pages/patient/patient_navigation.dart';
import 'pages/medecin/medecin_navigation.dart';
import 'services/auth_service.dart';
import 'services/app_data_mode.dart';
import 'models/user.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR');

  // Passer en mode production — désactive toutes les données mockées
  // et force l'utilisation des vrais endpoints Laravel.
  AppDataMode.enableProductionMode();

  runApp(const PlaidoyerSanteApp());
}

// ----------------------------------------------------------------------
// WIDGET PRINCIPAL DE L'APPLICATION
// ----------------------------------------------------------------------

class PlaidoyerSanteApp extends StatelessWidget {
  const PlaidoyerSanteApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,

      // L'écran de démarrage est la vérification d'authentification
      home: const LoginPage(),

      // Configuration des routes
      routes: {
        '/login': (context) => const LoginPage(),
        '/home': (context) => const MainNavigation(),
        '/add-patient': (context) => const AddPatientPage(),
        // '/ai-chat': (context) => const AIChatPage(),
      },
    );
  }
}

// ----------------------------------------------------------------------
// LOGIQUE D'AUTHENTIFICATION AU DÉMARRAGE
// ----------------------------------------------------------------------

class AuthCheck extends StatefulWidget {
  const AuthCheck({super.key});

  @override
  State<AuthCheck> createState() => _AuthCheckState();
}

class _AuthCheckState extends State<AuthCheck> {
  bool _isLoggedIn = false;
  bool _isLoading = true;
  String? _userRole;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus(); 
  }

  Future<void> _checkLoginStatus() async {
    final authService = AuthService.instance;

    // Attendre la vérification du token stocké
    final isLoggedIn = await authService.isLoggedIn();
    final role = await authService.getStoredRole();

    if (mounted) {
      setState(() {
        _isLoggedIn = isLoggedIn;
        _isLoading = false;
        _userRole = role;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      // Écran de chargement avec le logo de l'app
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo médical
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withAlpha((0.3 * 255).round()),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.local_hospital_rounded,
                  size: 70,
                  color: AppColors.textOnPrimary,
                ),
              ),
              const SizedBox(height: 24),
              const CircularProgressIndicator(color: AppColors.primary),
              const SizedBox(height: 16),
              Text(
                AppConstants.appName,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (!_isLoggedIn) return const LoginPage();

    if (_userRole == User.rolePatient) {
      return const PatientNavigation();
    }
    if (_userRole == User.roleDoctor) {
      return const MedecinNavigation();
    }
    return const MainNavigation();
  }
}

// ----------------------------------------------------------------------
// NAVIGATION PRINCIPALE
// ----------------------------------------------------------------------

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  
  final List<Widget> _pages = [
    const HomePage(), 
    const StatisticsPage(),
    const SponsorPage(),
    const ProfilePage(), // ✅ Vraie page de profil
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textSecondary,
        backgroundColor: AppColors.surface,
        elevation: 8,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_rounded),
            label: AppStrings.home,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics_rounded),
            label: AppStrings.statistics,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.people_rounded),
            label: AppStrings.sponsors,
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_rounded),
            label: AppStrings.profile,
          ),
        ],
      ),

      // Bouton flottant (visible seulement sur la page d'accueil)
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton(
              onPressed: () async {
                final result = await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const AddPatientPage(),
                  ),
                );
                if (result == true && mounted) {
                  setState(() {});
                }
              },
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.textOnPrimary,
              child: const Icon(Icons.add_rounded),
            )
          : null,
    );
  }
}