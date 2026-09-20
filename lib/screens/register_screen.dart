import 'package:appwrite/appwrite.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/reference_models.dart';
import '../models/user_role.dart';
import '../providers/appwrite_provider.dart';
import '../providers/auth_provider.dart';
import '../repositories/auth_repository.dart';
import '../repositories/reference_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/app_text_field.dart';
import '../widgets/auth_chrome.dart';
import '../widgets/motion.dart';
import 'login_screen.dart';

/// Inscription native, même séquence que `createAccount` du web.
///
/// Compte universitaire : université → faculté → filière → niveau, lus dans
/// le référentiel Appwrite (rien de codé en dur), et **toujours** rôle
/// `STUDENT` — aucun choix de rôle dans le formulaire, les autres rôles sont
/// créés par l'administration. Compte indépendant : nom, email, mot de passe,
/// pays facultatif.
class RegisterScreen extends ConsumerStatefulWidget {
  final AccountType initialType;
  const RegisterScreen({super.key, this.initialType = AccountType.university});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  final _countryController = TextEditingController();

  // Saisie libre de secours quand le référentiel est vide (collection non
  // provisionnée, hors ligne) : le formulaire reste utilisable.
  final _universityFree = TextEditingController();
  final _programFree = TextEditingController();

  late AccountType _type = widget.initialType;
  String? _universityCode;
  String? _facultyCode;
  String? _programCode;
  String? _level;

  bool _busy = false;
  String? _error;
  bool _done = false;

