import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../ui/app_button.dart';

/// Boîte à outils d'animation partagée par tous les écrans.
///
/// Le propriétaire a fait des animations une priorité visuelle : entrées en
/// cascade, squelettes de chargement, retours de succès et d'échec animés.
/// Tout est centralisé ici pour que chaque écran ait le **même** mouvement —
/// une cascade à 40 ms sur une page et 120 ms sur la voisine se lit comme un
/// défaut, pas comme un style.

/// Durée de référence d'une transition d'écran.
const Duration kMotionMedium = Duration(milliseconds: 280);

/// Réglage « réduire les animations » (Paramètres) : les cascades sautent
/// directement à leur état final. Un drapeau global plutôt qu'un provider,
/// pour que les widgets d'animation restent utilisables hors `ProviderScope`
/// (dialogues, superpositions).
final ValueNotifier<bool> motionReduced = ValueNotifier<bool>(false);

/// Apparition d'un enfant : fondu + glissement vers le haut, différé selon
/// [index] pour former une cascade. Utilisé sur les lignes de tableau, les
/// cartes de statistiques, les membres de l'équipe.
class CascadeIn extends StatefulWidget {
  final int index;
  final Widget child;

  /// Écart entre deux voisins. Plafonné à 12 crans : la trentième ligne d'un
  /// tableau apparaît au même moment que la douzième, sinon l'utilisateur
  /// attend une seconde et demie devant une liste vide.
  final Duration step;
  final Duration duration;
  final Offset offset;

  const CascadeIn({
    super.key,
    required this.index,
    required this.child,
    this.step = const Duration(milliseconds: 45),
    this.duration = const Duration(milliseconds: 380),
    this.offset = const Offset(0, 0.06),
  });

  @override
  State<CascadeIn> createState() => _CascadeInState();
}

class _CascadeInState extends State<CascadeIn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final CurvedAnimation _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  @override
  void initState() {
    super.initState();
    if (motionReduced.value) {
      _controller.value = 1;
      return;
    }
    final delay = widget.step * widget.index.clamp(0, 12);
    // `Timer` annulable plutôt que `Future.delayed` : un écran démonté avant
    // la fin de la cascade (navigation rapide, test de mise en page qui ne
    // pompe que 50 ms) laissait un minuteur orphelin — « A Timer is still
    // pending even after the widget tree was disposed ».
    _delay = Timer(delay, () {
      if (mounted) _controller.forward();
    });
  }

  Timer? _delay;

  @override
  void dispose() {
    _delay?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curve,
      child: SlideTransition(
        position: Tween<Offset>(begin: widget.offset, end: Offset.zero)
            .animate(_curve),
        child: widget.child,
      ),
    );
  }
}

/// Squelette de chargement : un bloc gris qui respire. Il remplace la roue
/// centrée des états de chargement, qui ne disait rien de la forme du contenu
/// à venir et faisait sauter la page à l'arrivée des données.
class Shimmer extends StatefulWidget {
  final double width;
  final double height;
  final BorderRadius borderRadius;

  const Shimmer({
    super.key,
    this.width = double.infinity,
    this.height = 14,
    this.borderRadius = const BorderRadius.all(Radius.circular(6)),
  });

  const Shimmer.circle({super.key, required double size})
      : width = size,
        height = size,
        borderRadius = const BorderRadius.all(Radius.circular(999));

  @override
  State<Shimmer> createState() => _ShimmerState();
}

class _ShimmerState extends State<Shimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: widget.borderRadius,
            gradient: LinearGradient(
              begin: Alignment(-1 + 2 * t - 1, 0),
              end: Alignment(-1 + 2 * t + 1, 0),
              colors: const [
                Color(0xFFE5E7EB),
                Color(0xFFF3F4F6),
                Color(0xFFE5E7EB),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Squelette d'un tableau : quelques lignes de largeur variable, dans une
/// carte blanche, comme le tableau réel qu'il annonce.
class TableSkeleton extends StatelessWidget {
  final int rows;
  const TableSkeleton({super.key, this.rows = 6});

  @override
  Widget build(BuildContext context) {
    // Défilant pour la même raison que `DataEmptyView` : un squelette de six
    // lignes ne tient pas dans un `Expanded` de fenêtre basse.
    return SingleChildScrollView(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.inputBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Shimmer(height: 16, width: 180),
            const SizedBox(height: 18),
            for (var i = 0; i < rows; i++) ...[
              Row(
                children: [
                  const Shimmer.circle(size: 30),
                  const SizedBox(width: 12),
                  Expanded(
                      flex: 3,
                      child: Shimmer(height: 12, width: 120 + (i % 3) * 40)),
                  const SizedBox(width: 16),
                  const Expanded(flex: 2, child: Shimmer(height: 12)),
                  const SizedBox(width: 16),
                  const Expanded(child: Shimmer(height: 12)),
                ],
              ),
              if (i < rows - 1) const SizedBox(height: 16),
            ],
          ],
        ),
      ),
    );
  }
}

