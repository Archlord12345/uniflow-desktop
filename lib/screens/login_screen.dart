import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../theme/app_theme.dart';
import '../widgets/uniflow_logo.dart';
import '../widgets/app_text_field.dart';
import '../repositories/auth_repository.dart';
import 'main_shell.dart';

/// Écran de connexion : 
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _rememberMe = false;
  bool _isLoading = false;
  String? _errorMessage;

  // Rôle sélectionné dans le menu déroulant ajouté sous "Se connecter".
  String? _selectedRole;
  static const List<String> _roles = ['Administrateur', 'Enseignant', 'Étudiant'];

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final authRepo = ref.read(authRepositoryProvider);
      await authRepo.login(_emailController.text, _passwordController.text);

      if (!mounted) return;

      setState(() => _isLoading = false);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainShell()),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Identifiants invalides ou problème de connexion.';
      });
    }
  }

  /// Contenu du formulaire seul (sans fond ni ombre propres : le panneau
  /// blanc et l'ombre sont maintenant portés par la carte englobante dans
  /// [build], pour que l'image et le formulaire ne fassent qu'un bloc).
  Widget _buildFormContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 40),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 28),
          const Text('Se connecter', textAlign: TextAlign.center, style: AppTextStyles.h1),
          if (_errorMessage != null) ...[
            const SizedBox(height: 12),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
          const SizedBox(height: 6),
          const Text('Connectez-vous à votre compte', textAlign: TextAlign.center, style: AppTextStyles.body),
          const SizedBox(height: 28),
          AppTextField(
            label: 'Email',
            hint: 'admin@uniflow.edu',
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            prefixIcon: Icons.mail_outline,
          ),
          const SizedBox(height: 18),
          AppTextField(
            label: 'Mot de passe',
            hint: '••••••••',
            controller: _passwordController,
            obscureText: true,
            prefixIcon: Icons.lock_outline,
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                onTap: () => setState(() => _rememberMe = !_rememberMe),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: Checkbox(
                        value: _rememberMe,
                        onChanged: (v) => setState(() => _rememberMe = v ?? false),
                        activeColor: AppColors.primaryBlue,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text('Se souvenir de moi', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                  ],
                ),
              ),
              GestureDetector(
                onTap: () {
                  // TODO: naviguer vers l'écran "mot de passe oublié"
                },
                child: const Text('Mot de passe oublié ?', style: AppTextStyles.link),
              ),
            ],
          ),
          const SizedBox(height: 26),
          SizedBox(
            height: 50,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _handleLogin,
              child: _isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.4),
                    )
                  : const Text('Se connecter'),
            ),
          ),
          // ----- Séparateur "ou" + sélecteur de rôle -----
          // Ajouté sous le bouton de connexion : permet de choisir le rôle
          // avec lequel se connecter (Administrateur / Enseignant / Étudiant).
          const SizedBox(height: 22),
          Row(
            children: [
              const Expanded(child: Divider(color: AppColors.inputBorder)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('ou', style: AppTextStyles.body.copyWith(fontSize: 13)),
              ),
              const Expanded(child: Divider(color: AppColors.inputBorder)),
            ],
          ),
          const SizedBox(height: 18),
          const Text('Rôle', style: AppTextStyles.label),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedRole,
            isExpanded: true,
            icon: const Icon(Icons.keyboard_arrow_down, color: AppColors.textMuted),
            style: const TextStyle(fontSize: 14, color: AppColors.textPrimary),
            hint: const Text(
              'Sélectionner votre rôle',
              style: TextStyle(fontSize: 14, color: AppColors.textMuted),
            ),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.inputFill,
              contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.inputBorder),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.inputBorder),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: const BorderSide(color: AppColors.primaryBlue, width: 1.5),
              ),
            ),
            items: _roles
                .map((role) => DropdownMenuItem(value: role, child: Text(role)))
                .toList(),
            onChanged: (value) => setState(() => _selectedRole = value),
          ),
        ],
      ),
    );
  }

  /// Disposition large écran : image et formulaire côte à côte, la Row
  /// étant enveloppée dans IntrinsicHeight + stretch pour que l'image
  /// s'étire exactement à la hauteur du formulaire.
  Widget _buildWideLayout() {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Stack(
              children: [
                Positioned.fill(
                  child: Image.asset('assets/images/login.jpg', fit: BoxFit.cover),
                ),
                Positioned(
                  top: 24,
                  left: 0,
                  right: 0,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      const UniFlowLogo(iconSize: 52, fontSize: 28),
                      const SizedBox(height: 8),
                      Text(
                        'Bienvenue sur Uniflow !',
                        style: AppTextStyles.h1.copyWith(color: Colors.white),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'la plate forme academique de référence',
                        style: AppTextStyles.body.copyWith(color: Colors.white),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 400,
            child: ColoredBox(color: AppColors.cardWhite, child: _buildFormContent()),
          ),
        ],
      ),
    );
  }

  /// Disposition petit écran : image au-dessus, formulaire en dessous,
  /// toujours dans le même bloc englobant (pas de carte séparée).
  Widget _buildNarrowLayout() {
    return Column(
      mainAxisSize: MainAxisSize.min,
        children: [
        SizedBox(
          height: 220,
          width: double.infinity,
          child: Stack(
            children: [
              Positioned.fill(
                child: Image.asset('assets/images/login.jpg', fit: BoxFit.cover),
              ),
              Positioned(
                top: 16,
                left: 0,
                right: 0,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                    const UniFlowLogo(iconSize: 48, fontSize: 26),
                    const SizedBox(height: 6),
                    Text(
                      'Bienvenue sur Uniflow !',
                      style: AppTextStyles.h1.copyWith(color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'la plate forme academique de référence',
                      style: AppTextStyles.body.copyWith(color: Colors.white),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        ColoredBox(color: AppColors.cardWhite, child: _buildFormContent()),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 900),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isWide = constraints.maxWidth >= 700;
                return Stack(
                  // Clip.none : les formes décoratives peuvent légèrement
                  // dépasser du coin de la carte sans être coupées.
                  clipBehavior: Clip.none,
                  children: [
                    Positioned(
                      left: -300,
                      bottom: -250,
                      child: _Blob(size: 350, color: AppColors.deepBlue.withValues(alpha: 1.0)),
                    ),
                    Positioned(
                      right: -300,
                      top: -250,
                      child: _Blob(size: 350, color: AppColors.teal.withValues(alpha: 1.0)),
                    ),
                    // La carte : un seul bloc (ombre + coins arrondis)
                    // contenant l'image et le formulaire collés ensemble.
                    Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 40,
                            offset: const Offset(0, 16),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: isWide ? _buildWideLayout() : _buildNarrowLayout(),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

/// Forme organique décorative (bleu/teal) qui dépasse légèrement du coin
/// inférieur gauche de la carte de connexion.
class _Blob extends StatelessWidget {
  final double size;
  final Color color;

  const _Blob({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(size * 0.4)),
    );
  }
}