import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../models/user.dart';
import '../widgets/metric_card.dart';
import '../main.dart';
import 'patient/patient_navigation.dart';
import 'medecin/medecin_navigation.dart';

class OnboardingPage extends StatefulWidget {
  final String role;

  const OnboardingPage({
    super.key,
    required this.role,
  });

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  // Contrôleurs pour le Médecin
  final _specialiteController = TextEditingController();
  final _licenceController = TextEditingController();
  final _hopitalController = TextEditingController();
  final _biographieController = TextEditingController();
  final _disponibiliteController = TextEditingController();

  // Contrôleurs pour le Patient
  final _dateNaissanceController = TextEditingController();
  final _groupeSanguinController = TextEditingController();
  final _maladieController = TextEditingController();
  final _antecedentsController = TextEditingController();

  bool _isMedecin() => widget.role == User.roleDoctor;

  @override
  void dispose() {
    _specialiteController.dispose();
    _licenceController.dispose();
    _hopitalController.dispose();
    _biographieController.dispose();
    _disponibiliteController.dispose();
    _dateNaissanceController.dispose();
    _groupeSanguinController.dispose();
    _maladieController.dispose();
    _antecedentsController.dispose();
    super.dispose();
  }

  String? _validateRequired(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Ce champ est requis';
    }
    return null;
  }

  Future<void> _completeProfile() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = AuthService.instance;

      late Map<String, dynamic> result;

      if (_isMedecin()) {
        result = await authService.completeProfile(
          role: widget.role,
          specialite: _specialiteController.text.trim(),
          licence: _licenceController.text.trim(),
          hopital: _hopitalController.text.trim(),
          biographie: _biographieController.text.trim(),
          disponibilite: _disponibiliteController.text.trim(),
        );
      } else {
        result = await authService.completeProfile(
          role: widget.role,
          dateNaissance: _dateNaissanceController.text.trim(),
          groupeSanguin: _groupeSanguinController.text.trim(),
          maladie: _maladieController.text.trim(),
          antecedents: _antecedentsController.text.trim(),
        );
      }

      if (!mounted) return;

      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 2),
          ),
        );

        // Navigation vers le bon écran selon le rôle
        // — Médecin → MedecinNavigation (dashboard médecin)
        // — Patient  → PatientHomePage  (accueil patient)
        // — Autre    → MainNavigation   (dashboard admin/staff)
        final Widget destination;
        if (widget.role == User.roleDoctor) {
          destination = const MedecinNavigation();
        } else if (widget.role == User.rolePatient) {
          destination = const PatientNavigation();
        } else {
          destination = const MainNavigation();
        }

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => destination),
          (route) => false, // supprime tout l'historique (pas de retour en arrière)
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Complétez votre profil'),
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.paddingL),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // En-tête
                Container(
                  padding: const EdgeInsets.all(AppSizes.paddingL),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withAlpha((0.1 * 255).round()),
                    borderRadius: BorderRadius.circular(AppSizes.radiusL),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          _isMedecin()
                              ? Icons.medical_services_outlined
                              : Icons.health_and_safety_outlined,
                          color: AppColors.textOnPrimary,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: AppSizes.paddingM),
                      Expanded(
                        child: Text(
                          _isMedecin()
                              ? 'Complétez vos informations professionnelles'
                              : 'Complétez vos informations de santé',
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    fontWeight: FontWeight.w500,
                                  ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSizes.paddingXL),

                if (_isMedecin()) ...[
                  // === FORMULAIRE MÉDECIN ===
                  Text(
                    'Informations professionnelles',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: AppSizes.paddingM),

                  TextFormField(
                    controller: _specialiteController,
                    decoration: const InputDecoration(
                      labelText: 'Spécialité',
                      hintText: 'Ex: Cardiologue, Dermatologue...',
                      prefixIcon: Icon(Icons.medical_services_outlined),
                    ),
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    validator: _validateRequired,
                    enabled: !_isLoading,
                  ),

                  const SizedBox(height: AppSizes.paddingM),

                  TextFormField(
                    controller: _licenceController,
                    decoration: const InputDecoration(
                      labelText: 'Numéro de licence',
                      hintText: 'Ex: LIC-2024-001',
                      prefixIcon: Icon(Icons.badge_outlined),
                    ),
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.next,
                    validator: _validateRequired,
                    enabled: !_isLoading,
                  ),

                  const SizedBox(height: AppSizes.paddingM),

                  TextFormField(
                    controller: _hopitalController,
                    decoration: const InputDecoration(
                      labelText: 'Hôpital/Clinique',
                      hintText: 'Ex: CHU de Bujumbura',
                      prefixIcon: Icon(Icons.location_on_outlined),
                    ),
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    validator: _validateRequired,
                    enabled: !_isLoading,
                  ),

                  const SizedBox(height: AppSizes.paddingM),

                  TextFormField(
                    controller: _disponibiliteController,
                    decoration: const InputDecoration(
                      labelText: 'Disponibilité',
                      hintText: 'Ex: Lundi-Vendredi 9h-17h',
                      prefixIcon: Icon(Icons.schedule_outlined),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.next,
                    validator: _validateRequired,
                    enabled: !_isLoading,
                  ),

                  const SizedBox(height: AppSizes.paddingM),

                  TextFormField(
                    controller: _biographieController,
                    decoration: const InputDecoration(
                      labelText: 'Biographie',
                      hintText: 'Présentez-vous...',
                      prefixIcon: Icon(Icons.description_outlined),
                    ),
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    validator: _validateRequired,
                    enabled: !_isLoading,
                  ),
                ] else ...[
                  // === FORMULAIRE PATIENT ===
                  Text(
                    'Informations de santé',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: AppSizes.paddingM),

                  TextFormField(
                    controller: _dateNaissanceController,
                    decoration: const InputDecoration(
                      labelText: 'Date de naissance',
                      hintText: 'JJ/MM/AAAA',
                      prefixIcon: Icon(Icons.calendar_today_outlined),
                    ),
                    keyboardType: TextInputType.datetime,
                    textInputAction: TextInputAction.next,
                    validator: _validateRequired,
                    enabled: !_isLoading,
                  ),

                  const SizedBox(height: AppSizes.paddingM),

                  TextFormField(
                    controller: _groupeSanguinController,
                    decoration: const InputDecoration(
                      labelText: 'Groupe sanguin',
                      hintText: 'Ex: O+, A-, B+...',
                      prefixIcon: Icon(Icons.bloodtype_outlined),
                    ),
                    textCapitalization: TextCapitalization.characters,
                    textInputAction: TextInputAction.next,
                    validator: _validateRequired,
                    enabled: !_isLoading,
                  ),

                  const SizedBox(height: AppSizes.paddingM),

                  TextFormField(
                    controller: _maladieController,
                    decoration: const InputDecoration(
                      labelText: 'Maladie chronique (le cas échéant)',
                      hintText: 'Ex: Diabète, Hypertension...',
                      prefixIcon: Icon(Icons.sick_outlined),
                    ),
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.next,
                    enabled: !_isLoading,
                  ),

                  const SizedBox(height: AppSizes.paddingM),

                  TextFormField(
                    controller: _antecedentsController,
                    decoration: const InputDecoration(
                      labelText: 'Antécédents médicaux',
                      hintText: 'Décrivez vos antécédents...',
                      prefixIcon: Icon(Icons.history_outlined),
                    ),
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    enabled: !_isLoading,
                  ),
                ],

                const SizedBox(height: AppSizes.paddingXL),

                // Bouton Continuer
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _completeProfile,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              AppColors.textOnPrimary,
                            ),
                          ),
                        )
                      : const Icon(Icons.check_rounded),
                  label: Text(
                    _isLoading
                        ? 'Finalisation...'
                        : 'Finaliser mon inscription',
                    style: const TextStyle(fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),

                const SizedBox(height: AppSizes.paddingXL),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