/// Squelette d'une grille de cartes.
class CardGridSkeleton extends StatelessWidget {
  final int count;
  const CardGridSkeleton({super.key, this.count = 6});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          for (var i = 0; i < count; i++)
            Container(
              width: 260,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppColors.cardWhite,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.inputBorder),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Shimmer.circle(size: 44),
                  SizedBox(height: 14),
                  Shimmer(height: 14, width: 160),
                  SizedBox(height: 8),
                  Shimmer(height: 11, width: 110),
                  SizedBox(height: 14),
                  Shimmer(height: 11),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Coche qui se dessine : le retour de succès que le propriétaire veut voir
/// après chaque action réussie.
class AnimatedCheck extends StatefulWidget {
  final double size;
  final Color color;
  const AnimatedCheck({super.key, this.size = 72, this.color = AppColors.teal});

  @override
  State<AnimatedCheck> createState() => _AnimatedCheckState();
}

class _AnimatedCheckState extends State<AnimatedCheck>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 700),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final scale =
            Curves.elasticOut.transform(_controller.value.clamp(0.0, 1.0));
        return Transform.scale(
          scale: 0.6 + 0.4 * scale,
          child: CustomPaint(
            size: Size.square(widget.size),
            painter: _CheckPainter(
              progress: Curves.easeOutCubic.transform(_controller.value),
              color: widget.color,
            ),
          ),
        );
      },
    );
  }
}

class _CheckPainter extends CustomPainter {
  final double progress;
  final Color color;
  _CheckPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width / 2;
    canvas.drawCircle(
      center,
      radius,
      Paint()..color = color.withValues(alpha: 0.14),
    );
    canvas.drawCircle(
      center,
      radius - 2,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );
    final path = Path()
      ..moveTo(size.width * 0.30, size.height * 0.52)
      ..lineTo(size.width * 0.45, size.height * 0.66)
      ..lineTo(size.width * 0.72, size.height * 0.36);
    final metrics = path.computeMetrics().toList();
    final total = metrics.fold<double>(0, (sum, m) => sum + m.length);
    var remaining = total * progress;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..strokeWidth = size.width * 0.075;
    for (final metric in metrics) {
      if (remaining <= 0) break;
      final length = remaining.clamp(0, metric.length).toDouble();
      canvas.drawPath(metric.extractPath(0, length), paint);
      remaining -= length;
    }
  }

  @override
  bool shouldRepaint(_CheckPainter old) =>
      old.progress != progress || old.color != color;
}

/// Croix qui tremble : le retour d'échec.
class AnimatedCross extends StatefulWidget {
  final double size;
  const AnimatedCross({super.key, this.size = 72});

  @override
  State<AnimatedCross> createState() => _AnimatedCrossState();
}

class _AnimatedCrossState extends State<AnimatedCross>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 600),
  )..forward();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        // Secousse latérale amortie, après l'apparition.
        final shake =
            t < 0.4 ? 0.0 : (1 - t) * 8 * ((t * 40).floor().isEven ? 1 : -1);
        return Transform.translate(
          offset: Offset(shake, 0),
          child: Opacity(
            opacity: Curves.easeOut.transform((t * 2).clamp(0.0, 1.0)),
            child: child,
          ),
        );
      },
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: AppColors.danger.withValues(alpha: 0.12),
          border: Border.all(color: AppColors.danger, width: 3),
        ),
        child: Icon(Icons.close_rounded,
            color: AppColors.danger, size: widget.size * 0.55),
      ),
    );
  }
}

