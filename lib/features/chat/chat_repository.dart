import 'demo_chat_data.dart';
import 'chat_models.dart';
import 'message_models.dart';

/// The single data source for Chat (Phases 6.1–6.2).
///
/// Intentionally simple: demo data only. No interfaces, no dependency
/// injection, no persistence, no networking. A future backend can replace
/// this class wholesale when real messaging arrives.
class LocalChatRepository {
  const LocalChatRepository();

  /// Loads every demo conversation (both tabs). Kept async so a real source
  /// can slot in later without changing call sites.
  Future<List<ConversationPreview>> loadConversations() async {
    // A tiny delay lets the inbox show its premium loading skeleton briefly.
    await Future<void>.delayed(const Duration(milliseconds: 450));
    return demoConversations;
  }

  /// Loads only private one-to-one chats for the **Connections** tab.
  Future<List<ConversationPreview>> loadConnectionConversations() async {
    await Future<void>.delayed(const Duration(milliseconds: 450));
    return demoConversations
        .where((c) => c.type == ConversationType.private)
        .toList();
  }

  /// Loads only plan group chats for the **Plans** tab.
  Future<List<ConversationPreview>> loadPlanConversations() async {
    await Future<void>.delayed(const Duration(milliseconds: 450));
    return demoConversations
        .where((c) => c.type == ConversationType.group)
        .toList();
  }

  /// Loads the message thread for a conversation (chronological order).
  /// Returns an empty list for conversations with no seeded history.
  Future<List<Message>> loadMessages(String conversationId) async {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return demoMessageThreads[conversationId] ?? const <Message>[];
  }

  /// Loads group metadata for a plan group chat, or null for private chats.
  Future<GroupMetadata?> loadGroupMetadata(String conversationId) async {
    await Future<void>.delayed(const Duration(milliseconds: 200));
    return demoGroupMetadata[conversationId];
  }
}
