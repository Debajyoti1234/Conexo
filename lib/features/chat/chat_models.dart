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
  this.otherUserId,
  this.availabilityStatus,
  this.otherUserCreatedAt,
  this.otherUserUpdatedAt,
  this.planId,
});

  final String id;
  final String name;
  final ConversationType type;
  final String avatarAsset;
  final String lastMessage;
  final String timestamp;
  final ConversationStatus status;
  final LastMessageType lastMessageType;
  final int unreadCount;
  final bool isTyping;
  final bool isPinned;
  final bool isMuted;
  final bool isVerified;
  final String? otherUserId;
  final String? availabilityStatus;
  final DateTime? otherUserCreatedAt;
  final DateTime? otherUserUpdatedAt;
  final String? planId;

  bool get hasUnread => unreadCount > 0;
  bool get isGroup => type == ConversationType.group;
}
