// lib/pages/login_page.dart

import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../models/user.dart';
import 'register_page.dart';
import 'patient/patient_navigation.dart';
import 'medecin/medecin_navigation.dart';
import '../widgets/metric_card.dart';
import 'forgot_password_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;

  late AnimationController _animController;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    _fadeAnim = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));
    _animController.forward();
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _animController.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) return 'L\'email est requis';
    if (!RegExp(r"^[^@\s]+@[^@\s]+\.[^@\s]+$").hasMatch(value.trim())) {
      return 'Adresse email invalide';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) return 'Le mot de passe est requis';
    if (value.length < 6) return 'Au moins 6 caractères requis';
    return null;
  }

  void _goToRegisterPage() async {
    final result = await Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const RegisterPage()),
    );
    if (mounted && result == true) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Compte créé. Connectez-vous pour continuer.'),
          backgroundColor: AppColors.primary,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final authService = AuthService.instance;
      final result = await authService.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (!mounted) return;

      if (result['success']) {
        final userRole = authService.currentUser?.role;
        if (userRole == User.rolePatient) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const PatientNavigation()),
          );
        } else if (userRole == User.roleDoctor) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const MedecinNavigation()),
          );
        } else {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const LoginPage()),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur de connexion : $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      body: Stack(
        children: [
          // ── Photo de fond ──────────────────────────────────────────
          SizedBox.expand(
            child: Image.asset(
              'assets/images/marcelo-leal-k7ll1hpdhFA-unsplash.jpg',
              fit: BoxFit.cover,
            ),
          ),

          // ── Dégradé sombre en bas pour lisibilité ─────────────────
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: const [0.0, 0.35, 1.0],
                colors: [
                  const Color(0xFF0B3D6B).withOpacity(0.55),
                  const Color(0xFF0B3D6B).withOpacity(0.70),
                  const Color(0xFF071F38).withOpacity(0.97),
                ],
              ),
            ),
          ),

          // ── Contenu ───────────────────────────────────────────────
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: size.height * 0.04,
                ),
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 420),
                      child: Column(
                        children: [
                          // ── Logo + titre ───────────────────────
                          _buildHeader(context),
                          const SizedBox(height: 36),

                          // ── Carte de connexion ─────────────────
                          _buildLoginCard(context),
                          const SizedBox(height: 20),

                          // ── Lien inscription ───────────────────
                          _buildRegisterLink(),

                          const SizedBox(height: 16),

                          // ── Badges de confiance ────────────────
                          _buildTrustBadges(),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      children: [
        // Icône avec halo
        Container(
          width: 84,
          height: 84,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5),
          ),
          child: Center(
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.5),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: const Icon(
                Icons.health_and_safety_rounded,
                size: 32,
                color: Colors.white,
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          AppConstants.appName,
          style: const TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.25)),
          ),
          child: Text(
            AppConstants.appSlogan,
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withOpacity(0.9),
              letterSpacing: 0.3,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.97),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // En-tête carte
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.login_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Connexion',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      'Patient ou médecin — le même accès.',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),

            const SizedBox(height: 6),
            Divider(color: AppColors.border, height: 24),

            // Champ email
            TextFormField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Email',
                hintText: 'exemple@email.com',
                prefixIcon: Icon(Icons.mail_outline_rounded,
                    color: AppColors.primary),
                labelStyle: TextStyle(color: AppColors.textSecondary),
              ),
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              validator: _validateEmail,
              enabled: !_isLoading,
            ),
            const SizedBox(height: 14),

            // Champ mot de passe
            TextFormField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: 'Mot de passe',
                prefixIcon: Icon(Icons.lock_outline_rounded,
                    color: AppColors.primary),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: AppColors.textSecondary,
                  ),
                  onPressed: () =>
                      setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.done,
              validator: _validatePassword,
              enabled: !_isLoading,
              onFieldSubmitted: (_) => _login(),
            ),
            // Lien mot de passe oublié
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _isLoading
                    ? null
                    : () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ForgotPasswordPage(),
                          ),
                        ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                      vertical: 4, horizontal: 0),
                ),
                child: const Text(
                  'Mot de passe oublié ?',
                  style: TextStyle(color: AppColors.primary, fontSize: 13),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Bouton connexion
            SizedBox(
              height: 52,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _login,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.login_rounded, size: 18),
                          SizedBox(width: 8),
                          Text(
                            'Se connecter',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegisterLink() {
    return TextButton(
      onPressed: _isLoading ? null : _goToRegisterPage,
      child: RichText(
        text: TextSpan(
          text: 'Pas encore de compte ? ',
          style: TextStyle(color: Colors.white.withOpacity(0.75), fontSize: 14),
          children: const [
            TextSpan(
              text: 'Créer un compte',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.underline,
                decorationColor: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrustBadges() {
    final badges = [
      (Icons.verified_user_rounded, 'Sécurisé'),
      (Icons.local_hospital_rounded, 'Certifié'),
      (Icons.lock_rounded, 'SSL'),
    ];

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 16,
      runSpacing: 6,
      children: badges.map((badge) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(badge.$1, size: 13, color: Colors.white.withOpacity(0.65)),
            const SizedBox(width: 4),
            Text(
              badge.$2,
              style: TextStyle(
                fontSize: 11,
                color: Colors.white.withOpacity(0.65),
              ),
            ),
          ],
        );
      }).toList(),
    );
  }
}