  @override
  void dispose() {
    for (final c in [
      _nameController,
      _emailController,
      _passwordController,
      _confirmController,
      _countryController,
      _universityFree,
      _programFree,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit(AcademicReference? reference) async {
    if (_passwordController.text != _confirmController.text) {
      setState(() => _error = 'Les deux mots de passe ne correspondent pas.');
      return;
    }

    final useReference = reference != null && !reference.isEmpty;
    final university = _type == AccountType.university
        ? (useReference
            ? reference.universityByCode(_universityCode ?? '')?.name
            : _universityFree.text)
        : null;
    final program = _type == AccountType.university
        ? (useReference ? _programCode : _programFree.text)
        : null;

    final request = RegistrationRequest(
      name: _nameController.text,
      email: _emailController.text,
      password: _passwordController.text,
      accountType: _type,
      university: university,
      program: program,
      level: _type == AccountType.university ? _level : null,
      country: _countryController.text.trim().isEmpty
          ? null
          : _countryController.text,
    );
    final invalid = validateRegistration(request);
    if (invalid != null) {
      setState(() => _error = invalid);
      return;
    }

    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final user = await ref.read(authRepositoryProvider).register(request);
      if (!mounted) return;
      ref.read(currentUserProvider.notifier).state = user;
      setState(() {
        _busy = false;
        _done = true;
      });
    } on AppwriteException catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = readableAuthError(e);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = e is ArgumentError
            ? e.message.toString()
            : 'Inscription impossible : $e';
      });
    }
  }

  Future<void> _openWebRegistration() async {
    final base = ref.read(appwriteServiceProvider).webAppUrl;
    final uri = Uri.parse('$base/register');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      showFeedback(context,
          message: 'Impossible d\'ouvrir $uri', success: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_done) {
      final user = ref.watch(currentUserProvider);
      return Scaffold(
        backgroundColor: AppColors.background,
        body: ResultView(
          success: true,
          title: 'Compte créé',
          message: _type == AccountType.university
              ? 'Bienvenue ${user?.name ?? ''}. Votre compte étudiant est prêt : vos cours, '
                  'votre emploi du temps et vos devoirs vous attendent.'
              : 'Bienvenue ${user?.name ?? ''}. Votre espace personnel est prêt.',
          actionLabel: 'Entrer dans UniFlow',
          onAction: () => Navigator.of(context).pop(true),
        ),
      );
    }

    final reference = ref.watch(academicReferenceProvider);
    return AuthShell(
      formWidth: 420,
      formWidthWide: 500,
      form: _form(reference),
    );
  }

  Widget _form(AsyncValue<AcademicReference> referenceAsync) {
    final reference = referenceAsync.valueOrNull;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Retour à la connexion',
              onPressed: _busy ? null : () => Navigator.of(context).pop(false),
              icon: const Icon(Icons.arrow_back),
            ),
            const Expanded(
              child: Text(
                'Créer un compte',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.h1,
              ),
            ),
            const SizedBox(width: 48),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          _type == AccountType.university
              ? 'Compte étudiant rattaché à votre établissement'
              : 'Espace personnel, sans rattachement',
          textAlign: TextAlign.center,
          style: AppTextStyles.body,
        ),
        const SizedBox(height: 20),
        AccountTypeSelector(
          value: _type,
          onChanged: _busy ? (_) {} : (type) => setState(() => _type = type),
        ),
        if (_error != null) ...[
          const SizedBox(height: 14),
          ErrorBanner(message: _error!)
        ],
        const SizedBox(height: 18),
        AppTextField(
          label: 'Nom complet',
          hint: 'Prénom Nom',
          controller: _nameController,
          prefixIcon: Icons.person_outline,
        ),
        const SizedBox(height: 14),
        AppTextField(
          label: 'Email',
          hint: 'prenom.nom@universite.cm',
          controller: _emailController,
          keyboardType: TextInputType.emailAddress,
          prefixIcon: Icons.mail_outline,
        ),
        const SizedBox(height: 14),
        AppTextField(
          label: 'Mot de passe (8 caractères minimum)',
          hint: '••••••••',
          controller: _passwordController,
          obscureText: true,
          prefixIcon: Icons.lock_outline,
        ),
        const SizedBox(height: 14),
        AppTextField(
          label: 'Confirmer le mot de passe',
          hint: '••••••••',
          controller: _confirmController,
          obscureText: true,
          prefixIcon: Icons.lock_outline,
        ),
        const SizedBox(height: 14),
        AnimatedSize(
          duration: kMotionMedium,
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: _type == AccountType.university
              ? _universityFields(referenceAsync, reference)
              : AppTextField(
                  label: 'Pays (facultatif)',
                  hint: 'Cameroun',
                  controller: _countryController,
                  prefixIcon: Icons.public_outlined,
                ),
        ),
        if (_type == AccountType.university) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.teal50,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.teal100),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, size: 16, color: AppColors.tealDark),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'L\'inscription crée un compte étudiant. Les comptes enseignant, '
                    'délégué et administration sont créés par l\'administration de '
                    'votre établissement.',
                    style: TextStyle(
                        fontSize: 12, color: AppColors.tealDark, height: 1.35),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 20),
        GradientButton(
          label: 'Créer mon compte',
          isLoading: _busy,
          onPressed: _busy ? null : () => _submit(reference),
        ),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: _busy ? null : _openWebRegistration,
          icon: const Icon(Icons.open_in_new, size: 16),
          label:
              const Text('S\'inscrire sur le web', style: AppTextStyles.link),
        ),
      ],
    );
  }

  Widget _universityFields(
    AsyncValue<AcademicReference> referenceAsync,
    AcademicReference? reference,
  ) {
    if (referenceAsync.isLoading) {
      return const Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Shimmer(
              height: 48, borderRadius: BorderRadius.all(Radius.circular(10))),
          SizedBox(height: 14),
          Shimmer(
              height: 48, borderRadius: BorderRadius.all(Radius.circular(10))),
          SizedBox(height: 14),
          Shimmer(
              height: 48, borderRadius: BorderRadius.all(Radius.circular(10))),
        ],
      );
    }

    if (reference == null || reference.isEmpty) {
      // Référentiel injoignable : saisie libre, avec explication.
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            label: 'Université',
            hint: 'Nom complet de l\'université',
            controller: _universityFree,
            prefixIcon: Icons.account_balance_outlined,
          ),
          const SizedBox(height: 14),
          AppTextField(
            label: 'Code de filière',
            hint: 'Tel qu\'indiqué par votre établissement',
            controller: _programFree,
            prefixIcon: Icons.menu_book_outlined,
          ),
          const SizedBox(height: 14),
          AuthDropdown<String>(
            label: 'Niveau',
            value: _level,
            items: [
              for (final level in const ['L1', 'L2', 'L3', 'M1', 'M2'])
                DropdownMenuItem(value: level, child: Text(level)),
            ],
            onChanged: (value) => setState(() => _level = value),
          ),
          if (referenceAsync.hasError) ...[
            const SizedBox(height: 8),
            Text(
              'Le référentiel des établissements est indisponible ; saisie manuelle.',
              style: AppTextStyles.bodySmall.copyWith(color: AppColors.warning),
            ),
          ],
        ],
      );
    }

    final universities = reference.universities.where((u) => u.active).toList();
    final faculties = _universityCode == null
        ? const <Faculty>[]
        : reference.facultiesOf(_universityCode!);
    final programs = _universityCode == null
        ? const <AcademicProgram>[]
        : reference.programsOf(_universityCode!, facultyCode: _facultyCode);
    final levels = _programCode == null
        ? const <String>[]
        : reference.levelsOf(_programCode);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AuthDropdown<String>(
          label: 'Université',
          value: _universityCode,
          hint: 'Choisir votre université',
          items: [
            for (final u in universities)
              DropdownMenuItem(
                value: u.code,
                child: Text(u.displayName,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: (value) => setState(() {
            _universityCode = value;
            _facultyCode = null;
            _programCode = null;
            _level = null;
          }),
        ),
        if (faculties.isNotEmpty) ...[
          const SizedBox(height: 14),
          AuthDropdown<String>(
            label: 'Faculté / établissement',
            value: _facultyCode,
            hint: 'Choisir votre faculté',
            items: [
              for (final f in faculties)
                DropdownMenuItem(
                  value: f.code,
                  child: Text(f.name,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                ),
            ],
            onChanged: (value) => setState(() {
              _facultyCode = value;
              _programCode = null;
              _level = null;
            }),
          ),
        ],
        const SizedBox(height: 14),
        AuthDropdown<String>(
          label: 'Filière',
          value: _programCode,
          hint: _universityCode == null
              ? 'Choisissez d\'abord l\'université'
              : 'Choisir votre filière',
          items: [
            for (final p in programs)
              DropdownMenuItem(
                value: p.code,
                child: Text(p.displayName,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
          ],
          onChanged: programs.isEmpty
              ? null
              : (value) => setState(() {
                    _programCode = value;
                    _level = null;
                  }),
        ),
        const SizedBox(height: 14),
        AuthDropdown<String>(
          label: 'Niveau',
          value: _level,
          hint: _programCode == null
              ? 'Choisissez d\'abord la filière'
              : 'Choisir votre niveau',
          items: [
            for (final l in levels) DropdownMenuItem(value: l, child: Text(l))
          ],
          onChanged:
              levels.isEmpty ? null : (value) => setState(() => _level = value),
        ),
      ],
    );
  }
}
