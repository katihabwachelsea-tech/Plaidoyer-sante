// lib/pages/medecin/medecin_profile_page.dart

import 'package:flutter/material.dart';
import '../../models/appointment.dart';
import '../../services/medecin_api_service.dart';
import '../../services/auth_service.dart';
import '../../widgets/metric_card.dart';
import '../login_page.dart';

class MedecinProfilePage extends StatefulWidget {
  const MedecinProfilePage({super.key});

  @override
  State<MedecinProfilePage> createState() => _MedecinProfilePageState();
}

class _MedecinProfilePageState extends State<MedecinProfilePage> {
  final _api = MedecinApiService.instance;
  final _formKey = GlobalKey<FormState>();

  bool _isLoading = true;
  bool _isSaving = false;

  late TextEditingController _nomController;
  late TextEditingController _telephoneController;
  late TextEditingController _specialiteController;
  late TextEditingController _hopitalController;
  late TextEditingController _biographieController;
  late TextEditingController _disponibiliteController;

  @override
  void initState() {
    super.initState();
    _nomController = TextEditingController();
    _telephoneController = TextEditingController();
    _specialiteController = TextEditingController();
    _hopitalController = TextEditingController();
    _biographieController = TextEditingController();
    _disponibiliteController = TextEditingController();
    _loadProfile();
  }

  @override
  void dispose() {
    _nomController.dispose();
    _telephoneController.dispose();
    _specialiteController.dispose();
    _hopitalController.dispose();
    _biographieController.dispose();
    _disponibiliteController.dispose();
    super.dispose();
  }

  void _fillControllers(MedecinProfile p) {
    _nomController.text = p.nom ?? '';
    _telephoneController.text = p.telephone ?? '';
    _specialiteController.text = p.specialite;
    _hopitalController.text = p.hopital;
    _biographieController.text = p.biographie ?? '';
    _disponibiliteController.text = p.disponibilite ?? '';
  }

  Future<void> _loadProfile() async {
    setState(() => _isLoading = true);
    try {
      final profile = await _api.getProfile();
      if (mounted) {
        setState(() {
          _fillControllers(profile);
          _isLoading = false;
        });
      }
    } catch (e) {
      final user = AuthService.instance.currentUser;
      if (mounted) {
        setState(() {
          _nomController.text = user?.fullName ?? '';
          _specialiteController.text = user?.specialization ?? '';
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Profil local (API : $e)')),
        );
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isSaving = true);
    try {
      await _api.updateProfile({
        'nom': _nomController.text.trim(),
        'telephone': _telephoneController.text.trim(),
        'specialite': _specialiteController.text.trim(),
        'hopital': _hopitalController.text.trim(),
        'biographie': _biographieController.text.trim(),
        'disponibilite': _disponibiliteController.text.trim(),
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Profil mis à jour'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _logout() async {
    await AuthService.instance.logout();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const LoginPage()),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    final initials = (_nomController.text.isNotEmpty
            ? _nomController.text
            : 'Dr')
        .substring(0, 1)
        .toUpperCase();

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(0),
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [AppColors.primary, Color(0xFF1565C0)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 54,
                    backgroundColor: Colors.white.withValues(alpha: 0.18),
                    child: Text(
                      initials,
                      style: const TextStyle(
                        fontSize: 42,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _nomController.text.isNotEmpty ? _nomController.text : 'Médecin',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      _specialiteController.text.isNotEmpty
                          ? _specialiteController.text
                          : 'Spécialité',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Informations',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _field(_nomController, 'Nom complet', Icons.person),
                  _field(_specialiteController, 'Spécialité *', Icons.medical_services,
                      required: true),
                  _field(_hopitalController, 'Hôpital / Clinique *', Icons.local_hospital,
                      required: true),
                  const SizedBox(height: 20),
                  Text(
                    'Contact',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _field(_telephoneController, 'Téléphone', Icons.phone),
                  const SizedBox(height: 20),
                  Text(
                    'Détails professionnels',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _field(_biographieController, 'Biographie', Icons.info_outline,
                      maxLines: 3),
                  _field(_disponibiliteController, 'Disponibilités', Icons.schedule,
                      maxLines: 2),
                  const SizedBox(height: 28),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: _isSaving ? null : _saveProfile,
                      icon: const Icon(Icons.save_rounded),
                      label: const Text('Enregistrer les modifications'),
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
                  if (_isSaving) const SizedBox(height: 8),
                  if (_isSaving)
                    const LinearProgressIndicator(
                      color: AppColors.primary,
                      minHeight: 3,
                    ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: _logout,
                      icon: const Icon(Icons.logout_rounded),
                      label: const Text('Déconnexion'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.error,
                        side: const BorderSide(color: AppColors.error),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(
    TextEditingController c,
    String label,
    IconData icon, {
    bool required = false,
    int maxLines = 1,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: TextFormField(
        controller: c,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: const TextStyle(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w500,
          ),
          prefixIcon: Icon(icon, color: AppColors.primary),
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: Color(0xFFE0E0E0),
              width: 1,
            ),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: Color(0xFFE0E0E0),
              width: 1,
            ),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: const BorderSide(
              color: AppColors.primary,
              width: 2,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        ),
        validator: required
            ? (v) => v == null || v.trim().isEmpty ? 'Champ requis' : null
            : null,
      ),
    );
  }
}
