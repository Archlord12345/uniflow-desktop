import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../uni_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/auth_provider.dart';
import '../../services/uniflow_api.dart';
import 'uni_mascot.dart';

/// Uni, l'assistant conversationnel d'UniFlow, côté desktop : un bouton
/// flottant en bas à droite et un panneau ancré, comme sur le web.
///
/// Le modèle (Gemini 3.1 Flash-Lite, repli Mistral) n'est jamais appelé
/// depuis l'application : tout passe par le service `/assistant` de la
/// Function `uniflow-api`, qui porte les clés et connaît le profil du compte.

class UniTurn {
  final String role; // 'user' | 'assistant'
  final String content;
  final bool failed;
  final DateTime at;

  UniTurn(
      {required this.role,
      required this.content,
      this.failed = false,
      DateTime? at})
      : at = at ?? DateTime.now();

  bool get isUser => role == 'user';

  UniTurn copyWith({bool? failed}) => UniTurn(
      role: role, content: content, failed: failed ?? this.failed, at: at);
}

class UniAssistantState {
  final List<UniTurn> turns;
  final List<String> suggestions;
  final bool pending;
  final bool greeted;
  final String? error;
  final String? provider;

  const UniAssistantState({
    this.turns = const [],
    this.suggestions = const [],
    this.pending = false,
    this.greeted = false,
    this.error,
    this.provider,
  });

  UniAssistantState copyWith({
    List<UniTurn>? turns,
    List<String>? suggestions,
    bool? pending,
    bool? greeted,
    String? error,
    bool clearError = false,
    String? provider,
  }) =>
      UniAssistantState(
        turns: turns ?? this.turns,
        suggestions: suggestions ?? this.suggestions,
        pending: pending ?? this.pending,
        greeted: greeted ?? this.greeted,
        error: clearError ? null : (error ?? this.error),
        provider: provider ?? this.provider,
      );
}

const _defaultGreeting =
    'Bonjour ! Je suis Uni, l’assistant UniFlow. Je connais ton emploi du temps, '
    'tes UE et les écrans de l’application : pose-moi ta question.';

const _defaultSuggestions = [
  'Quels cours ai-je aujourd’hui ?',
  'Comment lancer une visioconférence ?',
  'Que fait UniFlow ?',
];

const _maxHistory = 16;

class UniAssistantController extends StateNotifier<UniAssistantState> {
  final Ref _ref;

  UniAssistantController(this._ref) : super(const UniAssistantState());

  Future<Map<String, dynamic>> _call(Map<String, dynamic> payload) {
    return _ref.read(uniflowApiProvider).call('/assistant', {
      ...payload,
      'platform': 'desktop',
    });
  }

  Future<void> greet() async {
    if (state.greeted || state.pending) return;
    state = state.copyWith(greeted: true, suggestions: _defaultSuggestions);
    if (state.turns.isNotEmpty) return;
    var greeting = _defaultGreeting;
    var suggestions = _defaultSuggestions;
    try {
      final data = await _call({'action': 'hello'});
      if (data['ok'] == true) {
        final g = (data['greeting'] as String?)?.trim();
        if (g != null && g.isNotEmpty) greeting = g;
        final raw = data['suggestions'];
        if (raw is List && raw.isNotEmpty) {
          suggestions = raw.whereType<String>().toList();
        }
      }
    } catch (_) {}
    if (state.turns.isNotEmpty) return;
    state = state.copyWith(
      turns: [UniTurn(role: 'assistant', content: greeting)],
      suggestions: suggestions,
    );
  }

