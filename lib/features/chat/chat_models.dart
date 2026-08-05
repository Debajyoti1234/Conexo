library;

/// Immutable UI models for the Connections inbox (Phase 6.1).
///
/// UI preview data only — no messaging, no business logic, no persistence.
/// Everything here is const-constructible so tiles rebuild cheaply.

/// Whether a conversation is a one-to-one private chat or a plan group chat.
enum ConversationType {
  private,
  group,
}

/// Presence of a connection, purely for the inbox status affordance.
enum ConversationStatus {
  /// The person is currently active.
  online,

  /// Not active right now.
  offline,

  /// A freshly formed connection (shown as a subtle "New" accent).
  recentlyConnected,
}

/// A small hint about the last message so the preview line can show a
/// matching leading glyph. Not messaging — just a display hint.
enum LastMessageType {
  text,
  plan,
  connectionAccepted,
  voiceNote,
  photo,
}

/// A single row in the Connections inbox.
///
/// Immutable. Carries only what the UI needs to render a premium tile.
class ConversationPreview {
  const ConversationPreview({
    required this.id,
    required this.name,
    required this.avatarAsset,
    required this.lastMessage,
    required this.timestamp,
    this.type = ConversationType.private,
    this.status = ConversationStatus.offline,
    this.lastMessageType = LastMessageType.text,
    this.unreadCount = 0,
    this.isTyping = false,
    this.isPinned = false,
    this.isMuted = false,
    this.isVerified = false,
  });

  /// Stable identifier (used for [ValueKey]s and routing intent).
  final String id;

  /// Display name of the connection.
  final String name;

  /// Whether this is a private one-to-one chat or a plan group chat.
  final ConversationType type;

  /// Local portrait asset path (reuses the existing demo portraits).
  final String avatarAsset;

  /// The preview line of the most recent message.
  final String lastMessage;

  /// A short, already-formatted relative time (e.g. "2m", "1h", "Tue").
  final String timestamp;

  /// Current presence for the status affordance.
  final ConversationStatus status;

  /// Hint used to pick the preview glyph.
  final LastMessageType lastMessageType;

  /// Number of unread messages (0 = none).
  final int unreadCount;

  /// Whether the connection is currently typing.
  final bool isTyping;

  /// Whether this conversation is pinned to the top.
  final bool isPinned;

  /// Whether notifications are muted for this conversation.
  final bool isMuted;

  /// Whether the connection carries a verified badge.
  final bool isVerified;

  /// Convenience: whether there are any unread messages.
  bool get hasUnread => unreadCount > 0;

  /// Convenience: whether this conversation is a plan group chat.
  bool get isGroup => type == ConversationType.group;
}
