import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/uniflow_logo.dart';
import '../widgets/app_text_field.dart';
import '../repositories/auth_repository.dart';
import 'main_shell.dart';

/// Rouge plus sombre que `AppColors.danger`, réservé au **texte** posé sur un
/// fond rouge très clair : le rouge d'alerte est prévu pour des icônes et des
/// bordures, il manque de contraste pour de la lecture.
const Color _kDangerInk = Color(0xFFB91C1C);

/// Au-dessous de cette largeur, l'image passe au-dessus du formulaire au lieu
/// d'être à côté : en dessous, les deux colonnes seraient trop étroites pour
/// être lisibles.
const double _kSideBySideBreakpoint = 760;

/// Au-dessus de cette largeur, la colonne du formulaire peut s'élargir : elle
/// reste sinon volontairement étroite (380 px), une ligne de saisie trop large
/// étant inconfortable à lire.
const double _kWideBreakpoint = 1040;

/// Écran de connexion.
///
/// La mise en page s'adapte à la taille de la fenêtre : sur une fenêtre large
/// l'image et le formulaire sont côte à côte, sur une fenêtre étroite (mobile,
/// ou fenêtre de bureau réduite) l'image devient un bandeau au-dessus du
/// formulaire. Aucune largeur n'est imposée en dur sans qu'un parent puisse la
/// réduire, ce qui évite les débordements quand la fenêtre est petite.
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

      // La session Appwrite est créée, mais l'état Riverpod ne se remplit pas
      // tout seul : sans cette ligne, le dashboard et les paramètres affichent
      // « Utilisateur non connecté » alors que la connexion a réussi.
      final user = await authRepo.getCurrentUser();
      if (!mounted) return;
      if (user == null) {
        // `getCurrentUser` renvoie null aussi bien quand le document `users`
        // est refusé en lecture que lorsqu'il n'existe pas : dans les deux cas
        // la session est ouverte mais l'application n'a aucun profil à
        // afficher, et il vaut mieux le dire que d'ouvrir un shell vide.
        setState(() {
          _isLoading = false;
          _errorMessage =
              "Session ouverte, mais aucun profil UniFlow n'a pu être lu pour "
              'ce compte (collection « users » inaccessible ou document '
              'absent). Vérifiez les permissions de la collection.';
        });
        return;
      }
      ref.read(currentUserProvider.notifier).state = user;

      setState(() => _isLoading = false);
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const MainShell()),
      );
    } on AppwriteException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = _readableError(e);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Connexion impossible : $e';
      });
    }
  }

  /// Traduit les codes d'erreur Appwrite en messages compréhensibles.
  /// Un échec réseau et un mauvais mot de passe ne doivent pas être confondus :
  /// c'est ce qui rendait le diagnostic impossible jusqu'ici.
  String _readableError(AppwriteException e) {
    switch (e.code) {
      case 401:
        return 'Email ou mot de passe incorrect.';
      case 403:
        return "Accès refusé : cette plateforme n'est pas autorisée dans le "
            'projet Appwrite. Ajoutez son identifiant dans '
            'Overview → Platforms.';
      case 429:
        return 'Trop de tentatives. Réessayez dans quelques minutes.';
      default:
        if (e.message?.contains('Failed host lookup') == true ||
            e.message?.contains('Connection') == true) {
          return 'Appwrite est injoignable (${e.message}).';
        }
        return e.message ?? 'Erreur Appwrite (code ${e.code}).';
    }
  }

  /// Explique pourquoi le lien « Mot de passe oublié ? » ne mène nulle part.
  ///
  /// Auparavant ce lien était un `TODO` silencieux : le clic ne produisait
  /// rien, ce qui laisse croire à une panne. Un message explicite est plus
  /// honnête tant que la fonction n'existe pas.
  void _explainForgotPassword() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "La réinitialisation en libre-service n'est pas encore disponible. "
          'Contactez un administrateur pour réinitialiser votre mot de passe.',
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Formulaire
  // ---------------------------------------------------------------------

  /// Contenu du formulaire seul, sans marge extérieure : chaque disposition
  /// ([_buildNarrowLayout] / [_buildWideLayout]) applique la sienne, qui dépend
  /// de la place disponible.
  Widget _buildFormContent() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Se connecter',
          textAlign: TextAlign.center,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.h1,
        ),
        const SizedBox(height: 6),
        const Text(
          'Connectez-vous à votre compte',
          textAlign: TextAlign.center,
          style: AppTextStyles.body,
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 16),
          _ErrorBanner(message: _errorMessage!),
        ],
        const SizedBox(height: 24),
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
        // `Wrap` plutôt que `Row` : les deux libellés se placent côte à côte
        // quand la largeur le permet, et passent l'un sous l'autre sinon. Une
        // `Row` avec deux enfants rigides débordait de quelques pixels dès que
        // la colonne devenait étroite.
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 16,
          runSpacing: 2,
          children: [
            InkWell(
              onTap: () => setState(() => _rememberMe = !_rememberMe),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
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
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // `Flexible` : le libellé se tronque au lieu de pousser la
                    // case hors de la ligne quand la police système est agrandie.
                    const Flexible(
                      child: Text(
                        'Se souvenir de moi',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            TextButton(
              onPressed: _explainForgotPassword,
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 4),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Mot de passe oublié ?', style: AppTextStyles.link),
            ),
          ],
        ),
        const SizedBox(height: 22),
        _GradientButton(
          label: 'Se connecter',
          isLoading: _isLoading,
          onPressed: _isLoading ? null : _handleLogin,
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 14, color: AppColors.textMuted),
          ),
          // Même habillage que les champs `AppTextField` du dessus, pour que
          // les trois champs du formulaire soient visuellement alignés.
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
              .map((role) => DropdownMenuItem(
                    value: role,
                    child: Text(role, maxLines: 1, overflow: TextOverflow.ellipsis),
                  ))
              .toList(),
          onChanged: (value) => setState(() => _selectedRole = value),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------
  // Dispositions
  // ---------------------------------------------------------------------

  /// Disposition large : image à gauche, formulaire à droite.
  ///
  /// `IntrinsicHeight` + `stretch` donnent à l'image exactement la hauteur du
  /// formulaire : sans cela, l'un des deux panneaux serait plus court que
  /// l'autre et le bloc paraîtrait cassé.
  Widget _buildWideLayout({required bool isWide}) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _buildImagePanel()),
          SizedBox(
            // 380 px en dessous du seuil « large », 460 px au-dessus : la
            // colonne s'élargit quand la fenêtre le permet.
            width: isWide ? 460 : 380,
            child: ColoredBox(
              color: AppColors.cardWhite,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: isWide ? 44 : 32,
                  vertical: 40,
                ),
                child: _buildFormContent(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Disposition étroite : bandeau image, puis formulaire en dessous.
  Widget _buildNarrowLayout() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: 180,
          width: double.infinity,
          child: _buildImagePanel(compact: true),
        ),
        ColoredBox(
          color: AppColors.cardWhite,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 28, 22, 30),
            child: _buildFormContent(),
          ),
        ),
      ],
    );
  }

  /// Panneau visuel : photo de campus, voile dégradé bleu → teal (comme le
  /// dégradé de marque du web) par-dessus, et le message d'accueil.
  ///
  /// Tous les enfants sont `Positioned` : c'est volontaire. Un enfant non
  /// positionné imposerait sa hauteur intrinsèque au `Stack`, donc à la carte
  /// entière — la photo, qui est grande, étirerait le bloc démesurément.
  Widget _buildImagePanel({bool compact = false}) {
    return Stack(
      children: [
        Positioned.fill(
          child: Image.asset('assets/images/login.jpg', fit: BoxFit.cover),
        ),
        // Voile dégradé : garantit la lisibilité du texte quelle que soit la
        // photo, et donne au panneau la couleur de la marque.
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primaryBlue.withValues(alpha: 0.88),
                  AppColors.deepBlue.withValues(alpha: 0.82),
                  AppColors.teal.withValues(alpha: 0.78),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
        ),
        Positioned.fill(
          // `SingleChildScrollView` : le volet de gauche est centré dans la
          // hauteur disponible. Avec une police agrandie, son contenu dépassait
          // cette hauteur et débordait vers le bas ; ici il défile.
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 20 : 36,
              vertical: compact ? 16 : 40,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                UniFlowLogo(
                  iconSize: compact ? 40 : 54,
                  fontSize: compact ? 24 : 30,
                  // Le mot « UniFlow » est sombre par défaut : sur ce voile
                  // coloré il disparaîtrait.
                  textColor: Colors.white,
                ),
                SizedBox(height: compact ? 8 : 18),
                Text(
                  'Bienvenue sur UniFlow !',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.h1.copyWith(
                    color: Colors.white,
                    fontSize: compact ? 21 : 27,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'La plateforme académique de référence',
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.body.copyWith(
                    color: Colors.white.withValues(alpha: 0.88),
                    fontSize: compact ? 12.5 : 14,
                  ),
                ),
                // Les arguments ne tiennent pas dans le bandeau étroit : ils
                // sont réservés à la disposition large, où ils remplissent le
                // panneau au lieu de le surcharger.
                if (!compact) ...[
                  const SizedBox(height: 30),
                  const _HeroPoint(
                    icon: Icons.school_outlined,
                    text: 'Étudiants, enseignants et programmes au même endroit',
                  ),
                  const SizedBox(height: 12),
                  const _HeroPoint(
                    icon: Icons.calendar_today_outlined,
                    text: 'Emplois du temps et présences en temps réel',
                  ),
                  const SizedBox(height: 12),
                  const _HeroPoint(
                    icon: Icons.videocam_outlined,
                    text: 'Cours en visioconférence sans serveur central',
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      // Fond en dégradé « mesh » (bleu très clair → teal très clair → violet
      // très clair), comme les pages d'authentification du web.
      body: DecoratedBox(
        decoration: const BoxDecoration(gradient: AppColors.meshGradient),
        child: Stack(
          children: [
            // Formes décoratives, hors du flux : elles ne participent donc pas
            // au calcul de taille et ne peuvent pas provoquer de débordement.
            Positioned(
              top: -140,
              left: -120,
              child: _Blob(
                size: 320,
                color: AppColors.primaryBlue.withValues(alpha: 0.10),
              ),
            ),
            Positioned(
              bottom: -160,
              right: -130,
              child: _Blob(
                size: 340,
                color: AppColors.teal.withValues(alpha: 0.12),
              ),
            ),
            SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final width = constraints.maxWidth;
                  final useSideBySide = width >= _kSideBySideBreakpoint;
                  final isWide = width >= _kWideBreakpoint;
                  final horizontalPadding = useSideBySide ? 32.0 : 16.0;
                  final verticalPadding = useSideBySide ? 32.0 : 16.0;

                  return SingleChildScrollView(
                    padding: EdgeInsets.symmetric(
                      horizontal: horizontalPadding,
                      vertical: verticalPadding,
                    ),
                    child: ConstrainedBox(
                      // Occupe au moins toute la hauteur de la fenêtre : la
                      // carte est ainsi centrée verticalement quand il y a de
                      // la place, et la page défile quand il n'y en a pas.
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight - verticalPadding * 2,
                      ),
                      child: Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 1080),
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.cardWhite,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: AppColors.inputBorder),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.primaryBlue.withValues(alpha: 0.13),
                                  blurRadius: 48,
                                  offset: const Offset(0, 20),
                                ),
                              ],
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(24),
                              // Un `Material` transparent pour que les effets
                              // d'encre des boutons et du lien se peignent
                              // au-dessus de la carte, et non derrière elle.
                              child: Material(
                                type: MaterialType.transparency,
                                child: useSideBySide
                                    ? _buildWideLayout(isWide: isWide)
                                    : _buildNarrowLayout(),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bouton principal, en dégradé bleu → teal avec une ombre portée colorée.
///
/// Construit à la main plutôt qu'avec `ElevatedButton` : `ElevatedButton` ne
/// sait pas peindre un dégradé, et c'est ce dégradé qui rattache visuellement
/// l'écran de connexion au reste de la charte.
class _GradientButton extends StatelessWidget {
  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;

  const _GradientButton({
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final isDisabled = onPressed == null;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: isDisabled ? null : AppColors.logoGradient,
        color: isDisabled ? AppColors.inputBorder : null,
        borderRadius: BorderRadius.circular(AppTheme.radiusCard),
        boxShadow: isDisabled
            ? null
            : [
                BoxShadow(
                  color: AppColors.primaryBlue.withValues(alpha: 0.30),
                  blurRadius: 18,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(AppTheme.radiusCard),
          child: SizedBox(
            height: 52,
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.4,
                      ),
                    )
                  : Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.button,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Encadré rouge affichant l'erreur de connexion.
///
/// Remplace un simple texte rouge : sur un fond clair, un message d'erreur
/// isolé se confond avec le reste du formulaire.
class _ErrorBanner extends StatelessWidget {
  final String message;

  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.error_outline, size: 18, color: AppColors.danger),
          const SizedBox(width: 8),
          // `Flexible` : le message peut être long (erreur Appwrite brute), il
          // doit se replier sur plusieurs lignes et non élargir l'encadré.
          Flexible(
            child: Text(
              message,
              style: const TextStyle(
                fontSize: 12.5,
                height: 1.35,
                fontWeight: FontWeight.w500,
                color: _kDangerInk,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Une ligne d'argument du panneau visuel : icône dans une pastille, puis
/// texte. Le texte est `Flexible` pour se replier si la colonne est étroite.
class _HeroPoint extends StatelessWidget {
  final IconData icon;
  final String text;

  const _HeroPoint({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 15, color: Colors.white),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Padding(
            padding: const EdgeInsets.only(top: 5),
            child: Text(
              text,
              style: TextStyle(
                fontSize: 13,
                height: 1.35,
                color: Colors.white.withValues(alpha: 0.9),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Forme organique décorative du fond de page.
class _Blob extends StatelessWidget {
  final double size;
  final Color color;

  const _Blob({required this.size, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(size * 0.4),
      ),
    );
  }
}
