// lib/config/app_config.dart
//
// Point unique de configuration de l'application.
// Changer l'URL ici suffit pour que tout le projet pointe vers le bon serveur.

class AppConfig {
  AppConfig._();

  // ── URL du backend Laravel ────────────────────────────────────────────────
  // Émulateur Android : 10.0.2.2  (redirige vers localhost de la machine hôte)
  // Appareil physique  : IP LAN de ta machine (ex: 192.168.x.x ou 172.20.10.2)
  static const String _host = '192.168.30.24';
  static const int _port = 8000;

  static const String baseUrl = 'http://$_host:$_port/api';

  // ── Timeouts ──────────────────────────────────────────────────────────────
  static const Duration defaultTimeout = Duration(seconds: 30);
  static const Duration shortTimeout   = Duration(seconds: 15);

  // ── Clés de stockage sécurisé ─────────────────────────────────────────────
  static const String keyJwtToken  = 'jwt_token';
  static const String keyUserRole  = 'user_role';
}
