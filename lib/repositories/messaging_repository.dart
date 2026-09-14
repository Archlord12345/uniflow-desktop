import 'dart:convert';

import 'package:appwrite/appwrite.dart';
// `appwrite.dart` n'exporte pas les modèles : `Execution` vit dans `models.dart`.
import 'package:appwrite/models.dart' as models;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/appwrite_provider.dart';
import '../services/appwrite_service.dart';

/// Un message dans un fil de discussion.
///
/// `from` est calculé par la fonction Appwrite relativement à l'appelant : le
/// client n'a donc pas à comparer les identifiants pour savoir de quel côté
/// afficher la bulle.
class ChatMessage {
  final String id;
  final bool mine;
  final String text;
  final String time;
  final String senderId;

  ChatMessage({
    required this.id,
    required this.mine,
    required this.text,
    required this.time,
    required this.senderId,
  });

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    return ChatMessage(
      id: json['id'] ?? '',
      mine: json['from'] == 'me',
      text: json['text'] ?? '',
      time: json['time'] ?? '',
      senderId: json['senderId'] ?? '',
    );
  }
}

/// Un contact de l'annuaire, tel que renvoyé par `search` et `open`.
class ChatContact {
  final String userId;
  final String name;
  final String email;
  final String username;
  final String avatarFileId;
  final String role;

  ChatContact({
    required this.userId,
    required this.name,
    required this.email,
    required this.username,
    required this.avatarFileId,
    required this.role,
  });

  factory ChatContact.fromJson(Map<String, dynamic> json) {
    return ChatContact(
      userId: json['userId'] ?? '',
      name: json['name'] ?? '',
      email: json['email'] ?? '',
      username: json['username'] ?? '',
      avatarFileId: json['avatarFileId'] ?? '',
      role: json['role'] ?? '',
    );
  }
}

class Conversation {
  final String id;
  final String name;
  final String role;
  final String email;

  /// Pseudo du correspondant : c'est le référent affiché, l'email ne servant
  /// plus que de repli pour les comptes antérieurs au backfill.
  final String username;
  final String avatarFileId;
  final bool online;
  final String lastMessage;
  final String time;
  final int unread;
  final List<ChatMessage> messages;

  Conversation({
    required this.id,
    required this.name,
    required this.role,
    required this.email,
    required this.username,
    required this.avatarFileId,
    required this.online,
    required this.lastMessage,
    required this.time,
    required this.unread,
    required this.messages,
  });

  /// Libellé du correspondant : le pseudo s'il existe, l'email sinon.
  String get handle => username.isNotEmpty ? '@$username' : email;

  factory Conversation.fromJson(Map<String, dynamic> json) {
    final rawMessages = json['messages'];
    return Conversation(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      role: json['role'] ?? '',
      email: json['email'] ?? '',
      username: json['username'] ?? '',
      avatarFileId: json['avatarFileId'] ?? '',
      online: json['online'] ?? false,
      lastMessage: json['preview'] ?? '',
      time: json['time'] ?? '',
      unread: json['unread'] ?? 0,
      messages: rawMessages is List
          ? rawMessages
              .whereType<Map>()
              .map((item) => ChatMessage.fromJson(Map<String, dynamic>.from(item)))
              .toList()
          : const [],
    );
  }
}

/// Erreur portant le message rédigé par la fonction Appwrite.
///
/// La fonction distingue déjà « pseudo introuvable », « conversation qui ne vous
/// appartient pas » ou « accès refusé » : ces textes sont destinés à
/// l'utilisateur et ne doivent pas être remplacés par un message générique.
class MessagingException implements Exception {
  final String message;
  final String code;
  MessagingException(this.message, {this.code = ''});
  @override
  String toString() => message;
}

class MessagingRepository {
  final AppwriteService _service;
  static const String functionId = 'messaging';

  MessagingRepository(this._service);

  /// Exécute la fonction et renvoie la charge utile JSON.
  ///
  /// Le corps est analysé même lorsque le statut d'exécution n'est pas
  /// `completed` : Appwrite marque l'exécution en échec dès que la fonction
  /// répond avec un code 4xx, alors que le corps contient justement le message
  /// explicite à montrer à l'utilisateur.
  Future<Map<String, dynamic>> _invoke(Map<String, dynamic> payload) async {
    final models.Execution execution;
    try {
      execution = await _service.functions.createExecution(
        functionId: functionId,
        body: jsonEncode(payload),
        xasync: false,
      );
    } on AppwriteException catch (error) {
      throw MessagingException(
        error.code == 404
            ? 'La fonction « messaging » n\'est pas déployée sur Appwrite.'
            : 'Appwrite a refusé l\'appel (code ${error.code}).',
        code: 'EXECUTION_FAILED',
      );
    }

    Map<String, dynamic>? data;
    try {
      final decoded = jsonDecode(execution.responseBody);
      if (decoded is Map<String, dynamic>) data = decoded;
    } catch (_) {
      data = null;
    }

    if (data == null) {
      throw MessagingException(
        'La messagerie a répondu de façon inattendue (${execution.status}).',
        code: 'BAD_RESPONSE',
      );
    }
    if (data['ok'] != true) {
      throw MessagingException(
        data['message'] ?? 'La messagerie a échoué.',
        code: data['code'] ?? '',
      );
    }
    return data;
  }

  Future<List<Conversation>> getConversations() async {
    final data = await _invoke({'action': 'list'});
    final list = data['conversations'];
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((item) => Conversation.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  /// Retrouve des contacts par pseudo, nom ou email (au moins deux caractères).
  Future<List<ChatContact>> searchContacts(String query) async {
    final term = query.trim().replaceFirst(RegExp(r'^@'), '');
    if (term.length < 2) return const [];
    final data = await _invoke({'action': 'search', 'query': term});
    final list = data['contacts'];
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((item) => ChatContact.fromJson(Map<String, dynamic>.from(item)))
        .toList();
  }

  /// Ouvre — en la créant au besoin — la conversation avec un pseudo.
  Future<Conversation> openByUsername(String username) async {
    final data = await _invoke({
      'action': 'open',
      'username': username.trim().replaceFirst(RegExp(r'^@'), ''),
    });
    final conversation = data['conversation'];
    if (conversation is! Map) {
      throw MessagingException('Conversation illisible.');
    }
    return Conversation.fromJson(Map<String, dynamic>.from(conversation));
  }

  /// Marque comme lus les messages reçus et renvoie le nombre effectivement
  /// mis à jour.
  Future<int> markRead(String conversationId) async {
    final data = await _invoke({'action': 'read', 'conversationId': conversationId});
    return data['markedRead'] ?? 0;
  }

  /// Envoie un message et renvoie la conversation à jour.
  Future<Conversation> sendMessage(String conversationId, String text) async {
    final data = await _invoke({
      'action': 'send',
      'conversationId': conversationId,
      'text': text,
    });
    final conversation = data['conversation'];
    if (conversation is! Map) {
      throw MessagingException('Message envoyé, mais la conversation est illisible.');
    }
    return Conversation.fromJson(Map<String, dynamic>.from(conversation));
  }
}

final messagingRepositoryProvider = Provider<MessagingRepository>((ref) {
  final service = ref.watch(appwriteServiceProvider);
  return MessagingRepository(service);
});

/// Liste des conversations, rechargée à la demande.
final conversationsProvider = FutureProvider<List<Conversation>>((ref) {
  return ref.watch(messagingRepositoryProvider).getConversations();
});
