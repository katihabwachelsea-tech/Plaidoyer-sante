// // lib/utils/constants.dart

// import 'package:flutter/material.dart';

// class AppConstants {
//   // URLs de l'API
//   static const String baseUrl = 'https://votre-api.com';
//   static const String patientsEndpoint = '/patients';
//   static const String sponsorsEndpoint = '/sponsors';
//   static const String statsEndpoint = '/statistics';
  
//   // Textes de l'application
//   static const String appName = 'Mob-Clinic';
//   static const String appSlogan = 'Suivi des patients atteints du cancer';
// }

// class AppColors {
//   // Couleurs principales basées sur l'UI
//   static const Color primary = Color(0xFF6C63FF);        // Violet principal
//   static const Color primaryLight = Color(0xFF9C95FF);   // Violet clair
//   static const Color primaryDark = Color(0xFF4C46CC);    // Violet foncé
  
//   // Couleurs des cartes métriques
//   static const Color tealCard = Color(0xFF4ECDC4);       // Carte turquoise (Journal Stats)
//   static const Color purpleCard = Color(0xFF9B59B6);     // Carte violette (Sleep Report)
//   static const Color orangeCard = Color(0xFFE67E22);     // Carte orange/pêche
//   static const Color greenCard = Color(0xFF2ECC71);      // Carte verte
//   static const Color blueCard = Color(0xFF3498DB);       // Carte bleue
//   static const Color pinkCard = Color(0xFFE91E63);       // Carte rose
  
//   // Couleurs de fond et surfaces
//   static const Color background = Color(0xFFF8F9FA);     // Fond principal
//   static const Color cardBackground = Color(0xFFFFFFFF); // Fond des cartes
//   static const Color surface = Color(0xFFFFFFFF);        // Surface
//   static const Color surfaceVariant = Color(0xFFF5F5F5); // Variante de surface
  
//   // Couleurs de texte
//   static const Color textPrimary = Color(0xFF2C3E50);    // Texte principal
//   static const Color textSecondary = Color(0xFF7F8C8D);  // Texte secondaire
//   static const Color textLight = Color(0xFFBDC3C7);      // Texte clair
//   static const Color textOnPrimary = Color(0xFFFFFFFF);  // Texte sur couleur primaire
  
//   // Couleurs d'état
//   static const Color success = Color(0xFF27AE60);        // Succès
//   static const Color warning = Color(0xFFF39C12);        // Avertissement
//   static const Color error = Color(0xFFE74C3C);          // Erreur
//   static const Color info = Color(0xFF3498DB);           // Information
  
//   // Couleurs des graphiques
//   static const Color chartLine = Color(0xFF34495E);      // Ligne de graphique
//   static const Color chartFill = Color(0x1A3498DB);      // Remplissage de graphique
  
//   // Ombres et bordures
//   static const Color shadow = Color(0x1A000000);         // Ombre
//   static const Color border = Color(0xFFE1E8ED);         // Bordure
// }

// class AppTheme {
//   // Thème clair
//   static ThemeData lightTheme = ThemeData(
//     useMaterial3: true,
//     brightness: Brightness.light,
//     colorScheme: const ColorScheme.light(
//       primary: AppColors.primary,
//       secondary: AppColors.primaryLight,
//       surface: AppColors.surface,
//       background: AppColors.background,
//       error: AppColors.error,
//       onPrimary: AppColors.textOnPrimary,
//       onSecondary: AppColors.textOnPrimary,
//       onSurface: AppColors.textPrimary,
//       onBackground: AppColors.textPrimary,
//       onError: AppColors.textOnPrimary,
//     ),
    
//     // Configuration des cartes
//     cardTheme: CardTheme(
//       color: AppColors.cardBackground,
//       elevation: 4,
//       shadowColor: AppColors.shadow,
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(16),
//       ),
//       margin: const EdgeInsets.all(8),
//     ),
    
//     // Configuration des boutons
//     elevatedButtonTheme: ElevatedButtonThemeData(
//       style: ElevatedButton.styleFrom(
//         backgroundColor: AppColors.primary,
//         foregroundColor: AppColors.textOnPrimary,
//         elevation: 2,
//         padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(12),
//         ),
//       ),
//     ),
    
