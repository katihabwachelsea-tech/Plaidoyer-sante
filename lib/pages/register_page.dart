// lib/pages/register_page.dart

import 'package:flutter/material.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
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
  // LOGIQUE D'IMAGE
  // --------------------------------------------------

  Future<void> _pickAndSaveImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
      imageQuality: 85,
    );

    if (pickedFile != null) {
      setState(() => _isLoading = true);
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
        final newPath = p.join(appDir.path, fileName);
        final savedImage = await File(pickedFile.path).copy(newPath);

        if (mounted) {
          setState(() => _profileImagePath = savedImage.path);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.check_circle_outline, color: Colors.white),
                  SizedBox(width: 8),
                  Text('Photo de profil sélectionnée'),
                ],
              ),
              backgroundColor: AppColors.accent,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Erreur lors de la sélection : $e'),
              backgroundColor: AppColors.error,
            ),
          );
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  void _removeImage() {
    setState(() => _profileImagePath = null);
  }

  // --------------------------------------------------
  // VALIDATIONS
  // --------------------------------------------------

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'L\'email est requis';
    if (!RegExp(r"^[^@\s]+@[^@\s]+\.[^@\s]+$").hasMatch(value.trim())) {
      return 'Adresse email invalide';
    }
    return null;
  }

  String? _validateFullName(String? value) {
    if (value == null || value.trim().isEmpty) return 'Le nom complet est requis';
    if (value.trim().length < 3) return 'Au moins 3 caractères requis';
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Le mot de passe est requis';
    if (value.length < 8) return 'Au moins 8 caractères requis';
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) return 'Veuillez confirmer le mot de passe';
    if (value != _passwordController.text) return 'Les mots de passe ne correspondent pas';
    return null;
  }

  String? _validateTelephone(String? value) {
    if (value == null || value.trim().isEmpty) return 'Le téléphone est requis';
    if (value.trim().length < 8) return 'Au moins 8 chiffres requis';
    return null;
  }

  // --------------------------------------------------
  // INSCRIPTION
  // --------------------------------------------------

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final authService = AuthService.instance;
      final result = await authService.register(
        email: _emailController.text.trim(),
        telephone: _telephoneController.text.trim(),
        password: _passwordController.text,
        fullName: _fullNameController.text.trim(),
        role: _selectedRole,
        profileImageUrl: null,
      );

      if (!mounted) return;

      if (result['success']) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => OnboardingPage(role: _selectedRole),
          ),
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
            content: Text('Erreur : $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // --------------------------------------------------
  // WIDGETS HELPERS
  // --------------------------------------------------

  /// En-tête héro avec dégradé et photo de profil centrée
  Widget _buildHero() {
    final hasImage = _profileImagePath != null &&
        File(_profileImagePath!).existsSync();

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [AppColors.primaryDark, AppColors.primary, AppColors.primaryLight],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      child: Column(
        children: [
          // Titre de page
          Text(
            'Créer un compte',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Rejoignez Mob-Clinic en quelques étapes',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withAlpha(200),
                ),
          ),
          const SizedBox(height: 28),

          // Avatar cliquable
          Stack(
            alignment: Alignment.center,
            children: [
              // Anneau décoratif extérieur
              Container(
                width: 116,
                height: 116,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withAlpha(80), width: 3),
                ),
              ),
              // Avatar principal
              GestureDetector(
                onTap: _isLoading ? null : _pickAndSaveImage,
                child: Container(
                  width: 108,
                  height: 108,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withAlpha(30),
                    border: Border.all(color: Colors.white, width: 3),
                    image: hasImage
                        ? DecorationImage(
                            image: FileImage(File(_profileImagePath!)),
                            fit: BoxFit.cover,
                          )
                        : null,
                  ),
                  child: !hasImage
                      ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.person_outline_rounded,
                                color: Colors.white, size: 38),
                            const SizedBox(height: 2),
                            Text(
                              'Photo',
                              style: TextStyle(
                                color: Colors.white.withAlpha(220),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        )
                      : null,
                ),
              ),
              // Badge "+" ou "✓"
              Positioned(
                bottom: 2,
                right: 0,
                child: GestureDetector(
                  onTap: _isLoading
                      ? null
                      : (hasImage ? _removeImage : _pickAndSaveImage),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: hasImage ? AppColors.error : AppColors.accent,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withAlpha(40),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Icon(
                      hasImage ? Icons.close_rounded : Icons.add_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Label sous l'avatar
          Text(
            hasImage ? 'Photo ajoutée ✓' : 'Ajouter une photo (facultatif)',
            style: TextStyle(
              color: Colors.white.withAlpha(210),
              fontSize: 13,
              fontWeight: hasImage ? FontWeight.w600 : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  /// Titre de section avec ligne décorative
  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 20,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(width: 10),
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
          ),
        ],
      ),
    );
  }

  /// Carte de section avec ombre légère
  Widget _buildCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppSizes.paddingM),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(AppSizes.radiusL),
        boxShadow: [
          BoxShadow(
            color: AppColors.shadow,
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  /// Champ texte avec style uniforme
  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData prefixIcon,
    TextInputType keyboardType = TextInputType.text,
    TextInputAction textInputAction = TextInputAction.next,
    String? Function(String?)? validator,
    bool obscure = false,
    VoidCallback? onToggleObscure,
    TextCapitalization capitalization = TextCapitalization.none,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: Icon(prefixIcon, color: AppColors.primary),
        suffixIcon: onToggleObscure != null
            ? IconButton(
                icon: Icon(
                  obscure
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: AppColors.textSecondary,
                ),
                onPressed: onToggleObscure,
              )
            : null,
        filled: true,
        fillColor: AppColors.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusM),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusM),
          borderSide: const BorderSide(color: AppColors.border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusM),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusM),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSizes.radiusM),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
      ),
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      validator: validator,
      obscureText: obscure,
      textCapitalization: capitalization,
      enabled: !_isLoading,
    );
  }

  // --------------------------------------------------
  // BUILD PRINCIPAL
  // --------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      // AppBar transparente pour que le héro prenne tout le haut
      appBar: AppBar(
        backgroundColor: AppColors.primaryDark,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_rounded, color: Colors.white),
          onPressed: _isLoading ? null : () => Navigator.pop(context),
        ),
        // Le titre est dans le héro, on garde l'AppBar minimaliste
        title: const SizedBox.shrink(),
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── HÉRO : Photo + titre ─────────────────────────────────
              _buildHero(),

              // ── CONTENU DU FORMULAIRE ────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [

                    // ── SECTION 1 : Identité ──────────────────────────
                    _buildSectionTitle('Identité', Icons.badge_outlined),
                    _buildCard(
                      child: Column(
                        children: [
                          _buildTextField(
                            controller: _fullNameController,
                            label: 'Nom complet *',
                            hint: 'Ex: Jean Dupont',
                            prefixIcon: Icons.person_outline_rounded,
                            validator: _validateFullName,
                            capitalization: TextCapitalization.words,
                          ),
                          const SizedBox(height: AppSizes.paddingM),
                          // Sélection du rôle sous forme de deux chips
                          _buildRoleSelector(),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSizes.paddingL),

                    // ── SECTION 2 : Coordonnées ───────────────────────
                    _buildSectionTitle('Coordonnées', Icons.contact_mail_outlined),
                    _buildCard(
                      child: Column(
                        children: [
                          _buildTextField(
                            controller: _emailController,
                            label: 'Email *',
                            hint: 'jean.dupont@example.com',
                            prefixIcon: Icons.email_outlined,
                            keyboardType: TextInputType.emailAddress,
                            validator: _validateEmail,
                          ),
                          const SizedBox(height: AppSizes.paddingM),
                          _buildTextField(
                            controller: _telephoneController,
                            label: 'Téléphone *',
                            hint: 'Ex: 79 00 00 00',
                            prefixIcon: Icons.phone_outlined,
                            keyboardType: TextInputType.phone,
                            validator: _validateTelephone,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSizes.paddingL),

                    // ── SECTION 3 : Sécurité ──────────────────────────
                    _buildSectionTitle('Sécurité', Icons.lock_outline_rounded),
                    _buildCard(
                      child: Column(
                        children: [
                          _buildTextField(
                            controller: _passwordController,
                            label: 'Mot de passe *',
                            hint: 'Au moins 8 caractères',
                            prefixIcon: Icons.lock_outline_rounded,
                            obscure: _obscurePassword,
                            onToggleObscure: () => setState(
                              () => _obscurePassword = !_obscurePassword,
                            ),
                            validator: _validatePassword,
                            textInputAction: TextInputAction.next,
                          ),
                          const SizedBox(height: AppSizes.paddingM),
                          _buildTextField(
                            controller: _confirmPasswordController,
                            label: 'Confirmer le mot de passe *',
                            hint: 'Retapez le mot de passe',
                            prefixIcon: Icons.lock_reset_rounded,
                            obscure: _obscureConfirmPassword,
                            onToggleObscure: () => setState(
                              () => _obscureConfirmPassword = !_obscureConfirmPassword,
                            ),
                            validator: _validateConfirmPassword,
                            textInputAction: TextInputAction.done,
                          ),
                          const SizedBox(height: AppSizes.paddingS),
                          // Indicateur de sécurité du mot de passe
                          _buildPasswordStrengthIndicator(),
                        ],
                      ),
                    ),

                    const SizedBox(height: AppSizes.paddingL),

                    // Note champs obligatoires
                    Row(
                      children: [
                        const Icon(Icons.info_outline_rounded,
                            size: 13, color: AppColors.textLight),
                        const SizedBox(width: 5),
                        Text(
                          '* Champs obligatoires',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppColors.textLight,
                              ),
                        ),
                      ],
                    ),

                    const SizedBox(height: AppSizes.paddingXL),

                    // ── BOUTON PRINCIPAL ──────────────────────────────
                    SizedBox(
                      height: 54,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _register,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          elevation: 3,
                          shadowColor: AppColors.primary.withAlpha(80),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppSizes.radiusM),
                          ),
                        ),
                        child: _isLoading
                            ? const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      valueColor: AlwaysStoppedAnimation<Color>(
                                          Colors.white),
                                    ),
                                  ),
                                  SizedBox(width: 12),
                                  Text('Création en cours...',
                                      style: TextStyle(fontSize: 16)),
                                ],
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.person_add_rounded, size: 20),
                                  SizedBox(width: 10),
                                  Text('Créer le compte',
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600)),
                                ],
                              ),
                      ),
                    ),

                    const SizedBox(height: AppSizes.paddingM),

                    // ── BOUTON ANNULER ────────────────────────────────
                    SizedBox(
                      height: 48,
                      child: OutlinedButton(
                        onPressed:
                            _isLoading ? null : () => Navigator.pop(context),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          side: const BorderSide(
                              color: AppColors.border, width: 1.5),
                          shape: RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.circular(AppSizes.radiusM),
                          ),
                        ),
                        child: const Text('Annuler',
                            style: TextStyle(fontSize: 15)),
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

  // --------------------------------------------------
  // SÉLECTEUR DE RÔLE (Chips)
  // --------------------------------------------------

  Widget _buildRoleSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Je suis…',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w500,
              ),
        ),
        const SizedBox(height: 10),
        Row(
          children: User.roleLabels.entries.map((entry) {
            final isSelected = _selectedRole == entry.key;
            final isDoctor = entry.key == User.roleDoctor;
            return Expanded(
              child: GestureDetector(
                onTap: _isLoading
                    ? null
                    : () => setState(() => _selectedRole = entry.key),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  margin: EdgeInsets.only(
                    right: isDoctor ? 8 : 0,
                    left: isDoctor ? 0 : 8,
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppColors.primary.withAlpha(20)
                        : AppColors.surfaceVariant,
                    borderRadius: BorderRadius.circular(AppSizes.radiusM),
                    border: Border.all(
                      color: isSelected
                          ? AppColors.primary
                          : AppColors.border,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        isDoctor
                            ? Icons.medical_services_outlined
                            : Icons.person_outline_rounded,
                        size: 18,
                        color: isSelected
                            ? AppColors.primary
                            : AppColors.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        entry.value,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.normal,
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  // --------------------------------------------------
  // INDICATEUR FORCE DU MOT DE PASSE
  // --------------------------------------------------

  Widget _buildPasswordStrengthIndicator() {
    final password = _passwordController.text;
    if (password.isEmpty) return const SizedBox.shrink();

    int strength = 0;
    if (password.length >= 8) strength++;
    if (RegExp(r'[A-Z]').hasMatch(password)) strength++;
    if (RegExp(r'[0-9]').hasMatch(password)) strength++;
    if (RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(password)) strength++;

    final labels = ['Faible', 'Moyen', 'Bon', 'Fort'];
    final colors = [
      AppColors.error,
      AppColors.warning,
      AppColors.info,
      AppColors.accent,
    ];

    final index = (strength - 1).clamp(0, 3);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Row(
          children: List.generate(4, (i) {
            return Expanded(
              child: Container(
                margin: EdgeInsets.only(right: i < 3 ? 4 : 0),
                height: 4,
                decoration: BoxDecoration(
                  color: i < strength ? colors[index] : AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 4),
        Text(
          'Force : ${labels[index]}',
          style: TextStyle(
            fontSize: 11,
            color: colors[index],
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
