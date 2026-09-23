import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/app_config.dart';
import '../../models/appointment.dart';
import '../../services/auth_service.dart';
import '../../services/medecin_api_service.dart';
import '../../utils/doctor_photo.dart';
import '../../widgets/metric_card.dart';
import '../login_page.dart';
import '../notifications_page.dart';
import '../settings_page.dart';
import 'medecin_ui.dart';

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
  String? _email;
  String? _photoUrl;
  bool _uploadingPhoto = false;

  @override
  void initState() {
    super.initState();
    _nomController = TextEditingController();
    _telephoneController = TextEditingController();
    _specialiteController = TextEditingController();
    _hopitalController = TextEditingController();
    _biographieController = TextEditingController();
    _disponibiliteController = TextEditingController();
    _photoUrl = AuthService.instance.currentUser?.profileImageUrl;
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
    _email = p.email;
    if (p.photoUrl != null && p.photoUrl!.isNotEmpty) {
      _photoUrl = _abs(p.photoUrl);
      AuthService.instance.updateProfileImageUrl(_photoUrl);
    }
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
          _email = user?.email;
          _isLoading = false;
        });
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
          const SnackBar(content: Text('Profil mis à jour'), backgroundColor: AppColors.success),
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

  String _abs(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    final base = AppConfig.baseUrl.replaceAll('/api', '');
    return path.startsWith('/') ? '$base$path' : '$base/$path';
  }

  Future<void> _pickPhoto() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Caméra'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Galerie'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (source == null) return;
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );
    if (file == null) return;

    setState(() => _uploadingPhoto = true);
    try {
      final url = await _api.uploadPhoto(file.path);
      final abs = _abs(url);
      AuthService.instance.updateProfileImageUrl(abs);
      if (mounted) {
        setState(() => _photoUrl = abs);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo mise à jour'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AppColors.primary)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: RefreshIndicator(
        onRefresh: _loadProfile,
        color: AppColors.primary,
        child: Form(
        key: _formKey,
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            Container(
              decoration: const BoxDecoration(gradient: MedecinDecor.headerGradient),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                  child: Column(
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.notifications_outlined,
                                  color: Colors.white70),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const NotificationsPage(),
                                  ),
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.refresh_rounded,
                                  color: Colors.white70),
                              tooltip: 'Actualiser',
                              onPressed: _loadProfile,
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: _uploadingPhoto ? null : _pickPhoto,
                        child: Stack(
                          children: [
                            DoctorAvatar(
                              name: _nomController.text.isEmpty
                                  ? 'Dr'
                                  : _nomController.text,
                              radius: 40,
                              background: Colors.white,
                              foreground: AppColors.primary,
                              imageUrl: doctorPhotoUrl({
                                'nom': _nomController.text.isEmpty
                                    ? 'Dr'
                                    : _nomController.text,
                                'photo_url': _photoUrl ??
                                    AuthService
                                        .instance.currentUser?.profileImageUrl,
                              }),
                            ),
                            Positioned(
                              right: 0,
                              bottom: 0,
                              child: Container(
                                padding: const EdgeInsets.all(5),
                                decoration: const BoxDecoration(
                                  color: Colors.white,
                                  shape: BoxShape.circle,
                                ),
                                child: _uploadingPhoto
                                    ? const SizedBox(
                                        width: 14,
                                        height: 14,
                                        child: CircularProgressIndicator(
                                            strokeWidth: 2),
                                      )
                                    : const Icon(Icons.camera_alt,
                                        size: 16, color: AppColors.primary),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        _nomController.text.isEmpty ? 'Médecin' : _nomController.text,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(99),
                        ),
                        child: Text(
                          _specialiteController.text.isEmpty ? 'Spécialité' : _specialiteController.text,
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                      ),
                      if (_email != null) ...[
                        const SizedBox(height: 6),
                        Text(_email!, style: TextStyle(color: Colors.white.withValues(alpha: 0.75))),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
              child: Column(
                children: [
                  MedecinCard(
                    child: Column(
                      children: [
                        _field(_nomController, 'Nom complet', Icons.person_outline_rounded),
                        _field(_specialiteController, 'Spécialité', Icons.medical_services_outlined, required: true),
                        _field(_hopitalController, 'Hôpital / Clinique', Icons.local_hospital_outlined, required: true),
                        _field(_telephoneController, 'Téléphone', Icons.phone_outlined),
                        _field(_disponibiliteController, 'Disponibilités', Icons.schedule_outlined, maxLines: 2),
                        _field(_biographieController, 'Biographie', Icons.info_outline_rounded, maxLines: 3),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.settings_rounded, color: AppColors.primary),
                    title: const Text('Paramètres'),
                    subtitle: const Text('Thème sombre / clair'),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SettingsPage()),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _isSaving ? null : _saveProfile,
                      icon: const Icon(Icons.save_rounded),
                      label: Text(_isSaving ? 'Enregistrement...' : 'Enregistrer'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
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
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
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
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: c,
        maxLines: maxLines,
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon, color: AppColors.primary),
          filled: true,
          fillColor: AppColors.ice,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        ),
        validator: required ? (v) => v == null || v.trim().isEmpty ? 'Champ requis' : null : null,
      ),
    );
  }
}