  Future<void> send(String text) async {
    final content = text.trim();
    if (content.isEmpty || state.pending) return;
    final mine = UniTurn(role: 'user', content: content);
    state = state.copyWith(
      turns: [...state.turns, mine],
      pending: true,
      clearError: true,
      suggestions: const [],
    );
    try {
      final recent = state.turns.where((t) => !t.failed).toList();
      final history = recent
          .sublist(math.max(0, recent.length - _maxHistory))
          .map((t) => {'role': t.role, 'content': t.content})
          .toList();
      final data = await _call({'action': 'chat', 'messages': history});
      if (data['ok'] != true) {
        throw StateError(
            (data['message'] as String?) ?? 'Uni n’a pas pu répondre.');
      }
      final reply = (data['reply'] as String?)?.trim();
      final raw = data['suggestions'];
      state = state.copyWith(
        turns: [
          ...state.turns,
          UniTurn(
            role: 'assistant',
            content: reply != null && reply.isNotEmpty
                ? reply
                : 'Je n’ai pas de réponse, réessaie autrement.',
          ),
        ],
        pending: false,
        provider: data['provider'] as String?,
        suggestions: raw is List ? raw.whereType<String>().toList() : const [],
      );
    } catch (e) {
      final turns = [...state.turns];
      final idx = turns.lastIndexWhere((t) => t == mine);
      if (idx >= 0) turns[idx] = mine.copyWith(failed: true);
      state =
          state.copyWith(turns: turns, pending: false, error: _humanError(e));
    }
  }

  Future<void> retry() async {
    final failed = state.turns.where((t) => t.failed).toList();
    if (failed.isEmpty) return;
    final last = failed.last;
    state = state.copyWith(
        turns: state.turns.where((t) => t != last).toList(), clearError: true);
    await send(last.content);
  }

  void clear() => state = const UniAssistantState();

  static String _humanError(Object e) {
    if (e is ApiException) return e.message;
    final text = e
        .toString()
        .replaceFirst('Bad state: ', '')
        .replaceFirst('Exception: ', '');
    if (text.contains('SocketException') ||
        text.contains('Failed host lookup') ||
        text.contains('Connection')) {
      return 'Pas de réseau : Uni a besoin d’une connexion pour répondre.';
    }
    return text.length > 180 ? '${text.substring(0, 180)}…' : text;
  }
}

final uniAssistantProvider =
    StateNotifierProvider<UniAssistantController, UniAssistantState>((ref) {
  // La conversation appartient au compte : changer d'utilisateur la vide.
  ref.watch(currentUserProvider.select((u) => u?.id));
  return UniAssistantController(ref);
});

/// Panneau ouvert ou non (état d'interface, indépendant de la conversation).
final uniPanelOpenProvider = StateProvider<bool>((ref) => false);

