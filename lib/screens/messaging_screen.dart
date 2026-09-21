import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/messaging_repository.dart';
import '../theme/app_theme.dart';
import '../ui/app_button.dart';
import '../utils/avatar.dart';
import '../widgets/app_top_bar.dart';
import '../widgets/data_state_view.dart';
import '../widgets/uni_icons.dart';
import '../widgets/user_avatar.dart';

/// Messagerie du desktop : liste des conversations à gauche, fil de discussion
/// à droite. Adressée par pseudo, comme sur le web et le mobile.
class MessagingScreen extends ConsumerStatefulWidget {
  /// Recherche pré-remplie à l'ouverture. Les fiches étudiant et enseignant
  /// s'en servent pour arriver directement sur un brouillon adressé à la
  /// personne consultée, plutôt que sur une liste vide.
  final String? initialQuery;

  const MessagingScreen({super.key, this.initialQuery});

  @override
  ConsumerState<MessagingScreen> createState() => _MessagingScreenState();
}

class _MessagingScreenState extends ConsumerState<MessagingScreen> {
  final TextEditingController _composer = TextEditingController();
  final ScrollController _scroll = ScrollController();

  String? _selectedId;

  /// Conversation renvoyée par `open` ou `send`, utilisée le temps que la liste
  /// se recharge : sans elle, l'écran clignoterait vers un état vide juste
  /// après l'envoi d'un message.
  Conversation? _pending;

  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final query = widget.initialQuery;
    if (query != null && query.trim().isNotEmpty) {
      // Après la première frame : `showDialog` a besoin d'un contexte monté.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _startConversation(initialQuery: query);
      });
    }
  }

  @override
  void dispose() {
    _composer.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send(Conversation conversation) async {
    final text = _composer.text.trim();
    if (text.isEmpty || _sending) return;

    setState(() => _sending = true);
    try {
      final updated = await ref
          .read(messagingRepositoryProvider)
          .sendMessage(conversation.id, text);
      if (!mounted) return;
      setState(() {
        _pending = updated;
        _selectedId = updated.id;
        _error = null;
      });
      _composer.clear();
      ref.invalidate(conversationsProvider);
      _scrollToEnd();
    } catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _openConversation(Conversation conversation) async {
    setState(() {
      _selectedId = conversation.id;
      _pending = conversation;
      _error = null;
    });
    if (conversation.unread > 0) {
      try {
        await ref.read(messagingRepositoryProvider).markRead(conversation.id);
        ref.invalidate(conversationsProvider);
      } catch (_) {
        // Le compteur de non-lus n'est pas essentiel : un échec ici ne doit pas
        // empêcher la lecture du fil.
      }
    }
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _startConversation({String? initialQuery}) async {
    final contact = await showDialog<ChatContact>(
      context: context,
      builder: (_) => _NewConversationDialog(initialQuery: initialQuery),
    );
    if (contact == null || !mounted) return;

    try {
      final conversation = await ref
          .read(messagingRepositoryProvider)
          .openByUsername(
              contact.username.isNotEmpty ? contact.username : contact.email);
      if (!mounted) return;
      setState(() {
        _selectedId = conversation.id;
        _pending = conversation;
        _error = null;
      });
      ref.invalidate(conversationsProvider);
      _scrollToEnd();
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = error.toString());
    }
  }

  @override
  Widget build(BuildContext context) {
    final conversationsAsync = ref.watch(conversationsProvider);
    final conversations =
        conversationsAsync.valueOrNull ?? const <Conversation>[];

    // La version de la liste fait foi dès qu'elle est disponible ; `_pending`
    // ne sert que pendant le rechargement qui suit un envoi ou une ouverture.
    final match = conversations
        .where((item) => item.id == _selectedId)
        .cast<Conversation?>()
        .firstOrNull;
    final current = match ?? _pending;

    // Même squelette que les autres pages internes : l'en-tête blanc court
    // d'un bord à l'autre et le contenu est en retrait de 28 px. Cet écran
    // posait l'en-tête à l'intérieur d'une marge de 30 px : il apparaissait
    // comme une carte flottante, décalée par rapport aux écrans voisins.
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTopBar(
              title: 'Communications',
              subtitle:
                  'Messagerie adressée par pseudo — recherchez un contact pour démarrer un échange',
              actions: [
                AppButton.secondary(
                  label: 'Rafraîchir',
                  icon: UniIcons.refresh(UniIconStyle.bold),
                  onPressed: () => ref.invalidate(conversationsProvider),
                ),
                AppButton(
                  label: 'Nouvelle conversation',
                  icon: UniIcons.add(UniIconStyle.bold),
                  onPressed: () => _startConversation(),
                ),
              ],
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.page),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (_error != null) ...[
                      _ErrorBanner(
                        message: _error!,
                        onDismiss: () => setState(() => _error = null),
                      ),
                      const SizedBox(height: 14),
                    ],
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          SizedBox(
                            width: 340,
                            child: _ConversationList(
                              state: conversationsAsync,
                              conversations: conversations,
                              selectedId: current?.id,
                              onSelect: _openConversation,
                              onRetry: () =>
                                  ref.invalidate(conversationsProvider),
                            ),
                          ),
                          const SizedBox(width: 18),
                          Expanded(
                            child: _Thread(
                              conversation: current,
                              composer: _composer,
                              scroll: _scroll,
                              sending: _sending,
                              onSend: _send,
                              onStart: () => _startConversation(),
                            ),
                          ),
                        ],
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
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;

  const _ErrorBanner({required this.message, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 10, 8, 10),
      decoration: BoxDecoration(
        color: AppColors.danger.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.danger.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          PhosphorIcon(UniIcons.warningCircle(UniIconStyle.bold),
              size: 18, color: AppColors.danger),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(fontSize: 12.5, color: AppColors.danger),
            ),
          ),
          IconButton(
            onPressed: onDismiss,
            icon: PhosphorIcon(UniIcons.close(UniIconStyle.bold),
                size: 16, color: AppColors.danger),
            tooltip: 'Masquer',
          ),
        ],
      ),
    );
  }
}

