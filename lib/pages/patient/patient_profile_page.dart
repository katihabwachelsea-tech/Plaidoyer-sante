import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../services/patient_api_service.dart';
import '../../widgets/metric_card.dart';
import '../login_page.dart';

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
  String? _email;
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
      final groupe = data['groupe_sanguin']?.toString();
      _groupe = _groupes.contains(groupe) ? groupe : null;
    } catch (e) {
      _error = e.toString();
    } finally {
      if (mounted) setState(() => _loading = false);
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
          const SnackBar(content: Text('Profil enregistré'), backgroundColor: AppColors.success),
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
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Actualiser',
            onPressed: _load,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        ElevatedButton.icon(
                          onPressed: _load,
                          icon: const Icon(Icons.refresh_rounded),
                          label: const Text('Réessayer'),
                        ),
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_nom.text, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          Text(_email ?? '', style: const TextStyle(color: Colors.white70)),
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
                            decoration: const InputDecoration(labelText: 'Nom complet'),
                            validator: (v) => (v == null || v.trim().isEmpty) ? 'Nom requis' : null,
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _telephone,
                            decoration: const InputDecoration(labelText: 'Téléphone'),
                          ),
                          const SizedBox(height: 12),
                          DropdownButtonFormField<String>(
                            value: _groupe,
                            decoration: const InputDecoration(labelText: 'Groupe sanguin'),
                            items: _groupes
                                .map((g) => DropdownMenuItem(value: g, child: Text(g)))
                                .toList(),
                            onChanged: (v) => setState(() => _groupe = v),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _maladie,
                            decoration: const InputDecoration(labelText: 'Motif de suivi'),
                          ),
                          const SizedBox(height: 12),
                          TextFormField(
                            controller: _antecedents,
                            maxLines: 3,
                            decoration: const InputDecoration(labelText: 'Antécédents'),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    FilledButton(
                      onPressed: _saving ? null : _save,
                      child: Text(_saving ? 'Enregistrement...' : 'Enregistrer'),
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
