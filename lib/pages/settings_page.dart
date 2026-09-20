// lib/pages/settings_page.dart

import 'package:flutter/material.dart';
import '../widgets/metric_card.dart';
import '../services/settings_service.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _settingsService = SettingsService.instance;

  bool _isDarkMode = false;
  double _fontSize = 1.0;
  String _language = 'fr';

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  // Charger les paramètres sauvegardés
  Future<void> _loadSettings() async {
    final isDark = await _settingsService.isDarkMode();
    final fontSize = await _settingsService.getFontSize();
    final language = await _settingsService.getLanguage();

    setState(() {
      _isDarkMode = isDark;
      _fontSize = fontSize;
      _language = language;
    });
  }

  // Changer le thème
  Future<void> _toggleTheme(bool value) async {
    setState(() {
      _isDarkMode = value;
    });
    await _settingsService.setDarkMode(value);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(value ? 'Mode sombre activé' : 'Mode clair activé'),
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
      );
    }
  }

  // Changer la taille de police
  Future<void> _changeFontSize(double value) async {
    setState(() {
      _fontSize = value;
    });
    await _settingsService.setFontSize(value);
  }

  // Changer la langue
  Future<void> _changeLanguage(String? value) async {
    if (value == null) return;
    
    setState(() {
      _language = value;
    });
    await _settingsService.setLanguage(value);
    
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('🌐 Langue changée: ${_getLanguageName(value)}'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  String _getLanguageName(String code) {
    switch (code) {
      case 'fr':
        return 'Français';
      case 'en':
        return 'English';
      case 'rn':
        return 'Kirundi';
      default:
        return code;
    }
  }

  String _getFontSizeLabel(double value) {
    if (value <= 0.85) return 'Petit';
    if (value <= 1.0) return 'Normal';
    if (value <= 1.15) return 'Grand';
    return 'Très grand';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Paramètres'),
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ============ SECTION : APPARENCE ============
          _buildSectionHeader(
            icon: Icons.palette_outlined,
            title: 'Apparence',
            color: AppColors.primary,
          ),
          const SizedBox(height: 12),

          // Thème sombre/clair
          _buildThemeCard(),

          const SizedBox(height: 32),

          // ============ SECTION : ACCESSIBILITÉ ============
          _buildSectionHeader(
            icon: Icons.accessibility_new_rounded,
            title: 'Accessibilité',
            color: AppColors.success,
          ),
          const SizedBox(height: 12),

          // Taille de la police
          _buildFontSizeCard(),

          const SizedBox(height: 32),

          // ============ SECTION : LANGUE ============
          _buildSectionHeader(
            icon: Icons.language_rounded,
            title: 'Langue',
            color: AppColors.info,
          ),
          const SizedBox(height: 12),

          // Sélection de langue
          _buildLanguageCard(),

          const SizedBox(height: 32),

          // ============ SECTION : NOTIFICATIONS ============
          _buildSectionHeader(
            icon: Icons.notifications_outlined,
            title: 'Notifications',
            color: AppColors.warning,
          ),
          const SizedBox(height: 12),

          _buildNotificationsCard(),

          const SizedBox(height: 32),

          // ============ SECTION : DONNÉES ============
          _buildSectionHeader(
            icon: Icons.storage_rounded,
            title: 'Données',
            color: AppColors.error,
          ),
          const SizedBox(height: 12),

          _buildDataCard(),

          const SizedBox(height: 32),

          // ============ SECTION : À PROPOS ============
          _buildSectionHeader(
            icon: Icons.info_outline_rounded,
            title: 'À propos',
            color: AppColors.textSecondary,
          ),
          const SizedBox(height: 12),

          _buildAboutCard(),

          const SizedBox(height: 32),
        ],
      ),
    );
  }

  // ========================================================================
  // WIDGETS : EN-TÊTES DE SECTION
  // ========================================================================
  Widget _buildSectionHeader({
    required IconData icon,
    required String title,
    required Color color,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 12),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: color,
              ),
        ),
      ],
    );
  }

  // ========================================================================
  // CARTE : THÈME
  // ========================================================================
  Widget _buildThemeCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  _isDarkMode ? Icons.dark_mode : Icons.light_mode,
                  color: AppColors.primary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mode ${_isDarkMode ? 'sombre' : 'clair'}',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Réduire la fatigue oculaire',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: _isDarkMode,
                  onChanged: _toggleTheme,
                  activeColor: AppColors.primary,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: (_isDarkMode ? Colors.grey[800] : Colors.grey[100]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildThemePreview(
                    label: 'Clair',
                    isSelected: !_isDarkMode,
                    colors: [Colors.white, Colors.grey[200]!],
                    onTap: () => _toggleTheme(false),
                  ),
                  _buildThemePreview(
                    label: 'Sombre',
                    isSelected: _isDarkMode,
                    colors: [Colors.grey[900]!, Colors.grey[800]!],
                    onTap: () => _toggleTheme(true),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildThemePreview({
    required String label,
    required bool isSelected,
    required List<Color> colors,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: colors),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? AppColors.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: colors[0].computeLuminance() > 0.5
                ? Colors.black87
                : Colors.white,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // ========================================================================
  // CARTE : TAILLE DE POLICE
  // ========================================================================
  Widget _buildFontSizeCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.text_fields_rounded,
                  color: AppColors.success,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Taille du texte',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _getFontSizeLabel(_fontSize),
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            
            // Aperçu du texte
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Exemple de texte médical\nDiagnostic : Cancer du sein',
                style: TextStyle(
                  fontSize: 14 * _fontSize,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Slider de taille
            Row(
              children: [
                const Icon(Icons.text_decrease, size: 16),
                Expanded(
                  child: Slider(
                    value: _fontSize,
                    min: 0.8,
                    max: 1.3,
                    divisions: 5,
                    label: _getFontSizeLabel(_fontSize),
                    activeColor: AppColors.success,
                    onChanged: _changeFontSize,
                  ),
                ),
                const Icon(Icons.text_increase, size: 20),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ========================================================================
  // CARTE : LANGUE
  // ========================================================================
  Widget _buildLanguageCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          _buildLanguageTile(
            flag: '🇫🇷',
            name: 'Français',
            code: 'fr',
            isSelected: _language == 'fr',
          ),
          const Divider(height: 1),
          _buildLanguageTile(
            flag: '🇬🇧',
            name: 'English',
            code: 'en',
            isSelected: _language == 'en',
          ),
          const Divider(height: 1),
          _buildLanguageTile(
            flag: '🇧🇮',
            name: 'Kirundi',
            code: 'rn',
            isSelected: _language == 'rn',
          ),
        ],
      ),
    );
  }

  Widget _buildLanguageTile({
    required String flag,
    required String name,
    required String code,
    required bool isSelected,
  }) {
    return ListTile(
      leading: Text(flag, style: const TextStyle(fontSize: 28)),
      title: Text(
        name,
        style: TextStyle(
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      trailing: isSelected
          ? const Icon(Icons.check_circle, color: AppColors.success)
          : null,
      onTap: () => _changeLanguage(code),
    );
  }

  // ========================================================================
  // CARTE : NOTIFICATIONS
  // ========================================================================
  Widget _buildNotificationsCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.alarm, color: AppColors.warning),
            title: const Text('Rappels de rendez-vous'),
            subtitle: const Text('Recevoir des alertes'),
            value: true,
            onChanged: (value) {
              // TODO: Implémenter
            },
          ),
          const Divider(height: 1),
          SwitchListTile(
            secondary: const Icon(Icons.update, color: AppColors.info),
            title: const Text('Mises à jour'),
            subtitle: const Text('Nouvelles fonctionnalités'),
            value: false,
            onChanged: (value) {
              // TODO: Implémenter
            },
          ),
        ],
      ),
    );
  }

  // ========================================================================
  // CARTE : DONNÉES
  // ========================================================================
  Widget _buildDataCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.info.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.cloud_download, color: AppColors.info),
            ),
            title: const Text('Synchroniser les données'),
            subtitle: const Text('Mettre à jour depuis le serveur'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {
              // TODO: Implémenter sync
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Synchronisation...')),
              );
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(Icons.delete_forever, color: AppColors.error),
            ),
            title: const Text('Effacer le cache'),
            subtitle: const Text('Libérer de l\'espace'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: _confirmClearCache,
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClearCache() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Effacer le cache'),
        content: const Text('Êtes-vous sûr ? Les images seront rechargées.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
            child: const Text('Effacer'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      // TODO: Implémenter clear cache
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Cache effacé'),
          backgroundColor: AppColors.success,
        ),
      );
    }
  }

  // ========================================================================
  // CARTE : À PROPOS
  // ========================================================================
  Widget _buildAboutCard() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Version'),
            subtitle: const Text('1.0.0'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: const Text('Conditions d\'utilisation'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {},
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: const Text('Politique de confidentialité'),
            trailing: const Icon(Icons.arrow_forward_ios, size: 16),
            onTap: () {},
          ),
        ],
      ),
    );
  }
}