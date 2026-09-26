// lib/main.dart

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'widgets/metric_card.dart';
import 'pages/login_page.dart';
import 'pages/patient/patient_navigation.dart';
import 'pages/medecin/medecin_navigation.dart';
import 'services/auth_service.dart';
import 'services/app_data_mode.dart';
import 'services/local_reminder_service.dart';
import 'services/push_notification_service.dart';
import 'services/settings_service.dart';
import 'models/user.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR');
  await SettingsService.instance.loadSettings();
  await LocalReminderService.instance.init();

  // Firebase — à activer après ajout de google-services.json
  // await Firebase.initializeApp();

  // Mode production — API Laravel uniquement.
  AppDataMode.enableProductionMode();

  runApp(const MobClinicApp());
}

class MobClinicApp extends StatefulWidget {
  const MobClinicApp({super.key});

  @override
  State<MobClinicApp> createState() => _MobClinicAppState();
}

class _MobClinicAppState extends State<MobClinicApp> {
  final _settings = SettingsService.instance;

  @override
  void initState() {
    super.initState();
    _settings.addListener(_onSettingsChanged);
  }

  @override
  void dispose() {
    _settings.removeListener(_onSettingsChanged);
    super.dispose();
  }

  void _onSettingsChanged() {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final isDark = _settings.cachedDarkMode;

    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: isDark ? ThemeMode.dark : ThemeMode.light,
      home: const AuthCheck(),
      routes: {
        '/login': (context) => const LoginPage(),
      },
    );
  }
}

// ── Vérification du statut de connexion au démarrage ──────────────────────────
class AuthCheck extends StatefulWidget {
  const AuthCheck({super.key});

  @override
  State<AuthCheck> createState() => _AuthCheckState();
}

class _AuthCheckState extends State<AuthCheck> {
  bool _isLoading = true;
  String? _userRole;
  bool _isLoggedIn = false;

  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  Future<void> _checkLoginStatus() async {
    // Toujours démarrer sur la page de connexion — l'utilisateur doit se connecter à chaque lancement
    if (mounted) {
      setState(() {
        _isLoggedIn  = false;
        _userRole    = null;
        _isLoading   = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const _SplashScreen();
    if (!_isLoggedIn) return const LoginPage();
    if (_userRole == User.rolePatient) {
      // FCM désactivé — activer après google-services.json
      // PushNotificationService.instance.init();
      return const PatientNavigation();
    }
    if (_userRole == User.roleDoctor) {
      // PushNotificationService.instance.init();
      return const MedecinNavigation();
    }
    // Rôle inconnu → retour login
    return const LoginPage();
  }
}

// ── Écran de démarrage ─────────────────────────────────────────────────────────
class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 110,
              height: 110,
              decoration: BoxDecoration(
                color: AppColors.primary,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withAlpha(76),
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              child: const Icon(
                Icons.health_and_safety_rounded,
                size: 60,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 24),
            Text(
              AppConstants.appName,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.primary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              AppConstants.appSlogan,
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 32),
            const CircularProgressIndicator(color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}
