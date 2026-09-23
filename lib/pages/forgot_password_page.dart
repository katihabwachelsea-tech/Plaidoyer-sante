// lib/pages/forgot_password_page.dart
//
// Récupération mot de passe en 3 étapes :
//   1. Saisir l'email  → reçoit un code OTP à 6 chiffres
//   2. Saisir le code  → obtient un reset_token
//   3. Nouveau mdp     → connexion possible

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import '../config/app_config.dart';
import '../widgets/metric_card.dart';

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  // Étape courante : 1 = email, 2 = code OTP, 3 = nouveau mdp
  int _step = 1;
  bool _loading = false;

  // Contrôleurs
  final _emailCtrl    = TextEditingController();
  final _codeCtrl     = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmCtrl  = TextEditingController();

  bool _obscurePass    = true;
  bool _obscureConfirm = true;

  // Données passées d'une étape à l'autre
  String _email      = '';
  String _resetToken = '';

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  // ── Étape 1 : envoi du code ──────────────────────────────────────────

  Future<void> _sendCode() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      _showError('Entrez une adresse email valide');
      return;
    }
    setState(() => _loading = true);
    try {
      final res = await http.post(
        Uri.parse('${AppConfig.baseUrl}/password/forgot'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({'email': email}),
      ).timeout(AppConfig.defaultTimeout);

      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && data['status'] == true) {
        setState(() {
          _email = email;
          _step  = 2;
        });
        _showInfo(data['message'] ?? 'Code envoyé');
      } else {
        _showError(data['message'] ?? 'Erreur inconnue');
      }
    } catch (e) {
      _showError('Erreur de connexion : $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Étape 2 : vérification du code ──────────────────────────────────

  Future<void> _verifyCode() async {
    final code = _codeCtrl.text.trim();
    if (code.length != 6) {
      _showError('Entrez le code à 6 chiffres reçu par email');
      return;
    }
    setState(() => _loading = true);
    try {
      final res = await http.post(
        Uri.parse('${AppConfig.baseUrl}/password/verify-code'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({'email': _email, 'code': code}),
      ).timeout(AppConfig.defaultTimeout);

      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && data['status'] == true) {
        setState(() {
          _resetToken = data['reset_token'] as String;
          _step = 3;
        });
      } else {
        _showError(data['message'] ?? 'Code incorrect');
      }
    } catch (e) {
      _showError('Erreur de connexion : $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Étape 3 : nouveau mot de passe ──────────────────────────────────

  Future<void> _resetPassword() async {
    final pass    = _passwordCtrl.text;
    final confirm = _confirmCtrl.text;

    if (pass.length < 8) {
      _showError('Le mot de passe doit contenir au moins 8 caractères');
      return;
    }
    if (pass != confirm) {
      _showError('Les mots de passe ne correspondent pas');
      return;
    }
    setState(() => _loading = true);
    try {
      final res = await http.post(
        Uri.parse('${AppConfig.baseUrl}/password/reset'),
        headers: {'Content-Type': 'application/json', 'Accept': 'application/json'},
        body: jsonEncode({
          'email':                 _email,
          'reset_token':           _resetToken,
          'password':              pass,
          'password_confirmation': confirm,
        }),
      ).timeout(AppConfig.defaultTimeout);

      final data = jsonDecode(res.body);
      if (res.statusCode == 200 && data['status'] == true) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: const Text('Mot de passe mis à jour. Connectez-vous.'),
          backgroundColor: AppColors.success,
        ));
        Navigator.of(context).pop(); // retour login
      } else {
        _showError(data['message'] ?? 'Erreur');
      }
    } catch (e) {
      _showError('Erreur de connexion : $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppColors.error));
  }

  void _showInfo(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppColors.success));
  }

  // ── UI ───────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Mot de passe oublié'),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Barre de progression
              _StepIndicator(step: _step),
              const SizedBox(height: 28),

              // Contenu par étape
              if (_step == 1) _buildStep1(),
              if (_step == 2) _buildStep2(),
              if (_step == 3) _buildStep3(),
            ],
          ),
        ),
      ),
    );
  }

  // ── Étape 1 : email ─────────────────────────────────────────────────
  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.email_outlined, size: 56, color: AppColors.primary),
        const SizedBox(height: 16),
        const Text('Entrez votre email',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        const Text(
          'Nous vous enverrons un code à 6 chiffres pour réinitialiser votre mot de passe.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 28),
        TextField(
          controller: _emailCtrl,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          decoration: const InputDecoration(
            labelText: 'Email',
            hintText: 'exemple@email.com',
            prefixIcon: Icon(Icons.mail_outline_rounded),
          ),
          onSubmitted: (_) => _sendCode(),
        ),
        const SizedBox(height: 24),
        _SubmitButton(
          label: 'Envoyer le code',
          icon: Icons.send_rounded,
          loading: _loading,
          onPressed: _sendCode,
        ),
      ],
    );
  }

  // ── Étape 2 : code OTP ──────────────────────────────────────────────
  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.lock_open_rounded, size: 56, color: AppColors.primary),
        const SizedBox(height: 16),
        const Text('Entrez le code',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        Text(
          'Un code à 6 chiffres a été envoyé à\n$_email',
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 28),
        // Champ code centré, grand
        TextField(
          controller: _codeCtrl,
          keyboardType: TextInputType.number,
          maxLength: 6,
          textAlign: TextAlign.center,
          style: const TextStyle(
              fontSize: 32, fontWeight: FontWeight.w800, letterSpacing: 10),
          decoration: const InputDecoration(
            hintText: '------',
            hintStyle: TextStyle(letterSpacing: 8, color: AppColors.textLight),
            counterText: '',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (_) => _verifyCode(),
        ),
        const SizedBox(height: 10),
        // Renvoyer le code
        TextButton.icon(
          onPressed: _loading ? null : () {
            _codeCtrl.clear();
            setState(() => _step = 1);
          },
          icon: const Icon(Icons.refresh_rounded, size: 16),
          label: const Text('Renvoyer un code'),
        ),
        const SizedBox(height: 14),
        _SubmitButton(
          label: 'Vérifier le code',
          icon: Icons.check_circle_rounded,
          loading: _loading,
          onPressed: _verifyCode,
        ),
      ],
    );
  }

  // ── Étape 3 : nouveau mot de passe ──────────────────────────────────
  Widget _buildStep3() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.lock_reset_rounded, size: 56, color: AppColors.success),
        const SizedBox(height: 16),
        const Text('Nouveau mot de passe',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        const SizedBox(height: 8),
        const Text(
          'Choisissez un mot de passe de 8 caractères minimum.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 28),
        TextField(
          controller: _passwordCtrl,
          obscureText: _obscurePass,
          decoration: InputDecoration(
            labelText: 'Nouveau mot de passe',
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: IconButton(
              icon: Icon(_obscurePass
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined),
              onPressed: () =>
                  setState(() => _obscurePass = !_obscurePass),
            ),
          ),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _confirmCtrl,
          obscureText: _obscureConfirm,
          decoration: InputDecoration(
            labelText: 'Confirmer le mot de passe',
            prefixIcon: const Icon(Icons.lock_outline_rounded),
            suffixIcon: IconButton(
              icon: Icon(_obscureConfirm
                  ? Icons.visibility_off_outlined
                  : Icons.visibility_outlined),
              onPressed: () =>
                  setState(() => _obscureConfirm = !_obscureConfirm),
            ),
          ),
          onSubmitted: (_) => _resetPassword(),
        ),
        const SizedBox(height: 24),
        _SubmitButton(
          label: 'Réinitialiser',
          icon: Icons.save_rounded,
          loading: _loading,
          onPressed: _resetPassword,
        ),
      ],
    );
  }
}