//     // Configuration de l'AppBar
//     appBarTheme: const AppBarTheme(
//       backgroundColor: AppColors.primary,
//       foregroundColor: AppColors.textOnPrimary,
//       elevation: 0,
//       centerTitle: true,
//       titleTextStyle: TextStyle(
//         fontSize: 20,
//         fontWeight: FontWeight.w600,
//         color: AppColors.textOnPrimary,
//       ),
//     ),
    
//     // Configuration du texte
//     textTheme: const TextTheme(
//       headlineLarge: TextStyle(
//         fontSize: 32,
//         fontWeight: FontWeight.bold,
//         color: AppColors.textPrimary,
//       ),
//       headlineMedium: TextStyle(
//         fontSize: 28,
//         fontWeight: FontWeight.w600,
//         color: AppColors.textPrimary,
//       ),
//       headlineSmall: TextStyle(
//         fontSize: 24,
//         fontWeight: FontWeight.w600,
//         color: AppColors.textPrimary,
//       ),
//       titleLarge: TextStyle(
//         fontSize: 22,
//         fontWeight: FontWeight.w600,
//         color: AppColors.textPrimary,
//       ),
//       titleMedium: TextStyle(
//         fontSize: 16,
//         fontWeight: FontWeight.w500,
//         color: AppColors.textPrimary,
//       ),
//       titleSmall: TextStyle(
//         fontSize: 14,
//         fontWeight: FontWeight.w500,
//         color: AppColors.textSecondary,
//       ),
//       bodyLarge: TextStyle(
//         fontSize: 16,
//         color: AppColors.textPrimary,
//       ),
//       bodyMedium: TextStyle(
//         fontSize: 14,
//         color: AppColors.textPrimary,
//       ),
//       bodySmall: TextStyle(
//         fontSize: 12,
//         color: AppColors.textSecondary,
//       ),
//     ),
    
//     // Configuration des input fields
//     inputDecorationTheme: InputDecorationTheme(
//       border: OutlineInputBorder(
//         borderRadius: BorderRadius.circular(12),
//         borderSide: const BorderSide(color: AppColors.border),
//       ),
//       enabledBorder: OutlineInputBorder(
//         borderRadius: BorderRadius.circular(12),
//         borderSide: const BorderSide(color: AppColors.border),
//       ),
//       focusedBorder: OutlineInputBorder(
//         borderRadius: BorderRadius.circular(12),
//         borderSide: const BorderSide(color: AppColors.primary, width: 2),
//       ),
//       filled: true,
//       fillColor: AppColors.surfaceVariant,
//       contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//     ),
//   );

//   // ✅ THÈME SOMBRE (NOUVEAU)
//   static ThemeData darkTheme = ThemeData(
//     useMaterial3: true,
//     brightness: Brightness.dark,
//     colorScheme: ColorScheme.dark(
//       primary: AppColors.primary,
//       secondary: AppColors.primaryLight,
//       surface: const Color(0xFF1E1E1E),
//       background: const Color(0xFF121212),
//       error: AppColors.error,
//       onPrimary: AppColors.textOnPrimary,
//       onSecondary: AppColors.textOnPrimary,
//       onSurface: Colors.white,
//       onBackground: Colors.white,
//       onError: AppColors.textOnPrimary,
//     ),
    
//     cardTheme: CardTheme(
//       color: const Color(0xFF2C2C2C),
//       elevation: 4,
//       shadowColor: Colors.black.withOpacity(0.5),
//       shape: RoundedRectangleBorder(
//         borderRadius: BorderRadius.circular(16),
//       ),
//       margin: const EdgeInsets.all(8),
//     ),
    
//     elevatedButtonTheme: ElevatedButtonThemeData(
//       style: ElevatedButton.styleFrom(
//         backgroundColor: AppColors.primary,
//         foregroundColor: AppColors.textOnPrimary,
//         elevation: 2,
//         padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
//         shape: RoundedRectangleBorder(
//           borderRadius: BorderRadius.circular(12),
//         ),
//       ),
//     ),
    