/// Bouton flottant + panneau ancré : à poser au-dessus du corps du shell.
class UniAssistantDock extends ConsumerWidget {
  const UniAssistantDock({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final open = ref.watch(uniPanelOpenProvider);
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final size = MediaQuery.sizeOf(context);
    final panelHeight = math.min(640.0, size.height - 96);
    final panelWidth = math.min(420.0, size.width - 32);

    return Stack(
      children: [
        Positioned(
          right: 20,
          bottom: 92,
          child: IgnorePointer(
            ignoring: !open,
            child: AnimatedScale(
              scale: open ? 1 : 0.92,
              alignment: Alignment.bottomRight,
              duration:
                  reduce ? Duration.zero : const Duration(milliseconds: 220),
              curve: Curves.easeOutBack,
              child: AnimatedOpacity(
                opacity: open ? 1 : 0,
                duration:
                    reduce ? Duration.zero : const Duration(milliseconds: 180),
                child: SizedBox(
                  width: panelWidth,
                  height: panelHeight,
                  child: open
                      ? const UniAssistantPanel()
                      : const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          right: 20,
          bottom: 20,
          child: UniLauncher(
            open: open,
            onToggle: () =>
                ref.read(uniPanelOpenProvider.notifier).state = !open,
          ),
        ),
      ],
    );
  }
}

/// Le bouton d'Uni : l'avatar dans une pastille qui « fait signe »
/// périodiquement (comme le hibou de Duolingo) tant que le panneau est fermé.
class UniLauncher extends StatefulWidget {
  final bool open;
  final VoidCallback onToggle;

  const UniLauncher({super.key, required this.open, required this.onToggle});

  @override
  State<UniLauncher> createState() => _UniLauncherState();
}

class _UniLauncherState extends State<UniLauncher>
    with SingleTickerProviderStateMixin {
  late final AnimationController _nudge = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900));
  Timer? _timer;
  bool _hover = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(seconds: 6), _tick);
  }

  void _tick() {
    if (!mounted) return;
    final reduce = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    if (!reduce && !widget.open) _nudge.forward(from: 0);
    _timer = Timer(const Duration(seconds: 18), _tick);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _nudge.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: widget.open ? 'Fermer Uni' : 'Ouvrir Uni, l’assistant UniFlow',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: Semantics(
          button: true,
          label: widget.open ? 'Fermer Uni' : 'Ouvrir Uni, l’assistant UniFlow',
          child: AnimatedBuilder(
            animation: _nudge,
            builder: (context, child) {
              final t = _nudge.value;
              final wiggle = math.sin(t * math.pi * 4) * (1 - t) * 0.18;
              final lift = -math.sin(t * math.pi) * 8;
              return Transform.translate(
                offset: Offset(0, lift),
                child: Transform.rotate(angle: wiggle, child: child),
              );
            },
            child: GestureDetector(
              onTap: widget.onToggle,
              child: AnimatedScale(
                scale: _hover ? 1.06 : 1,
                duration: const Duration(milliseconds: 160),
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Container(
                      width: 60,
                      height: 60,
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                            color: const Color(0xFFDCE5FD), width: 2),
                        boxShadow: const [
                          BoxShadow(
                              color: Color(0x331E3A8A),
                              blurRadius: 18,
                              offset: Offset(0, 8)),
                        ],
                      ),
                      child: ClipOval(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 200),
                          child: widget.open
                              ? Center(
                                  key: const ValueKey('close'),
                                  child: PhosphorIcon(
                                      UniIcons.close(UniIconStyle.bold),
                                      color: const Color(0xFF1E3A8A),
                                      size: 26),
                                )
                              : Image.asset(
                                  'assets/assistant/uni_avatar.webp',
                                  key: const ValueKey('avatar'),
                                  fit: BoxFit.cover,
                                  filterQuality: FilterQuality.high,
                                  errorBuilder: (_, __, ___) => PhosphorIcon(
                                      UniIcons.robot(UniIconStyle.fill),
                                      color: const Color(0xFF1E3A8A)),
                                ),
                        ),
                      ),
                    ),
                    if (!widget.open)
                      Positioned(
                        bottom: -4,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 7, vertical: 1.5),
                            decoration: BoxDecoration(
                              color: const Color(0xFF1E3A8A),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: const Text(
                              'UNI',
                              style: TextStyle(
                                  color: Colors.white,
                                  fontSize: 9,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.6),
                            ),
                          ),
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

class UniAssistantPanel extends ConsumerStatefulWidget {
  const UniAssistantPanel({super.key});

  @override
  ConsumerState<UniAssistantPanel> createState() => _UniAssistantPanelState();
}

class _UniAssistantPanelState extends ConsumerState<UniAssistantPanel> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(uniAssistantProvider.notifier).greet();
      _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _send([String? text]) async {
    final content = (text ?? _input.text).trim();
    if (content.isEmpty) return;
    _input.clear();
    _scrollToEnd();
    await ref.read(uniAssistantProvider.notifier).send(content);
    _scrollToEnd();
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(uniAssistantProvider);
    final user = ref.watch(currentUserProvider);
    ref.listen(uniAssistantProvider.select((s) => s.turns.length),
        (_, __) => _scrollToEnd());

    final pose = state.error != null
        ? UniPose.sorry
        : state.pending
            ? UniPose.thinking
            : state.turns.length <= 1
                ? UniPose.wave
                : UniPose.headset;

    return Material(
      color: const Color(0xFFF3F4F6),
      elevation: 0,
      borderRadius: BorderRadius.circular(22),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: const Color(0xFFE5E7EB)),
          borderRadius: BorderRadius.circular(22),
          boxShadow: const [
            BoxShadow(
                color: Color(0x2E111827), blurRadius: 40, offset: Offset(0, 20))
          ],
        ),
        child: Column(
          children: [
            _Header(
              pose: pose,
              subtitle: state.pending
                  ? 'Réfléchit…'
                  : state.error != null
                      ? 'Quelque chose a coincé'
                      : 'En ligne · ${state.provider == 'mistral' ? 'Mistral' : 'Gemini 3.1 Flash-Lite'}',
              onClear: state.turns.length > 1
                  ? () {
                      ref.read(uniAssistantProvider.notifier).clear();
                      ref.read(uniAssistantProvider.notifier).greet();
                    }
                  : null,
              onClose: () =>
                  ref.read(uniPanelOpenProvider.notifier).state = false,
            ),
            Expanded(
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 8),
                children: [
                  for (final turn in state.turns)
                    _Bubble(
                      turn: turn,
                      initials: _initials(user?.name),
                      onRetry: turn.failed
                          ? () =>
                              ref.read(uniAssistantProvider.notifier).retry()
                          : null,
                    ),
                  if (state.pending) const _Typing(),
                  if (state.error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(
                        children: [
                          const UniMascot(
                              pose: UniPose.sorry, size: 54, effects: false),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              state.error!,
                              style: const TextStyle(
                                  fontSize: 12.5,
                                  color: Color(0xFFB91C1C),
                                  fontWeight: FontWeight.w600),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            if (!state.pending && state.suggestions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final s in state.suggestions)
                      ActionChip(
                        label: Text(s,
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w600)),
                        backgroundColor: Colors.white,
                        side: const BorderSide(color: Color(0xFFDCE5FD)),
                        shape: const StadiumBorder(),
                        onPressed: () => _send(s),
                      ),
                  ],
                ),
              ),
            _Composer(
                controller: _input,
                focus: _focus,
                enabled: !state.pending,
                onSend: _send),
          ],
        ),
      ),
    );
  }

  static String _initials(String? name) {
    if (name == null || name.trim().isEmpty) return 'U';
    final parts = name.trim().split(RegExp(r'\s+'));
    return parts.take(2).map((p) => p[0].toUpperCase()).join();
  }
}