/// Bandeau de retour éphémère, en haut à droite, qui glisse depuis le bord.
///
/// Remplace les `SnackBar` bruts : sur une fenêtre de bureau large, la barre
/// en bas à gauche passait inaperçue, et elle ne distinguait pas visuellement
/// un succès d'un échec.
void showFeedback(
  BuildContext context, {
  required String message,
  bool success = true,
  String? detail,
  Duration duration = const Duration(seconds: 3),
}) {
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return;
  late OverlayEntry entry;
  entry = OverlayEntry(
    builder: (_) => _FeedbackToast(
      message: message,
      detail: detail,
      success: success,
      duration: duration,
      onDone: () => entry.remove(),
    ),
  );
  overlay.insert(entry);
}

class _FeedbackToast extends StatefulWidget {
  final String message;
  final String? detail;
  final bool success;
  final Duration duration;
  final VoidCallback onDone;

  const _FeedbackToast({
    required this.message,
    required this.detail,
    required this.success,
    required this.duration,
    required this.onDone,
  });

  @override
  State<_FeedbackToast> createState() => _FeedbackToastState();
}

class _FeedbackToastState extends State<_FeedbackToast>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );

  @override
  void initState() {
    super.initState();
    _controller.forward();
    Future<void>.delayed(widget.duration, () async {
      if (!mounted) return;
      await _controller.reverse();
      if (mounted) widget.onDone();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.success ? AppColors.teal : AppColors.danger;
    final curve =
        CurvedAnimation(parent: _controller, curve: Curves.easeOutBack);
    return Positioned(
      top: 24,
      right: 24,
      child: SafeArea(
        child: SlideTransition(
          position: Tween<Offset>(begin: const Offset(1.2, 0), end: Offset.zero)
              .animate(curve),
          child: FadeTransition(
            opacity: _controller,
            child: Material(
              color: Colors.transparent,
              child: Container(
                constraints: const BoxConstraints(maxWidth: 380),
                padding: const EdgeInsets.fromLTRB(14, 12, 18, 12),
                decoration: BoxDecoration(
                  color: AppColors.cardWhite,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: color.withValues(alpha: 0.35)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (widget.success)
                      const AnimatedCheck(size: 30)
                    else
                      const AnimatedCross(size: 30),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.message,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          if (widget.detail != null &&
                              widget.detail!.isNotEmpty) ...[
                            const SizedBox(height: 2),
                            Text(
                              widget.detail!,
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontSize: 12, color: AppColors.textSecondary),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Écran plein de résultat (succès ou échec) : gros pictogramme animé, titre,
/// explication, action. Utilisé après une inscription, une visioconférence
/// terminée, un serveur introuvable…
class ResultView extends StatelessWidget {
  final bool success;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;

  const ResultView({
    super.key,
    required this.success,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
    this.secondaryLabel,
    this.onSecondary,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CascadeIn(
                  index: 0,
                  child: success
                      ? const AnimatedCheck(size: 88)
                      : const AnimatedCross(size: 88)),
              const SizedBox(height: 24),
              CascadeIn(
                index: 2,
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.h1.copyWith(fontSize: 22),
                ),
              ),
              const SizedBox(height: 10),
              CascadeIn(
                index: 3,
                child: Text(message,
                    textAlign: TextAlign.center, style: AppTextStyles.body),
              ),
              if (actionLabel != null || secondaryLabel != null) ...[
                const SizedBox(height: 26),
                CascadeIn(
                  index: 4,
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 10,
                    alignment: WrapAlignment.center,
                    children: [
                      if (secondaryLabel != null)
                        AppButton.secondary(
                            label: secondaryLabel!, onPressed: onSecondary),
                      if (actionLabel != null)
                        AppButton(label: actionLabel!, onPressed: onAction),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Transition de page commune : fondu + léger glissement, la même partout.
Widget pageTransition(Widget child, Animation<double> animation) {
  final curve = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
  return FadeTransition(
    opacity: curve,
    child: SlideTransition(
      position: Tween<Offset>(begin: const Offset(0, 0.02), end: Offset.zero)
          .animate(curve),
      child: child,
    ),
  );
}

/// Route à transition douce pour les écrans poussés (fiches, salle de visio).
PageRoute<T> softRoute<T>(Widget page) => PageRouteBuilder<T>(
      transitionDuration: kMotionMedium,
      reverseTransitionDuration: kMotionMedium,
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) =>
          pageTransition(child, animation),
    );