//     appBarTheme: const AppBarTheme(
//       backgroundColor: Color(0xFF1E1E1E),
//       foregroundColor: Colors.white,
//       elevation: 0,
//       centerTitle: true,
//       titleTextStyle: TextStyle(
//         fontSize: 20,
//         fontWeight: FontWeight.w600,
//         color: Colors.white,
//       ),
//     ),
    
//     textTheme: const TextTheme(
//       headlineLarge: TextStyle(
//         fontSize: 32,
//         fontWeight: FontWeight.bold,
//         color: Colors.white,
//       ),
//       headlineMedium: TextStyle(
//         fontSize: 28,
//         fontWeight: FontWeight.w600,
//         color: Colors.white,
//       ),
//       headlineSmall: TextStyle(
//         fontSize: 24,
//         fontWeight: FontWeight.w600,
//         color: Colors.white,
//       ),
//       titleLarge: TextStyle(
//         fontSize: 22,
//         fontWeight: FontWeight.w600,
//         color: Colors.white,
//       ),
//       titleMedium: TextStyle(
//         fontSize: 16,
//         fontWeight: FontWeight.w500,
//         color: Colors.white,
//       ),
//       titleSmall: TextStyle(
//         fontSize: 14,
//         fontWeight: FontWeight.w500,
//         color: Colors.white70,
//       ),
//       bodyLarge: TextStyle(
//         fontSize: 16,
//         color: Colors.white,
//       ),
//       bodyMedium: TextStyle(
//         fontSize: 14,
//         color: Colors.white,
//       ),
//       bodySmall: TextStyle(
//         fontSize: 12,
//         color: Colors.white70,
//       ),
//     ),
    
//     inputDecorationTheme: InputDecorationTheme(
//       border: OutlineInputBorder(
//         borderRadius: BorderRadius.circular(12),
//         borderSide: const BorderSide(color: Color(0xFF424242)),
//       ),
//       enabledBorder: OutlineInputBorder(
//         borderRadius: BorderRadius.circular(12),
//         borderSide: const BorderSide(color: Color(0xFF424242)),
//       ),
//       focusedBorder: OutlineInputBorder(
//         borderRadius: BorderRadius.circular(12),
//         borderSide: const BorderSide(color: AppColors.primary, width: 2),
//       ),
//       filled: true,
//       fillColor: const Color(0xFF2C2C2C),
//       contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
//     ),
//   );
// }

// class AppSizes {
//   // Espacements
//   static const double paddingXS = 4.0;
//   static const double paddingS = 8.0;
//   static const double paddingM = 16.0;
//   static const double paddingL = 24.0;
//   static const double paddingXL = 32.0;
  
//   // Rayons de bordure
//   static const double radiusS = 8.0;
//   static const double radiusM = 12.0;
//   static const double radiusL = 16.0;
//   static const double radiusXL = 24.0;
  
//   // Tailles d'icônes
//   static const double iconS = 16.0;
//   static const double iconM = 24.0;
//   static const double iconL = 32.0;
//   static const double iconXL = 48.0;
// }

// class AppStrings {
//   // Textes généraux
//   static const String loading = 'Chargement...';
//   static const String error = 'Une erreur est survenue';
//   static const String retry = 'Réessayer';
//   static const String cancel = 'Annuler';
//   static const String confirm = 'Confirmer';
//   static const String save = 'Enregistrer';
//   static const String delete = 'Supprimer';
//   static const String edit = 'Modifier';
//   static const String add = 'Ajouter';
  
//   // Navigation
//   static const String patients = 'Patients';
//   static const String statistics = 'Statistiques';
//   static const String sponsors = 'Sponsors';
//   static const String profile = 'Profil';
  
//   // Métriques de santé
//   static const String mentalHealth = 'Santé Mentale';
//   static const String heartRate = 'Fréquence Cardiaque';
//   static const String sleepQuality = 'Qualité du Sommeil';
//   static const String wellbeing = 'Bien-être';
//   static const String journalStats = 'Statistiques Journal';
// }