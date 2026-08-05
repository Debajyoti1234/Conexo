import 'demo_chat_data.dart';
import 'chat_models.dart';

/// The single data source for the Connections inbox (Phase 6.1).
///
/// Intentionally simple: demo data only. No interfaces, no dependency
/// injection, no persistence, no networking. A future backend can replace
/// this class wholesale when messaging arrives.
class LocalChatRepository {
  const LocalChatRepository();

  /// Loads the demo conversations. Kept async so a real source can slot in
  /// later without changing call sites.
  Future<List<ConversationPreview>> loadConversations() async {
    // A tiny delay lets the inbox show its premium loading skeleton briefly.
    await Future<void>.delayed(const Duration(milliseconds: 450));
    return demoConversations;
  }
}