// ── Widget bouton submit ─────────────────────────────────────────────────────
class _SubmitButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool loading;
  final VoidCallback onPressed;

  const _SubmitButton({
    required this.label,
    required this.icon,
    required this.loading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: FilledButton.icon(
        onPressed: loading ? null : onPressed,
        icon: loading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : Icon(icon),
        label: Text(label,
            style:
                const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

// ── Indicateur d'étapes ──────────────────────────────────────────────────────
class _StepIndicator extends StatelessWidget {
  final int step;
  const _StepIndicator({required this.step});

  @override
  Widget build(BuildContext context) {
    const labels = ['Email', 'Code', 'Mot de passe'];
    return Row(
      children: List.generate(3, (i) {
        final active  = i + 1 == step;
        final done    = i + 1 < step;
        final color   = (active || done) ? AppColors.primary : AppColors.border;
        return Expanded(
          child: Row(
            children: [
              Expanded(
                child: Column(
                  children: [
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: done
                            ? AppColors.success
                            : active
                                ? AppColors.primary
                                : AppColors.border,
                      ),
                      child: Icon(
                        done ? Icons.check_rounded : Icons.circle,
                        size: done ? 16 : 10,
                        color: (active || done) ? Colors.white : Colors.white54,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      labels[i],
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: active
                            ? FontWeight.w700
                            : FontWeight.w400,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
              if (i < 2)
                Expanded(
                  child: Container(
                    height: 2,
                    margin: const EdgeInsets.only(bottom: 20),
                    color: done ? AppColors.success : AppColors.border,
                  ),
                ),
            ],
          ),
        );
      }),
    );
  }
}