class _ConversationList extends StatelessWidget {
  final AsyncValue<List<Conversation>> state;
  final List<Conversation> conversations;
  final String? selectedId;
  final ValueChanged<Conversation> onSelect;
  final VoidCallback onRetry;

  const _ConversationList({
    required this.state,
    required this.conversations,
    required this.selectedId,
    required this.onSelect,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Text('Conversations', style: AppTextStyles.h2),
          ),
          const Divider(height: 1),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  Widget _buildBody() {
    // États compacts : la colonne des conversations fait 340 px de large,
    // les versions pleine taille (Uni de 110 px, marges de 60 px) y prenaient
    // toute la hauteur visible.
    if (state.isLoading && conversations.isEmpty) {
      return const Center(
        child: DataLoadingView(
            label: 'Chargement des conversations…', compact: true),
      );
    }
    if (state.hasError && conversations.isEmpty) {
      return Center(
        child: DataErrorView(
          title: 'Conversations indisponibles',
          error: state.error ?? 'Erreur inconnue',
          compact: true,
          onRetry: onRetry,
        ),
      );
    }
    if (conversations.isEmpty) {
      return const Center(
        child: DataEmptyView(
          compact: true,
          message: 'Aucune conversation. Utilisez « Nouvelle conversation » '
              'pour écrire à un contact par son pseudo.',
        ),
      );
    }

    // Uni se range dans le coin bas gauche sur cet écran (le composeur occupe
    // le coin droit) : la marge basse laisse la dernière conversation visible
    // une fois la liste déroulée, au lieu de la cacher sous son bouton.
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(0, 6, 0, AppSpacing.uniClearance),
      itemCount: conversations.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final conversation = conversations[index];
        final selected = conversation.id == selectedId;
        return InkWell(
          onTap: () => onSelect(conversation),
          child: Container(
            color: selected
                ? AppColors.primaryBlue.withValues(alpha: 0.07)
                : Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                InitialsAvatar(
                  initials: conversation.name.isNotEmpty
                      ? initialsOf(conversation.name)
                      : '?',
                  avatarFileId: conversation.avatarFileId,
                  size: 38,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        conversation.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontWeight: FontWeight.w700, fontSize: 13.5),
                      ),
                      if (conversation.handle.isNotEmpty)
                        Text(
                          conversation.handle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.primaryBlue),
                        ),
                      Text(
                        conversation.lastMessage,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 11.5, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                if (conversation.unread > 0)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '${conversation.unread}',
                      style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.w700),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Thread extends StatelessWidget {
  final Conversation? conversation;
  final TextEditingController composer;
  final ScrollController scroll;
  final bool sending;
  final ValueChanged<Conversation> onSend;
  final VoidCallback onStart;

  const _Thread({
    required this.conversation,
    required this.composer,
    required this.scroll,
    required this.sending,
    required this.onSend,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    final current = conversation;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: current == null
          ? Center(
              child: DataEmptyView(
                compact: true,
                icon: UniIcons.messaging(),
                message: 'Sélectionnez une conversation',
                action: AppButton(
                  label: 'Nouvelle conversation',
                  icon: UniIcons.add(UniIconStyle.bold),
                  height: 40,
                  onPressed: onStart,
                ),
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 14, 18, 14),
                  child: Row(
                    children: [
                      InitialsAvatar(
                        initials: initialsOf(current.name),
                        avatarFileId: current.avatarFileId,
                        size: 40,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(current.name,
                                style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14.5)),
                            if (current.handle.isNotEmpty)
                              Text(
                                current.handle,
                                style: const TextStyle(
                                    fontSize: 11.5,
                                    color: AppColors.primaryBlue),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: current.messages.isEmpty
                      ? const Center(
                          child: DataEmptyView(
                            compact: true,
                            message: 'Aucun message pour l\'instant. '
                                'Écrivez le premier ci-dessous.',
                          ),
                        )
                      : ListView.builder(
                          controller: scroll,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 18, vertical: 16),
                          itemCount: current.messages.length,
                          itemBuilder: (context, index) =>
                              _Bubble(message: current.messages[index]),
                        ),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: TextField(
                          controller: composer,
                          minLines: 1,
                          maxLines: 5,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => onSend(current),
                          decoration: const InputDecoration(
                            hintText: 'Votre message…',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      AppButton(
                        label: 'Envoyer',
                        icon: UniIcons.send(UniIconStyle.bold),
                        loading: sending,
                        onPressed: () => onSend(current),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final ChatMessage message;
  const _Bubble({required this.message});

  @override
  Widget build(BuildContext context) {
    final mine = message.mine;
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 460),
        decoration: BoxDecoration(
          color: mine ? AppColors.primaryBlue : AppColors.inputFill,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(12),
            topRight: const Radius.circular(12),
            bottomLeft: Radius.circular(mine ? 12 : 3),
            bottomRight: Radius.circular(mine ? 3 : 12),
          ),
        ),
        child: Column(
          crossAxisAlignment:
              mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(
              message.text,
              style: TextStyle(
                fontSize: 13,
                color: mine ? Colors.white : AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              formatClock(message.time),
              style: TextStyle(
                fontSize: 10,
                color: mine
                    ? Colors.white.withValues(alpha: 0.75)
                    : AppColors.textMuted,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Sélecteur de contact : recherche par pseudo, nom ou email.
///
/// La recherche interroge l'action `search` de la fonction après une pause de
/// 300 ms, pour ne pas envoyer une requête à chaque caractère saisi.
class _NewConversationDialog extends ConsumerStatefulWidget {
  /// Terme pré-rempli, recherché dès l'ouverture du dialogue.
  final String? initialQuery;

  const _NewConversationDialog({this.initialQuery});

  @override
  ConsumerState<_NewConversationDialog> createState() =>
      _NewConversationDialogState();
}

class _NewConversationDialogState
    extends ConsumerState<_NewConversationDialog> {
  final TextEditingController _input = TextEditingController();
  Timer? _debounce;

  List<ChatContact> _results = const [];
  bool _searching = false;
  String? _error;

  /// Numéro de la recherche en cours : une réponse arrivée après une frappe plus
  /// récente est ignorée, sinon les résultats affichés ne correspondent plus au
  /// texte du champ.
  int _requestId = 0;

  @override
  void initState() {
    super.initState();
    final query = widget.initialQuery;
    if (query != null && query.trim().isNotEmpty) {
      _input.text = query.trim();
      // `_onChanged` s'appuie sur un `setState` : il ne peut pas être appelé
      // pendant `initState`, d'où le report à la première frame.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _onChanged(_input.text);
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _input.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    final term = value.trim().replaceFirst(RegExp(r'^@'), '');
    if (term.length < 2) {
      setState(() {
        _results = const [];
        _searching = false;
        _error = null;
      });
      return;
    }
    setState(() => _searching = true);
    _debounce = Timer(const Duration(milliseconds: 300), () => _search(term));
  }

  Future<void> _search(String term) async {
    final id = ++_requestId;
    try {
      final contacts =
          await ref.read(messagingRepositoryProvider).searchContacts(term);
      if (!mounted || id != _requestId) return;
      setState(() {
        _results = contacts;
        _error = null;
        _searching = false;
      });
    } catch (error) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _results = const [];
        _error = error.toString();
        _searching = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Nouvelle conversation'),
      content: SizedBox(
        width: 420,
        height: 380,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Recherchez un contact par son pseudo.',
              style: TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _input,
              autofocus: true,
              onChanged: _onChanged,
              decoration: InputDecoration(
                hintText: '@pseudo',
                prefixIcon:
                    PhosphorIcon(UniIcons.search(UniIconStyle.bold), size: 18),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(child: _buildResults()),
          ],
        ),
      ),
      actions: [
        AppButton.secondary(
          label: 'Annuler',
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  Widget _buildResults() {
    if (_error != null) {
      return Center(
        child: DataErrorView(
          title: 'Recherche impossible',
          error: _error!,
          compact: true,
          onRetry: () => _onChanged(_input.text),
        ),
      );
    }
    if (_searching) {
      return const Center(
        child: DataLoadingView(label: 'Recherche…', compact: true),
      );
    }
    if (_input.text.trim().replaceFirst(RegExp(r'^@'), '').length < 2) {
      return const Center(
        child: Text(
          'Saisissez au moins deux caractères.',
          style: TextStyle(color: AppColors.textMuted, fontSize: 12),
        ),
      );
    }
    if (_results.isEmpty) {
      return const Center(
        child: DataEmptyView(
            message: 'Aucun contact ne correspond.', compact: true),
      );
    }
    return ListView.separated(
      itemCount: _results.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (context, index) {
        final contact = _results[index];
        return ListTile(
          contentPadding: EdgeInsets.zero,
          leading: InitialsAvatar(
            initials: contact.name.isNotEmpty ? initialsOf(contact.name) : '?',
            avatarFileId: contact.avatarFileId,
            size: 36,
          ),
          title: Text(contact.name,
              style:
                  const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5)),
          subtitle: Text(
            contact.username.isNotEmpty
                ? '@${contact.username}'
                : contact.email,
            style: const TextStyle(fontSize: 11, color: AppColors.primaryBlue),
          ),
          onTap: () => Navigator.of(context).pop(contact),
        );
      },
    );
  }
}

/// Heure d'envoi, ou chaîne vide si l'horodatage est illisible : mieux vaut une
/// bulle sans heure qu'une exception au milieu du fil.
String formatClock(String raw) {
  final parsed = DateTime.tryParse(raw);
  if (parsed == null) return '';
  final local = parsed.toLocal();
  String two(int value) => value.toString().padLeft(2, '0');
  return '${two(local.hour)}:${two(local.minute)}';
}

extension _FirstOrNull<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
