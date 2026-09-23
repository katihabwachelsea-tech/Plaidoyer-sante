import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../config/app_config.dart';
import '../../services/auth_service.dart';
import '../../services/patient_api_service.dart';
import '../../widgets/metric_card.dart';
import '../login_page.dart';
import '../notifications_page.dart';
import '../settings_page.dart';

class PatientProfilePage extends StatefulWidget {
  const PatientProfilePage({super.key});

  @override
  State<PatientProfilePage> createState() => _PatientProfilePageState();
}

class _PatientProfilePageState extends State<PatientProfilePage> {
  final _api = PatientApiService.instance;
  final _formKey = GlobalKey<FormState>();
  final _nom = TextEditingController();
  final _telephone = TextEditingController();
  final _maladie = TextEditingController();
  final _antecedents = TextEditingController();
  String? _groupe;
  bool _loading = true;
  bool _saving = false;
  bool _uploadingPhoto = false;
  String? _email;
  String? _photoUrl;
  String? _error;

  static const _groupes = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _nom.dispose();
    _telephone.dispose();
    _maladie.dispose();
    _antecedents.dispose();
    super.dispose();
  }

  String _abs(String? path) {
    if (path == null || path.isEmpty) return '';
    if (path.startsWith('http')) return path;
    final base = AppConfig.baseUrl.replaceAll('/api', '');
    return path.startsWith('/') ? '$base$path' : '$base/$path';
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _api.getProfile();
      _nom.text = (data['nom'] ?? '').toString();
      _telephone.text = (data['telephone'] ?? '').toString();
      _maladie.text = (data['maladie'] ?? '').toString();
      _antecedents.text = (data['antecedents'] ?? '').toString();
      _email = data['email']?.toString();
      _photoUrl = _abs(data['photo_url']?.toString());
      final groupe = data['groupe_sanguin']?.toString();
      _groupe = _groupes.contains(groupe) ? groupe : null;
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
    }
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
      AuthService.instance.updateProfileImageUrl(_abs(url));
      if (mounted) {
        setState(() => _photoUrl = _abs(url));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo mise à jour'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await _api.updateProfile({
        'nom': _nom.text.trim(),
        'telephone': _telephone.text.trim(),
        'maladie': _maladie.text.trim(),
        'antecedents': _antecedents.text.trim(),
        if (_groupe != null) 'groupe_sanguin': _groupe,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
              content: Text('Profil enregistré'),
              backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
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
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mon profil'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.textOnPrimary,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const NotificationsPage()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings_rounded),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsPage()),
              );
            },
          ),
        ],
      ),
      body: _loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        ElevatedButton(
                            onPressed: _load, child: const Text('Réessayer')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primary,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [AppColors.primary, Color(0xFF1565C0)],
                          ),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          children: [
                            GestureDetector(
                              onTap: _uploadingPhoto ? null : _pickPhoto,
                              child: Stack(
                                children: [
                                  CircleAvatar(
                                    radius: 36,
                                    backgroundColor: Colors.white,
                                    backgroundImage:
                                        _photoUrl != null && _photoUrl!.isNotEmpty
                                            ? NetworkImage(_photoUrl!)
                                            : null,
                                    child: _photoUrl == null || _photoUrl!.isEmpty
                                        ? Text(
                                            (_nom.text.isNotEmpty
                                                    ? _nom.text[0]
                                                    : 'P')
                                                .toUpperCase(),
                                            style: const TextStyle(
                                              fontSize: 28,
                                              color: AppColors.primary,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          )
                                        : null,
                                  ),
                                  Positioned(
                                    right: 0,
                                    bottom: 0,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
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
                                              size: 16,
                                              color: AppColors.primary),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(_nom.text,
                                      style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold)),
                                  Text(_email ?? '',
                                      style:
                                          const TextStyle(color: Colors.white70)),
                                  const SizedBox(height: 4),
                                  const Text('Toucher la photo pour changer',
                                      style: TextStyle(
                                          color: Colors.white60, fontSize: 11)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Form(
                        key: _formKey,
                        child: Column(
                          children: [
                            TextFormField(
                              controller: _nom,
                              decoration: const InputDecoration(
                                  labelText: 'Nom complet'),
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Nom requis'
                                  : null,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _telephone,
                              decoration: const InputDecoration(
                                  labelText: 'Téléphone'),
                            ),
                            const SizedBox(height: 12),
                            DropdownButtonFormField<String>(
                              value: _groupe,
                              decoration: const InputDecoration(
                                  labelText: 'Groupe sanguin'),
                              items: _groupes
                                  .map((g) => DropdownMenuItem(
                                      value: g, child: Text(g)))
                                  .toList(),
                              onChanged: (v) => setState(() => _groupe = v),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _maladie,
                              decoration: const InputDecoration(
                                  labelText: 'Motif de suivi'),
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _antecedents,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                  labelText: 'Antécédents'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _saving ? null : _save,
                        child: Text(
                            _saving ? 'Enregistrement...' : 'Enregistrer'),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton(
                        onPressed: _logout,
                        child: const Text('Se déconnecter'),
                      ),
                    ],
                  ),
                ),
    );
  }
}
