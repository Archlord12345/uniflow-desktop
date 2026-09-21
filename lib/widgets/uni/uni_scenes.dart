import 'dart:async';

import 'package:flutter/material.dart';

import 'uni_mascot.dart';

/// Scènes prêtes à l'emploi autour d'Uni : chargement, erreur, vide, et la
/// tête qui passe par le bord de l'écran. Ce sont les mêmes que sur le web
/// (`UniScenes.tsx`) pour que le personnage se comporte pareil partout.

/// Chargement long : Uni réfléchit, trois points rebondissent.
class UniLoading extends StatelessWidget {
  final String? label;
  final double size;

  const UniLoading({super.key, this.label, this.size = 120});

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: const Color(0xFF6B7280),
          fontWeight: FontWeight.w600,
        );
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            UniMascot(pose: UniPose.thinking, size: size),
            const SizedBox(height: 14),
            const UniDots(),
            if (label != null) ...[
              const SizedBox(height: 10),
              Text(label!, textAlign: TextAlign.center, style: style),
            ],
          ],
        ),
      ),
    );
  }
}

/// Erreur, contenu introuvable ou liste vide : Uni s'excuse, cherche ou dort.
///
/// `pose` par défaut : `sorry` pour une erreur, `search` quand rien n'a été
/// trouvé, `sleeping` quand on est hors ligne.
class UniOops extends StatelessWidget {
  final String title;
  final String? message;
  final UniPose pose;
  final Widget? action;
  final Widget? secondaryAction;
  final double size;

  const UniOops({
    super.key,
    required this.title,
    this.message,
    this.pose = UniPose.sorry,
    this.action,
    this.secondaryAction,
    this.size = 140,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.maxHeight.isFinite ? constraints.maxHeight : 0,
          ),
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  UniMascot(pose: pose, size: size),
                  const SizedBox(height: 16),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: const Color(0xFF111827),
                    ),
                  ),
                  if (message != null) ...[
                    const SizedBox(height: 6),
                    Text(
                      message!,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: const Color(0xFF6B7280),
                        height: 1.4,
                      ),
                    ),
                  ],
                  if (action != null || secondaryAction != null) ...[
                    const SizedBox(height: 18),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      alignment: WrapAlignment.center,
                      children: [
                        if (action != null) action!,
                        if (secondaryAction != null) secondaryAction!,
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Écran plein pour une erreur non rattrapée (`ErrorWidget.builder`) : Uni
/// s'excuse au lieu du rectangle rouge de Flutter. Ne dépend d'aucun thème
/// ni provider : il doit s'afficher même quand l'arbre est cassé.
class UniCrashScreen extends StatelessWidget {
  final String? details;
  final VoidCallback? onRetry;

  const UniCrashScreen({super.key, this.details, this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xFFF3F4F6),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: SafeArea(
          child: UniOops(
            title: 'Oups, quelque chose s’est mal passé',
            message: 'Uni est désolé. Cette partie de l’écran n’a pas pu s’afficher. '
                'Vous pouvez revenir en arrière ou réessayer.',
            action: onRetry == null
                ? null
                : FilledButton.icon(
                    onPressed: onRetry,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Réessayer'),
                  ),
            secondaryAction: details == null
                ? null
                : Text(
                    details!,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 11, color: Color(0xFF9CA3AF)),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Bord par lequel Uni passe la tête.
enum UniPeekEdge { right, bottom }

/// Uni passe la tête par le bord de l'écran avec un mot, une fois par
/// `id` et par lancement de l'application, puis se retire tout seul.
///
/// À poser dans un `Stack` au-dessus du contenu (voir `AppShell`).
class UniPeek extends StatefulWidget {
  /// Identifiant de l'apparition : la même clé n'est jouée qu'une fois par
  /// session de l'application.
  final String id;
  final String message;
  final UniPeekEdge edge;
  final Duration delay;
  final Duration visibleFor;
  final VoidCallback? onTap;

  const UniPeek({
    super.key,
    required this.id,
    required this.message,
    this.edge = UniPeekEdge.right,
    this.delay = const Duration(milliseconds: 1800),
    this.visibleFor = const Duration(seconds: 7),
    this.onTap,
  });

  /// Apparitions déjà jouées depuis le lancement.
  static final Set<String> shown = <String>{};

  @override
  State<UniPeek> createState() => _UniPeekState();
}

class _UniPeekState extends State<UniPeek> {
  bool _visible = false;
  Timer? _in;
  Timer? _out;

  @override
  void initState() {
    super.initState();
    if (UniPeek.shown.contains(widget.id)) return;
    _in = Timer(widget.delay, () {
      if (!mounted) return;
      UniPeek.shown.add(widget.id);
      setState(() => _visible = true);
      _out = Timer(widget.visibleFor, _dismiss);
    });
  }

  void _dismiss() {
    if (!mounted) return;
    setState(() => _visible = false);
  }

  @override
  void dispose() {
    _in?.cancel();
    _out?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final pose = widget.edge == UniPeekEdge.right ? UniPose.peekRight : UniPose.peekBottom;
    final hidden = widget.edge == UniPeekEdge.right ? const Offset(1.2, 0) : const Offset(0, 1.2);

    final body = GestureDetector(
      onTap: () {
        _dismiss();
        widget.onTap?.call();
      },
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: widget.edge == UniPeekEdge.right
            // La bulle est souple : dans une fenêtre étroite (420 px avec la
            // barre latérale), une largeur fixe débordait de 55 px à droite.
            ? Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(child: UniBubble(side: UniBubbleSide.left, child: Text(widget.message))),
                  const SizedBox(width: 4),
                  UniMascot(pose: pose, size: 96, effects: false),
                ],
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  UniBubble(side: UniBubbleSide.top, child: Text(widget.message)),
                  UniMascot(pose: pose, size: 90, effects: false),
                ],
              ),
      ),
    );

    return IgnorePointer(
      ignoring: !_visible,
      child: AnimatedSlide(
        offset: _visible ? Offset.zero : hidden,
        duration: reduce ? Duration.zero : const Duration(milliseconds: 520),
        curve: Curves.easeOutBack,
        child: AnimatedOpacity(
          opacity: _visible ? 1 : 0,
          duration: const Duration(milliseconds: 250),
          child: Align(
            alignment: widget.edge == UniPeekEdge.right ? Alignment.bottomRight : Alignment.bottomCenter,
            child: body,
          ),
        ),
      ),
    );
  }
}