class _Header extends StatelessWidget {
  final UniPose pose;
  final String subtitle;
  final VoidCallback? onClear;
  final VoidCallback onClose;

  const _Header(
      {required this.pose,
      required this.subtitle,
      required this.onClear,
      required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF1E3A8A), Color(0xFF0D9488)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child:
                Center(child: UniMascot(pose: pose, size: 58, effects: false)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Uni · Assistant UniFlow',
                  style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 14.5),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: const BoxDecoration(
                          color: Color(0xFF34D399), shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (onClear != null)
            IconButton(
              tooltip: 'Effacer la conversation',
              onPressed: onClear,
              icon: PhosphorIcon(UniIcons.delete(UniIconStyle.bold),
                  color: Colors.white, size: 20),
            ),
          IconButton(
            tooltip: 'Fermer',
            onPressed: onClose,
            icon: PhosphorIcon(UniIcons.close(UniIconStyle.bold),
                color: Colors.white, size: 20),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final UniTurn turn;
  final String initials;
  final VoidCallback? onRetry;

  const _Bubble({required this.turn, required this.initials, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final mine = turn.isUser;
    final bubble = Container(
      constraints: const BoxConstraints(maxWidth: 300),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: mine ? const Color(0xFF1E3A8A) : Colors.white,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(mine ? 18 : 6),
          bottomRight: Radius.circular(mine ? 6 : 18),
        ),
        border: mine ? null : Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: mine
            ? null
            : const [
                BoxShadow(
                    color: Color(0x0F111827),
                    blurRadius: 10,
                    offset: Offset(0, 4))
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SelectionArea(
            child: UniMarkdownLite(
              turn.content,
              baseStyle: TextStyle(
                  fontSize: 13.5,
                  height: 1.45,
                  color: mine ? Colors.white : const Color(0xFF1F2937)),
            ),
          ),
          if (turn.failed && onRetry != null)
            TextButton.icon(
              onPressed: onRetry,
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                foregroundColor: const Color(0xFFFECACA),
              ),
              icon: PhosphorIcon(UniIcons.refresh(UniIconStyle.bold), size: 14),
              label: const Text('Non envoyé · réessayer',
                  style:
                      TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutCubic,
      builder: (context, v, child) => Opacity(
        opacity: v,
        child:
            Transform.translate(offset: Offset(0, (1 - v) * 10), child: child),
      ),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Row(
          mainAxisAlignment:
              mine ? MainAxisAlignment.end : MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (!mine) ...[const _UniAvatar(), const SizedBox(width: 8)],
            Flexible(child: bubble),
            if (mine) ...[
              const SizedBox(width: 8),
              Container(
                width: 28,
                height: 28,
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                    color: Color(0xFFDCE5FD), shape: BoxShape.circle),
                child: Text(initials,
                    style: const TextStyle(
                        fontSize: 10.5,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF1E3A8A))),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _UniAvatar extends StatelessWidget {
  const _UniAvatar();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFDCE5FD)),
      ),
      child: ClipOval(
        child: Image.asset(
          'assets/assistant/uni_avatar.webp',
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => PhosphorIcon(
              UniIcons.robot(UniIconStyle.fill),
              size: 16,
              color: const Color(0xFF1E3A8A)),
        ),
      ),
    );
  }
}

class _Typing extends StatelessWidget {
  const _Typing();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          const _UniAvatar(),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: const UniDots(size: 6),
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focus;
  final bool enabled;
  final Future<void> Function([String?]) onSend;

  const _Composer(
      {required this.controller,
      required this.focus,
      required this.enabled,
      required this.onSend});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 8, 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Color(0xFFE5E7EB))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              focusNode: focus,
              enabled: enabled,
              minLines: 1,
              maxLines: 4,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => onSend(),
              style: const TextStyle(fontSize: 13.5),
              decoration: InputDecoration(
                hintText: 'Écrire à Uni… (Entrée pour envoyer)',
                isDense: true,
                filled: true,
                fillColor: const Color(0xFFF9FAFB),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              final canSend = enabled && value.text.trim().isNotEmpty;
              return IconButton.filled(
                tooltip: 'Envoyer',
                onPressed: canSend ? () => onSend() : null,
                style: IconButton.styleFrom(
                  backgroundColor: const Color(0xFF1E3A8A),
                  disabledBackgroundColor: const Color(0xFFDCE5FD),
                  foregroundColor: Colors.white,
                ),
                icon: PhosphorIcon(UniIcons.send(UniIconStyle.fill), size: 20),
              );
            },
          ),
        ],
      ),
    );
  }
}

