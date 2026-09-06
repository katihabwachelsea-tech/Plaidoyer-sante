// lib/pages/register_page.dart

import 'package:flutter/material.dart';
import 'dart:io'; // Pour le type File
import 'package:image_picker/image_picker.dart'; // Pour la sélection d'image
import 'package:path_provider/path_provider.dart'; // Pour trouver le dossier de l'app
import 'package:path/path.dart' as p; // Pour manipuler les chemins
//import '../utils/constants.dart';
import '../services/auth_service.dart';
import '../models/user.dart';
import '../widgets/metric_card.dart';
import 'onboarding_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _telephoneController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _fullNameController = TextEditingController();
  

  // 💡 NOUVEAU : Chemin d'accès à la photo sélectionnée
  String? _profileImagePath; 

  String _selectedRole = User.roleDoctor;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _telephoneController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _fullNameController.dispose();
    super.dispose();
  }

  // --------------------------------------------------
  // 💡 LOGIQUE D'IMAGE
  // --------------------------------------------------

  Future<void> _pickAndSaveImage() async {
    final picker = ImagePicker();
    // Utilisation de la galerie pour simplifier
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _isLoading = true;
      });
      try {
        final appDir = await getApplicationDocumentsDirectory();
        // Créer un nom de fichier unique basé sur le temps
        final fileName = 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final newPath = p.join(appDir.path, fileName);
        
        // Copier l'image sélectionnée vers le chemin permanent de l'application
        final savedImage = await File(pickedFile.path).copy(newPath);

        if (mounted) {
          setState(() {
            _profileImagePath = savedImage.path;
          });
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Photo de profil sélectionnée avec succès.'),
              backgroundColor: Colors.green,
              duration: Duration(seconds: 1),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur de sélection ou de sauvegarde de la photo: $e'),
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
  }

  // --------------------------------------------------
  // 💡 VALIDATIONS
  // --------------------------------------------------

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'L\'email est requis';
    }
    if (!RegExp(r"^[^@\s]+@[^@\s]+\.[^@\s]+$").hasMatch(value.trim())) {
      return 'Entrez une adresse email valide';
    }
    return null;
  }

  String? _validateFullName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Le nom complet est requis';
    }
    if (value.trim().length < 3) {
      return 'Au moins 3 caractères requis';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Le mot de passe est requis';
    }
    if (value.length < 8) {
      return 'Au moins 8 caractères requis';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Veuillez confirmer le mot de passe';
    }
    if (value != _passwordController.text) {
      return 'Les mots de passe ne correspondent pas';
    }
    return null;
  }

  // --------------------------------------------------
  // 💡 INSCRIPTION (AJOUT DU CHEMIN D'IMAGE)
  // --------------------------------------------------

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() {
      _isLoading = true;
    });

    try {
      final authService = AuthService.instance;
      final result = await authService.register(
        email: _emailController.text.trim(),
        telephone: _telephoneController.text.trim().isEmpty
            ? null
            : _telephoneController.text.trim(),
        password: _passwordController.text,
        fullName: _fullNameController.text.trim(),
        role: _selectedRole,
        profileImageUrl: _profileImagePath,
      );

      if (!mounted) return;

      if (result['success']) {
        // ✅ Compte créé, rediriger vers l'onboarding
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => OnboardingPage(
              role: _selectedRole,
            ),
          ),
        );
      } else {
        // Afficher l'erreur
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

  // --------------------------------------------------
  // 💡 CONSTRUCTION DE L'UI
  // --------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Créer un compte'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSizes.paddingL),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // En-tête avec icône
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
                        child: const Icon(
                          Icons.person_add_rounded,
                          color: AppColors.textOnPrimary,
                          size: 32,
                        ),
                      ),
                      const SizedBox(width: AppSizes.paddingM),
                      Expanded(
                        child: Text(
                          'Créez un nouveau compte utilisateur',
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppSizes.paddingXL),

                // Section: Informations de connexion
                Text(
                  'Informations de connexion',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: AppSizes.paddingM),

                // Email pour la connexion et l'inscription
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    hintText: 'Ex: jean.dupont@example.com',
                    prefixIcon: Icon(Icons.email_outlined),
                  ),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  validator: _validateEmail,
                  enabled: !_isLoading,
                ),

                const SizedBox(height: AppSizes.paddingM),

                // Téléphone
                TextFormField(
                  controller: _telephoneController,
                  decoration: const InputDecoration(
                    labelText: 'Téléphone',
                    hintText: 'Ex: 0612345678',
                    prefixIcon: Icon(Icons.phone_outlined),
                  ),
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  enabled: !_isLoading,
                ),

                const SizedBox(height: AppSizes.paddingM),

                // Mot de passe
                TextFormField(
                  controller: _passwordController,
                  decoration: InputDecoration(
                    labelText: 'Mot de passe ',
                    hintText: 'Au moins 8 caractères',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscurePassword = !_obscurePassword;
                        });
                      },
                    ),
                  ),
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.next,
                  validator: _validatePassword,
                  enabled: !_isLoading,
                ),

                const SizedBox(height: AppSizes.paddingM),

                // Confirmation mot de passe
                TextFormField(
                  controller: _confirmPasswordController,
                  decoration: InputDecoration(
                    labelText: 'Confirmer le mot de passe ',
                    hintText: 'Retapez le mot de passe',
                    prefixIcon: const Icon(Icons.lock_outline_rounded),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscureConfirmPassword
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                      ),
                      onPressed: () {
                        setState(() {
                          _obscureConfirmPassword = !_obscureConfirmPassword;
                        });
                      },
                    ),
                  ),
                  obscureText: _obscureConfirmPassword,
                  textInputAction: TextInputAction.next,
                  validator: _validateConfirmPassword,
                  enabled: !_isLoading,
                ),

                const SizedBox(height: AppSizes.paddingXL),

                // Section: Informations personnelles
                Text(
                  'Informations personnelles',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: AppSizes.paddingL),

                // 💡 WIDGET : SÉLECTION DE PHOTO
                Center(
                  child: GestureDetector(
                    onTap: _isLoading ? null : _pickAndSaveImage,
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundColor: AppColors.primary.withAlpha((0.1 * 255).round()),
                          backgroundImage: _profileImagePath != null && File(_profileImagePath!).existsSync()
                              ? FileImage(File(_profileImagePath!)) as ImageProvider
                              : null,
                          child: _profileImagePath == null
                              ? const Icon(
                                  Icons.camera_alt_rounded,
                                  size: 40,
                                  color: AppColors.primary,
                                )
                              : null,
                        ),
                        const SizedBox(height: AppSizes.paddingS),
                        Text(
                          _profileImagePath == null
                              ? 'Ajouter une photo de profil (Optionnel)'
                              : 'Changer la photo',
                          style: TextStyle(color: AppColors.primary),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: AppSizes.paddingXL),

                // Nom complet
                TextFormField(
                  controller: _fullNameController,
                  decoration: const InputDecoration(
                    labelText: 'Nom complet ',
                    hintText: 'Ex: Jean Dupont',
                    prefixIcon: Icon(Icons.person_outline_rounded),
                  ),
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  validator: _validateFullName,
                  enabled: !_isLoading,
                ),

                const SizedBox(height: AppSizes.paddingM),

                // Rôle
                DropdownButtonFormField<String>(
                  initialValue: _selectedRole,
                  decoration: const InputDecoration(
                    labelText: 'Rôle ',
                    prefixIcon: Icon(Icons.badge_outlined),
                  ),
                  items: User.roleLabels.entries.map((entry) {
                    return DropdownMenuItem(
                      value: entry.key,
                      child: Text(entry.value),
                    );
                  }).toList(),
                  onChanged: _isLoading
                      ? null
                      : (value) {
                            setState(() {
                              _selectedRole = value!;
                            });
                          },
                ),

                const SizedBox(height: AppSizes.paddingXL),

                // Note
                // Row(
                //   children: [
                //     const Icon(
                //       Icons.info_outline_rounded,
                //       size: 16,
                //       color: AppColors.textSecondary,
                //     ),
                //     const SizedBox(width: AppSizes.paddingS),
                    // Text(
                    //   '* Champs obligatoires',
                    //   style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    //         color: AppColors.textSecondary,
                    //       ),
                    // ),
                //   ],
                // ),

                // const SizedBox(height: AppSizes.paddingL),

                // Bouton Créer le compte
                ElevatedButton.icon(
                  onPressed: _isLoading ? null : _register,
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
                    _isLoading ? 'Création en cours...' : 'Créer le compte',
                    style: const TextStyle(fontSize: 16),
                  ),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                ),

                const SizedBox(height: AppSizes.paddingM),

                // Bouton Annuler
                OutlinedButton.icon(
                  onPressed: _isLoading ? null : () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                  label: const Text(
                    'Annuler',
                    style: TextStyle(fontSize: 16),
                  ),
                  style: OutlinedButton.styleFrom(
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