/// Rendu minimal du Markdown que le modèle emploie spontanément : paragraphes,
/// listes à puces (`* ` / `- `), gras `**x**`. Rien d'autre — le texte reste
/// du texte, jamais interprété.
class UniMarkdownLite extends StatelessWidget {
  final String text;
  final TextStyle baseStyle;

  const UniMarkdownLite(this.text, {super.key, required this.baseStyle});

  @override
  Widget build(BuildContext context) {
    final blocks = <Widget>[];
    final lines = text.replaceAll('\r', '').split('\n');
    final paragraph = <String>[];
    final bullets = <String>[];

    void flushParagraph() {
      if (paragraph.isEmpty) return;
      blocks.add(_richLine(paragraph.join(' ')));
      paragraph.clear();
    }

    void flushBullets() {
      if (bullets.isEmpty) return;
      blocks.add(Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final item in bullets)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('•  ',
                      style: baseStyle.copyWith(fontWeight: FontWeight.w800)),
                  Expanded(child: _richLine(item)),
                ],
              ),
            ),
        ],
      ));
      bullets.clear();
    }

    for (final raw in lines) {
      final line = raw.trim();
      if (line.isEmpty) {
        flushParagraph();
        flushBullets();
        continue;
      }
      final bullet = RegExp(r'^([*\-•]|\d+[.)])\s+(.*)$').firstMatch(line);
      if (bullet != null) {
        flushParagraph();
        bullets.add(bullet.group(2)!);
      } else {
        flushBullets();
        paragraph.add(line);
      }
    }
    flushParagraph();
    flushBullets();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < blocks.length; i++) ...[
          if (i > 0) const SizedBox(height: 6),
          blocks[i],
        ],
      ],
    );
  }

  Widget _richLine(String line) {
    final spans = <InlineSpan>[];
    final pattern = RegExp(r'\*\*(.+?)\*\*');
    var index = 0;
    for (final match in pattern.allMatches(line)) {
      if (match.start > index) {
        spans.add(TextSpan(text: line.substring(index, match.start)));
      }
      spans.add(TextSpan(
          text: match.group(1),
          style: const TextStyle(fontWeight: FontWeight.w800)));
      index = match.end;
    }
    if (index < line.length) spans.add(TextSpan(text: line.substring(index)));
    return Text.rich(TextSpan(style: baseStyle, children: spans));
  }
}
